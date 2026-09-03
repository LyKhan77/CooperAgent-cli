# Verifikasi kredensial — gerbang yang dilewati SEBELUM apa pun ditulis.
#
# KENAPA ADA. Sampai 3 September 2026 kedua pemasang memang menanyakan
# `/api/auth/whoami`, tapi kegagalannya ditelan `catch {}` KOSONG: gateway tak
# terjangkau, token tidak dikenal, dan kredensial DICABUT ketiganya jatuh diam-
# diam ke prompt "ketik nama dan device Anda". Setup lalu berjalan sampai akhir,
# mencetak tanda centang, dan menulis config yang PASTI dijawab 401 -- yang baru
# dev temukan saat mencoba bekerja.
#
# Ketiga sebab itu jalan keluarnya berbeda: yang pertama soal jaringan, yang
# kedua soal salah tempel, yang ketiga menuntut penerbitan ulang oleh admin.
# Satu pesan untuk ketiganya adalah pesan yang tidak menolong satu pun.
#
# Kredensial diperiksa SETIAP kali skrip berjalan, bukan hanya saat pertama.
# Pencabutan terjadi di sisi server tanpa memberi tahu klien; satu-satunya cara
# dev mengetahuinya adalah kita bertanya.

# Bentuk token diperiksa di klien lebih dulu: salah tempel adalah kesalahan
# paling umum saat onboarding, dan menemukannya tanpa perjalanan jaringan jauh
# lebih murah -- juga satu-satunya pemeriksaan yang tetap bekerja saat gateway
# sedang mati.
function Test-CooperTokenForm([string]$Token) {
    return ($Token -and $Token.StartsWith('ca_') -and $Token.Length -eq 51)
}

# Membuang sufiks path apa pun dari alamat gateway. Dev menempel bentuk yang
# berbeda-beda (`/api/v1`, `/v1`, garis miring di ujung); yang dituju di sini
# selalu akar.
function Get-CooperGatewayBase([string]$Url) {
    $b = ($Url + '').TrimEnd('/')
    $b = $b -replace '/api/v1$', ''
    $b = $b -replace '/v1$', ''
    return $b.TrimEnd('/')
}

