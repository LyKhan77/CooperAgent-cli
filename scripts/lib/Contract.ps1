# Kontrak klien - DIAMBIL dari gateway, tidak dipatok di skrip.
#
# Padanan PowerShell dari scripts/lib/contract.sh; alasan lengkapnya ada di
# sana. Ringkasnya: context_window, max_tokens, ambang compaction, dan nama
# model ditulis tangan di sepuluh tempat sampai 1 September 2026, sementara
# gateway sudah menyajikan keempatnya lewat /v1/models sejak 31 Agustus. Yang
# dipatok klien tidak pernah tahu saat server berubah.
#
# Ditulis untuk PowerShell 5.1 - itu yang ada di laptop dev, dan sintaks
# PowerShell 7 (operator terner, ??) diam-diam gagal di sana.

# Nilai CADANGAN, dipakai HANYA bila gateway tidak terjangkau. Sengaja sama
# dengan produksi per 1 September 2026 supaya kegagalan mengambil kontrak tidak
# memperburuk keadaan; $ContractSource yang menyatakan mana yang terpakai.
$script:ContractContextWindow = 131072
$script:ContractMaxTokens     = 12288
$script:ContractCompactPct    = 80
$script:ContractCompactTokens = 104857
$script:ContractModelId       = 'intercon-agent'
$script:ContractSource        = 'cadangan'
$script:ContractUpstreamSource = ''
# Alamat gateway yang diumumkan kontrak: objek { id, label, url }.
# Kosong bukan kesalahan -- gateway yang tidak menyetel COOPERAGENT_ENDPOINT_*
# hanya berarti "tidak ada alternatif".
$script:ContractEndpoints    = @()

function Format-CooperNumber {
    # Ribuan bertitik, gaya Indonesia: 131072 -> 131.072.
    # Regex, bukan '{0:N0}', karena format-N mengikuti culture mesin: di lokal
    # en-US ia menghasilkan "131,072" dan angka di layar berubah bentuk
    # tergantung siapa yang menjalankannya.
    param([int]$Value)
    return ([string]$Value) -replace '\B(?=(\d{3})+(?!\d))', '.'
}

function Get-CooperContract {
    # Mengambil kontrak. $BaseUrl TANPA /api/v1 dan tanpa /v1.
    # Mengembalikan $true bila seluruh kontrak terbaca dan sah.
    #
    # SEMUA-ATAU-TIDAK SAMA SEKALI: kontrak yang terurai separuh berarti bentuk
    # responsnya berubah, dan itu harus terlihat -- bukan ditambal dengan
    # mencampur nilai gateway dan nilai cadangan dalam satu config, yang
    # menghasilkan berkas yang tidak pernah benar-benar berasal dari mana pun.
    param([string]$BaseUrl)

    if ([string]::IsNullOrWhiteSpace($BaseUrl)) { return $false }

    $r = $null
    try {
        $r = Invoke-RestMethod -Uri "$BaseUrl/v1/models" -TimeoutSec 8 -ErrorAction Stop
    } catch {
        return $false
    }
    if ($null -eq $r -or $null -eq $r.cooperagent) { return $false }

    $c = $r.cooperagent
    $cw  = $c.context_window
    $mt  = $c.max_tokens
    $pct = $null; $tok = $null
    if ($null -ne $c.compaction) {
        $pct = $c.compaction.threshold_percent
        $tok = $c.compaction.threshold_tokens
    }
    $mid = $c.model_id

    # TryParse, bukan pemeriksaan tipe: Invoke-RestMethod di PowerShell 5.1
    # mengembalikan angka JSON sebagai Int32, Int64, Decimal, atau Double
    # tergantung nilainya, dan mendaftar tipe yang "sah" berarti kontrak yang
    # benar suatu hari ditolak karena tipenya kebetulan lain.
    foreach ($n in @($cw, $mt, $pct, $tok)) {
        if ($null -eq $n) { return $false }
        $v = 0
        if (-not [int]::TryParse([string]$n, [ref]$v)) { return $false }
        if ($v -le 0) { return $false }
    }
    if ([string]::IsNullOrWhiteSpace($mid)) { return $false }

    $script:ContractContextWindow  = [int]$cw
    $script:ContractMaxTokens      = [int]$mt
    $script:ContractCompactPct     = [int]$pct
    $script:ContractCompactTokens  = [int]$tok
    $script:ContractModelId        = [string]$mid
    $script:ContractUpstreamSource = [string]$c.context_source
    # Daftar alamat TIDAK ikut menentukan sukses: gateway tanpa alternatif tetap
    # gateway yang sah. Menjadikannya wajib berarti pemasangan gagal karena
    # sebuah kenyamanan tidak tersedia.
    if ($null -ne $c.endpoints) { $script:ContractEndpoints = @($c.endpoints) }
    $script:ContractSource         = 'gateway'
    return $true
}

