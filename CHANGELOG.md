# 📜 Changelog

Semua perubahan penting pada **CooperAgent CLI** (`cooperagent-cli`) dicatat di
berkas ini.

Formatnya mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dan
proyek ini memakai [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Aturan lengkap — termasuk apa yang membuat sebuah perubahan MAJOR pada sebuah
*pemasang* — ada di [`docs/versioning.md`](docs/versioning.md).

---

## [1.3.0](https://github.com/LyKhan77/CooperAgent-cli/compare/v1.2.0...v1.3.0) (2026-09-03)


### Fitur

* aturan agent opsional dan skill berawalan cooper- ([5657012](https://github.com/LyKhan77/CooperAgent-cli/commit/5657012f060a8a8b43ed0504e41a8fe927b30c75))

## [1.2.0](https://github.com/LyKhan77/CooperAgent-cli/compare/v1.1.1...v1.2.0) (2026-09-03)


### Fitur

* gerbang kredensial dan mode "sudah terpasang" pada pemasang ([19052bf](https://github.com/LyKhan77/CooperAgent-cli/commit/19052bf659ace3b15c4077482936dd274bd9b656))


### Perbaikan

* pilihan default tidak buntu bagi dev omp-saja, dan rekomendasi mengikuti keadaan ([14980b3](https://github.com/LyKhan77/CooperAgent-cli/commit/14980b3e8f7af97d360e934a4b5bfe995e093c92))

## [1.1.1](https://github.com/LyKhan77/CooperAgent-cli/compare/v1.1.0...v1.1.1) (2026-09-02)


### Dokumentasi

* luruskan riwayat versi — tidak ada v1.0.0 ([9656f9e](https://github.com/LyKhan77/CooperAgent-cli/commit/9656f9e096776c2705b16f512b51d4248450c887))

## [Unreleased]

### Fitur

* pi ditambahkan sebagai harness opsional pada pilihan 5. Adapter terisolasi
  menulis `~/.pi/agent/models.json` dan `settings.json` secara merge, memakai
  token `ca_...`, kontrak `/v1/models`, aturan penuh `~/.pi/agent/AGENTS.md`,
  compaction turunan kontrak, serta `verify()` untuk chat, identitas gateway,
  aturan global, dan checkpoint; default Grok/omp tidak berubah.

### Perbaikan

* **harness:** `verify()` pi menolak pemasangan yang benar

  **Konteks.** `setup.sh` pilihan 5 selesai menulis config, lalu `verify()`
  melaporkan `POST /v1/chat/completions lewat pi tidak terverifikasi 200 atau
  marker AGENTS.md tidak muncul` — padahal pi sungguhan menembus gateway dan
  membaca aturan global dengan benar. Kegagalannya berpindah-pindah titik antar
  percobaan, sehingga sempat dikira beban mesin inferensi.

  **Perubahan.**
  - `scripts/lib/pi_verify.sh` — seluruh assertion membaca dari berkas, bukan
    dari pipa. `printf '%s' "$output" | grep -q POLA` tidak aman di bawah
    `set -o pipefail`: `grep -q` menutup pipa saat cocok, `printf` kena SIGPIPE
    dan keluar 141, dan `pipefail` menjadikan 141 status pipeline — sehingga
    assertion gagal **persis ketika polanya ditemukan**. Hanya muncul bila
    keluaran cukup besar sehingga `printf` belum selesai menulis.
  - `scripts/lib/pi_verify.sh` — marker aturan diberi label
    (`VERIFICATION SENTENCE: ...`), bukan token acak telanjang; prompt tidak
    lagi menuntut penalaran.
  - `scripts/lib/pi_verify.sh` — tiga sebab kegagalan dilaporkan terpisah:
    habis waktu (disebut eksplisit **bukan** bukti pemasangan salah), pi keluar
    bukan-nol, dan marker tidak muncul.
  - `scripts/lib/pi_verify.sh` — `PI_VERIFY_TIMEOUT` (default 240s) per
    panggilan, dan `COOPER_PI_KEEP_TMP=1` menyimpan bukti kegagalan
    (`call1.jsonl`, `call2.jsonl`, config, aturan bertanda) alih-alih
    menghapusnya.
  - `test/test-pi-adapter.sh` — stub pi mengikuti kontrak marker berlabel yang
    sama seperti model sungguhan.

  **Bukti.** Pada keluaran 34 KB, `call1.jsonl` yang tersimpan memuat
  `message_end` dan tiga `"stopReason":"stop"`, sementara gerbang melaporkan
  keduanya tidak ada — itulah yang menunjukkan akarnya. Sesudah perbaikan,
  `setup-pi.sh` terhadap pi 0.84.4 dan gateway sungguhan meluluskan keempat
  gerbang, termasuk checkpoint task-boundary yang menulis
  `.cooper/context/pi-verify-29118.md`. Suite 7 dari 7 hijau; `setup.ps1` tetap
  seimbang 296/296 kurung.

  **Dampak.** Tidak ada perubahan pada config yang ditulis maupun pada jalur
  Grok/omp. Yang berubah hanya cara `verify()` menilai dan melaporkan. Dev yang
  sebelumnya melihat pemasangan pi ditolak kini melihatnya lulus.

  **Rollback.** `git revert` commit ini. Tidak ada state di mesin dev yang perlu
  dibatalkan — `verify()` tidak menulis apa pun di luar direktori sementaranya.

  **Utang yang diketahui, belum disentuh:** pola `printf | grep -q` yang sama
  masih ada di `test/test-contract-from-gateway.sh` (baris 148, 154, 157, 161)
  dan `test/test-cli-output.sh` (baris 89). Keduanya lulus hari ini karena
  keluarannya kecil, tetapi rapuh untuk alasan yang sama. `scripts/setup-pi.sh`
  juga masih menerima token lewat argumen `--token`, yang terlihat di `ps aux`.

## [1.1.0](https://github.com/LyKhan77/CooperAgent-cli/compare/v1.0.0...v1.1.0) (2026-09-02)


### Fitur

* pemasang harness CooperAgent untuk developer ([9b4560e](https://github.com/LyKhan77/CooperAgent-cli/commit/9b4560ea9581e7baa7130590d6f17232aa614e70))


### Perbaikan

* **ci:** test.yml tidak dapat diurai sehingga tidak ada job yang berjalan ([d13c38e](https://github.com/LyKhan77/CooperAgent-cli/commit/d13c38e26a5fdb942729cacda193a22e7f29c3bb))

## Sebelum v1.1.0 — pemisahan repo (2026-09-02)

**Tidak ada tag `v1.0.0`.** Angka itu ditulis sebagai garis dasar di
`.release-please-manifest.json` — artinya "1.0.0 dianggap sudah terbit" — jadi
commit `feat:` pertama menaikkannya ke **1.1.0**. Untuk membuat rilis pertama
benar-benar bernomor 1.0.0, garis dasarnya seharusnya `0.0.0`.

Dibiarkan apa adanya: v1.1.0 sudah terbit, dan menarik ulang sebuah rilis yang
sudah ditandai lebih berisiko daripada satu nomor yang dilewati. Tautan
perbandingan pada entri 1.1.0 di atas menunjuk `v1.0.0` yang tidak ada — itu
konsekuensi yang sama, dan sengaja tidak ditambal dengan tag palsu.

Isi pemisahan repo itu:

* pemasang harness CooperAgent untuk developer — `setup.sh`, `setup.ps1`,
  `templates/`, `scripts/setup-dev.*`
* nilai kontrak (`context_window`, `max_tokens`, ambang compaction, nama model)
  diambil dari `GET /v1/models`, tidak dipatok di klien
* alamat gateway datang dari dev atau dari kontrak; alias `lan`/`vpn`/`local`
  diselesaikan gateway, dan daftarnya tersimpan di `~/.cooper/gateway-endpoints`
  agar tetap terjawab saat gateway tidak terjangkau
* keluaran menyesuaikan tempatnya dibaca: warna hanya ke terminal, `NO_COLOR`
  dihormati, simbol ASCII di konsol non-UTF-8, `--ascii` dan `--no-color`

### Catatan

Repo ini **tidak memuat satu pun alamat internal** — itu syarat yang membuatnya
boleh publik, dan dijaga uji. Riwayat dimulai dari nol, bukan `git subtree
split`: riwayat repo server bercerita tentang firewall dan penerbitan kredensial
lewat pesan commit-nya.

Nomor versi di sini **terpisah** dari repo server. Yang mengikat keduanya adalah
`contract_version` pada `/v1/models` — lihat `docs/versioning.md`, termasuk
catatan bahwa medan itu belum dibaca klien mana pun.
