# Verifikasi kredensial — gerbang yang dilewati SEBELUM apa pun ditulis.
#
# KENAPA ADA. Sampai 3 September 2026 kedua pemasang memang menanyakan
# `/api/auth/whoami`, tapi kegagalannya ditelan `catch {}` kosong: gateway tak
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

# Hasil pemeriksaan terakhir. Dibaca pemanggil sesudah `cooper_verify_token`.
COOPER_VERIFY_STATE=""   # ok | bad-form | unreachable | unknown-token | revoked
                         # | no-whoami | maintenance | bad-response | http-<kode>
COOPER_WHO=""            # `nama@device` menurut GATEWAY, bukan menurut dev
COOPER_ROLE=""           # dev | admin | service
COOPER_HTTP=""           # kode HTTP apa adanya, untuk baris log

# Bentuk token diperiksa di klien lebih dulu: salah tempel adalah kesalahan
# paling umum saat onboarding, dan menemukannya tanpa perjalanan jaringan jauh
# lebih murah -- juga satu-satunya pemeriksaan yang tetap bekerja saat gateway
# sedang mati.
cooper_token_form_ok() { # $1 = token
    case "${1:-}" in ca_*) ;; *) return 1 ;; esac
    [ "${#1}" -eq 51 ]
}

# Membuang sufiks path apa pun dari alamat gateway. Dev menempel bentuk yang
# berbeda-beda (`/api/v1`, `/v1`, garis miring di ujung); yang dituju di sini
# selalu akar.
cooper_gateway_base() { # $1 = alamat apa adanya
    local b="${1:-}"
    b="${b%/}"; b="${b%/api/v1}"; b="${b%/v1}"; b="${b%/}"
    printf '%s' "$b"
}

# Menanyakan "siapa pemilik token ini" ke gateway.
#
# Ini SATU-SATUNYA rute yang benar-benar memverifikasi kredensial: `/api/health`
# dan `/v1/models` dilayani tanpa autentikasi, jadi keduanya membuktikan gateway
# hidup dan TIDAK membuktikan apa pun tentang token.
cooper_verify_token() { # $1 = alamat gateway  $2 = token
    local base body code
    COOPER_VERIFY_STATE=""; COOPER_WHO=""; COOPER_ROLE=""; COOPER_HTTP=""

    if ! cooper_token_form_ok "${2:-}"; then
        COOPER_VERIFY_STATE="bad-form"; return 1
    fi

    base="$(cooper_gateway_base "${1:-}")"
    body="$(mktemp)" || { COOPER_VERIFY_STATE="bad-response"; return 1; }
    # `--max-time` selain `--connect-timeout`: gateway yang menerima koneksi lalu
    # menggantung adalah kegagalan yang paling sering terlihat lewat VPN, dan
    # tanpa batas total skrip akan diam tanpa ujung.
    code="$(curl -s -o "$body" -w '%{http_code}' \
        --connect-timeout 5 --max-time 15 \
        -H "Authorization: Bearer $2" \
        "${base}/api/auth/whoami" 2>/dev/null || true)"
    COOPER_HTTP="$code"

    case "$code" in
        200)
            COOPER_WHO="$(sed -n 's/.*"who"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$body")"
            COOPER_ROLE="$(sed -n 's/.*"role"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$body")"
            # 200 tanpa `who` bukan keberhasilan: proxy perusahaan yang
            # mengembalikan halaman login juga menjawab 200.
            if [ -n "$COOPER_WHO" ]; then COOPER_VERIFY_STATE="ok"
            else COOPER_VERIFY_STATE="bad-response"; fi ;;
        400) COOPER_VERIFY_STATE="bad-form" ;;
        401)
            # Gateway sengaja MEMBEDAKAN keduanya di rute ini (berbeda dari rute
            # login yang menyamarkannya), karena di sini penerimanya pemilik
            # token, bukan penebak.
            if grep -q 'dicabut' "$body" 2>/dev/null; then COOPER_VERIFY_STATE="revoked"
            else COOPER_VERIFY_STATE="unknown-token"; fi ;;
        404) COOPER_VERIFY_STATE="no-whoami" ;;
        503) COOPER_VERIFY_STATE="maintenance" ;;
        ""|000) COOPER_VERIFY_STATE="unreachable" ;;
        *)   COOPER_VERIFY_STATE="http-$code" ;;
    esac
    rm -f "$body"
    [ "$COOPER_VERIFY_STATE" = ok ]
}

# Pesan per sebab. Setiap cabang menyebutkan JALAN KELUARNYA, bukan hanya
# gejalanya -- "token ditolak" tanpa langkah berikutnya membuat dev menebak di
# antara tiga masalah yang penanganannya berbeda.
cooper_verify_explain() { # $1 = state  $2 = alamat gateway
    local gw; gw="$(cooper_gateway_base "${2:-}")"
    case "$1" in
        bad-form)
            echo "Token tidak berbentuk kredensial CooperAgent."
            echo "Bentuk yang sah: ca_ diikuti 48 karakter heksadesimal (51 total)."
            echo "Yang paling sering: token terpotong saat disalin dari chat." ;;
        unreachable)
            echo "Gateway tidak menjawab: ${gw}"
            echo "Yang perlu diperiksa, berurutan:"
            echo "  1. VPN aktif bila Anda di luar kantor"
            echo "  2. alamatnya benar (lihat blok serah-terima dari admin)"
            echo "  3. gateway memang sedang hidup — tanya admin" ;;
        unknown-token)
            echo "Token DITOLAK gateway (401): tidak dikenal."
            echo "Periksa salinannya — spasi di ujung dan baris yang terpotong"
            echo "adalah penyebab paling umum. Bila hilang, minta penerbitan ulang:"
            echo "    cooper issue <nama> <device>" ;;
        revoked)
            echo "Token DITOLAK gateway (401): kredensial telah DICABUT."
            echo "Ini bukan salah ketik — admin mencabutnya di sisi server."
            echo "Minta penerbitan ulang ke pemilik gateway:"
            echo "    cooper issue <nama> <device>" ;;
        no-whoami)
            echo "Gateway di ${gw} tidak punya /api/auth/whoami (404)."
            echo "Versinya lebih tua daripada penegakan kredensial (1 September 2026),"
            echo "jadi token tidak bisa diverifikasi dari sini."
            echo "Minta admin memperbarui gateway, atau periksa alamatnya —"
            echo "404 juga muncul bila yang ditempel bukan gateway CooperAgent." ;;
        maintenance)
            echo "Gateway sedang dalam mode maintenance (503)."
            echo "Kredensial tidak dapat diperiksa sekarang. Coba lagi setelah"
            echo "jendela maintenance selesai — tanya admin bila mendesak." ;;
        bad-response)
            echo "Jawaban dari ${gw} bukan jawaban gateway CooperAgent."
            echo "Yang paling sering: alamatnya menunjuk proxy perusahaan atau"
            echo "layanan lain yang kebetulan hidup di port itu." ;;
        *)
            echo "Gateway menjawab ${1#http-} saat memeriksa token."
            echo "Ini bukan jawaban yang dikenal; tunjukkan baris ini ke admin." ;;
    esac
}
