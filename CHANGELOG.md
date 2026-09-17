# 📜 Changelog

Semua perubahan penting pada **CooperAgent CLI** (`cooperagent-cli`) dicatat di
berkas ini.

Formatnya mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dan
proyek ini memakai [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Aturan lengkap — termasuk apa yang membuat sebuah perubahan MAJOR pada sebuah
*pemasang* — ada di [`docs/versioning.md`](docs/versioning.md).

---

## [3.1.2](https://github.com/LyKhan77/CooperAgent-cli/compare/v3.1.1...v3.1.2) (2026-09-17)

Rilis pertama yang diberi tag dengan tangan. Seksi ini tidak lagi ditulis
release-please.

### Perbaikan

* **pi:** migrasi `defaultProvider` lama `cooperagent` ke `cooper-agent` ([20a53c3](https://github.com/LyKhan77/CooperAgent-cli/commit/20a53c3))
* **omp:** kenali provider `cooper-*` di sisi Windows — omp dilewati sepenuhnya saat ganti gateway sejak 3.0.0 ([1c6d7dd](https://github.com/LyKhan77/CooperAgent-cli/commit/1c6d7dd))
* **setup:** baca token pi meski omp dan grok tidak terpasang ([67b24c4](https://github.com/LyKhan77/CooperAgent-cli/commit/67b24c4))

### Perkakas & CI

* lepas release-please dan seluruh gerbang PR; rilis diberi tag dengan tangan ([dcf1687](https://github.com/LyKhan77/CooperAgent-cli/commit/dcf1687))

  Dua langkah antaranya — pagar judul dibalik, lalu suite dipindah ke lokal —
  dibuat dan dicabut kembali dalam jendela rilis yang sama, jadi tidak ada yang
  pernah terbit darinya. Ketiganya dicatat utuh di **Catatan rinci**.

## [3.1.1](https://github.com/LyKhan77/CooperAgent-cli/compare/v3.1.0...v3.1.1) (2026-09-12)


### Perbaikan

* **omp:** umumkan supportsImages, dan naikkan pemasangan yang sudah ada ([66cc338](https://github.com/LyKhan77/CooperAgent-cli/commit/66cc338a63527452aa3db3bc714937b0bb250eb2))
* **pi:** umumkan input image, jangan biarkan pi memakai subagent vision ([4bb0dff](https://github.com/LyKhan77/CooperAgent-cli/commit/4bb0dffe79ea41d8c9d6a8e71d82187f7e3234fa))

## [3.1.0](https://github.com/LyKhan77/CooperAgent-cli/compare/v3.0.0...v3.1.0) (2026-09-12)


### Fitur

* **scripts:** pr.sh — periksa judul, push, dan tautan PR dalam satu langkah ([f1f028f](https://github.com/LyKhan77/CooperAgent-cli/commit/f1f028f0849f2b566ef856a784e25aa05d8b070a))


### Dokumentasi

* rapikan CHANGELOG sesudah v3.0.0, dan tulis harga merge commit ([e7c7cb5](https://github.com/LyKhan77/CooperAgent-cli/commit/e7c7cb558fe317f6c04feabd6ce35eb017e3f805))

## [3.0.0](https://github.com/LyKhan77/CooperAgent-cli/compare/v2.1.1...v3.0.0) (2026-09-11)


### ⚠ BREAKING CHANGES

* nama profil model berubah dari `internal-qwen*`/`cooperagent*` menjadi `cooper-agent`/`cooper-s1`/`cooper-s2`. Config bermigrasi otomatis saat setup dijalankan, tetapi dev yang menyimpan pilihan model di UI harness-nya perlu memilih ulang sekali.

### Fitur

* satukan tiga profil model di semua harness ([3aaf052](https://github.com/LyKhan77/CooperAgent-cli/commit/3aaf052ccc35b1e1ff2dc55c5b6732f3b2d9ccc7))


### Perbaikan

* **setup-dev:** --remove-rules mati sebelum menghapus apa pun ([aa9699e](https://github.com/LyKhan77/CooperAgent-cli/commit/aa9699e4f1464617b9f0d25d8214d86663dd8b4f))
* **setup-dev:** pembaru Windows ikut bermigrasi juga ([494d143](https://github.com/LyKhan77/CooperAgent-cli/commit/494d143d93054f885ba57efe0652a369c88dfbed))
* **setup:** bawa migrasi profil ke KEDUA pemasang, bukan hanya pembaru ([ddb12ae](https://github.com/LyKhan77/CooperAgent-cli/commit/ddb12ae455168c90a9010ec780f8d1bd38dc21a7))


### Dokumentasi

* tulis alur git tiga aturan ke AGENTS.md ([19c2642](https://github.com/LyKhan77/CooperAgent-cli/commit/19c26428165369a9ad6497133ecf32f75cd6b6eb))

## [2.1.1](https://github.com/LyKhan77/CooperAgent-cli/compare/v2.1.0...v2.1.1) (2026-09-05)


### Dokumentasi

* buang entri kembar di seksi CHANGELOG v2.1.0 ([1777813](https://github.com/LyKhan77/CooperAgent-cli/commit/17778139f7215bbb8bc8a737f9bf371d54c7be11))

## [2.1.0](https://github.com/LyKhan77/CooperAgent-cli/compare/v2.0.1...v2.1.0) (2026-09-05)


### Fitur

* **setup:** retensi cadangan .bak di kedua installer ([aed93dd](https://github.com/LyKhan77/CooperAgent-cli/commit/aed93dd8ee5c830cba54b08120d67097c5e6a3a3))

## [2.0.1](https://github.com/LyKhan77/CooperAgent-cli/compare/v2.0.0...v2.0.1) (2026-09-04)


### Dokumentasi

* lipat prosa [Unreleased] ke dalam v2.0.0 ([13b7068](https://github.com/LyKhan77/CooperAgent-cli/commit/13b70685eead29a400c64f8c9f3c29fe6531ae46))

## [2.0.0](https://github.com/LyKhan77/CooperAgent-cli/compare/v1.4.0...v2.0.0) (2026-09-04)


### ⚠ BREAKING CHANGES

* **harness:** menu pemilihan harness diurutkan ulang dan opsi "Keduanya (Grok Build + Oh My Pi)" dihapus. pi kini pilihan 3; Manual tetap 4; pilihan 5 tidak lagi ada. Dev yang terbiasa mengetik `3` untuk memasang Grok + omp kini mendapat pi, dan memasang keduanya menuntut menjalankan setup sekali per harness. Tidak ada config yang rusak dan tidak ada berkas yang perlu disunting -- yang berubah adalah alur interaktifnya, dan pemilik memutuskan kejutan itu cukup besar untuk ditandai MAJOR.

### Fitur

* **harness:** pi jadi pilihan 3, opsi "Keduanya" dihapus, header menyebut pi ([41faca8](https://github.com/LyKhan77/CooperAgent-cli/commit/41faca8adcdc89fb6e127cd90e45feca9adbe2bb))


### Perbaikan

* **harness:** merge config pi gagal di Windows, array satu elemen terbongkar ([a728910](https://github.com/LyKhan77/CooperAgent-cli/commit/a728910ca283db2d6f7450f1d80912c671e68376))
* **harness:** pesan "aturan pi milik dev" mengklaim yang tidak diperiksa ([692066a](https://github.com/LyKhan77/CooperAgent-cli/commit/692066a7ac228ee11fd92f5ecfac8743cb129f26))
* **harness:** pi diperlakukan seperti harness lain di "lepas aturan agent" ([742d4d0](https://github.com/LyKhan77/CooperAgent-cli/commit/742d4d09366cce0acc3d79686b27fc1c9dfeb048))
* **harness:** pilihan pi tidak terlihat di menu Windows ([40568f5](https://github.com/LyKhan77/CooperAgent-cli/commit/40568f5e450eefccc7a1193e03c39e335cdffc20))
* **harness:** setup.ps1 gagal di-parse untuk setiap dev Windows ([22a2282](https://github.com/LyKhan77/CooperAgent-cli/commit/22a228241a8784e2d2ef5cec95a113701890eea9))
* **harness:** verify() pi di Windows menyalin config ke jalur yang salah ([b4c2a31](https://github.com/LyKhan77/CooperAgent-cli/commit/b4c2a3130a14d062400051d1a5ac1f96c3c91276))


### Kinerja

* **harness:** verify() pi memeriksa konfigurasi, bukan menjalankan model ([8a8338e](https://github.com/LyKhan77/CooperAgent-cli/commit/8a8338e56bf2aa110a1fa5c25926d9f9449f569b))

#### Rincian — Perbaikan

* **test:** em dash di dalam string kode `.ps1` memutus parser PowerShell

  **Konteks.** `ps-parse` tetap merah setelah lint dipindah. Parser melaporkan
  `baris 130: The string is missing the terminator: "` pada baris yang jelas
  seimbang kutipnya, plus `}` tak tertutup di baris 81 dan 28 — semuanya efek
  berantai dari satu karakter di baris 82.

  **Sebabnya.** Windows PowerShell 5.1 membaca berkas tanpa BOM memakai code
  page ANSI. Em dash UTF-8 (`e2 80 94`) terbaca sebagai tiga karakter, dan byte
  `0x94` menjadi `U+201D` — karakter yang PowerShell **terima sebagai penutup
  string**. Em dash di dalam string kode karena itu menutup string di tengah
  baris; sisanya menjadi kode dan kutip berikutnya membuka string baru yang
  berjalan sampai akhir berkas.

  Di dalam **komentar** ia tak berbahaya: `#` berlaku sampai akhir baris.
  Seluruh `.ps1` lain di repo ini memang hanya memakainya di komentar —
  `Test-PiModels.ps1` satu-satunya yang menaruhnya di string kode. Itu sebabnya
  hanya berkas itu yang gagal, dan itu pula aturan yang sudah tercatat di repo
  sebagai *Windows PowerShell 5.1 ASCII Hardening*.

  **Perubahan.**
  - `test/Test-PiModels.ps1` — em dash pada baris 82 diganti tanda hubung ASCII.
  - `test/test-pi-adapter.sh` — lint baru menolak non-ASCII pada **baris kode**
    `.ps1` mana pun, dan membiarkannya di komentar sesuai praktik yang berlaku.

  **Bukti.** Lint diuji dua arah: pada berkas sebelum perbaikan ia menyebut
  `test/Test-PiModels.ps1:82` persis; sesudahnya bersih. Suite 7 dari 7 hijau.

  **Catatan proses.** Tiga hipotesis sebelumnya — `else` yatim, here-string,
  BOM — semuanya gugur saat diperiksa, dan masing-masing memakan satu putaran
  CI. Yang akhirnya menyelesaikannya adalah menjalankan parser PowerShell di
  mesin yang punya PowerShell. Lint ini memindahkan pemeriksaannya ke tempat
  yang bisa dijalankan tanpa itu.

* **test:** lint jalur dipindah ke bash; uji PowerShell gagal di-parse

  **Konteks.** Job `ps-parse` merah pada PR. Kedelapan berkas `.ps1` **produksi**
  lolos — termasuk `setup.ps1`, `setup-pi.ps1`, dan `PiModels.ps1` yang disunting
  paling banyak. Yang gagal hanya `test/Test-PiModels.ps1`, berkas uji yang saya
  tulis sendiri: `baris 137: The string is missing the terminator`.

  **Perubahan.**
  - `test/Test-PiModels.ps1` — lint jalur dicabut. Regexnya memakai backtick
    sebagai escape di dalam string berkutip-ganda, dan itu membuat parser
    kehilangan jejak kutip; galat di baris 28 dan 81 hanyalah efek berantai.
  - `test/test-pi-adapter.sh` — lint yang sama dipasang **di bash**. Ia membaca
    berkas sebagai teks dan tidak pernah butuh PowerShell; menaruhnya di uji
    PowerShell berarti menulis kode yang tidak bisa dijalankan penulisnya.

  **Bukti.** Lint diuji dua arah dari bash: **terdeteksi** pada `PiModels.ps1`
  versi sebelum perbaikan jalur, **bersih** pada versi sekarang. Suite 7 dari 7
  hijau.

  **Yang belum terbukti.** Karena job berhenti di langkah parse,
  `Test-PiModels.ps1` **belum pernah benar-benar dieksekusi**. Ia lolos parse
  sekarang menurut pemeriksaan tangan — backtick hanya di komentar, terminator
  here-string di kolom 0, kurung seimbang — tetapi itu bukan pengganti
  menjalankannya. Job CI berikutnya yang akan membuktikannya.

  **Catatan.** Tidak ada PowerShell di mesin pengembangan, jadi berkas `.ps1`
  tidak dapat diverifikasi secara lokal sama sekali. Itu justru alasan job
  `ps-parse` ada — dan ia bekerja: ongkosnya satu putaran CI, bukan rilis rusak.

* **harness:** pesan "aturan pi milik dev" mengklaim yang tidak diperiksa

  **Konteks.** Log Windows menunjukkan dua baris yang saling bertentangan dalam
  satu run: `[!] aturan pi milik dev dipertahankan` saat memasang, lalu
  `[v] aturan agent global sesuai templates/agent-rules.md` saat verifikasi.
  Keduanya tidak bisa benar bersamaan.

  **Perubahan.**
  - `scripts/setup-pi.sh`, `scripts/setup-pi.ps1` — kepemilikan diperiksa
    **sebelum** diklaim. Urutannya terbalik: berkas yang ada dan tanpa
    `--rules` langsung dilaporkan "milik dev" tanpa pernah dibandingkan dengan
    template. Akibatnya "Perbarui parameter" melewati `AGENTS.md` milik
    CooperAgent sendiri sambil menyebutnya milik dev. Kini yang identik
    dilaporkan "sudah mutakhir", dan yang berbeda dilaporkan apa adanya —
    "BERBEDA dari template CooperAgent" — berikut cara menggantinya.
  - `scripts/lib/pi_verify.sh`, `scripts/lib/PiModels.ps1` — aturan yang berbeda
    kini **peringatan, bukan kegagalan**. Versi pertama perbaikan ini
    menggagalkan seluruh pemasangan bagi dev yang menyunting aturannya sendiri —
    menghukum dev atas keputusan yang justru kita ambil untuk melindunginya, dan
    membuat pemasangan mustahil diselesaikan olehnya. Yang wajib ada hanyalah
    berkasnya, karena pi memuat aturan global dari sana.

  **Bukti.** Dua arah diuji terhadap gateway sungguhan: aturan milik kami →
  `aturan agent pi sudah mutakhir` dan verify lulus; aturan disunting dev →
  `BERBEDA dari template CooperAgent — dipertahankan`, verify memperingatkan,
  pemasangan tetap `rc=0`.

  **Dampak.** "Perbarui parameter" kini benar-benar menyegarkan aturan pi milik
  CooperAgent bila template berubah, dan berhenti salah melabeli berkasnya
  sendiri sebagai milik dev.

  **Batas yang jujur.** Kepemilikan ditentukan dengan perbandingan byte terhadap
  template **saat ini**. Aturan kami versi LAMA karena itu tidak dapat dibedakan
  dari aturan yang disunting dev, dan akan diperlakukan sebagai milik dev —
  dipertahankan, tidak ditimpa. Membedakannya menuntut penanda asal-usul di
  dalam berkas; belum dikerjakan.

  **Rollback.** `git revert` commit ini.

* **harness:** `verify()` pi memeriksa konfigurasi, bukan menjalankan model

  **Konteks.** `setup.ps1`/`setup.sh` pilihan pi memakan **lebih dari lima
  menit**. Terukur, sebabnya bukan pi: `verify()` memanggil model **dua kali**
  pada mesin yang disetel `--reasoning-effort xhigh` dengan
  `--reasoning-budget 6144` — sampai 6.144 token penalaran per jawaban, untuk
  permintaan sesepele "kembalikan baris ini apa adanya". Journal s1 pada jendela
  itu menunjukkan sesi dev lain dengan prompt 36.849–90.173 token, dan laju
  decode turun dari 20–25 ms/token saat lengang menjadi **80–137 ms/token**.
  Lima menit itu aritmetika, bukan bug.

  **Perubahan.**
  - `scripts/lib/pi_verify.sh`, `scripts/lib/PiModels.ps1` — verifikasi baku
    kini **berbasis berkas** dan tidak memanggil model sama sekali. Yang
    diperiksa: provider `cooperagent` ada, `baseUrl` menunjuk gateway yang sama,
    `apiKey` adalah token `ca_…` yang barusan diverifikasi, compaction aktif,
    `reserveTokens` sama dengan turunan kontrak, dan `AGENTS.md` byte-identik
    dengan `templates/agent-rules.md`.
  - Verifikasi mendalam — dua panggilan pi sungguhan — kini **opsional**, di
    balik `COOPERAGENT_PI_VERIFY_DEEP=1`. Ia dipertahankan, bukan dihapus:
    empat cacat khusus Windows pada 4 September 2026 ketahuan justru karena
    jalur itu menjalankan sesuatu alih-alih membaca berkas.
  - `scripts/setup-pi.ps1` — `Invoke-PiVerify` menerima token dan jalur template
    aturan supaya sisi Windows memeriksa hal yang sama dengan sisi Unix.
  - `test/test-pi-adapter.sh` — menyalakan `COOPERAGENT_PI_VERIFY_DEEP=1`. pi di
    sana adalah stub, jadi jalur mendalam gratis diuji dan tidak berubah menjadi
    kode yang tidak pernah dieksekusi.

  **Bukti.** `setup-pi.sh` lengkap terhadap gateway sungguhan: **0,306 detik**,
  dari sebelumnya lebih dari lima menit. Suite 7 dari 7 hijau.

  **Dampak.** Pemasangan dan "perbarui parameter" berhenti membayar ongkos
  inferensi. Yang dijamin tetap sama untuk hal-hal yang memang milik pemasang;
  yang tidak lagi dijamin secara baku adalah bahwa pi benar-benar MEMBACA aturan
  itu saat berjalan — untuk itu jalankan verifikasi mendalam.

  **Rollback.** `git revert` commit ini.

  **Diketahui.** Jalur mendalam di PowerShell masih tanpa batas waktu; sisi bash
  punya `PI_VERIFY_TIMEOUT`. Karena jalur itu kini opsional, paparannya kecil,
  tetapi kesenjangannya belum ditutup.

* **harness:** pi diperlakukan seperti harness lain di "lepas aturan agent"

  **Konteks.** Cacat berpasangan dengan yang di atas. Pilihan 5 memakai syarat
  `installed_pi && ! installed_grok && ! installed_omp`, sehingga dev yang punya
  Grok/omp **dan** pi tidak punya jalan sama sekali untuk memasang atau melepas
  aturan pi.

  **Perubahan.**
  - `setup.sh`, `setup.ps1` — aturan pi diatur bila pi terpasang, apa pun
    harness lain yang ada. Kode keluar setup-pi diteruskan, tidak ditelan.
  - `test/test-pi-adapter.sh` — pemeriksa syarat sempit kini menuntut **nol**
    kemunculan di baris non-komentar, bukan "paling banyak satu".

  **Yang TIDAK disentuh — dan sekarang dijaga uji.** Baik "perbarui parameter"
  maupun "lepas aturan agent" tidak boleh merusak milik dev:
  - `--remove-rules` hanya menghapus `AGENTS.md` yang **byte-identik** dengan
    template kami (`cmp -s`), sesudah mencadangkan dan memverifikasi cadangannya
    tidak kosong. Aturan yang sudah disunting dev dibiarkan, dengan pesan.
  - `models.json` dan `settings.json` **di-merge**, tidak ditimpa: provider
    lain, model tambahan, kunci berbayar, dan kunci tingkat atas milik dev
    dipertahankan. `skills` **disatukan** — skill dev dan `~/.cooper/skills`
    hidup berdampingan, tidak saling menggusur.
  - Kunci yang tidak dikelola CooperAgent tidak disentuh sama sekali. Uji kini
    menegaskan `mcpServers`, `extensions`, dan `keybindings` milik dev lolos
    utuh melewati merge, di **kedua** jalur: `test/test-pi-adapter.sh` untuk
    Node, `test/Test-PiModels.ps1` untuk PowerShell.

  **Bukti.** Suite 7 dari 7 hijau; uji PowerShell dijalankan runner Windows.

  **Rollback.** `git revert` commit ini.

* **harness:** pi jadi pilihan 3, opsi "Keduanya" dihapus, header menyebut pi

  **Konteks.** Sesudah jalur Windows terbukti, menu masih memperlakukan pi
  sebagai tempelan di nomor 5, dan header "sudah terpasang" tidak pernah
  menyebut pi meski jelas terpasang.

  **Perubahan.**
  - `setup.sh`, `setup.ps1` — menu harness diurutkan ulang: `1) Grok Build`,
    `2) Oh My Pi / omp`, `3) Pi Agent / pi`, `4) Manual`. Opsi
    `Keduanya (Grok Build + Oh My Pi)` **dihapus** atas keputusan pemilik.
    Nomor 4 (Manual) tidak bergeser; nomor 5 tidak lagi ada.
  - `setup.sh`, `setup.ps1` — keterangan pi diganti agar sejajar gaya dua
    lainnya: `coding agent CLI ringan: 4 tool inti, hemat token, sesi
    bercabang`.
  - `setup.sh:663`, `setup.ps1:565` — pi ditambahkan ke daftar harness
    **sesudah** barisnya dicetak, sehingga header selamanya berbunyi
    `Grok Build, Oh My Pi (omp)` pada mesin yang punya ketiganya. Dipindah ke
    sebelum pencetakan, di kedua installer.
  - `setup.sh`, `setup.ps1` — "Perbarui parameter dari kontrak gateway" kini
    menyegarkan pi bila terpasang. Syarat lamanya menuntut pi terpasang **dan**
    Grok/omp tidak ada, sehingga hanya dev yang memakai pi saja yang terlayani.
    pi tidak pernah **dipasang** di jalur ini: yang belum punya pi tetap tidak
    mendapatkannya.
  - `test/test-pi-adapter.sh` — tiga uji baru: pi ada di nomor 3 dan dicetak
    sebelum prompt; pi masuk daftar harness sebelum baris header dicetak; dan
    jalur "perbarui parameter" tidak lagi memakai syarat sempit.

  **Bukti.** Suite 7 dari 7 hijau.

  **Dampak — perlu diketahui dev.** Dev yang terbiasa mengetik `3` untuk
  memasang Grok + omp sekarang mendapat **pi**. Kombinasi Grok + omp dalam satu
  jalan tidak lagi tersedia; keduanya dipasang dengan menjalankan setup dua
  kali. Default (`1` = Grok Build) tidak berubah.

  **Rollback.** `git revert` commit ini.

  **Diketahui, belum diputuskan.** Pilihan 5 ("Lepas aturan agent") masih
  memakai syarat sempit yang sama, sehingga dev dengan Grok/omp **dan** pi
  mengatur aturan pi-nya tidak lewat jalur itu. Cacat yang sama bentuknya,
  sengaja tidak disentuh karena tidak diminta.

* **harness:** `verify()` pi di Windows menyalin config ke jalur yang salah

  **Konteks.** Sesudah merge diperbaiki, `.\setup.ps1` pilihan 5 menulis
  `models.json`, `settings.json`, aturan, dan cadangannya dengan benar, lalu
  `verify()` gagal: `Unknown provider "cooperagent"` — pi tidak melihat provider
  yang baru saja ditulis.

  **Perubahan.**
  - `scripts/lib/PiModels.ps1` — `Invoke-PiVerify` menyalin berkas ke
    `Join-Path $tmp 'agentmodels.json'`: nama direktori `agent` disambung ke
    nama berkas **tanpa pemisah**, sisa terjemahan harfiah dari
    `"$tmp/agent/models.json"` versi bash. Berkasnya mendarat di akar direktori
    sementara, sementara `PI_CODING_AGENT_DIR` menunjuk `agent` yang ada tetapi
    kosong. Direktori kini dibentuk sekali (`$agentTmp`, `$projectTmp`) dan
    dipakai ulang.
  - `scripts/lib/PiModels.ps1` — marker aturan diberi label
    (`VERIFICATION SENTENCE: ...`) dan promptnya dibuat deterministik, sejajar
    dengan jalur Unix; tiga sebab kegagalan dilaporkan terpisah alih-alih satu
    pesan gabungan.
  - `test/Test-PiModels.ps1` — lint yang menolak `Join-Path` yang menyambung
    `agent` ke nama berkas tanpa pemisah, dengan baris komentar dibuang lebih
    dulu supaya ia tidak menyala pada dokumentasinya sendiri.

  **Bukti.** Lint diuji terhadap kedua versi: **4 kecocokan** pada berkas
  sebelum perbaikan, **0** sesudahnya.

  **Dampak.** Memulihkan `verify()` pi di Windows. Tidak ada perubahan pada
  jalur Linux/macOS.

  **Rollback.** `git revert` commit ini.

  **Batas yang jujur.** Lint hanya menangkap bentuk typo ini, bukan kelas
  "jalur salah" secara umum. `Invoke-PiVerify` sendiri tetap tidak dapat diuji
  di CI — ia menuntut biner pi dan gateway yang hidup — jadi jalur itu masih
  bergantung pada uji manual di Windows.

* **harness:** merge config pi gagal di Windows — array satu elemen terbongkar

  **Konteks.** Sesudah menu diperbaiki, `.\setup.ps1` pilihan 5 berhasil
  melewati gerbang kredensial dan mengambil kontrak, lalu berhenti dengan
  `Template models pi tidak memuat model` di `PiModels.ps1:75` — pada template
  yang jelas-jelas memuat satu model.

  **Perubahan.**
  - `scripts/lib/PiModels.ps1` — `Merge-PiModels` membaca `models` lewat
    `Get-PiPropertyValue`, yang berakhir dengan `return $p.Value`. `return`
    mengirim nilai ke pipeline, dan pipeline **membongkar** array: array berisi
    satu elemen keluar sebagai elemennya sendiri. Karena template memuat tepat
    satu model, `-isnot [System.Array]` bernilai benar dan gerbang menuduh
    template kosong. Kini membaca `.Value` dari objek propertinya langsung,
    pola yang memang sudah dipakai `Merge-PiSettings` untuk `skills`.
  - `test/Test-PiModels.ps1` (baru) — uji runtime yang menjalankan
    `Merge-PiModels` dan `Merge-PiSettings` sungguhan atas template yang
    dirender, memakai config dev tiruan. Ia menegaskan `models` tetap array,
    angka kontrak masuk, provider dan kunci berbayar milik dev utuh, `skills`
    tetap array, dan setelan lain tidak hilang. Tanpa jaringan, tanpa memasang
    apa pun.
  - `.github/workflows/test.yml` — uji itu dijalankan pada runner Windows,
    bersama job parse.

  **Bukti.** Galat aslinya `PiModels.ps1:75`, dan jalur Unix tidak pernah
  terpengaruh karena merge di sana dikerjakan Node, bukan PowerShell.

  **Dampak.** Memulihkan pemasangan pi di Windows. Tidak ada perubahan pada
  jalur Linux/macOS maupun pada bentuk config yang ditulis.

  **Rollback.** `git revert` commit ini; pemasangan pi di Windows kembali
  berhenti di merge.

  **Catatan.** Ini cacat Windows **kedua** yang lolos karena tidak ada satu pun
  yang menjalankan PowerShell. Job parse membuktikan berkas sah; ia tidak
  membuktikan fungsinya bekerja. Membongkar array satu elemen saat `return`
  adalah perilaku yang tidak punya padanan di bash, jadi tidak ada uji Linux
  yang bisa menangkapnya — hanya menjalankannya di Windows yang bisa.

* **harness:** pilihan 5 (pi) tidak terlihat di menu Windows

  **Konteks.** Sesudah cacat parse diperbaiki, `.\setup.ps1` berjalan tetapi
  menu harness hanya menampilkan 1–4. Promptnya sendiri sudah menerima 5
  (`Pilihan [1/2/3/4/5, default: 1]`), sehingga pilihannya ada tetapi tak
  seorang pun tahu.

  **Perubahan.**
  - `setup.ps1` — `Write-Host "  5) Pi Agent ..."` berada SESUDAH
    `Read-Host`. `Read-Host` memblokir, jadi baris itu baru tercetak setelah dev
    menjawab. Dipindah ke sebelum prompt, sejajar dengan `setup.sh` yang memang
    sudah benar.
  - `setup.sh`, `setup.ps1` — label menu mode "sudah terpasang" diperbarui dari
    `Pasang harness tambahan (Grok / omp yang belum ada)` menjadi
    `(Grok / omp / pi yang belum ada)`. Jalur itulah yang menuju pemasangan pi,
    dan sebelumnya namanya tidak menyebutkannya.
  - `test/test-pi-adapter.sh` — uji baru memeriksa **urutan**: baris menu
    pilihan 5 harus muncul sebelum baris prompt, di kedua installer.

  **Bukti.** Uji lama lolos karena hanya memeriksa string `5) Pi` **ada** di
  berkas, bukan letaknya. Uji baru gagal pada berkas sebelum perbaikan dan lulus
  sesudahnya, di `setup.sh` maupun `setup.ps1`.

  **Dampak.** Dev Windows kini melihat pilihan pi. Tidak ada perubahan perilaku
  bagi yang memilih 1–4.

  **Rollback.** `git revert` commit ini; pilihan 5 kembali tersembunyi di
  Windows.

  **Catatan.** Cacat ini tidak dapat ditangkap job `ps-parse`: berkasnya sah
  secara sintaks, hanya urutan eksekusinya yang salah. Parser membuktikan berkas
  dapat dijalankan, bukan bahwa ia melakukan hal yang benar.

* **harness:** `setup.ps1` gagal di-parse untuk SETIAP dev Windows

  **Konteks.** Sesudah `v1.4.0` terbit, `.\setup.ps1` mati sebelum baris
  pertama dengan `MissingEndParenthesisInExpression`. Bukan hanya jalur pi:
  berkas yang tidak dapat di-parse membuat seluruh pemasang berhenti, apa pun
  harness yang dipilih dev.

  **Perubahan.**
  - `scripts/lib/PiModels.ps1` — `Invoke-PiPrint` memecah satu pemanggilan
    perintah ke baris berikutnya tanpa backtick. PowerShell membaca
    `--no-session` di awal baris sebagai operator, dan seluruh berkas gagal
    di-parse. Argumen kini dikumpulkan ke array lalu di-splat (`& $PiPath
    @piArgs`) — backtick di akhir baris memperbaiki gejalanya tetapi rapuh
    sendiri, karena satu spasi di belakangnya mematahkannya lagi dan spasi itu
    tidak terlihat saat review.
  - `.github/workflows/test.yml` — job baru `ps-parse` pada `windows-latest`
    mem-parse **setiap** berkas `.ps1` dengan parser Windows PowerShell 5.1
    (`[Parser]::ParseFile`), bukan pwsh 7, karena 5.1 yang menjadi target
    kompatibilitas repo ini.

  **Bukti.** Galat aslinya menunjuk `scripts/lib/PiModels.ps1:218 char:76`.
  Berkas itu lolos uji hitung-kurung yang ada (`80/80` kurawal, `127/127`
  kurung biasa) — bukti langsung bahwa menghitung kurung **bukan** parser.
  Tidak ada `pwsh` di mesin pengembangan, sehingga satu-satunya penjaga yang
  sahih adalah runner Windows di CI.

  **Dampak.** Memulihkan `setup.ps1` untuk seluruh dev Windows. Tidak ada
  perubahan pada jalur Linux/macOS, pada config yang ditulis, maupun pada
  perilaku Grok/omp.

  **Rollback.** `git revert` commit ini; `setup.ps1` kembali gagal di-parse di
  Windows, jadi rollback hanya masuk akal bila diganti perbaikan lain.

  **Catatan proses.** `v1.4.0` terbit sebelum jalur Windows pernah dieksekusi
  sekali pun. Job `ps-parse` ada supaya urutan itu tidak terulang: cacat
  sintaks PowerShell kini menghentikan PR, bukan menunggu dev menemukannya.

## [1.4.0](https://github.com/LyKhan77/CooperAgent-cli/compare/v1.3.0...v1.4.0) (2026-09-04)


### Fitur

* **harness:** pi sebagai pilihan pemasangan ketiga, tanpa menyentuh Grok/omp ([dde4721](https://github.com/LyKhan77/CooperAgent-cli/commit/dde472130c12cb06986a44016eccfd6d80db523b))


### Perbaikan

* **harness:** verify() pi gagal justru ketika polanya ditemukan ([f9abcc4](https://github.com/LyKhan77/CooperAgent-cli/commit/f9abcc474cef259cd14b2284e606691b6579f8de))


### Dokumentasi

* luruskan --help, riwayat versi, dan entri changelog kembar ([205d7b7](https://github.com/LyKhan77/CooperAgent-cli/commit/205d7b7d81d03b8cb1e54aa6b65777c853955701))

#### Rincian — Fitur

* pi ditambahkan sebagai harness opsional pada pilihan 5. Adapter terisolasi
  menulis `~/.pi/agent/models.json` dan `settings.json` secara merge, memakai
  token `ca_...`, kontrak `/v1/models`, aturan penuh `~/.pi/agent/AGENTS.md`,
  compaction turunan kontrak, serta `verify()` untuk chat, identitas gateway,
  aturan global, dan checkpoint; default Grok/omp tidak berubah.

#### Rincian — Perbaikan

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


---

## Catatan rinci

Seksi bernomor di atas: satu baris per perubahan, ditulis saat merilis. Sampai
17 September 2026 ia diisi otomatis oleh release-please; sejak itu ditulis
tangan bersama tag rilisnya.

Seksi ini berisi catatan panjangnya — konteks, bukti, dampak, dan cara mundur —
untuk perubahan yang membutuhkannya. Ditulis saat perubahannya dikerjakan, tidak
menunggu rilis; tanggal pada tiap judul menyebut kapan ia masuk, dan seksi
bernomor di atas menyebut rilis mana yang membawanya.


### Fixed · 2026-09-17 — token dev pi-saja tidak pernah terbaca

**Konteks.** `stored_token` membaca dari grok, lalu omp, lalu pi. Cabang pi
berada **di dalam** cabang omp: indentasinya menyatakan sejajar, `fi` gandanya
menyatakan bersarang.

```bash
if [ -z "$v" ] && installed_omp; then
    v="$(omp_api_key_of ...)"
    case "$v" in ca_*) ;; *) v="" ;; esac
if [ -z "$v" ] && installed_pi; then     # <- di dalam cabang omp
    v="$(pi_api_key_of ...)"
fi
fi
```

Dev yang memasang **pi saja** karena itu tidak pernah sampai ke pembacaannya:
layar "sudah terpasang" mengatakan *"tidak ada token di config — Permintaan ke
gateway akan dijawab 401"* padahal tokennya ada di `models.json`. Lalu pilihan
"Ganti alamat gateway" menolaknya dengan *"Tidak ada token untuk diverifikasi"*
dan menyuruhnya menempel ulang token yang sudah benar — hanya untuk pindah
LAN/VPN.

`stored_gateway` tepat di atasnya datar dan benar, dan jalur `--endpoint` punya
rantai fallback sendiri yang juga benar. Cacatnya hanya di satu fungsi — dan di
cerminannya, `Get-CooperStoredToken` di `setup.ps1`, dengan bentuk yang sama
persis.

**Perubahan.**

- `setup.sh` (`stored_token`) dan `setup.ps1` (`Get-CooperStoredToken`) —
  ketiga pembacaan diratakan, masing-masing memvalidasi `ca_*`.
- `setup.sh` — pesan galat jalur `--endpoint` menyebut satu berkas
  (`~/.grok/config.toml`) padahal fallbacknya membaca tiga. Dev pi-saja
  disuruh memperbaiki berkas yang memang tidak ia punya; kini ketiganya
  disebut.
- `test/test-credential-gate.sh` — bagian "dev pi-saja" dan pagar struktural
  untuk sisi Windows.

**Bukti.** Ujinya menjalankan `setup.sh` sungguhan terhadap `HOME` berisi pi
saja, dan memeriksa **apa yang dibacakan kepada dev** — bukan nilai kembalian
fungsinya. Sisi Windows diperiksa dari Linux tanpa PowerShell: ketiga pembacanya
harus berada pada **kedalaman kurung yang sama**, dan yang bersarang terbaca
lebih dalam. Ketiga pemeriksaan dibuktikan merah dengan mengembalikan bentuk
bersarangnya di kedua berkas.

**Dampak.** Dev yang memasang pi saja. Yang memasang grok atau omp di sampingnya
tidak pernah terkena — tokennya terbaca lebih dulu dari sana, dan itulah yang
menyembunyikan cacat ini.

**Rollback.** Revert commit ini.

### Fixed · 2026-09-17 — omp tidak terlihat di Windows sejak 3.0.0

**Konteks.** Ditemukan saat memeriksa apakah ganti gateway benar-benar menyentuh
ketiga harness. Di Linux/macOS: ya, semuanya lewat satu pintu
(`apply_to_all_harness`). Di Windows: **omp dilewati sepenuhnya.**

`Test-CooperOmpInstalled` mendeteksi omp dengan `-match '^  cooperagent:'` —
nama sebelum penyatuan profil 3.0.0. `templates/omp-models.yml` menulis
`cooper-agent`, `cooper-s1`, `cooper-s2`, dan `'  cooper-agent:'` tidak cocok
dengan pola itu: ada stripnya. Setiap pemasangan omp Windows yang berkasnya
dibuat 3.0.0 ke atas karena itu tidak pernah terlihat sebagai terpasang, dan
`Set-CooperAllHarness` melewati seluruh blok omp — **baseUrl dan apiKey-nya
tidak pernah ditulis** saat dev berganti LAN/VPN atau mengganti token.

Pemasangan lama justru selamat: berkasnya masih menyimpan kunci `cooperagent`
di sampingnya.

`Get-OmpStoredKey` dan `Get-OmpStoredGateway` punya cacat yang sama lewat
`-like 'cooperagent*'`, jadi pembacaannya ikut buta. Yang tidak bermasalah:
`Set-OmpBaseUrl` dan `Set-OmpApiKey` mengenali provider dari baris `baseUrl`-nya,
bukan dari nama — keduanya akan bekerja, hanya tidak pernah dipanggil.

Sisi bash tidak pernah terkena: regexnya menerima kedua nama sejak awal. Itu
justru yang membuatnya bertahan — dev Linux tidak pernah mengalaminya, dan
tidak ada satu pun uji yang MENJALANKAN sisi PowerShell omp.

**Perubahan.**

- `scripts/lib/OmpModels.ps1` — `Test-OmpNamaMilikKami`, satu fungsi, cermin
  regex di `omp_models.sh`. Kedua pembaca memanggilnya.
- `setup.ps1` — `Test-CooperOmpInstalled` memakai fungsi itu, tidak lagi mematok
  polanya sendiri. Pesan "(3 provider: otomatis, localhost, server 2)" juga
  dibetulkan: provider keduanya s1, bukan localhost, sejak 3.0.0.
- `test/Test-OmpModels.ps1` (baru) — uji runtime di runner Windows: nama 3.0.0
  dikenali, nama lama tetap dikenali, provider dev **tidak** diakui milik kita,
  gateway berpindah dengan jalur `/upstream` utuh, kunci berbayar dev selamat.
- `test/test-credential-gate.sh` — pagar paritas dari Linux.

**Kenapa polanya disatukan, bukan sekadar diperbaiki di tiga tempat.** Tiga
salinan dengan dua ejaan berbeda adalah persis bagaimana cacat ini lahir: nama
berubah di satu tempat, dan tidak ada yang tahu dua tempat lain ikut berhenti
cocok. Pagar paritasnya karena itu menjaga bahwa polanya **tetap satu fungsi**,
bukan menjaga ejaannya.

**Bukti.** `test-credential-gate.sh` bertambah empat pemeriksaan, dan saya
buktikan memerah dengan mengembalikan `-like 'cooperagent*'`. Pagar paritas itu
sempat merah atas kode yang sudah benar — ia mengenai komentar yang menjelaskan
pola lamanya; kini komentar dibuang sebelum dicocokkan.

`Test-OmpModels.ps1` **belum pernah dijalankan**: tidak ada PowerShell di mesin
ini, dan runner Windows-lah yang akan membuktikannya pertama kali. Yang sudah
diperiksa dari sini hanya kurung seimbang dan tiadanya non-ASCII di baris kode.

**Dampak.** Dev omp Windows menjalankan `.\setup.ps1` sekali; sesudah itu ganti
gateway dan token menyentuh omp seperti seharusnya. Yang di Linux/macOS tidak
terpengaruh sama sekali.

**Rollback.** Revert commit ini. Omp Windows kembali tidak terlihat; tidak ada
yang lain yang bergantung padanya.

### Fixed · 2026-09-18 — mendorong tag menjalankan seluruh suite

**Konteks.** `git push origin v3.1.2` menjalankan seluruh suite — tiga menit —
untuk mendorong satu objek tag 207 byte. Commit yang ditunjuknya sudah diuji
beberapa detik sebelumnya, saat `git push origin main`.

Hook `pre-push` hanya membedakan satu hal: penghapusan branch, yang SHA lokalnya
nol. Push tag terlihat sama seperti push branch baginya.

**Perubahan.** `scripts/hooks/pre-push` melewati ref `refs/tags/*` **bila commit
yang ditunjuknya sudah ada di remote**. Tag yang menunjuk commit yang belum
terdorong justru membawa kodenya, jadi ia tetap diuji — begitu pula bila keadaan
remote tidak bisa dipastikan dari sini. Ragu berarti menguji, bukan melewati.

**Bukti.** `test-hook-pre-push.sh` 8 → 10. Kasus keduanya dibuktikan merah
dengan melewati tag tanpa syarat: *"kode bisa sampai ke origin tanpa diuji"*.
Pembuktian itu sempat gagal menunjukkan apa pun karena label `ok` dan `no`-nya
berbeda sehingga pencariannya meleset — keduanya kini sama.

**Dampak.** Mendorong tag rilis tidak lagi menunggu tiga menit.

### Changed · 2026-09-17 — release-please dilepas, rilis diberi tag dengan tangan

**Konteks.** Tiga kali dalam satu hari alur PR berhenti karena aturan, bukan
karena kode: judul ditolak, lalu judul ditolak lagi dengan alasan yang
berlawanan, lalu PR harus dibuka ulang karena body-nya tidak memuat checklist.
Kalimat yang mengakhirinya: *"sumpah ini bingung sekali."*

Akarnya satu, dan bukan salah satu dari aturan itu. release-please menentukan
rilis dari pesan commit, sementara GitHub menaruh judul PR ke badan merge commit
— sehingga judul PR ikut terbaca sebagai commit, dan satu perubahan tercatat dua
kali. Setiap tambalan melahirkan tambalan berikutnya:

- larangan prefiks di judul PR (karena merge commit menggandakan),
- lalu **kewajiban** prefiks (karena squash membuat judul menjadi commit),
- lalu skrip dan uji yang menjaga keduanya tetap sinkron dengan workflow-nya.

Tiga lapis aturan untuk satu masalah yang tidak dimiliki siapa pun yang memberi
tag dengan tangan.

**Perubahan.**

- Dihapus: `.github/workflows/pr-title.yml`, `.github/workflows/release-please.yml`,
  `release-please-config.json`, `.release-please-manifest.json`,
  `test/test-pr-title-guard.sh`, `test/test-checklist-uji.sh`.
- `.github/workflows/test.yml` → `windows-powershell.yml`, disisakan **satu job**:
  parser PowerShell 5.1 dan `Test-PiModels.ps1`.
- `scripts/pr.sh` — pagar judul dan penanaman checklist dibuang. Yang tersisa:
  jalankan suite, push, cetak tautan. Judul PR bebas.
- `docs/versioning.md`, `AGENTS.md` — alur rilis ditulis ulang untuk `git tag`.

**Kenapa job Windows tidak ikut dilepas.** Alasannya tidak pernah sama dengan
yang lain. Ia tidak menuntut apa pun dari siapa pun — tidak ada judul yang harus
berbentuk tertentu, tidak ada checklist yang harus diisi — dan ia memeriksa
satu-satunya hal yang tidak bisa diperiksa dari mesin dev mana pun di tim ini:
`.ps1`. Menghitung kurung bukan parser; `PiModels.ps1` pernah punya kurung
seimbang sempurna dan tetap gagal di-parse, dan `setup.ps1` mati untuk setiap dev
Windows sampai v1.4.0 terbit.

**Yang hilang, dan itu memang hilang.** CHANGELOG tidak lagi terisi sendiri, dan
versi tidak lagi naik sendiri. Keduanya kini keputusan manusia yang harus
diingat saat merilis. Di repo dengan satu penulis tetap dan beberapa rilis
sebulan, ongkos mengetik `git tag` lebih kecil daripada ongkos mengingat tiga
lapis aturan judul — tetapi ongkosnya bukan nol, dan lupa menaikkan
`version.txt` tidak akan digagalkan oleh apa pun.

**Dampak.** Dua baris kembar peninggalan merge commit `#31` dan `#33` menjadi
tidak relevan: tidak ada lagi PR rilis yang akan memuatnya. Tulis entri
rilisnya dengan tangan saat memberi tag.

**Rollback.** Kembalikan keempat berkas konfigurasi dan kedua workflow dari
riwayat git. Pagar judul harus ikut kembali, dengan polaritas yang sesuai
strategi merge yang dipilih — itulah yang membuatnya mahal sejak awal.

### Changed · 2026-09-17 — suite pindah ke lokal, CI tinggal memeriksa

**Konteks.** Alur PR masih menuntut pekerjaan manual: judul diketik ulang, lalu
menunggu CI menjalankan suite yang sama yang baru saja hijau di mesin dev.
Permintaannya jelas — "cukup unit test di lokal, CI hanya cross check, saya
hanya cek PR masuk lalu confirm merge".

**Perubahan.**

- `scripts/lib/uji_lokal.sh` (baru) — satu penjalan suite, dipakai hook maupun
  `pr.sh`. Daftar ujinya adalah isi `test/`, bukan daftar yang disalin tangan.
- `scripts/hooks/pre-push` (baru) — menjalankan suite; push ditolak bila merah.
  Dipasang lewat `core.hooksPath` yang ikut ter-commit, bukan disalin per mesin.
- `.github/workflows/test.yml` — job yang menjalankan suite **dihapus**. Yang
  tersisa: sintaks bash, validator checklist, dan job Windows yang tidak
  disentuh sama sekali.
- `scripts/pr.sh` — menjalankan suite, menanam hasilnya sebagai checklist ke
  pesan commit, lalu mem-push. Argumen judul **dihapus**.
- `test/test-hook-pre-push.sh`, `test/test-checklist-uji.sh` (baru) — 8 dan 16
  pemeriksaan; keduanya mengeksekusi yang sebenarnya berjalan, bukan salinannya.

**Kenapa judul tidak lagi bisa dititipkan.** Di bawah squash, yang menentukan
judul PR adalah isian otomatis GitHub — pada branch satu commit, subjek commit.
Judul yang dititipkan lewat argumen atau query string hanya akan berbeda dari
yang sebenarnya terpakai, dan pemeriksaan yang memeriksa hal lain dari yang
berlaku lebih buruk daripada tidak ada pemeriksaan. Sekaligus itulah yang membuat
body PR selamat: ia terisi dari badan commit, tanpa batas panjang URL dan tanpa
kehilangan prosa. Ganti judul = `git commit --amend`.

**Checklist adalah sambungannya.** Suite berjalan di lokal, jadi CI tidak bisa
melihat hasilnya. `pr.sh` menanam hasil itu ke pesan commit; pesan commit menjadi
body PR; CI membacanya dari sana dan memastikan **setiap** berkas `test/test-*.sh`
disebut, tidak ada yang ditandai merah, dan tidak ada baris yang menyebut berkas
yang tidak ada. Satu uji baru yang tidak pernah dijalankan karena itu tidak bisa
lolos diam-diam.

**Yang TIDAK dibuktikan, dan jangan dianggap sebaliknya.** Validator itu
membuktikan **kecocokan** antara checklist dan isi repo — bukan bahwa ujinya
lulus. Yang membuktikan lulus adalah hook, di mesin yang menjalankannya, dan
`git push --no-verify` melewatinya. Jaringnya lebih longgar dari sebelumnya; itu
pertukaran yang diminta dan disetujui, bukan kebetulan. Job Windows sengaja tidak
ikut pindah: tidak ada PowerShell di mesin dev mana pun di tim ini, jadi
memindahkannya berarti menghapusnya.

**Bukti.** Suite 12 → 14 berkas, semuanya hijau lewat `pr.sh`. Hook dibuktikan
menahan: satu uji dibuat merah, push ditolak dan nama ujinya disebut. Validator
dibuktikan menangkap keempat bentuk kegagalannya (berkas tak disebut, uji merah,
berkas hantu, body kosong).

Penanaman checklist diuji dari ujung ke ujung, dan itu perlu — jalur itu rusak
dua kali saat ditulis, keduanya dengan bentuk yang sama: **melapor sukses yang
tidak terjadi**. Pertama `BLOK` diteruskan sebagai argumen alih-alih env,
`python3` melempar `KeyError`, dan `2>/dev/null` menelannya sehingga yang
terlihat hanya tuduhan terhadap python3. Kedua, `git commit --amend` ditolak git
sementara `pr.sh` tetap mencetak tanda centang dan mem-push.

`pr.sh` kini memeriksa **hasilnya**: pesan commit sesudah amend dibandingkan
dengan pesan yang dimaksud, bukan dicari penandanya — commit pada jalan kedua
sudah memuat penanda dari jalan pertama, sehingga pencarian penanda meloloskan
amend yang gagal. Gagal menanam berarti **tidak di-push**: body PR tanpa
checklist pasti ditolak validator, dan mem-push-nya hanya memindahkan kegagalan
ke tempat yang lebih lambat terlihat. Diuji dengan mengunci `.git/objects`
sehingga amend benar-benar gagal.

**Dampak.** Setiap push kini menunggu suite (~3 menit). Itu ongkos yang dipindah,
bukan yang ditambah — sebelumnya menunggu di CI sesudah push.

**Rollback.** Kembalikan langkah-langkah suite ke `test.yml` dan hapus hook. Job
Windows dan pagar judul tidak terlibat; keduanya berdiri sendiri.

### Changed · 2026-09-17 — squash merge, dan pagar judul PR dibalik

**Konteks.** Alur PR menuntut satu pekerjaan manual pada **setiap** PR, dan
pekerjaan itu tidak pernah bisa dihindari. Di bawah merge commit, judul PR
berprefiks conventional dilarang — GitHub menaruhnya di badan merge commit dan
release-please membacanya sebagai commit kedua, sehingga entri terbit dua kali.
Sudah lima kali: `v2.0.1`, `v2.1.0`, `v2.1.1`, `v3.0.0`, `v3.0.1`.

Tapi bila branch berisi **tepat satu commit** — bentuk normal di repo ini —
GitHub mengisi judul PR dari subjek commit itu, yang tentu conventional. Jadi
isian otomatis GitHub **selalu** melanggar aturannya sendiri, dan setiap PR
menuntut judulnya diketik ulang. Pagar yang menuntut pekerjaan manual pada setiap
PR adalah pagar yang akhirnya dimatikan orang; permintaannya memang muncul
sebagai "tolong buat CI-nya tidak perlu".

**Perubahan.** Repo pindah ke **Squash and merge**. Judul PR menjadi subjek
satu-satunya commit di `main`, jadi prefiks conventional kini **wajib** — dan
isian otomatis GitHub sudah memenuhinya. Tidak ada merge commit yang
menyelundupkan judul sebagai commit kedua, jadi tidak ada duplikasi. Satu commit
per branch berarti: buat PR, tekan Squash and merge, tanpa mengetik apa pun.

- `.github/workflows/pr-title.yml` — kondisinya dibalik: prefiks wajib, bukan
  dilarang. Struktur yang dijaga uji tetap utuh (pemicu `edited`, pengecualian
  release-please, pola dibaca dari satu baris `grep -qE`).
- `scripts/pr.sh` — verdictnya dibalik, dan **argumennya kini opsional**: pada
  branch satu commit ia mengambil judul dari subjek commit, persis yang akan
  diisi GitHub. Pada branch dua commit atau lebih ia menolak menebak.
- `docs/versioning.md`, `AGENTS.md` — keputusan dan alasannya dibalik, termasuk
  kenapa kebijakan lama tidak bisa dipertahankan.
- `test/test-pr-title-guard.sh` — kolom ekspektasi dibalik, 18 → 21 pemeriksaan.
- `release-please-config.json` — seksi `ci` ditambahkan (tidak disembunyikan).
  Tanpanya perubahan kebijakan seperti ini tidak pernah muncul di catatan rilis,
  padahal setiap PR berikutnya bergantung padanya. `ci` tetap tidak menaikkan
  versi; entrinya ikut rilis berikutnya yang memang naik.

**Keberatan asli dijawab, bukan dilewati.** Squash ditolak pada 5 September 2026
dengan alasan yang sah: footer `BREAKING CHANGE:` hidup di badan commit, dan
badan commit squash diambil dari body PR — yang bisa disunting atau dikosongkan
siapa pun sebelum merge. Kenaikan MAJOR yang hilang tidak menggagalkan apa pun;
ia terbit sebagai patch, diam-diam.

Jawabannya: penanda MAJOR dipindahkan ke **`!` di subjek** (`feat(setup)!: …`),
yang selalu menjadi subjek commit dan karena itu tidak bisa hilang. Footer tetap
boleh ditulis sebagai penjelasan, tetapi bukan lagi yang menentukan. Pagarnya
sudah menerima bentuk itu dan kini diuji untuk kedua bentuknya.

**Bukti.** `test-pr-title-guard.sh` 21/21. Ujinya **mengeksekusi blok `run:` dari
workflow**, bukan salinan regexnya, jadi membalik workflow otomatis membalik apa
yang diuji — yang saya balik dengan tangan hanya kolom ekspektasinya. Kasus yang
LOLOS kini berlanjut ke `git push`, jadi ia dipindahkan ke kotak pasir; hanya
kasus yang ditolak dijalankan di repo ini, karena ia berhenti sebelum menyentuh
remote. Suite bash penuh 12/12.

**Dampak.** Satu setelan di GitHub yang harus ditekan tangan: Settings → General
→ Pull Requests → aktifkan *Allow squash merging*, *Default commit message* =
**"Pull request title and description"**, dan matikan *Allow merge commits*
supaya tombol yang salah tidak bisa ditekan. Tanpa setelan itu, PR berikutnya
di-merge sebagai merge commit dengan judul conventional — tepat pola yang
menggandakan entri. Urutannya karena itu mengikat: setelan dulu, merge PR ini
kemudian, dan PR ini di-merge dengan **Squash**.

**Rollback.** Revert commit ini DAN kembalikan setelan repo ke merge commit.
Membalik salah satunya saja menghasilkan keadaan yang tidak pernah benar: pagar
lama dengan squash membuat setiap perubahan terbit tanpa entri, pagar baru dengan
merge commit menggandakan setiap entri.
### Fixed · 2026-09-17 — pi menunjuk provider yang tidak dikelola siapa pun

**Konteks.** `templates/pi-settings.json` menyetel `defaultProvider` ke
`cooperagent` — nama tanpa strip, peninggalan sebelum penyatuan profil 3.0.0.
`templates/pi-models.json` tidak pernah punya provider bernama itu, dan
`Merge-PiModels`/`mergeModels` hanya mengelola provider yang **ada di template**.
Nilai itu karena itu tidak pernah tersentuh siapa pun.

Dua populasi, dua gejala, dan keduanya senyap dari sisi pemasang:

- Pemasangan pra-3.0.0 masih menyimpan provider yatim `cooperagent` di
  `models.json`. Ia dipertahankan apa adanya — memang begitu aturannya untuk
  provider di luar template — sehingga `baseUrl`-nya **beku**. pi tetap menembak
  alamat gateway lama setiap kali mesin pindah LAN/VPN, dan yang terlihat hanya
  timeout.
- Pemasangan 3.0.0 ke atas mendapat `cooperagent` dari template padahal provider
  itu tidak ada di `models.json`. pi menjawab `Unknown provider "cooperagent"` —
  bunyinya sama dengan galat 11 September, sebabnya lain.

Yang membuatnya bertahan: `verify()` memeriksa `baseUrl` dan `apiKey` provider
`cooper-agent`, dan provider itu selalu benar. Ia tidak pernah menanyakan
provider mana yang sebenarnya dipakai pi.

**Perubahan.**

- `templates/pi-settings.json` — `defaultProvider` menjadi `cooper-agent`.
- `scripts/lib/PiModels.ps1` (`Merge-PiSettings`) dan `scripts/lib/pi_json.mjs`
  (`mergeSettings`) — nilai lama `cooperagent` dipindah ke nilai template. Hanya
  nilai itu: `defaultProvider` lain adalah pilihan sadar dev dan tetap utuh.
- `test/Test-PiModels.ps1` dan `test/test-pi-adapter.sh` — kasus regresi di
  **kedua** jalur. Template yang benar tidak menolong pemasangan yang sudah ada;
  yang menentukan adalah merge-nya benar-benar memindahkan nilai lama.

**Bukti.** `test-pi-adapter.sh` bertambah tiga pemeriksaan: template menunjuk
provider yang benar-benar ada di `pi-models.json`, merge memindahkan
`cooperagent`, dan pilihan dev tidak ikut terbawa. Dengan template dikembalikan
ke `cooperagent`, yang pertama merah; dengan cabang migrasinya dibuang, yang
kedua merah. `Test-PiModels.ps1` 13/13 di job Windows. Direproduksi manual:
gateway dipindah LAN→VPN lewat `setup.ps1`, pi timeout ke IP lama; sesudah
patch, provider aktif ikut pindah dan pi menjawab.

**Dampak.** **Semua** pemasangan pi sejak 3.0.0, bukan hanya peninggalan —
templatnya sendiri yang menulis nilai buruk itu. Satu kali `setup`
memindahkannya; tidak ada yang perlu disunting tangan.

**Rollback.** Revert commit ini mengembalikan template ke `cooperagent` sekaligus
mematikan migrasinya — artinya mengembalikan bug-nya, pada kedua populasi. Bila
yang ingin dibatalkan hanya migrasi paksanya (mis. ada dev yang sengaja menamai
providernya sendiri `cooperagent`), buang cabang `elseif`/`else if`-nya saja dan
biarkan perubahan template berdiri: pemasangan baru selamat, yang lama tidak
tersentuh.

**Yang belum dibereskan.** `verify()` masih tidak pernah memeriksa provider mana
yang dipakai pi — ia mencetak "konfigurasi pi sesuai kontrak" sementara pi
merutekan lewat provider lain. Perbaikan ini menyembuhkan satu nilai buruk yang
diketahui, bukan titik butanya.

### Fixed · 2026-09-12 — omp juga tidak tahu modelnya bisa melihat

**Konteks.** Perbaikan pi di bawah sempat disertai klaim bahwa "Grok dan omp
tidak terpengaruh". Klaim itu berdasar `grep`, bukan pemeriksaan. Ditanya ulang
apakah SEMUA harness sudah dipastikan, jawabannya ternyata belum — dan omp
punya cacat yang sama.

omp membaca `c.supportsImages === true`. Perbandingannya ketat dan **tidak ada
nilai bawaan**: kunci yang hilang berarti model dianggap teks saja.
`templates/omp-models.yml` tidak pernah menyetelnya.

Grok memang bersih: binernya tidak punya deklarasi modalitas per-model sama
sekali, jadi ia selalu mengirim gambar apa adanya.

**Perubahan.**

- `templates/omp-models.yml` — `supportsImages: true` pada ketiga provider.
- `scripts/lib/omp_models.sh` — `omp_ensure_supports_images()`, jalur naik untuk
  pemasangan yang sudah ada.
- `scripts/setup-dev.sh` — memanggilnya **tanpa syarat**, terpisah dari
  penambahan provider.

Yang ketiga itu intinya. `merge_providers` bersifat **tambah-saja**: provider
yang sudah ada tidak pernah disentuh, supaya endpoint suntingan dev dan kunci
berbayarnya selamat. Konsekuensinya, memperbaiki template saja tidak menjangkau
seorang pun yang sudah memasang — dan merekalah semua dev kita. Menggantungkan
jalur naik ini pada cabang `$missing` akan membuatnya tidak pernah berjalan.

Jalur naik hanya **menambah kunci yang hilang**, hanya pada provider milik kita.
`supportsImages: false` yang ditulis dev tetap dihormati: itu pilihan sadar,
bukan kelalaian.

**Bukti.** `test-omp-providers.sh` 11 → 16: template menyatakan `true`,
pemasangan lama ikut naik, `false` dev dihormati, provider dev utuh, dan
idempoten. Suite penuh 11/11.

**Dampak.** Dev omp menjalankan `./scripts/setup-dev.sh` sekali.

### Fixed · 2026-09-12 — pi diberi tahu bahwa modelnya bisa melihat

**Konteks.** Di pi, meminta agent membaca gambar menghasilkan catatan di blok
thinking-nya: *"my model can't see images directly — description came from
vision subagent."* Jawabannya tetap datang, hanya saja dari model lain.

Modelnya sendiri bisa melihat. Kedua node memuat `mmproj` (889 MB, BF16) dan
presetnya menyatakan `capabilities = ["chat", "tools", "vision"]`. Diuji
langsung lewat gateway dengan PNG 64×64 separuh merah separuh biru: `s1`, `s2`,
dan `cooper-agent` ketiganya menjawab "Kiri: merah, kanan: biru".

Yang keliru ada di pihak kita: `templates/pi-models.json` menyatakan
`"input": ["text"]` untuk ketiga provider. pi mempercayainya, menolak mengirim
gambar ke model, lalu memanggil subagent vision. Tidak ada yang galat — kelas
kegagalan yang paling mahal, karena ia terlihat seperti berhasil.

**Perubahan.**

- `templates/pi-models.json` — `"input": ["text", "image"]` untuk `cooper-agent`,
  `cooper-s1`, dan `cooper-s2`.
- `test/test-pi-adapter.sh` — dua pemeriksaan baru: ketiga provider menyatakan
  `image`, **dan** merge benar-benar menimpa `["text"]` milik pemasangan lama.
  Yang kedua yang menentukan: template yang benar tidak menolong siapa pun bila
  merge memperlakukan provider yang sudah ada sebagai milik dev dan melewatinya.

**Bukti.** Dengan template dikembalikan ke `["text"]`, kedua pemeriksaan merah.
Suite penuh 11/11.

**Dampak.** Dev pi menjalankan `./scripts/setup-dev.sh` sekali; nilai lamanya
ditimpa. Grok dan omp tidak terpengaruh — keduanya tidak mendeklarasikan modalitas.

**Yang belum dibereskan.** Kemampuan ini **dipatok di klien**, melanggar aturan
#2. Gateway tidak mengumumkan `capabilities` pada `/v1/models` sama sekali,
sehingga template tidak punya sumber untuk menurunkannya. Selama itu, preset
yang mencabut vision tidak akan pernah sampai ke pi.

### Added · 2026-09-12 — `scripts/pr.sh`: satu langkah membuat PR

Pagar judul PR menangkap kesalahan **sesudah** PR dibuat: cek merah, sunting
judul, tunggu CI lagi. Yang salah pun bukan kelalaian — GitHub mengisi judul
sendiri dari subjek commit bila branch berisi tepat satu commit, jadi dev
melihat kolom yang sudah terisi dan tidak punya alasan mencurigainya.

`./scripts/pr.sh "Judul deskriptif"` memindahkan pemeriksaan itu ke sebelum PR
ada, lalu push dan mencetak tautan `compare` yang **judulnya sudah terisi** —
sehingga isian otomatis GitHub tidak pernah terpakai. Empat langkah manual
(push, salin tautan, buka peramban, ketik judul) menjadi satu.

Polanya **dibaca dari** `.github/workflows/pr-title.yml`, tidak disalin: pagar
lokal yang menyimpang dari pagar CI memberi lampu hijau pada judul yang ditolak
di server, dan itu persis penyakit yang pagar ini ada untuk mencegahnya.
`test/test-pr-title-guard.sh` (13 → 18) menuntutnya, memeriksa penolakan terjadi
sebelum remote disentuh, dan menjalankan jalur suksesnya di kotak pasir — uji
yang mem-push branch yang sedang dikerjakan adalah uji yang lama-lama tidak
dijalankan orang.

### Added · 2026-09-05 — Pagar judul PR

Larangan judul PR berprefiks conventional-commit dilanggar tiga kali di repo
ini — `v2.0.1`, `v2.1.0`, `v3.0.0` — dan juga di repo server. Dua di antaranya
adalah PR yang sedang memperbaiki akibat pelanggaran sebelumnya.

Pengulangannya bukan kelalaian: judul PR sering **tidak pernah diketik siapa
pun**. Bila branch berisi tepat satu commit, GitHub mengisinya dari subjek
commit itu — conventional. Tidak ada yang salah di layar; judulnya sudah
terisi, tinggal klik.

`.github/workflows/pr-title.yml` menggagalkan PR seperti itu sebelum sempat
di-merge. PR release-please dikecualikan lewat `head_ref`; tanpa itu pagar ini
memblokir setiap rilis.

`test/test-pr-title-guard.sh` (13 uji, masuk CI) **mengurai workflow-nya dan
menjalankan blok `run` apa adanya** — bukan salinan polanya, supaya tidak lahir
dua kebenaran yang harus dijaga sinkron dengan tangan. Ia memagari juga pemicu
`edited` dan pengecualian release-please. Judul PR diteruskan lewat `env`,
bukan `${{ }}` di badan skrip: judul ditulis siapa pun yang bisa membuka PR.

Aturannya kini juga tertulis di `docs/versioning.md`, yang sebelumnya hanya
membahas squash dan tidak menyebut masalah kembar sama sekali.

### Fixed · 2026-09-12 — Pembaru Windows tidak ikut bermigrasi

**Konteks.** Rename profil `internal-qwen*` → `cooper-*` dipasang di `setup.sh`,
`setup.ps1`, dan `scripts/setup-dev.sh`, lalu didokumentasikan sebagai "ketiga
jalur". Jalurnya ada **empat**: `scripts/setup-dev.ps1` terlewat — dan itulah
jalur yang `docs/dev_setup.md` anjurkan kepada dev Windows yang **sudah**
terpasang, yakni satu-satunya populasi yang pasti memegang config lama.

**Perubahan.**

- `scripts/setup-dev.ps1` — rename dijalankan sebelum `Merge-Toml`, hasilnya ke
  `$source` sehingga cadangan `.bak` tetap merekam berkas apa adanya di disk.
- `test/test-harness-profiles.sh` — kini menuntut **keempat** jalur, dengan pola
  yang lebih ketat: `[model.cooper-agent]` sebagai literal sesudah
  `internal-qwen`. Pola longgar sebelumnya diloloskan oleh regex penyuntik token
  di `setup-dev.ps1` yang menyebut kedua nama pada satu baris dan tidak
  mengganti apa pun. 31 → 33.

**Bukti.** Dengan `scripts/setup-dev.ps1` dikembalikan ke keadaan lama, uji
merah 2; dengan perbaikannya, 33/0. Keseimbangan kurung 142/142 (sebelumnya
134/134).

**Dampak.** Dev Windows yang memakai pembaru tidak lagi ditinggali
`[model.internal-qwen]` yatim di sebelah `[model.cooper-agent]`.

**Rollback.** Buang blok rename; uji akan kembali merah 2.

**Belum terverifikasi.** Jalur PowerShell tidak dijalankan di runner Linux —
`pwsh` tidak terpasang. Yang dijalankan hanyalah keseimbangan kurung dan uji
statis pola rename.

### Fixed · 2026-09-12 — `--remove-rules` berhenti tepat sebelum menghapus

**Konteks.** `scripts/setup-dev.sh --remove-rules` melaporkan aturan agent
dilepas, tetapi berkasnya masih di tempatnya. Uji `test-setup-dev.sh` sudah
merah sejak retensi `.bak` masuk (5 September 2026) — merahnya satu baris tanpa
sebab, `dapat 'ada', harusnya 'tidak'`, dan diperlakukan sebagai kegagalan lama
yang sudah ada.

**Perubahan.**

- `scripts/setup-dev.sh` — `. scripts/lib/backup.sh` dipindah ke atas blok
  `--remove-rules`. `bak_prune` dipakai di baris 147, tetapi pustakanya di-source
  di baris 207 dan blok itu `exit 0` lebih dulu. Di bawah `set -e`:
  `cp` ke `.bak` jalan → `bak_prune: command not found` → skrip berhenti →
  `rm -f` tidak pernah jalan. Dev mendapat pesan sukses, berkasnya utuh, dan
  sebuah `.bak` baru di sebelahnya.
- `test/test-setup-dev.sh` — keluaran `--remove-rules` kini **ditangkap**, bukan
  dibuang ke `/dev/null`. Menuntut `rc=0`, tidak ada `command not found`, dan
  memeriksa sisi omp (`~/.omp/agent/AGENTS.md`) yang selama ini tidak pernah
  dilihat sama sekali.

**Bukti.** `bash test/test-setup-dev.sh` — 64/1 → **68/0**. Suite penuh 10/10
hijau untuk pertama kalinya. Reproduksi manual sebelum perbaikan menunjukkan
`scripts/setup-dev.sh: line 147: bak_prune: command not found` lalu AGENTS.md
Grok dan omp keduanya masih ada; sesudahnya keduanya terhapus dan skill utuh.

**Dampak.** Hanya jalur `--remove-rules`. Tidak ada config yang berubah bentuk.
Dev yang pernah menjalankannya punya `AGENTS.md.bak.<stamp>` yatim di
`~/.grok/` dan `~/.omp/agent/` — aman dihapus.

**Rollback.** Kembalikan urutan `. backup.sh`; kegagalan uji akan kembali.

### Changed · 2026-09-05 — Alur git tiga aturan, dan PR rilis dibuka sebagai draft

Satu rencana selesai = satu tag. Hari ini PR rilis di-merge lima kali berturut
untuk lima perubahan kecil — tiga tag di repo ini, dua di repo server, semuanya
untuk satu rencana yang sama.

Sebabnya bukan salah paham. PR rilis yang terbuka dan terlihat siap merge memang
**tampak seperti pekerjaan yang belum selesai**, dan respons wajar terhadap itu
adalah menyelesaikannya.

`draft-pull-request: true` membalik bawaannya. PR rilis tetap muncul dan tetap
memperbarui dirinya setiap kali ada PR baru masuk `main` — itu memang gunanya,
ia papan status dari apa yang belum terbit — tetapi dibuka sebagai **draft**,
dan GitHub mematikan tombol merge-nya.

Mendiamkannya kini keadaan yang benar. Menerbitkan menuntut satu tindakan sadar:
*Ready for review*, lalu merge.

**Rollback:** buang `draft-pull-request` dari `release-please-config.json`.

Alurnya kini tertulis di `AGENTS.md`: branch → PR → CI hijau → merge, sesering
perlu; PR rilis mengurus dirinya sendiri sebagai draft; rencana selesai →
Ready for review → merge → satu tag.

Yang sengaja **tidak** diadopsi dari alur tim yang lebih besar: cabang
`develop` (pemisahan terbit dari belum-terbit sudah dipegang tag), peer review
wajib (belum ada reviewer kedua), dan squash merge — squash melipat commit jadi
satu, dan footer `BREAKING CHANGE:` bisa hilang bersama kenaikan MAJOR.

PR di repo ini memang membeli sesuatu: CI menjalankan parser PowerShell 5.1 di
runner Windows, satu-satunya cara memeriksa `.ps1` dari sini.


### Docs · 2026-09-05 — Buang entri kembar di seksi v2.1.0

Satu perubahan tercatat dua kali: sekali dengan hash commit aslinya (`aed93dd`)
dan sekali lagi dengan hash merge commit PR #14 (`5eb9ee7`). Isi tag `v2.1.0`
tidak bisa diubah; yang dirapikan berkasnya di `main`.

Sebabnya bukan kelalaian judul, dan itu yang membuatnya terus berulang: branch
ini berisi **tepat satu commit**, sehingga GitHub mengisi judul PR dari subjek
commit itu — `feat(setup): …`, conventional. PR server yang dibuat berdampingan
punya dua commit, judulnya terisi dari nama branch, dan CHANGELOG-nya bersih.
Jebakan itu kini tertulis di `docs/OPS-02-versioning.md` repo server.


### Added · 2026-09-05 — Retensi cadangan `.bak`

Setiap "perbarui parameter" mencadangkan config yang disentuhnya ke
`<berkas>.bak.<yyyyMMdd-HHmmss>`, dan sampai hari ini tidak ada satu pun yang
pernah membuangnya — di dua puluh tempat, di empat berkas, di kedua platform.
Cadangannya kecil, jadi ini bukan soal ruang: ia soal direktori config dev yang
lama-lama tidak terbaca, dan soal `config.toml.bak.20260812-094431` yang duduk
di sana tanpa ada yang tahu apakah ia masih berarti.

Kebijakannya satu, dipakai kedua installer: **simpan lima cadangan termuda per
berkas**, buang sisanya. `COOPERAGENT_BAK_KEEP` mengubah batasnya; `0`
mematikannya sepenuhnya, supaya dev yang ingin menyimpan seluruh riwayatnya
tidak perlu menambal skrip. Batas defaultnya diuji **sama di kedua platform** —
dua dev dengan perkakas yang sama tidak boleh melihat hasil berbeda tanpa tahu
kenapa.

Yang lebih dijaga daripada pemangkasannya adalah **batasnya**. Ia tidak pernah
menyentuh berkas yang namanya tidak persis `<basis>.bak.<8 digit>-<6 digit>`.
Pelajaran itu dibayar di repo server pada hari yang sama: pemilih cadangan di
sana memakai glob `.bak.*` yang lebar, dan sebuah berkas bernama
`run-qwen.sh.bak.catatan` terbukti bisa terpilih sebagai sasaran rollback. Pola
longgar pada perkakas yang MENGHAPUS jauh lebih mahal daripada pada perkakas
yang membaca — jadi `.bak.catatan`, `.bak.20260101` (cap waktu separuh), dan
cadangan milik berkas lain semuanya punya ujinya sendiri.

Ia juga tidak pernah menjatuhkan pemanggilnya. Installer berjalan di bawah
`set -e`, dan membatalkan pemasangan yang sudah berhasil karena gagal
*merapikan* cadangan adalah pertukaran yang salah arah; argumen kosong,
direktori hilang, dan batas yang bukan angka semuanya diuji tetap `rc=0`.

Diurutkan dari **nama**, bukan mtime — `yyyyMMdd-HHmmss` membuat urutan
leksikografis sama dengan urutan waktu, sementara penyalinan bisa membawa serta
stempel waktu berkas sumbernya.

`test/test-bak-retention.sh` (20 uji) masuk CI. Sekalian: `scripts/setup-pi.sh`
tidak pernah ikut diperiksa `bash -n` di CI — sekarang ikut.

### Docs · 2026-09-05 — Buang entri kembar di seksi v2.0.1

Satu perubahan tercatat dua kali: sekali dengan hash commit aslinya dan sekali
lagi dengan hash merge commit PR #12, karena judul PR-nya berawalan
conventional-commit. Isi tag `v2.0.1` tidak bisa diubah; yang dirapikan
berkasnya di `main`.
