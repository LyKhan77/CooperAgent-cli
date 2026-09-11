# Tiga profil model

Setiap harness — Grok, Oh My Pi, dan pi — memakai **nama yang sama** untuk tiga
profil yang sama. Yang membedakan ketiganya hanya satu hal: **siapa yang memilih
server.**

| profil | endpoint | routing | failover |
| :--- | :--- | :--- | :---: |
| `cooper-agent` | `/api/v1` | gateway yang memilih | **ya** |
| `cooper-s1` | `/api/v1/upstream/s1` | dipaksa ke server 1 | tidak |
| `cooper-s2` | `/api/v1/upstream/s2` | dipaksa ke server 2 | tidak |

**Sehari-hari pakai `cooper-agent`.** Gateway memilih node dengan slot lowong
terbanyak, dan memindahkan sesi bila satu node penuh atau mati.

`cooper-s1` dan `cooper-s2` adalah **alat pembanding**. Gunanya menjawab
pertanyaan seperti "apakah kuantisasi di s2 menurunkan kualitas jawaban?" —
kirim prompt yang sama ke keduanya, bandingkan.

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

Jalankan `./scripts/setup-dev.sh`. Migrasinya otomatis:

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

Tidak perlu menyunting repo ini. `cooperagent.upstreams` pada `GET /v1/models`
menyebut node yang ada; profil `cooper-s<N>` mengikuti pola yang sama
(`/api/v1/upstream/s<N>`).
