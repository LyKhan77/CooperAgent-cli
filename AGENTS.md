# Panduan agent — CooperAgent CLI

Repo ini adalah **pemasang klien**, bukan server. Ia berjalan di mesin orang
lain dan menulis ke berkas milik mereka. Itu satu kalimat yang menjelaskan
hampir semua aturan di bawah.

Repo server (`CooperAgent-server`) bersifat privat dan memuat control plane —
penerbitan kredensial, firewall, kunci mesin, topologi. **Tidak ada satu pun
dari itu yang boleh masuk ke sini.**

---

## Enam aturan yang tidak boleh dilanggar

### 1. Tidak ada alamat internal

Tidak ada literal IPv4 selain `127.0.0.1` di jalur pemasang. Alamat gateway
datang dari dev (blok serah-terima admin, `--endpoint`, atau
`$COOPERAGENT_GATEWAY`) dan alternatifnya dari kontrak `/v1/models`.

Repo ini publik dan **riwayat git tidak bisa dilupakan** — satu commit sudah
cukup untuk menerbitkan topologi internal selamanya. Fixture uji memakai blok
dokumentasi RFC 5737 (`198.51.100.0/24`).

Dijaga: `test/test-contract-from-gateway.sh`.

### 2. Fakta server tidak dipatok di klien

`context_window`, `max_tokens`, ambang compaction, dan nama model **hanya** boleh
berasal dari `GET /v1/models`. Nilai cadangan hidup di **satu** tempat per
platform — `scripts/lib/contract.sh` dan `scripts/lib/Contract.ps1` — dan setiap
kali dipakai, skrip **wajib mengatakannya** ("memakai nilai cadangan"), tidak
pernah diam.

Yang paling berbahaya bukan config yang salah, melainkan **verifikasi** yang
salah. Sampai 1 September 2026 `setup-dev.sh` mencocokkan config terhadap
`131072` yang dipatok di dirinya sendiri — mencetak tanda centang dengan yakin
justru saat nilainya sudah basi.

Template memakai placeholder (`__CONTEXT_WINDOW__`, `__MODEL_ID__`,
`__GATEWAY__`); yang di-merge selalu hasil render, dan
`contract_assert_rendered` menolak berkas yang masih memuatnya.

### 3. Jangan pernah menimpa milik dev

`~/.grok/config.toml` dan `~/.omp/agent/models.yml` bukan milik kita: dev
menaruh server MCP, seksi `[ui]`, model tambahan, dan **kunci berbayar**
(Anthropic, OpenAI, Ollama) di berkas yang sama.

Merge, jangan tulis-ulang. Hanya kunci yang muncul di template yang disentuh.
Ini bukan teori — pada 1 September 2026 dua bug dengan bentuk yang sama
menghapus kunci berbayar dev.

Dijaga: `test/test-setup-preserves-dev-config.sh`.

### 4. Kegagalan kredensial tidak boleh ditelan

Token diverifikasi ke `/api/auth/whoami` **sebelum satu berkas pun ditulis**, dan
kegagalannya menghentikan skrip dengan kode `3` serta sebab yang spesifik —
bentuk salah, gateway tak terjangkau, token tidak dikenal, kredensial dicabut.
Keempatnya jalan keluarnya berbeda; satu pesan untuk semuanya adalah pesan yang
tidak menolong satu pun.

Jangan pernah jatuh diam-diam ke identitas yang diketik dev sendiri. Itu bug
aslinya: sampai 3 September 2026 sebuah `catch {}` kosong membuat setup berjalan
sampai akhir, mencetak tanda centang, dan menulis config yang pasti dijawab 401.

Kredensial diperiksa **setiap kali skrip berjalan**, bukan hanya saat pertama:
pencabutan terjadi di sisi server tanpa memberi tahu klien.

Dijaga: `test/test-credential-gate.sh`.

### 5. Keluaran harus terbaca di tempat ia dibaca

