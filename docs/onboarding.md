# Onboarding dev — alur lengkap

> **Alamat gateway tidak ditulis di dokumen ini.** Ia ada di blok serah-terima
> yang Anda terima bersama token (`cooper issue`), dan disajikan gateway sendiri
> pada `GET /v1/models` di bawah kunci `cooperagent.endpoints`. Contoh di bawah
> memakai `<gateway>` — ganti dengan alamat Anda.


Satu skrip untuk keduanya: pemasangan pertama **dan** pembaruan.

```bash
./setup.sh --token ca_...        # Linux · macOS · WSL
.\setup.ps1 -Token ca_...        # Windows
```



---

## Port: **8987**, selalu

```
✔  http://<gateway>:8987     gateway — satu-satunya pintu
✘  http://<gateway>:8001     mesin — TERTUTUP
```

Port `:8001` ditutup firewall di kedua server **dan** menuntut kunci internal.
Mengetuknya dari mesin lain tidak menghasilkan apa-apa (timeout), dan itu
disengaja: lewat sana berarti melewati kredensial, telemetri, routing, dan
failover sekaligus.

`:8987` yang memberi Anda: pemilihan server otomatis, failover kalau satu mesin
sibuk, dan pemakaian yang tercatat atas nama Anda.

---

## Langkah 0 — minta token ke admin

Tanpa token, apa pun yang Anda pasang akan dijawab **401**. Sebutkan **nama
perangkat** — token terikat satu perangkat, jadi laptop dan PC kantor mendapat
token berbeda.

Admin menjalankan `cooper issue <nama> <device>` dan mengirimkannya lewat kanal
pribadi. **Token hanya ditampilkan sekali.**

---

## A. Pertama kali memasang

```bash
git clone https://github.com/LyKhan77/CooperAgent-cli.git
cd CooperAgent-cli
./setup.sh --token ca_...
```

Yang ditanyakan, berurutan:

1. **Coding agent mana** — Grok, omp, keduanya, atau **manual** (pakai punya
   Anda sendiri: Cursor, Continue, aider, Cline, …)
2. **Token** — hanya bila belum diberikan lewat `--token`
3. **Endpoint** — LAN kantor, VPN, atau localhost

**Nama dan perangkat tidak ditanyakan.** Keduanya berasal dari token:

```
[v] Identitas dari token: lee@laptop-tuf
    Inilah yang tercatat di dashboard — tidak perlu diketik.
```

Gateway mencatat identitas dari **token**, bukan dari config klien. Sampai
1 September 2026 skrip ini tetap menanyakannya — jawaban yang tidak pernah
dipakai untuk apa pun, dan yang membingungkan: dev yang mengetik `laptop`
sementara tokennya diterbitkan untuk `laptop-tuf` melihat `laptop-tuf` di
dashboard tanpa penjelasan.

Prompt manual hanya muncul bila token tidak diberikan, atau gateway tidak
terjangkau saat setup berjalan.

### Tanpa `--token`

Skrip **menanyakannya**, dan menyebut perintah yang perlu dijalankan admin:

```
--- Token CooperAgent ---
Gateway menuntut token. Minta ke admin bila belum punya:
  cooper issue lee laptop
Tempel token (ca_...), atau Enter untuk melewati:
```

Bentuknya divalidasi sebelum apa pun ditulis — token yang terpotong saat
disalin ditolak dengan menyebut panjang yang diterima, bukan dibiarkan menjadi
401 yang tidak jelas sebabnya nanti.

Menekan Enter **melewatinya**: agent tetap dipasang, tapi skrip mengatakan
terus terang bahwa config yang ditulis akan ditolak, beserta cara
menambahkannya nanti. Berguna saat Anda ingin memasang agent dulu sambil
menunggu token dari admin.

Kalau config Anda **sudah** memuat token, ia dipertahankan tanpa bertanya —
menjalankan ulang setup untuk memperbarui parameter tidak menuntut token
ditempel ulang.

