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
   Pilihan tambahan **5) Pi Agent (`pi`)** memasang harness Node.js dengan
   adapter dan verifikasi CooperAgent.
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

Prompt manual hanya muncul bila token **tidak diberikan sama sekali**.

### Aturan agent bersifat opsional

Sebelum aturan ditulis, skrip **bertanya** — dengan default "ya":

```
--- Aturan kerja agent (CooperxHarness) ---
  Aturan global: checkpoint, surgical changes, goal-driven execution.
  Ukuran: 5980 karakter, dipasang ke rumah harness yang dipilih:
  ~/.grok/, ~/.omp/agent/, atau ~/.pi/agent/.
  Opsional. Anda boleh memakai aturan sendiri, atau tanpa aturan sama sekali.
  Skill CooperAgent tetap dipasang apa pun jawabannya.
Pasang aturan CooperAgent? [Y/n]:
```

Menekan Enter memberi hasil yang sama seperti sebelumnya. Menjawab `n` berguna
bila Anda sudah punya aturan harness sendiri, atau memang ingin agent mentah.

Pertanyaan ini **hanya muncul sekali**: bila `AGENTS.md` sudah ada, skrip
menganggap pilihannya sudah dibuat dan langsung memperbaruinya. Untuk memaksa,
pakai `--rules` / `--no-rules` / `--remove-rules` (`-Rules` / `-NoRules` /
`-RemoveRules` di PowerShell).

### Skill yang dipasang

Dua, keduanya ke Grok **dan** omp, dan keduanya terpasang apa pun jawaban Anda
soal aturan di atas:

| Skill | Untuk apa |
| :-- | :-- |
| `/cooper-handoff` | menyerahkan sesi saat context hampir penuh — menulis checkpoint, tidak meringkas percakapan |
| `/cooper-structure` | menyarankan struktur project: membaca codebase, menawarkan **beberapa kandidat** kombinasi pola, Anda memilih dan menyesuaikan, lalu ia menulis rencana migrasi ke `.cooper/structure/rencana.md` |

`/cooper-structure` **tidak pernah memindahkan berkas.** Ia menulis rencana;
mengeksekusinya keputusan Anda.

Sampai 3 September 2026 skill handoff bernama `/handoff`. Nama lama dihapus
otomatis saat Anda memperbarui, supaya tidak ada dua skill kembar.

### Gerbang kredensial

Sebelum satu berkas pun ditulis, skrip menanyakan token Anda ke
`/api/auth/whoami` pada gateway yang Anda pilih. Kalau jawabannya bukan "sah",
setup **berhenti** — dengan kode keluar `3` dan sebab yang spesifik:

```
[x] Kredensial tidak lolos pemeriksaan.
    Token DITOLAK gateway (401): kredensial telah DICABUT.
    Ini bukan salah ketik — admin mencabutnya di sisi server.
    Minta penerbitan ulang ke pemilik gateway:
        cooper issue <nama> <device>

    Tidak ada satu berkas pun yang ditulis.
```

Empat sebab dibedakan, karena jalan keluarnya berbeda:

| Sebab | Artinya | Yang perlu dilakukan |
| :--- | :--- | :--- |
| bentuk salah | bukan `ca_` + 48 heksadesimal | periksa salinan, minta ulang |
| gateway tak menjawab | jaringan atau alamat | nyalakan VPN, periksa alamat |
| token tidak dikenal | tidak ada di gateway | `cooper issue <nama> <device>` |
| kredensial dicabut | admin mencabutnya | minta penerbitan ulang |

Sampai 3 September 2026 pemeriksaan ini ada tapi kegagalannya **ditelan**:
ketiganya jatuh diam-diam ke prompt "ketik nama dan device Anda", setup berjalan
sampai akhir, dan config yang ditulis pasti dijawab 401 — yang baru ditemukan
saat mencoba bekerja.

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
dan skill (`/cooper-handoff`, `/cooper-structure`), dan menyetel ambang compaction.

**Mulai sesi baru setelah selesai** — agent membaca config saat start.

---


### Pi Agent sebagai harness tambahan

Pi tidak dipasang atau dipilih secara default. Pilih **5** pada onboarding untuk
memasang `@earendil-works/pi-coding-agent`; pilihan itu tidak menjalankan
installer Grok maupun omp. Jalur langsungnya adalah:

```bash
./scripts/setup-pi.sh --endpoint <gateway> --token ca_... --rules
```

Adapter menulis `~/.pi/agent/models.json` dan `settings.json` secara merge.
Provider/kunci berbayar, model tambahan, default provider, tema, dan
`keepRecentTokens` milik dev dipertahankan. `reserveTokens` dihitung dari
`context_window - threshold_tokens` yang diumumkan gateway, sehingga compaction
pi mengikuti ambang CooperAgent tanpa angka server dipatok di klien.

Sebelum konfigurasi ditulis, token diperiksa ke `/api/auth/whoami`; bentuk
`dev-<nama>@<device>` ditolak. Sesudahnya `verify()` melakukan chat lewat pi,
membuktikan pi membaca `~/.pi/agent/AGENTS.md`, dan membuat
`.cooper/context/<slug>.md` pada proyek sementara. Identitas yang diverifikasi
adalah `devName@device` dari gateway. Repo ini tidak mendefinisikan endpoint
leaderboard terpisah, jadi `/whoami` adalah bukti identitas gateway yang tersedia.
## B. Sudah pernah memasang