Warna hanya ke terminal (`[ -t 1 ]`). `NO_COLOR` dan `TERM=dumb` dihormati.
Simbol Unicode hanya bila locale-nya UTF-8; selain itu `[v]` / `[x]`.

Terukur: satu jalankan yang diarahkan ke berkas pernah menulis 17 baris
ber-`^[[0;32m` — tepat saat dev menyalin log untuk **melaporkan** masalah.

Jangan memakai escape `\uXXXX` di bash: itu menuntut bash 4.2, sedangkan
`/bin/bash` bawaan macOS masih **3.2**. Pakai literal UTF-8 langsung.

Dijaga: `test/test-cli-output.sh`.

### 6. Satu kosakata profil untuk semua harness

Grok, omp, dan pi memakai nama yang sama: `cooper-agent`, `cooper-s1`,
`cooper-s2`. Definisinya hidup di **tujuh** tempat — tiga template, dua pemasang
yang memuat salinan inline sendiri, dan dua pembaru (Unix dan Windows).

Tidak ada satu berkas pun yang salah ketika mereka menyimpang; yang salah adalah
selisihnya, dan tidak ada uji yang melihat lebih dari satu berkas sampai
12 September 2026. Akibatnya berjalan berbulan-bulan: pi hanya punya satu dari
tiga profil, dan tidak ada harness yang bisa menembus langsung ke s1 — sehingga
perbandingan antar node berat sebelah.

Menambah profil ke template **tidak cukup** — dan itu bertahan lebih lama dari
yang diduga. Merger pi diperbaiki 12 September, tetapi `models.yml` omp tetap
hanya di-`sed` di tempat sampai **18 September 2026**: profil baru tidak pernah
sampai ke dev yang sudah terpasang, dan `cooper-s3` membuktikannya. Sejak itu omp
di-merge per kunci seperti Grok dan pi, dan `test/test-paritas-windows.sh`
membandingkan kedua implementasinya byte per byte.

Begitu pula **keempat** jalur pemasangan: dua pemasang dan dua pembaru.
Mengganti nama profil di sebagian saja meninggalkan dev di jalur lain ditanyai
ulang alamat yang sudah ia jawab, lalu ditinggali seksi yatim berisi `api_key`-
nya di sebelah seksi baru yang kosong. Yang paling mudah terlewat adalah
`scripts/setup-dev.ps1`, dan justru itu jalur yang dianjurkan kepada dev Windows
yang **sudah** terpasang — satu-satunya populasi yang pasti memegang config
lama. Setiap perubahan kosakata profil harus menyentuh keempatnya.

Dijaga: `test/test-harness-profiles.sh`, `test/test-omp-providers.sh`.
Latar: [`docs/profil-model.md`](docs/profil-model.md).

---

## Sebelum menutup pekerjaan

```bash
./scripts/pr.sh
```

Satu perintah: ia menjalankan **seluruh** suite, mem-push, lalu mencetak tautan
PR. Tidak ada daftar uji yang disalin dengan tangan ke berkas ini — daftarnya
adalah isi `test/`, dan yang membacanya `scripts/lib/uji_lokal.sh`.

Menjalankan satu uji saja tetap boleh saat sedang mengerjakannya:

```bash
bash test/test-credential-gate.sh
```

**Suite tidak dijalankan di GitHub.** Ia dijalankan di sini, dan
`scripts/hooks/pre-push` menahan push bila ada yang merah. Satu-satunya yang
berjalan di GitHub adalah parser PowerShell — karena itu yang tidak ada di mesin
ini.

Uji hermetis — masing-masing menyalakan gateway tiruannya sendiri
(`test/fixtures/fake-gateway.py`) dan bekerja di `HOME` sekali pakai. **Tidak ada
uji yang boleh menunjuk gateway produksi**: hasil yang bergantung pada keadaan
server bukan uji, melainkan pemantauan. Satu uji pernah melakukannya tanpa
disengaja, lewat fixture beralamat LAN sungguhan.