Lalu skrip memasang agent bila diminta, menulis config, menyalin aturan kerja
dan skill `/handoff`, dan menyetel ambang compaction.

**Mulai sesi baru setelah selesai** — agent membaca config saat start.

---

## B. Sudah pernah memasang

Perintah yang **sama persis**:

```bash
git pull
./setup.sh --token ca_...
```

Ia mendeteksi apa yang sudah ada dan menawarkan tiga pilihan:

```
1) Perbarui parameter CooperAgent saja   [disarankan]
   Endpoint dan identitas dipertahankan. Milik Anda tidak disentuh.
2) Ganti endpoint saja
3) Tulis ulang penuh dari template
```

Pilihan **1** adalah yang normal. Server MCP, seksi `[ui]`, dan model tambahan
yang Anda tambahkan sendiri **tidak disentuh** — skrip hanya mengelola kunci
yang memang miliknya, dan menyebutkan apa yang di luar kelolaannya sebelum
Anda memilih.

Cadangan selalu dibuat, apa pun pilihannya.

### Hanya berpindah jaringan

```bash
./setup.sh --endpoint vpn       # atau: lan · local · <url>
```

Tidak ada prompt, tidak ada pemasangan. Identitas dibaca ulang dari config yang
ada — berpindah jaringan tidak mengubah siapa Anda.

### Hanya mengganti token

```bash
./scripts/setup-dev.sh --token ca_...
```

Memperbarui `api_key` di config Grok **dan** `models.yml` omp, lalu memverifikasi
hasilnya. Dipakai saat admin memutar token Anda.

---

## C. Memakai coding agent Anda sendiri

Pilih **opsi 4** saat ditanya. Tidak ada yang dipasang; skrip mencetak tiga
nilai yang Anda butuhkan:

```
Base URL   http://<gateway>:8987/v1
API key    ca_...
Model      intercon-agent
```

Isikan ke alat apa pun yang bisa bicara ke OpenAI. Pilih penyedia
**OpenAI-compatible** — bukan "OpenAI", karena itu memaksa `api.openai.com`.

Cetak ulang kapan saja: `./setup.sh --info`

**Yang tidak Anda dapat tanpa harness:** ambang compaction otomatis, `/handoff`,
dan aturan agent. Pemakaian tetap tercatat — itu melekat pada token.

Selengkapnya: [`docs/api_langsung.md`](api_langsung.md), termasuk jebakan
`max_tokens` yang akan menggigit lebih dulu.

---

## Kalau ditolak

| Kode | Artinya | Yang dilakukan |
| :-- | :-- | :-- |
| **401** `unknown_dev` | token salah, dicabut, atau tidak dikirim | minta admin menerbitkan ulang |
| **401** `missing_device` | masih memakai identitas lama `nama@device` | jalankan setup dengan `--token` |
| **503** `maintenance` | gateway sengaja ditutup | tunggu; `Retry-After` menyebut perkiraan |
| jawaban **kosong** | `max_tokens` terlalu kecil | beri minimal ~2000 — model berpikir dulu |

Token hilang tidak bisa dibaca ulang: admin mencabut lalu menerbitkan ulang.

---

## Yang dikelola skrip, dan yang bukan

| Berkas | Dikelola |
| :-- | :-- |
| `~/.grok/config.toml` | hanya seksi CooperAgent; sisanya milik Anda |
| `~/.omp/agent/models.yml` | `apiKey` dan `baseUrl` gateway; provider lain tidak disentuh |
| `~/.cooper/skills/` | skill CooperAgent |
| `AGENTS.md` di proyek | hanya bila Anda memintanya |

Yang **tidak pernah** disentuh: server MCP, `[ui]`, model tambahan, provider
pihak ketiga (Anthropic, Ollama), dan skill Anda sendiri di `~/.grok/skills/`.
