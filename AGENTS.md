# Panduan agent — CooperAgent CLI

Repo ini adalah **pemasang klien**, bukan server. Ia berjalan di mesin orang
lain dan menulis ke berkas milik mereka. Itu satu kalimat yang menjelaskan
hampir semua aturan di bawah.

Repo server (`CooperAgent-server`) bersifat privat dan memuat control plane —
penerbitan kredensial, firewall, kunci mesin, topologi. **Tidak ada satu pun
dari itu yang boleh masuk ke sini.**

---

## Empat aturan yang tidak boleh dilanggar

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

### 4. Keluaran harus terbaca di tempat ia dibaca

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
