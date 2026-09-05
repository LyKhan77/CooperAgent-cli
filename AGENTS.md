# Panduan agent — CooperAgent CLI

Repo ini adalah **pemasang klien**, bukan server. Ia berjalan di mesin orang
lain dan menulis ke berkas milik mereka. Itu satu kalimat yang menjelaskan
hampir semua aturan di bawah.

Repo server (`CooperAgent-server`) bersifat privat dan memuat control plane —
penerbitan kredensial, firewall, kunci mesin, topologi. **Tidak ada satu pun
dari itu yang boleh masuk ke sini.**

---

## Lima aturan yang tidak boleh dilanggar

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

---

## Sebelum menutup pekerjaan

```bash
bash test/test-contract-from-gateway.sh      # 17 pemeriksaan
bash test/test-setup-dev.sh                  # 50 pemeriksaan (perlu jaringan)
bash test/test-cli-output.sh                 #  9 pemeriksaan
bash test/test-setup-preserves-dev-config.sh
bash test/test-omp-api-key.sh                # models.yml omp membawa token
bash test/test-credential-gate.sh            # gerbang kredensial + mode "sudah terpasang"
```

Tiga yang pertama hermetis — masing-masing menyalakan gateway tiruannya sendiri
(`test/fixtures/fake-gateway.py`) dan bekerja di `HOME` sekali pakai. **Tidak ada
uji yang boleh menunjuk gateway produksi**: hasil yang bergantung pada keadaan
server bukan uji, melainkan pemantauan. Satu uji pernah melakukannya tanpa
disengaja, lewat fixture beralamat LAN sungguhan.

`test-setup-dev.sh` adalah pengecualian: ia memilih agent `omp`, sehingga
`setup.sh` mencoba memasangnya dari internet. Karena itu ia **tidak** berjalan di
CI dan harus dijalankan dengan tangan. Perbaikan yang layak dikerjakan: penjaga
lingkungan `COOPERAGENT_NO_INSTALL=1` yang melewati pemasangan agent dan hanya
menulis config — berguna juga bagi dev yang cuma ingin memperbarui parameter.

Perbarui `CHANGELOG.md`. Versi ditentukan prefiks commit — baca
[`docs/versioning.md`](docs/versioning.md), terutama bagian **Kontrak**, yang
menjelaskan apa yang mengikat repo ini dengan repo server dan satu janji yang
belum ditepati (`contract_version` belum dibaca klien mana pun).

## Alur Git — satu rencana selesai, satu tag

Tiga aturan. Tidak ada yang keempat.

```
1.  Ada perubahan  →  branch  →  PR  →  CI hijau  →  merge ke main
                      (ulangi sesering perlu; satu rencana boleh berisi
                       sepuluh PR)

2.  PR rilis mengurus dirinya sendiri
      muncul otomatis · memperbarui diri tiap ada yang masuk main
      berstatus DRAFT — tombol merge mati

3.  Rencana selesai  →  Ready for review  →  merge  →  SATU TAG
```

**Kenapa draft.** Pada 5 September 2026 PR rilis di-merge lima kali berturut
untuk lima perubahan kecil — tiga tag di repo ini, dua di repo server, semuanya
untuk satu rencana yang sama. Sebabnya bukan salah paham: PR rilis yang terbuka
dan terlihat siap merge memang *tampak seperti pekerjaan yang belum selesai*.
`draft-pull-request` membalik bawaannya — mendiamkannya kini keadaan yang benar.

**Judul PR jangan berawalan prefiks conventional-commit.** GitHub menaruh judul
PR ke badan merge commit, dan release-please membacanya sebagai commit
tersendiri — entri yang sama terbit dua kali. Jebakannya: bila branch berisi
**tepat satu commit**, GitHub mengisi judul dari subjek commit itu, yang tentu
saja conventional. Baca judulnya sebelum membuat PR. Lihat
[`docs/versioning.md`](docs/versioning.md).

**Merge commit, bukan squash.** Squash melipat semua commit jadi satu: detail
CHANGELOG hilang, dan footer `BREAKING CHANGE:` bisa ikut hilang — bersamanya
kenaikan MAJOR.

**PR di repo ini membeli sesuatu yang nyata**, tidak seperti di sebagian repo:
CI menjalankan parser PowerShell 5.1 di runner Windows, satu-satunya cara
memeriksa `.ps1` tanpa mesin Windows. Ia sudah sekali menyelamatkan setiap dev
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