Perintah yang **sama persis**:

```bash
git pull
./setup.sh --token ca_...
```

Mesin yang **sudah terpasang tidak diseret ke onboarding**. Skrip menampilkan
keadaannya, memeriksa ulang kredensial ke gateway, lalu menawarkan enam pilihan:

```
=================================================================
   CooperAgent — sudah terpasang di mesin ini
=================================================================
  gateway   : http://<host>:8987/api/v1
  harness   : Grok Build, Oh My Pi (omp) (Pi Agent bila dipilih)
  identitas : lee@laptop-tuf (peran: dev)
  kredensial: sah — diverifikasi ke gateway barusan
  kontrak   : context 131.072 · output 12.288 · compact 80% · model intercon-agent

Apa yang ingin Anda lakukan?
  1) Perbarui parameter dari kontrak gateway [disarankan]
     aturan agent, skill, ambang compaction, context_window
  2) Ganti alamat gateway (pindah LAN <-> VPN)
  3) Pasang / ganti token kredensial
  4) Pasang harness tambahan (Grok / omp yang belum ada)
  5) Lepas aturan agent CooperxHarness (skill tetap terpasang)
  6) Keluar
```

Pilihan 5 berganti sendiri mengikuti keadaan: **Lepas** bila aturan terpasang,
**Pasang** bila tidak. Melepasnya **tidak menyentuh skill** — aturan adalah
pendapat tentang cara bekerja, skill adalah perkakas, dan dev yang menolak
pendapat kami tetap berhak atas perkakasnya.

Yang dilepas hanya berkas yang bisa dibuktikan milik CooperAgent. Bila
`AGENTS.md` Anda ternyata tulisan sendiri, skrip menolak menyentuhnya dan
mengatakannya. Cadangan tetap dibuat pada setiap pelepasan.

**Kredensial diperiksa setiap kali**, bahkan ketika Anda hanya ingin memperbarui
parameter. Pencabutan terjadi di sisi server tanpa memberi tahu klien — kalau
bukan skrip yang bertanya, Anda baru mengetahuinya lewat 401 di tengah kerja:

```
  kredensial: DITOLAK (revoked)

    Token DITOLAK gateway (401): kredensial telah DICABUT.
```

Saat itu terjadi, tanda `[disarankan]` **berpindah ke pilihan 3** — menyarankan
"perbarui parameter" kepada dev yang kredensialnya baru ditolak berarti
menyarankan satu-satunya pilihan yang tidak memperbaiki apa pun.

Semua pilihan lama tetap bekerja untuk dev yang memasang **omp saja**. Bila pi
saja yang terpasang, alamat gateway dan kredensialnya dibaca dari
`~/.pi/agent/models.json`, dan pembaruan default diarahkan ke adapter pi —
`~/.grok/config.toml` yang tidak pernah ia punya bukan lagi syarat.

Pilihan **2** dan **3** memverifikasi lebih dulu dan **tidak menulis apa pun**
bila verifikasinya gagal — berpindah ke alamat yang tidak menjawab berarti
kehilangan gateway yang tadinya bekerja. Keduanya menyentuh **semua harness yang
terpasang**, jadi Grok dan omp tidak pernah lagi menunjuk alamat yang berbeda.

Server MCP, seksi `[ui]`, model tambahan, dan **kunci berbayar** Anda
(Anthropic, OpenAI, Ollama) tidak disentuh pada pilihan mana pun. Cadangan
selalu dibuat.

### Hanya berpindah jaringan

```bash
./setup.sh --endpoint vpn       # atau: lan · local · <url>
```

Tidak ada prompt, tidak ada pemasangan. Identitas dibaca ulang dari config yang
ada — berpindah jaringan tidak mengubah siapa Anda.

Token diverifikasi di alamat **baru** sebelum config disentuh: alamat yang tidak
menjawab ditolak dengan kode `3`, dan config lama dibiarkan utuh. `models.yml`
omp ikut berpindah — sampai 3 September 2026 hanya config Grok yang bergerak,
sehingga omp tetap menunjuk jaringan lama dan gagal sendirian.

### Hanya mengganti token

```bash
./scripts/setup-dev.sh --token ca_...
```

Memperbarui `api_key` di config Grok **dan** `models.yml` omp, lalu memverifikasi
hasilnya. Dipakai saat admin memutar token Anda.

Untuk pi, gunakan adapter terisolasi agar `models.json` dan `settings.json`
di-merge serta diverifikasi:

```bash
./scripts/setup-pi.sh --token ca_... --endpoint <gateway>
```

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

**Yang tidak Anda dapat tanpa harness:** ambang compaction otomatis, `/cooper-handoff`,
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
| `~/.pi/agent/AGENTS.md` | salinan penuh aturan, hanya pada pilihan pi atau `--rules` |
| `~/.pi/agent/models.json` | provider `cooperagent` dan model kontrak; JSON lain dipertahankan |
| `~/.pi/agent/settings.json` | compaction kontrak dan sumber skill; setting dev lain dipertahankan |
| `~/.cooper/skills/` | skill CooperAgent |
| `AGENTS.md` di proyek | hanya bila Anda memintanya |

Yang **tidak pernah** disentuh: server MCP, `[ui]`, model tambahan, provider
pihak ketiga (Anthropic, Ollama), dan skill Anda sendiri di `~/.grok/skills/`.
