# Versioning & Rilis — CooperAgent CLI

Semantic Versioning, otomatis dari Conventional Commits lewat
[release-please](https://github.com/googleapis/release-please).

Repo ini berversi **sendiri**, terpisah dari `CooperAgent-server`. Keduanya
memang berjalan pada laju berbeda: server berubah saat mesin atau gateway
berubah, pemasang berubah saat cara memasang berubah. Yang mengikat keduanya
bukan nomor versi, melainkan **kontrak** — lihat bagian terakhir.

> **Kenapa mulai dari 1.0.0 padahal server sudah 2.2.0?**
> Karena ini artefak baru dengan permukaan kompatibilitas sendiri. Nomor di sini
> menjawab "apakah pemasang saya mutakhir", bukan "versi server berapa". Dev yang
> melihat `cooperagent-cli 1.0.0` setelah `CooperAgent 2.2.0` **tidak** sedang
> mundur — keduanya menghitung hal yang berbeda.

---

## Apa yang membuat sebuah perubahan MAJOR di sini

Pemasang ini menulis ke mesin orang lain. Karena itu ukurannya bukan "apakah
kodenya berubah banyak", melainkan **apakah dev harus turun tangan**:

```
MAJOR   config dev yang sudah ada berhenti bekerja, atau dev harus
        menyunting/menjalankan sesuatu dengan tangan agar tetap jalan
MINOR   kemampuan baru yang tidak menuntut tindakan siapa pun
PATCH   perbaikan tanpa perubahan antarmuka
```

Konkretnya **MAJOR**:

- bentuk berkas yang ditulis berubah sehingga config lama tidak lagi terbaca
- nama atau argumen `setup.sh` / `setup-dev.sh` berubah (`--endpoint` hilang,
  `--token` berganti nama)
- letak berkas yang dipakai berpindah (`~/.cooper/gateway-endpoints`,
  `~/.grok/config.toml`) tanpa migrasi otomatis
- pemasang berhenti mendukung sebuah `contract_version` yang masih disajikan
  gateway produksi

Konkretnya **BUKAN** major, meski terasa besar:

- menambah pilihan agent atau bendera baru yang default-nya mati
- mengubah teks, warna, atau tata letak keluaran
- menambah uji, dokumen, atau penjaga
- menyesuaikan diri terhadap nilai kontrak baru yang **opsional**

Aturan praktisnya satu kalimat: **kalau sebelas dev bisa menjalankan versi baru
tanpa diberi tahu apa pun, itu bukan MAJOR.**

---

## Bagaimana versinya ditentukan

Dari prefiks commit, bukan dari penilaian manusia:

| Commit | Naik ke |
| :-- | :-- |
| `fix: ...` | PATCH |
| `feat: ...` | MINOR |
| `feat!: ...` atau footer `BREAKING CHANGE:` | MAJOR |

`docs:`, `test:`, `chore:` tidak menaikkan versi. Kalau sebuah commit hanya
menyentuh dokumen tapi **mengubah instruksi yang dijalankan dev**, ia `fix:` —
petunjuk yang salah memutus orang sama nyatanya dengan kode yang salah.

Untuk memaksa versi tertentu:

```
Release-As: 2.0.0
```

## Alurnya

1. Push ke `main` → release-please membuka/memperbarui **satu PR rilis**
2. PR itu memuat CHANGELOG dan kenaikan versi — belum ada yang dirilis
3. **Merge PR itu** = menerbitkan tag `vX.Y.Z` dan GitHub Release

Tidak ada yang dirilis tanpa seseorang menekan merge. Rilis adalah keputusan,
bukan efek samping dari push.

Pakai **"Create a merge commit"**, bukan squash. Squash membuat judul PR menjadi
pesan commit, sehingga judul yang tidak berbentuk conventional commit membuat
release-please tidak melihat perubahan apa pun.

---

## Kontrak: yang sebenarnya mengikat kedua repo

Nomor versi kedua repo tidak perlu cocok. Yang harus cocok adalah **bentuk
kontrak** yang disajikan gateway pada `GET /v1/models`:

```json
"cooperagent": {
  "contract_version": 1,
  "model_id": "...",
  "context_window": 131072,
  "max_tokens": 12288,
  "compaction": { "threshold_percent": 80, "threshold_tokens": 104857 },
  "context_source": "upstream",
  "endpoints": [ { "id": "lan", "label": "...", "url": "..." } ]
}
```

Aturannya:

- **Menambah kunci** pada kontrak = MINOR di sisi server, dan **tidak** menuntut
  rilis di sini. Pemasang mengabaikan yang tidak dikenalnya.
- **Mengubah arti atau menghapus kunci** = MAJOR di kedua sisi, dan
  `contract_version` **harus** naik.
- Pemasang harus tetap berjalan menghadapi `contract_version` yang **lebih
  tinggi** dari yang ia kenal — dengan mengatakannya, bukan dengan diam.

### ⚠ Yang belum dikerjakan

`contract_version` **diumumkan gateway tetapi tidak dibaca satu pun klien.**
`scripts/lib/contract.sh` dan `Contract.ps1` mengurai `model_id`,
`context_window`, `max_tokens`, dan ambang compaction — tidak `contract_version`.

Artinya menaikkannya hari ini **tidak berefek apa pun**: pemasang lama akan
tetap mengurai kontrak baru seolah tidak terjadi apa-apa, dan gagal di tempat
yang jauh dari sebabnya.

Ini pekerjaan yang perlu dilakukan sebelum `contract_version` pernah dinaikkan:

1. Urai `contract_version` di kedua pustaka.
2. Bila lebih tinggi dari yang dikenal → **tetap lanjut**, tapi cetak peringatan
   yang menyebut angkanya dan menyarankan `git pull`. Menolak bekerja lebih
   buruk: gateway yang lebih baru biasanya masih kompatibel.
3. Bila lebih rendah dari yang dikenal → pemasang lebih baru dari gateway;
   katakan itu, jangan berasumsi kunci baru ada.
4. Tambahkan penjaganya di `test/test-contract-from-gateway.sh` — gateway tiruan
   di sana sudah menyajikan `contract_version`, jadi ujinya tinggal ditulis.

Sampai itu selesai, `contract_version` adalah janji yang belum ditepati. Jangan
menaikkannya di sisi server dan mengira klien akan menyadarinya.

---

## Riwayat

| Versi | Isi |
| :-- | :-- |
| **1.0.0** | Pemasang dipisahkan dari repo server. Kontrak diambil dari gateway; tidak ada alamat internal di repo ini. |
