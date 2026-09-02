# 📜 Changelog

Semua perubahan penting pada **CooperAgent CLI** (`cooperagent-cli`) dicatat di
berkas ini.

Formatnya mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dan
proyek ini memakai [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Aturan lengkap — termasuk apa yang membuat sebuah perubahan MAJOR pada sebuah
*pemasang* — ada di [`docs/versioning.md`](docs/versioning.md).

---

## [1.1.1](https://github.com/LyKhan77/CooperAgent-cli/compare/v1.1.0...v1.1.1) (2026-09-02)


### Dokumentasi

* luruskan riwayat versi — tidak ada v1.0.0 ([9656f9e](https://github.com/LyKhan77/CooperAgent-cli/commit/9656f9e096776c2705b16f512b51d4248450c887))

## [Unreleased]

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