# Menanyakan "siapa pemilik token ini" ke gateway.
#
# Ini SATU-SATUNYA rute yang benar-benar memverifikasi kredensial: `/api/health`
# dan `/v1/models` dilayani tanpa autentikasi, jadi keduanya membuktikan gateway
# hidup dan TIDAK membuktikan apa pun tentang token.
#
# Mengembalikan objek: State, Who, Role, Http.
#   State: ok | bad-form | unreachable | unknown-token | revoked
#        | no-whoami | maintenance | bad-response | http-<kode>
function Test-CooperCredential([string]$Gateway, [string]$Token) {
    $res = [pscustomobject]@{ State = ''; Who = ''; Role = ''; Http = '' }
    if (-not (Test-CooperTokenForm $Token)) { $res.State = 'bad-form'; return $res }

    $base = Get-CooperGatewayBase $Gateway
    $url  = "$base/api/auth/whoami"
    try {
        $r = Invoke-WebRequest -Uri $url -Headers @{ Authorization = "Bearer $Token" } `
                -TimeoutSec 15 -UseBasicParsing -ErrorAction Stop
        $res.Http = [string][int]$r.StatusCode
        $who = ''; $role = ''
        try {
            $j = $r.Content | ConvertFrom-Json
            $who = [string]$j.who; $role = [string]$j.role
        } catch { }
        # 200 tanpa `who` bukan keberhasilan: proxy perusahaan yang
        # mengembalikan halaman login juga menjawab 200.
        if ($who) { $res.Who = $who; $res.Role = $role; $res.State = 'ok' }
        else { $res.State = 'bad-response' }
        return $res
    } catch {
        # Kode DAN badan diambil dari exception. PowerShell 5.1 menaruhnya di
        # HttpWebResponse, PowerShell 7 di ErrorDetails -- keduanya ditangani,
        # karena dev memakai keduanya.
        $code = ''
        $body = ''
        $resp = $null
        try { $resp = $_.Exception.Response } catch { }
        if ($resp) {
            try { $code = [string][int]$resp.StatusCode } catch { }
            try { $body = [string]$_.ErrorDetails.Message } catch { }
            if (-not $body) {
                try {
                    $sr = New-Object System.IO.StreamReader($resp.GetResponseStream())
                    $body = $sr.ReadToEnd(); $sr.Close()
                } catch { }
            }
        }
        $res.Http = $code
        switch ($code) {
            '400' { $res.State = 'bad-form' }
            '401' {
                # Gateway sengaja MEMBEDAKAN keduanya di rute ini (berbeda dari
                # rute login yang menyamarkannya), karena di sini penerimanya
                # pemilik token, bukan penebak.
                if ($body -match 'dicabut') { $res.State = 'revoked' }
                else { $res.State = 'unknown-token' }
            }
            '404' { $res.State = 'no-whoami' }
            '503' { $res.State = 'maintenance' }
            ''    { $res.State = 'unreachable' }
            default { $res.State = "http-$code" }
        }
        return $res
    }
}

# Pesan per sebab. Setiap cabang menyebutkan JALAN KELUARNYA, bukan hanya
# gejalanya -- "token ditolak" tanpa langkah berikutnya membuat dev menebak di
# antara tiga masalah yang penanganannya berbeda.
function Get-CooperCredentialHelp([string]$State, [string]$Gateway) {
    $gw = Get-CooperGatewayBase $Gateway
    switch ($State) {
        'bad-form' { return @(
            'Token tidak berbentuk kredensial CooperAgent.',
            'Bentuk yang sah: ca_ diikuti 48 karakter heksadesimal (51 total).',
            'Yang paling sering: token terpotong saat disalin dari chat.') }
        'unreachable' { return @(
            "Gateway tidak menjawab: $gw",
            'Yang perlu diperiksa, berurutan:',
            '  1. VPN aktif bila Anda di luar kantor',
            '  2. alamatnya benar (lihat blok serah-terima dari admin)',
            '  3. gateway memang sedang hidup - tanya admin') }
        'unknown-token' { return @(
            'Token DITOLAK gateway (401): tidak dikenal.',
            'Periksa salinannya - spasi di ujung dan baris yang terpotong',
            'adalah penyebab paling umum. Bila hilang, minta penerbitan ulang:',
            '    cooper issue <nama> <device>') }
        'revoked' { return @(
            'Token DITOLAK gateway (401): kredensial telah DICABUT.',
            'Ini bukan salah ketik - admin mencabutnya di sisi server.',
            'Minta penerbitan ulang ke pemilik gateway:',
            '    cooper issue <nama> <device>') }
        'no-whoami' { return @(
            "Gateway di $gw tidak punya /api/auth/whoami (404).",
            'Versinya lebih tua daripada penegakan kredensial (1 September 2026),',
            'jadi token tidak bisa diverifikasi dari sini.',
            'Minta admin memperbarui gateway, atau periksa alamatnya -',
            '404 juga muncul bila yang ditempel bukan gateway CooperAgent.') }
        'maintenance' { return @(
            'Gateway sedang dalam mode maintenance (503).',
            'Kredensial tidak dapat diperiksa sekarang. Coba lagi setelah',
            'jendela maintenance selesai - tanya admin bila mendesak.') }
        'bad-response' { return @(
            "Jawaban dari $gw bukan jawaban gateway CooperAgent.",
            'Yang paling sering: alamatnya menunjuk proxy perusahaan atau',
            'layanan lain yang kebetulan hidup di port itu.') }
        default { return @(
            "Gateway menjawab $($State -replace '^http-','') saat memeriksa token.",
            'Ini bukan jawaban yang dikenal; tunjukkan baris ini ke admin.') }
    }
}
