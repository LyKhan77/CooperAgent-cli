# 📜 Changelog

Semua perubahan penting pada **CooperAgent CLI** (`cooperagent-cli`) dicatat di
berkas ini.

Formatnya mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dan
proyek ini memakai [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Aturan lengkap — termasuk apa yang membuat sebuah perubahan MAJOR pada sebuah
*pemasang* — ada di [`docs/versioning.md`](docs/versioning.md).

---

## [Unreleased]

## 1.0.0 (2026-09-02)

Rilis pertama sebagai repo tersendiri. Dipisahkan dari `CooperAgent-server`, yang
kini privat karena memuat control plane.

### Fitur

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
