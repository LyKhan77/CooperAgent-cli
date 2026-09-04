# CooperAgent — pemasang harness

Pemasang klien untuk **CooperAgent**, LLM internal yang berjalan di server GPU
perusahaan. Satu skrip untuk pasang maupun perbarui, di Linux, macOS, dan
Windows.

Anda butuh dua hal, dan keduanya datang dari admin:

| | |
| :-- | :-- |
| **Token** | `ca_…` — diterbitkan per perangkat lewat `cooper issue` |
| **Alamat gateway** | tercetak di blok yang sama dengan token Anda |

Token tidak bisa ditampilkan ulang. Kalau hilang, minta dicabut lalu diterbitkan
kembali — jangan pinjam milik orang lain: satu token dipakai dari dua tempat
akan terlihat, dan yang dicabut adalah token itu.

---

## Pasang

```bash
git clone https://github.com/LyKhan77/CooperAgent-cli.git
cd CooperAgent-cli
./setup.sh --token ca_...
```

Windows:

```powershell
.\setup.ps1 -Token ca_...
```

Skrip menanyakan coding agent mana yang Anda pakai:

1. **Grok Build** — TUI Rust layar penuh
2. **Oh My Pi (`omp`)** — coding agent CLI
3. **Pi Agent (`pi`)** — coding agent CLI ringan: 4 tool inti, hemat token,
   sesi bercabang; membawa aturan, compaction, dan checkpoint CooperAgent
4. **Manual** — hanya mencetak endpoint, untuk agent pilihan Anda sendiri
   (Cline, Continue, Cursor, SDK OpenAI, `curl`)

Untuk memakai lebih dari satu harness, jalankan skripnya sekali per harness.
Nama dan perangkat **tidak ditanyakan** — keduanya melekat pada token, dan
gateway yang memberi tahu skrip siapa Anda. Yang muncul di dashboard adalah yang
tercatat pada token, bukan yang Anda ketik.

Menjalankan ulang skrip ini aman. Ia menggabungkan, bukan menimpa: server MCP,
seksi `[ui]`, model tambahan, dan kunci berbayar Anda sendiri tidak disentuh.
Pilihan 3 bersifat tambahan dan eksplisit; bila Anda menekan Enter, default tetap
Grok Build seperti sebelum pi ditambahkan.

## Pi Agent (opsi tambahan)

Pi dipasang hanya bila Anda memilih **5**. Jalurnya menulis hanya:

- `~/.pi/agent/models.json`, dengan provider `cooperagent` di-merge;
- `~/.pi/agent/settings.json`, dengan compaction kontrak;
- `~/.pi/agent/AGENTS.md`, salinan penuh `templates/agent-rules.md`;
- `~/.cooper/skills/`, sumber skill bersama tanpa menghapus tambahan dev.

Provider lain, model tambahan, kunci berbayar, dan setting pribadi dipertahankan.
`baseUrl`, model, context window, max output, dan ambang compaction berasal dari
`GET /v1/models`; `reserveTokens` pi diturunkan dari kontrak, bukan dipatok.
Token `ca_...` diverifikasi ke `/api/auth/whoami` sebelum berkas ditulis; bentuk
`dev-<nama>@<device>` tidak digunakan. `verify()` lalu menguji chat melalui pi,
pembacaan AGENTS, dan checkpoint `.cooper/context/` pada proyek sementara.

Pembaruan langsung:

```bash
./scripts/setup-pi.sh --endpoint <gateway> --token ca_... --rules
```
---

## Cline (ekstensi VS Code)

Pilih **4) Manual** saat setup, lalu salin nilai yang tercetak ke pengaturan
Cline:

| Kolom di Cline | Isi |
| :-- | :-- |
| API Provider | **OpenAI Compatible** |
| Base URL | `<alamat-gateway>/v1` |
| API Key | token `ca_…` Anda |
| Model ID | dari baris **Model** yang dicetak setup |

Cetak ulang kapan saja tanpa memasang apa pun:

```bash
./setup.sh --info
```

Nilai `context window` dan `max output` yang tercetak **ditanyakan ke gateway**,
bukan ditulis di skrip ini — jadi angkanya ikut berubah saat server berubah.

Tiga hal yang paling cepat menggigit pengguna Cline:

- **Beri `max_tokens` minimal ~2000.** Model ini berpikir dulu; token yang habis
  untuk penalaran menghasilkan jawaban **kosong**, bukan jawaban pendek.
- **Auto-compaction adalah fitur klien.** Cline punya sendiri — nyalakan, dan
  setel ambangnya sesuai persentase yang dicetak setup. Tanpa itu percakapan
  tumbuh sampai menabrak plafon slot lalu terpotong di tengah.
- **Model ID boleh apa saja secara teknis, tapi jangan diarang.** Gateway
  meneruskannya apa adanya; yang benar adalah yang dicetak setup.

---

## Berpindah jaringan

Alamat kantor dan VPN berbeda. Anda tidak perlu memasang ulang:

```bash
./setup.sh --endpoint vpn      # atau: lan, local
./setup.sh --endpoint http://alamat-lain:8987/api/v1
```

Alias `lan`/`vpn`/`local` **ditanyakan ke gateway**, bukan tabel di skrip ini.
Setelah sekali tersambung, daftarnya disimpan di `~/.cooper/gateway-endpoints`
supaya tetap bisa dipakai justru ketika gateway sedang tidak terjangkau — yaitu
saat Anda paling butuh tahu alamat satunya.

Token Anda **tidak berubah** saat berpindah jaringan. Ia mengidentifikasi
perangkat, bukan lokasi.

---

## Kalau ada yang salah

```bash
./setup.sh --info      # endpoint + kunci + angka kontrak yang berlaku
```

| Gejala | Kemungkinan |
| :-- | :-- |
| `401` | token belum terpasang, salah tempel, atau sudah dicabut |
| `503` + `Retry-After` | maintenance; spanduk di dashboard menyebut sampai kapan |
| Tidak tersambung | jaringan salah — coba `--endpoint vpn` atau `lan` |
| Jawaban kosong | `max_tokens` terlalu kecil; naikkan ke ≥2000 |

Saat melaporkan masalah, **alihkan keluarannya ke berkas** lalu lampirkan:

```bash
./setup.sh --info > log.txt 2>&1
```

Keluaran yang dialihkan sengaja tidak memuat kode warna, jadi berkasnya terbaca
apa adanya. Konsol yang tidak mendukung UTF-8 otomatis memakai penanda ASCII
(`[v]`, `[x]`); `--ascii` dan `--no-color` memaksanya.

---

## Yang TIDAK ada di repo ini

Tidak ada rahasia, dan **tidak ada satu pun alamat internal**. Skrip di sini
tidak tahu di mana server berada sampai Anda memberitahunya, dan nilai seperti
context window serta ambang compaction diambil dari `GET /v1/models` saat
pemasangan — bukan dipatok.

Itu disengaja: nilai yang dipatok di klien tidak pernah tahu saat server
berubah, dan riwayat git tidak bisa dilupakan.

Aturan lengkap untuk yang mengembangkan repo ini ada di
[`AGENTS.md`](AGENTS.md); aturan versi dan rilis di
[`docs/versioning.md`](docs/versioning.md).

Uji yang menjaganya:

```bash
bash test/test-contract-from-gateway.sh   # kontrak diikuti; tak ada IP dipatok
bash test/test-cli-output.sh              # keluaran terbaca di berkas & non-UTF-8
bash test/test-setup-dev.sh               # pemasang idempoten
bash test/test-setup-preserves-dev-config.sh
```
bash test/test-pi-adapter.sh