function Get-CooperEndpointUrl {
    # URL untuk sebuah alias ('lan', 'vpn', 'local'); kosong bila tidak diumumkan.
    param([string]$Id)
    foreach ($e in $script:ContractEndpoints) {
        if ($e.id -eq $Id) { return [string]$e.url }
    }
    return ''
}

function Get-CooperContractNote {
    # Satu baris yang menyebut dari mana angka-angka itu berasal. Angka tebakan
    # yang tampil seperti angka pasti adalah cara repo ini pernah kehilangan
    # tiga jam produksi.
    if ($script:ContractSource -eq 'gateway') {
        if ($script:ContractUpstreamSource -eq 'env-fallback') {
            return 'kontrak dari gateway (gateway sendiri memakai nilai env - tidak ada slot upstream sehat saat ditanya)'
        }
        return 'kontrak dari gateway'
    }
    return 'gateway tidak terjangkau - memakai nilai cadangan, periksa ulang setelah tersambung'
}

function Expand-CooperTemplate {
    # Mengisi placeholder kontrak pada isi template. Placeholder milik pemanggil
    # (__GATEWAY__, __API_KEY__) sengaja TIDAK disentuh: alamat dan kredensial
    # bukan urusan kontrak.
    #
    # Varian _FMT__ diganti LEBIH DULU: ia lebih panjang dan harus menang
    # sebelum pola pendeknya sempat menyentuh awalannya.
    param([string]$Text)

    $peak  = $script:ContractCompactTokens + $script:ContractMaxTokens
    $slack = $script:ContractContextWindow - $peak

    $t = $Text
    $t = $t.Replace('__CONTEXT_WINDOW_FMT__', (Format-CooperNumber $script:ContractContextWindow))
    $t = $t.Replace('__MAX_TOKENS_FMT__',     (Format-CooperNumber $script:ContractMaxTokens))
    $t = $t.Replace('__MODEL_ID__',           $script:ContractModelId)
    $t = $t.Replace('__CONTEXT_WINDOW__',     [string]$script:ContractContextWindow)
    $t = $t.Replace('__MAX_TOKENS__',         [string]$script:ContractMaxTokens)
    $t = $t.Replace('__COMPACT_PCT__',        [string]$script:ContractCompactPct)
    $t = $t.Replace('__COMPACT_TOKENS__',     (Format-CooperNumber $script:ContractCompactTokens))
    $t = $t.Replace('__PEAK__',               (Format-CooperNumber $peak))
    $t = $t.Replace('__SLACK__',              (Format-CooperNumber $slack))
    return $t
}

function Assert-CooperRendered {
    # Menolak isi yang masih memuat placeholder. Tanpa ini, template yang
    # di-merge mentah-mentah menulis `context_window = __CONTEXT_WINDOW__` ke
    # config dev - kerusakan yang baru terlihat jauh dari sini, saat harness-nya
    # gagal start.
    param([string]$Text, [string]$Label = 'template')

    $m = [regex]::Matches($Text, '__[A-Z_]+__')
    if ($m.Count -eq 0) { return $true }
    $names = ($m | ForEach-Object { $_.Value } | Sort-Object -Unique) -join ' '
    Write-Host "Placeholder belum terisi di ${Label}: $names" -ForegroundColor Red
    return $false
}
