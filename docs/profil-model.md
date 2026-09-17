# Empat profil model

Setiap harness — Grok, Oh My Pi, dan pi — memakai **nama yang sama** untuk empat
profil yang sama. Yang membedakan keempatnya hanya satu hal: **siapa yang memilih
server.**

| profil | endpoint | routing | failover |
| :--- | :--- | :--- | :---: |
| `cooper-agent` | `/api/v1` | gateway yang memilih | **ya** |
| `cooper-s1` | `/api/v1/upstream/s1` | dipaksa ke server 1 | tidak |
| `cooper-s2` | `/api/v1/upstream/s2` | dipaksa ke server 2 | tidak |
| `cooper-s3` | `/api/v1/upstream/s3` | dipaksa ke server 3 | tidak |

**Sehari-hari pakai `cooper-agent`.** Gateway memilih node dengan slot lowong
terbanyak, dan memindahkan sesi bila satu node penuh atau mati.

`cooper-s1`, `cooper-s2`, dan `cooper-s3` adalah **alat pembanding**. Gunanya
menjawab pertanyaan seperti "apakah kuantisasi di s2 menurunkan kualitas
jawaban?" — kirim prompt yang sama ke node yang dibandingkan.

> **Sesi yang memakai profil langsung KEHILANGAN failover.** Bila node itu
> penuh, permintaan mengantre; bila mati, permintaan gagal — ia tidak berpindah.
> Itu bukan cacat, itu memang gunanya: perbandingan yang diam-diam dialihkan ke
> node lain tidak membandingkan apa pun.

## Alamat bukan bagian dari pilihan ini

LAN, VPN, dan localhost adalah pertanyaan yang berbeda — soal **cara mencapai**
gateway, bukan soal node mana yang menjawab. Ia dijawab sekali saat setup:

```bash
./setup.sh --endpoint lan      # atau vpn, local, atau URL lengkap
./setup.sh --endpoint          # tanpa nilai: pilih dari daftar
```

Daftar alamatnya **datang dari gateway**, bukan dari tabel di repo ini. Lihat
`cooperagent.endpoints` pada `GET /v1/models`. Repo ini publik, dan alamat
internal yang pernah masuk riwayat git tidak bisa dilupakan.

Sampai 12 September 2026 `localhost` adalah profil model tersendiri
(`internal-qwen-localhost`, `cooperagent-localhost`). Itu mencampur dua sumbu:
dev di host GPU mendapat profil terpisah yang harus dijaga sinkron dengan yang
lain setiap kali kontrak berubah.

## Kalau Anda sudah terpasang sebelum 12 September 2026

Jalankan **salah satu** dari empat jalur — keempatnya bermigrasi dengan cara
yang sama sejak 12 September 2026:

| jalur | untuk siapa |
| :--- | :--- |
| `./scripts/setup-dev.sh` | pembaru, dev Unix/macOS yang sudah terpasang |
| `.\scripts\setup-dev.ps1` | pembaru, dev Windows yang sudah terpasang |
| `./setup.sh` → **opsi 1** | onboarding Unix/macOS |
| `.\setup.ps1` → **opsi 1** | onboarding Windows |

Migrasinya otomatis:

- **Grok** — `[model.internal-qwen]` diganti nama menjadi `[model.cooper-agent]`
  **di tempat**, dan `-s2` menjadi `[model.cooper-s2]`. Isinya ikut terbawa:
  `api_key`, `base_url` pilihan Anda, dan kunci apa pun yang Anda tambahkan.
  `[model.internal-qwen-localhost]` **tidak** diganti — tidak ada padanannya, dan
  menghapus config yang masih bekerja bukan tugas pembaru. Ia dilaporkan sebagai
  kini di luar kelolaan CooperAgent; hapus sendiri bila tidak dipakai.
- **omp** — provider yang hilang **ditambahkan**; yang sudah ada tidak disentuh
  sama sekali, termasuk endpoint yang Anda sunting dan kunci berbayar Anda.
- **pi** — sama, lewat merge JSON.

Satu hal yang **tidak** bisa dimigrasikan: bila harness Anda menyimpan pilihan
model di UI-nya, nama lama tidak lagi ada. Pilih `cooper-agent` sekali.

## Kenapa rename, bukan sekadar menambah yang baru

Meninggalkan seksi lama merusak dua hal, dan keduanya diam:

1. **`api_key` hidup di seksi lama.** Seksi baru lahir tanpa kunci, dan tanpa
   `--token` tidak ada yang mengisinya — Grok menjawab 401 pada profil yang baru
   saja dianjurkan pemasang.
2. **Verifikasi membaca `context_window` PERTAMA** yang ditemukan. Seksi lama
   berada lebih dulu di berkas, jadi angkanya yang basi yang terbaca, dan
   pemasang mencetak tanda centang untuk nilai yang salah — persis kelas
   kegagalan yang `docs/versioning.md` sebut sebagai paling berbahaya.

## Menambahkan node baru