`test-setup-dev.sh` adalah pengecualian: ia memilih agent `omp`, sehingga
`setup.sh` mencoba memasangnya dari internet. Runner otomatis **melewatinya**
dan menyebutkan sebabnya. Jalankan dengan tangan bila menyentuh jalur
pemasangan. Perbaikan yang layak
dikerjakan: penjaga lingkungan `COOPERAGENT_NO_INSTALL=1` yang melewati
pemasangan agent dan hanya menulis config.


Perbarui `CHANGELOG.md` — ia **tidak** lagi terisi sendiri. Bagian bernomor satu
baris per perubahan; prosa panjangnya (konteks, bukti, dampak, cara mundur) ke
bagian **Catatan rinci**. Baca [`docs/versioning.md`](docs/versioning.md),
terutama bagian **Kontrak**, yang menjelaskan apa yang mengikat repo ini dengan
repo server dan satu janji yang belum ditepati (`contract_version` belum dibaca
klien mana pun).

## Alur Git — satu rencana selesai, satu tag

Tiga aturan. Tidak ada yang keempat.

```
1.  Ada perubahan  →  branch  →  ./scripts/pr.sh  →  PR  →  merge ke main
                      (ulangi sesering perlu; satu rencana boleh berisi
                       sepuluh PR)

2.  Rencana selesai  →  CHANGELOG + version.txt  →  commit

3.  git tag -a vX.Y.Z  →  git push origin main --follow-tags  →  SATU TAG
```

**Tidak ada aturan bentuk judul PR, dan tidak ada bentuk pesan commit yang
wajib.** Pada 17 September 2026 release-please dilepas; versi kini dinaikkan
dengan tangan. Tidak ada mesin yang membaca judul PR atau pesan commit, jadi
tidak ada yang bisa dipatahkan olehnya. Tulis yang jelas bagi manusia.

Tiga lapis aturan sempat ada untuk menambal satu kepekaan release-please —
larangan prefiks di judul PR, lalu kewajiban prefiks, lalu skrip penjaga
sinkronnya. Semuanya lenyap bersama sebabnya. Kalau Anda menemukan sisa aturan
itu di suatu berkas, itu peninggalan: buang, jangan patuhi.

**Satu commit per branch dianjurkan**, bukan diwajibkan: GitHub lalu mengisi
judul dan body PR dari commit itu, jadi tidak ada yang perlu diketik.

```
./scripts/pr.sh                      # suite + push + tautan PR
```

**Yang berjalan di GitHub hanya satu job: parser PowerShell.** Suite bash
dijalankan sebelum push oleh `scripts/hooks/pre-push`.


**PR di repo ini membeli sesuatu yang nyata**, tidak seperti di sebagian repo:
CI menjalankan parser PowerShell 5.1 di runner Windows, satu-satunya cara
memeriksa `.ps1` tanpa mesin Windows. Sisanya — suite bash — dijalankan sebelum
push, bukan sesudahnya.
Windows — `PiModels.ps1` lolos hitungan kurung tetapi gagal di-parse, dan
`setup.ps1` mati untuk semua orang sampai v1.4.0 terbit.

**Yang sengaja TIDAK dipakai.** Tidak ada cabang `develop` (pemisahan terbit
dari belum-terbit sudah dipegang tag) dan tidak ada peer review wajib (belum ada
reviewer kedua; aturan yang tidak bisa dijalankan hanya melatih orang
mengabaikan aturan). Pertimbangkan lagi saat repo ini punya dua penulis tetap.

## Melaporkan hasil dengan jujur

Repo ini punya sejarah panjang berupa kode yang melapor sukses berdasarkan
**niat**, bukan **hasil** — sebelas kejadian tercatat dalam satu hari. Beberapa
bentuknya:

- mencetak `OK` tanpa memeriksa apa pun
- `cp || true` lalu mengaku sudah mencadangkan
- memverifikasi terhadap konstanta yang dipatok di skrip itu sendiri
- `2>$null` di PowerShell yang tidak menekan stderr native

Kalau sebuah langkah tidak diverifikasi, katakan begitu. Perintah yang gagal
diam-diam lebih mahal daripada perintah yang berteriak.
