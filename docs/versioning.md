# Versioning & Rilis — CooperAgent CLI

Semantic Versioning, dinaikkan dan diberi tag dengan tangan.

Repo ini berversi **sendiri**, terpisah dari `CooperAgent-server`. Keduanya
memang berjalan pada laju berbeda: server berubah saat mesin atau gateway
berubah, pemasang berubah saat cara memasang berubah. Yang mengikat keduanya
bukan nomor versi, melainkan **kontrak** — lihat bagian terakhir.

> **Kenapa mulai dari 1.x padahal server sudah 2.x?**
> Karena ini artefak baru dengan permukaan kompatibilitas sendiri. Nomor di sini
> menjawab "apakah pemasang saya mutakhir", bukan "versi server berapa". Dev yang
> melihat `cooperagent-cli 1.1.0` setelah `CooperAgent 2.3.0` **tidak** sedang
> mundur — keduanya menghitung hal yang berbeda.

> **Kenapa rilis pertama bernomor 1.1.0, bukan 1.0.0?**
> Peninggalan release-please, yang dipakai sampai 17 September 2026: garis
> dasarnya diisi `1.0.0`, yang baginya berarti "1.0.0 dianggap sudah terbit" —
> bukan "mulailah dari 1.0.0". Kenaikan pertama karena itu mendarat di 1.1.0,
> dan tag `v1.0.0` tidak pernah ada.

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

**Oleh Anda, bukan oleh mesin.** Sampai 17 September 2026 versi dinaikkan
otomatis oleh release-please dari prefiks commit. Itu dilepas; alasannya di
bawah.

Aturannya tetap SemVer, dan tabel di atas tetap berlaku — yang berubah hanya
siapa yang menerapkannya:

| Perubahannya | Naik ke |
| :-- | :-- |
| perbaikan bug, tanpa mengubah cara memakainya | PATCH |
| kemampuan baru yang tidak memaksa siapa pun berubah | MINOR |
| dev harus melakukan sesuatu, atau sesuatu yang dulu jalan kini tidak | MAJOR |

Dokumen yang **mengubah instruksi yang dijalankan dev** ikut menaikkan PATCH —
petunjuk yang salah memutus orang sama nyatanya dengan kode yang salah.

## Alurnya

### Sehari-hari

```bash
git checkout -b <nama>
# ... kerjakan, commit
./scripts/pr.sh
```

`pr.sh` menjalankan seluruh suite, mem-push, lalu mencetak tautan `compare`.
Buka tautan itu → *Create pull request* → merge. Satu commit per branch berarti
GitHub mengisi judul dan body PR dari commit itu, jadi tidak ada yang perlu
diketik; lebih dari satu commit berarti Anda menulis judulnya sendiri. Keduanya
boleh.

**Tidak ada aturan bentuk judul PR.** Tidak ada yang membacanya selain manusia.

Yang berjalan di GitHub hanya satu job: parser PowerShell. Suite bash dijalankan
sebelum push oleh `scripts/hooks/pre-push`, yang menolak push bila ada yang
merah.

### Merilis

Rilis adalah keputusan, dan kini benar-benar berupa keputusan — bukan efek
samping dari sebuah prefiks.

```bash
git checkout main && git pull

# 1. Tulis entrinya di CHANGELOG.md, dan naikkan version.txt
#    (bagian "Catatan rinci" untuk prosa panjangnya)
$EDITOR CHANGELOG.md version.txt
git commit -am "Rilis 3.2.0"

# 2. Beri tag, lalu dorong keduanya
git tag -a v3.2.0 -m "v3.2.0 — ringkasan satu baris"
git push origin main --follow-tags

# 3. Terbitkan GitHub Release dari tag itu (opsional, lewat peramban)
```

`version.txt` adalah sumber kebenarannya; tag hanya menandai commit-nya. Keduanya
harus cocok — bila berbeda, `version.txt` yang benar dan tagnya salah tempel.

### Kenapa release-please dilepas

Ia menentukan rilis dari pesan commit, dan itu menuntut pesan commit berbentuk
tertentu **selamanya**, di setiap tempat pesan itu muncul. GitHub menaruh judul
PR ke badan merge commit, jadi judul PR ikut terbaca sebagai commit — satu
perubahan tercatat dua kali. Menambalnya berarti mengatur judul PR, dan setiap
tambalan melahirkan tambalan berikutnya:

- larangan prefiks di judul PR (karena merge commit menggandakan),
- lalu kewajiban prefiks (karena squash membuat judul menjadi commit),
- lalu skrip yang menjaga keduanya tetap sinkron dengan workflow-nya.

Tiga lapis aturan untuk satu masalah yang tidak pernah dimiliki siapa pun yang
memberi tag dengan tangan. Repo ini punya satu penulis tetap dan merilis
beberapa kali sebulan; ongkos mengetik `git tag` jauh lebih kecil daripada
ongkos mengingat aturan-aturan itu. Entri kembar di `v2.0.1`, `v2.1.0`,
`v2.1.1`, `v3.0.0`, dan `v3.0.1` adalah harga yang sudah terlanjur dibayar.

Yang hilang bersamanya: CHANGELOG tidak lagi terisi sendiri. Itu bukan kerugian
besar di sini — bagian **Catatan rinci** memang selalu ditulis tangan, dan
bagian bernomor hanya satu baris per perubahan.


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
| **1.3.0** | Aturan agent jadi opsional (prompt, default ya) + menu pasang/lepas. Skill berawalan `cooper-`: `handoff` → `cooper-handoff`, dan `cooper-structure` baru. |
| **1.2.0** | Gerbang kredensial: token diverifikasi sebelum satu berkas pun ditulis, gagal = keluar kode 3 dengan sebab yang dibedakan. Mode "sudah terpasang". Perbaikan 401 pada `models.yml` omp. |
| **1.1.1** | Meluruskan riwayat versi — `v1.0.0` tidak pernah ada. |
| **1.1.0** | Rilis pertama yang bertag. Pemasang dipisahkan dari repo server; kontrak diambil dari gateway; tidak ada alamat internal di repo ini. |
| ~~1.0.0~~ | Tidak pernah ada — hanya garis dasar manifest. Lihat catatan di atas. |