Tidak ada mekanisme otomatis — profil `cooper-s<N>` untuk node baru harus
ditambahkan dengan tangan, mengikuti pola persis `cooper-s1`/`cooper-s2`
(`/api/v1/upstream/s<N>`), di **setiap** tempat yang didaftar di
"## Apa yang menjaga keseragamannya" di bawah. `MANAGED_SECTIONS` di `setup.sh`
dan `setup.ps1`, serta daftar provider terkelola di `scripts/lib/omp_models.sh`
dan `scripts/lib/PiModels.ps1`/`pi_verify.sh`, semuanya daftar statis — tidak
ada yang membaca `cooperagent.upstreams` dari `GET /v1/models` untuk
menghasilkan profil secara dinamis.

## Apa yang menjaga keseragamannya

Definisi profil hidup di **tujuh** tempat:

| berkas | perannya |
| :--- | :--- |
| `templates/config.toml` | Grok, jalur pembaruan |
| `templates/omp-models.yml` | omp |
| `templates/pi-models.json` | pi |
| `setup.sh` | salinan inline + migrasi, jalur onboarding Unix |
| `setup.ps1` | salinan inline + migrasi, jalur onboarding Windows |
| `scripts/setup-dev.sh` | migrasi, jalur pembaruan Unix |
| `scripts/setup-dev.ps1` | migrasi, jalur pembaruan Windows |

Ketika keenamnya menyimpang, **tidak ada satu berkas pun yang salah** — yang
salah adalah selisihnya. Itu jenis kegagalan yang tidak pernah muncul sebagai
galat: ia hanya membuat dev yang berpindah harness menemukan nama yang berbeda,
atau tidak menemukan profil sama sekali.

`test/test-harness-profiles.sh` membandingkan kelimanya terhadap daftar yang
sama, lalu memeriksa tiga hal yang gagal secara diam-diam bila terlewat:

- **Profil langsung benar-benar menunjuk `/upstream/sN`.** Yang menyalin
  endpoint auto-routing bukan alat banding — ia ikut routing, dan hasil
  bandingnya bohong tanpa ada yang tahu.
- **Peringatan kehilangan failover ikut tersalin.** Memindahkan konfigurasi
  tanpa peringatannya berarti memindahkan jebakannya saja.
- **Tidak ada IPv4 internal di jalur pemasang** (aturan #1 `AGENTS.md`).

Sejak 12 September 2026 ia juga **menjalankan** migrasi `setup.sh`, bukan
sekadar memeriksa bahwa kodenya ada: `write_grok_config` dijalankan atas config
lama di kotak pasir, lalu hasilnya diperiksa. Sampai saat itu hanya
`scripts/setup-dev.sh` yang bermigrasi — kedua pemasang membaca
`[model.cooper-agent]` saja, jadi dev yang belum bermigrasi kehilangan alamatnya
dan ditanyai ulang alamat yang sebenarnya sudah ia jawab, lalu ditinggali seksi
yatim di sebelah seksi baru. Jalur pemasangan yang memperlakukan config lama
secara berbeda adalah perilaku yang harus dijaga sinkron dengan tangan, jadi
ujinya sekarang menuntut **keempatnya** memuat rename yang sama.

`scripts/setup-dev.ps1` sempat terlewat justru pada hari jalur lain diperbaiki —
padahal itulah jalur yang `docs/dev_setup.md` anjurkan kepada dev Windows yang
**sudah** terpasang, yakni satu-satunya populasi yang pasti memegang config
lama. Ujinya kini menuntut `[model.cooper-agent]` sebagai literal sesudah
`internal-qwen`, bukan sekadar kedua kata di satu baris: berkas itu punya regex
penyuntik token yang menyebut keduanya sekaligus dan tidak mengganti apa pun —
pola yang longgar akan lulus tanpa ada yang bermigrasi.

Migrasinya menulis ke berkas **sementara** (`$source` pada jalur PowerShell),
lalu merge membandingkannya dengan config asli. Urutan itu bukan gaya penulisan: menulis rename lebih dulu membuat
cadangan `.bak` merekam berkas yang sudah terlanjur berubah — cadangan yang
tidak bisa dipakai mundur, dan itu baru ketahuan saat seseorang membutuhkannya.

`test/test-omp-providers.sh` menjaga sisi yang berlawanan: provider yang hilang
memang ditambahkan, **dan** kunci berbayar dev tetap selamat. Menambal yang
pertama dengan cara yang melanggar yang kedua adalah kemunduran, bukan
perbaikan.

### Yang belum terjaga

Jalur PowerShell tidak dapat dijalankan pada runner Linux — `pwsh` tidak
terpasang. `scripts/lib/PiModels.ps1` dan `setup.ps1` diubah mengikuti cerminan
jalur Node, dan `test/Test-PiModels.ps1` sudah menuntut ketiga profil, tetapi
keduanya menunggu verifikasi di Windows.

### Penjagaan statis untuk jalur PowerShell

`test/test-credential-gate.sh` memeriksa keseimbangan kurung setiap berkas
`.ps1`. `PiModels.ps1` dan `Test-PiModels.ps1` ditambahkan ke daftar itu pada
12 September 2026 — keduanya berkas PowerShell yang paling sering disunting dari
mesin Linux, tempat `pwsh` tidak terpasang.

Ia tidak membuktikan berkasnya berjalan. Ia hanya menutup penyebab kegagalan
yang paling mungkin dari suntingan struktural, dan menutupnya di tempat yang
bisa dijalankan setiap hari alih-alih menunggu seorang dev Windows menemukannya.
