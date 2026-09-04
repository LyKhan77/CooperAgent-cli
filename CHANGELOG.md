# 📜 Changelog

Semua perubahan penting pada **CooperAgent CLI** (`cooperagent-cli`) dicatat di
berkas ini.

Formatnya mengikuti [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), dan
proyek ini memakai [Semantic Versioning](https://semver.org/spec/v2.0.0.html).
Aturan lengkap — termasuk apa yang membuat sebuah perubahan MAJOR pada sebuah
*pemasang* — ada di [`docs/versioning.md`](docs/versioning.md).

---

## [Unreleased]

### Perbaikan

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
