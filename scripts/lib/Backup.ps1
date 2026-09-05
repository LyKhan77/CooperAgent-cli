# Retensi cadangan .bak - kembaran scripts/lib/backup.sh untuk Windows.
#
# KENAPA ADA. Setiap "perbarui parameter" mencadangkan config yang disentuhnya
# ke <berkas>.bak.<yyyyMMdd-HHmmss>, dan sampai 5 September 2026 tidak ada satu
# pun yang pernah membuangnya. Cadangannya kecil, jadi ini bukan soal ruang: ia
# soal direktori config dev yang lama-lama tidak terbaca.
#
# YANG TIDAK DILAKUKANNYA. Ia tidak pernah menyentuh berkas yang namanya tidak
# persis <basis>.bak.<8 digit>-<6 digit>. Pelajarannya dibayar di repo server:
# pemilih cadangan di sana memakai pola .bak.* yang lebar, dan sebuah berkas
# bernama run-qwen.sh.bak.catatan terbukti bisa terpilih sebagai sasaran
# rollback. Pola longgar pada perkakas yang MENGHAPUS jauh lebih mahal daripada
# pada perkakas yang membaca.
#
# Nilai baliknya selalu kosong dan ia tidak pernah melempar: gagal merapikan
# cadangan bukan alasan membatalkan pemasangan yang sudah berhasil.

function Invoke-CooperBakPrune {
    param([Parameter(Mandatory=$true)][string]$Path)

    $keep = 5
    if ($env:COOPERAGENT_BAK_KEEP) {
        $parsed = 0
        if ([int]::TryParse($env:COOPERAGENT_BAK_KEEP, [ref]$parsed)) { $keep = $parsed }
    }
    if ($keep -le 0) { return }

    try {
        $dir  = Split-Path -Parent $Path
        $base = Split-Path -Leaf   $Path
        if (-not $dir -or -not (Test-Path $dir)) { return }

        # Disaring dua kali: Filter memangkas daftarnya di sisi penyedia, regex
        # menegakkan bentuk cap waktunya. Wildcard saja meloloskan
        # "config.toml.bak.catatan".
        $re = '^' + [regex]::Escape($base) + '\.bak\.[0-9]{8}-[0-9]{6}$'

        # Diurutkan dari NAMANYA, bukan LastWriteTime: cap waktu yyyyMMdd-HHmmss
        # membuat urutan leksikografis == urutan waktu, dan penyalinan bisa
        # membawa serta stempel waktu berkas sumber.
        $all = @(Get-ChildItem -LiteralPath $dir -File -Filter "$base.bak.*" -ErrorAction SilentlyContinue |
                 Where-Object { $_.Name -match $re } |
                 Sort-Object -Property Name)

        if ($all.Count -le $keep) { return }
        $buang = $all[0..($all.Count - $keep - 1)]
        foreach ($f in $buang) {
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
        }
        Write-Host ("     " + $buang.Count + " cadangan lama dibuang, " + $keep +
                    " terbaru disimpan (" + $base + ")") -ForegroundColor DarkGray
    } catch {
        # Sengaja diam. Lihat catatan di kepala berkas.
    }
}
