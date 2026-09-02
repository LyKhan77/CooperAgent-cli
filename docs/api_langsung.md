# Memakai API tanpa harness CooperAgent

> **Alamat gateway tidak ditulis di dokumen ini.** Ia ada di blok serah-terima
> yang Anda terima bersama token (`cooper issue`), dan disajikan gateway sendiri
> pada `GET /v1/models` di bawah kunci `cooperagent.endpoints`. Contoh di bawah
> memakai `<gateway>` — ganti dengan alamat Anda.


Gateway berbicara **OpenAI Chat Completions**, jadi apa pun yang bisa bicara ke
OpenAI bisa bicara ke sini: `curl`, SDK resmi, Continue, aider, Cursor, LangChain,
skrip sendiri. Harness (Grok/omp) hanya menambahkan aturan, skill, dan ambang
compaction — ia bukan syarat.

Yang dibutuhkan TIGA hal:

```
base_url  http://<gateway>:8987/v1
api_key   token CooperAgent Anda (ca_... atau ca_ layanan)
model     intercon-agent
```

**Ketiganya, bukan hanya base URL.** Tanpa `api_key` permintaan dijawab
**401** — gateway menuntut kredensial sejak penegakan menyala. `model` boleh
diisi apa saja secara teknis (mesin mengabaikannya), tapi isi yang benar supaya
log dan galat tetap bisa dibaca.

Token diterbitkan admin — `cooper issue <nama> <device>` untuk orang,
`cooper issue <nama> <tempat> --service` untuk aplikasi internal.

---

## ⚠ Jebakan yang akan menggigit Anda lebih dulu

**Model ini berpikir sebelum menjawab.** Server berjalan dengan
`--reasoning-effort xhigh` dan `--reasoning-budget 6144`, jadi sebagian
`max_tokens` habis untuk penalaran yang **tidak muncul di `content`**.

Terukur:

```
max_tokens: 60    → content: ""        finish_reason: "length"
max_tokens: 2000  → content: "Merah."  finish_reason: "stop"
```

Pertanyaan yang sama, jawaban kosong pada yang pertama. Penalarannya ada di
`choices[0].message.reasoning_content`, bukan di `content`.

**Beri `max_tokens` minimal ~2000** untuk jawaban pendek sekalipun. Kalau
`content` kosong dan `finish_reason` `length`, itu selalu sebabnya.

---

## curl

```bash
curl http://<gateway>:8987/v1/chat/completions \
  -H "Authorization: Bearer $COOPERAGENT_TOKEN" \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "intercon-agent",
    "max_tokens": 2000,
    "messages": [{"role": "user", "content": "Sebutkan satu warna."}]
  }'
```

Streaming: tambahkan `"stream": true` — SSE standar, terverifikasi.

## Python

```python
from openai import OpenAI

client = OpenAI(
    base_url="http://<gateway>:8987/v1",
    api_key="ca_...",           # token dari admin
)

r = client.chat.completions.create(
    model="intercon-agent",
    max_tokens=2000,
    messages=[{"role": "user", "content": "Sebutkan satu warna."}],
)
print(r.choices[0].message.content)
```

## Node / TypeScript

```ts
import OpenAI from 'openai';

const client = new OpenAI({
  baseURL: 'http://<gateway>:8987/v1',
  apiKey: process.env.COOPERAGENT_TOKEN,
});

const r = await client.chat.completions.create({
  model: 'intercon-agent',
  max_tokens: 2000,
  messages: [{ role: 'user', content: 'Sebutkan satu warna.' }],
});
```

## Alat pihak ketiga

Isi tiga kolom yang sama. Kebanyakan alat menamainya `Base URL`, `API Key`, dan
`Model`. Bila alat menuntut penyedia, pilih **OpenAI-compatible** — bukan
"OpenAI", karena itu memaksa `api.openai.com`.

---

## Menanyakan batasnya, jangan mematoknya

```bash
curl -H "Authorization: Bearer $TOKEN" http://<gateway>:8987/v1/models
```

```json
{
  "data": [{ "id": "intercon-agent" }],
  "cooperagent": {
    "context_window": 131072,
    "compaction": { "threshold_percent": 80, "threshold_tokens": 104857 }
  }
}
```

`context_window` **dibaca dari slot mesin yang hidup**, bukan dari konfigurasi
statis. Kalau server mengubah `--ctx-size`, klien yang menanyakan ikut berubah;
klien yang mematok `131072` di kodenya diam-diam menjadi salah.

## Header pada setiap jawaban

```
x-upstream:          s1
x-upstream-weights:  Q8_0
x-upstream-reason:   sticky
```

Berguna saat sebuah jawaban terasa lain dari biasanya: kedua server melayani
kuantisasi berbeda (`Q8_0` di s1, `UD-Q4_K_XL` di s2), dan header ini menyebut
mana yang menjawab.

## Menembak satu server tertentu

```
/v1/upstream/s1/chat/completions
/v1/upstream/s2/chat/completions
```

Melewati routing dan **tanpa failover** — kalau server itu sibuk, permintaan
menunggu atau gagal. Untuk membandingkan kualitas antar kuantisasi, bukan untuk
pemakaian sehari-hari.

---

## Yang TIDAK Anda dapat tanpa harness

| | dengan harness | API langsung |
| :-- | :-- | :-- |
| ambang compaction | otomatis 80% | Anda kelola sendiri |
| `/handoff` dan skill | ada | tidak |
| aturan agent | dipasang | tidak |
| identitas di telemetri | otomatis | ikut, dari token |

Pemakaian tetap tercatat di `usage_logs` selama tokennya benar — itu melekat
pada kredensial, bukan pada harness.

## Bila ditolak

| Kode | Artinya |
| :-- | :-- |
| **401** `unknown_dev` | token salah, dicabut, atau tidak dikirim |
| **401** `missing_device` | identitas lama `nama@device`, bukan token |
| **503** `maintenance` | gateway sengaja ditutup; `Retry-After` menyebut perkiraan selesai |

Pesan galatnya menyebut apa yang harus dilakukan. Token yang hilang tidak bisa
dibaca ulang — minta admin `cooper revoke` lalu menerbitkan ulang.

## Akses langsung ke mesin tidak tersedia

Port `:8001` **tertutup** dari LAN dan VPN, dan mesin juga menuntut kunci
internalnya sendiri. Menembak mesin langsung akan melewati kredensial dan
telemetri, jadi itu ditutup dengan sengaja. Gateway `:8987` adalah satu-satunya
pintu.
