# Kontrak klien — DIAMBIL dari gateway, tidak dipatok di skrip.
#
# KENAPA ADA. Sampai 1 September 2026 `context_window = 131072`, `max_tokens =
# 12288`, dan ambang compaction `80` ditulis tangan di sepuluh tempat:
# `templates/config.toml` (3), `templates/omp-models.yml` (3), `setup.sh` (2),
# `setup.ps1` (2) — plus teks banner di kedua skrip. Gateway sudah menyajikan
# nilai yang sama lewat `/v1/models` sejak commit 9c1c434, tapi tidak ada satu
# pun klien yang MEMBACANYA: `setup.sh` hanya mengambil `id` model dari sana.
#
# Angkanya kebetulan cocok hari ini, jadi tidak ada yang rusak. Tapi cocoknya
# karena kebetulan, bukan karena konstruksi. P2 jendela 2 menaikkan `--parallel`
# dan `--ctx-size` ikut berubah; saat itu terjadi, sebelas config dev diam-diam
# menjadi salah dan tidak ada yang memberi tahu mereka.
#
# Yang lebih buruk sudah terjadi: `scripts/setup-dev.sh` MEMVERIFIKASI
# `context_window` terhadap 131072 yang dipatok di dirinya sendiri, sehingga ia
# akan mencetak "✔ context_window = 131072" dengan yakin justru ketika nilai itu
# sudah basi.
#
# Ini juga prasyarat mutlak P6 (pemisahan repo) yang ditulis roadmap sendiri:
# "kontrak disajikan gateway, bukan dipatok klien". Separuh pertamanya sudah
# benar sejak 31 Agustus; berkas ini menutup separuh keduanya.

# Nilai CADANGAN — dipakai HANYA bila gateway tidak terjangkau saat setup
# berjalan (dev di luar kantor, gateway sedang maintenance). Sengaja disamakan
# dengan produksi per 1 September 2026 supaya kegagalan mengambil kontrak tidak
# memburukkan keadaan; `CONTRACT_SOURCE` yang menyatakan mana yang terpakai.
CONTRACT_CONTEXT_WINDOW=131072
CONTRACT_MAX_TOKENS=12288
CONTRACT_COMPACT_PCT=80
CONTRACT_COMPACT_TOKENS=104857
CONTRACT_MODEL_ID="intercon-agent"
# `gateway` atau `cadangan`. Setiap pencetak nilai di atas WAJIB menyebut ini
# bila `cadangan` — angka tebakan yang tampil seperti angka pasti adalah cara
# repo ini pernah kehilangan tiga jam produksi.
CONTRACT_SOURCE="cadangan"
# Kejujuran berlapis: gateway sendiri bisa jatuh ke env bila tidak ada slot
# upstream yang sehat saat ditanya. `upstream` = dibaca dari mesin yang hidup.
CONTRACT_UPSTREAM_SOURCE=""

# grep -E, bukan sed dengan `.*` yang rakus: `.*"key":` mencocokkan kemunculan
# TERAKHIR, dan `context_window` muncul dua kali di respons (di `data[0]` dan di
# `cooperagent`). Keduanya sama nilainya hari ini — justru karena itu bug
# semacam ini tidak akan ketahuan sampai suatu hari mereka berbeda.
# `-E` juga satu-satunya bentuk yang jalan di grep BSD (macOS) dan GNU sekaligus.
_contract_num() { # $1 = json, $2 = kunci
    printf '%s' "$1" | tr -d ' \t\n' \
        | grep -Eo "\"$2\":[0-9]+" | head -1 | cut -d: -f2
}

_contract_str() { # $1 = json, $2 = kunci
    printf '%s' "$1" | tr -d '\n' \
        | grep -Eo "\"$2\"[[:space:]]*:[[:space:]]*\"[^\"]+\"" | head -1 \
        | sed -E 's/.*"([^"]*)"[[:space:]]*$/\1/'
}

_contract_pos() { # angka positif?
    case "$1" in ''|*[!0-9]*) return 1 ;; esac
    [ "$1" -gt 0 ]
}

# Ambil kontrak dari gateway. $1 = base URL TANPA /api/v1 dan tanpa /v1.
#
# SEMUA-ATAU-TIDAK SAMA SEKALI. Kontrak yang terurai separuh berarti bentuk
# responsnya berubah, dan itu bug yang harus terlihat — bukan keadaan yang
# ditoleransi dengan mencampur nilai gateway dan nilai cadangan dalam satu
# config, yang menghasilkan berkas yang tidak pernah benar-benar berasal dari
# mana pun.
fetch_contract() {
    local base="$1" json cw mt cp ct mid usrc
    [ -n "$base" ] || return 1

    json="$(curl -s --connect-timeout 5 --max-time 8 "${base}/v1/models" 2>/dev/null)" || return 1
    [ -n "$json" ] || return 1
    # Tanpa penanda ini yang kita hubungi bukan gateway CooperAgent (mis. proxy
    # perusahaan yang mengembalikan halaman login dengan status 200).
    case "$json" in *'"cooperagent"'*) ;; *) return 1 ;; esac

    cw="$(_contract_num "$json" context_window)"
    mt="$(_contract_num "$json" max_tokens)"
    cp="$(_contract_num "$json" threshold_percent)"
    ct="$(_contract_num "$json" threshold_tokens)"
    mid="$(_contract_str "$json" model_id)"
    usrc="$(_contract_str "$json" context_source)"

    _contract_pos "$cw" || return 1
    _contract_pos "$mt" || return 1
    _contract_pos "$cp" || return 1
    _contract_pos "$ct" || return 1
    [ -n "$mid" ] || return 1

    CONTRACT_CONTEXT_WINDOW="$cw"
    CONTRACT_MAX_TOKENS="$mt"
    CONTRACT_COMPACT_PCT="$cp"
    CONTRACT_COMPACT_TOKENS="$ct"
    CONTRACT_MODEL_ID="$mid"
    CONTRACT_UPSTREAM_SOURCE="$usrc"
    # Daftar alamat TIDAK ikut menentukan sukses: gateway yang tidak mengumumkan
    # alternatif tetap gateway yang sah. Menjadikannya wajib berarti pemasangan
    # gagal karena sebuah kenyamanan tidak tersedia.
    CONTRACT_ENDPOINTS="$(_contract_eps "$json")"
    CONTRACT_SOURCE="gateway"
}

# Alamat gateway yang diumumkan kontrak: "id<TAB>label<TAB>url" per baris.
#
# Kosong bukan kesalahan -- gateway yang tidak menyetel COOPERAGENT_ENDPOINT_*
# hanya berarti "tidak ada alternatif", dan pemanggil menanganinya dengan
# meminta alamat diketik.
CONTRACT_ENDPOINTS=""

# grep -Eo atas BENTUK objeknya, bukan sed atas seluruh array.
#
# `sed -n 's/.*"endpoints":\[\(.*\)\].*/\1/p'` akan salah: `.*` rakus dan
# menelan sampai `]` TERAKHIR di dokumen -- yaitu penutup `upstreams`, yang
# datang sesudahnya. Objek `upstreams` punya bentuk berbeda (`id` lalu
# `weights`), jadi mencocokkan bentuk id+label+url tidak pernah menyentuhnya.
_contract_eps() { # $1 = json
    printf '%s' "$1" | tr -d '\n' | grep -Eo \
      '\{[[:space:]]*"id"[[:space:]]*:[[:space:]]*"[^"]+"[[:space:]]*,[[:space:]]*"label"[[:space:]]*:[[:space:]]*"[^"]+"[[:space:]]*,[[:space:]]*"url"[[:space:]]*:[[:space:]]*"[^"]+"[[:space:]]*\}' \
      | sed -E 's/.*"id"[[:space:]]*:[[:space:]]*"([^"]*)".*"label"[[:space:]]*:[[:space:]]*"([^"]*)".*"url"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1\t\2\t\3/'
}

# URL untuk sebuah alias (`lan`, `vpn`, `local`); kosong bila tidak diumumkan.
contract_endpoint_url() { # $1 = id
    printf '%s\n' "$CONTRACT_ENDPOINTS" | awk -F'\t' -v k="$1" '$1==k {print $3; exit}'
}

# Ribuan bertitik, gaya Indonesia: 131072 -> 131.072
contract_fmt() {
    printf '%s' "$1" | sed -e :a -e 's/\(.*[0-9]\)\([0-9]\{3\}\)/\1.\2/;ta'
}

# Satu baris yang menyebut dari mana angka-angka itu berasal. Dipanggil setiap
# kali nilai kontrak dicetak atau ditulis ke config.
contract_note() {
    if [ "$CONTRACT_SOURCE" = "gateway" ]; then
        if [ "$CONTRACT_UPSTREAM_SOURCE" = "env-fallback" ]; then
            printf 'kontrak dari gateway (gateway sendiri memakai nilai env — tidak ada slot upstream sehat saat ditanya)'
        else
            printf 'kontrak dari gateway'
        fi
    else
        printf 'gateway tidak terjangkau — memakai nilai cadangan, periksa ulang setelah tersambung'
    fi
}

# ── render template ───────────────────────────────────────────────────────────

# Mengisi placeholder kontrak pada sebuah template, hasilnya ke stdout.
#
# Placeholder milik pemanggil (`__GATEWAY__`, `__API_KEY__`) sengaja TIDAK
# disentuh di sini: alamat dan kredensial bukan urusan kontrak, dan mencampurnya
# berarti pustaka ini ikut memegang rahasia.
#
# CATATAN BENTUK: `__COMPACT_TOKENS__`, `__PEAK__`, dan `__SLACK__` dirender
# dengan pemisah ribuan bertitik karena ketiganya hanya muncul di KOMENTAR.
# Bila salah satunya suatu hari dipakai sebagai nilai TOML/YAML, ia harus pindah
# ke bentuk polos -- `131.072` bukan angka yang sah di kedua format.
contract_render() { # $1 = path template
    local peak slack
    peak=$(( CONTRACT_COMPACT_TOKENS + CONTRACT_MAX_TOKENS ))
    slack=$(( CONTRACT_CONTEXT_WINDOW - peak ))
    # Varian `_FMT__` disubstitusi LEBIH DULU: ia lebih panjang dan harus
    # menang sebelum pola pendeknya sempat menyentuh awalannya.
    sed \
        -e "s|__CONTEXT_WINDOW_FMT__|$(contract_fmt "$CONTRACT_CONTEXT_WINDOW")|g" \
        -e "s|__MAX_TOKENS_FMT__|$(contract_fmt "$CONTRACT_MAX_TOKENS")|g" \
        -e "s|__MODEL_ID__|${CONTRACT_MODEL_ID}|g" \
        -e "s|__CONTEXT_WINDOW__|${CONTRACT_CONTEXT_WINDOW}|g" \
        -e "s|__MAX_TOKENS__|${CONTRACT_MAX_TOKENS}|g" \
        -e "s|__COMPACT_PCT__|${CONTRACT_COMPACT_PCT}|g" \
        -e "s|__COMPACT_TOKENS__|$(contract_fmt "$CONTRACT_COMPACT_TOKENS")|g" \
        -e "s|__PEAK__|$(contract_fmt "$peak")|g" \
        -e "s|__SLACK__|$(contract_fmt "$slack")|g" \
        "$1"
}

# Menolak berkas yang masih memuat placeholder.
#
# Tanpa ini, template yang di-merge mentah-mentah akan menulis
# `context_window = __CONTEXT_WINDOW__` ke config dev -- rusak dengan cara yang
# baru terlihat saat harness-nya gagal start, jauh dari sini.
contract_assert_rendered() { # $1 = path berkas hasil render
    local left
    left="$(grep -oE '__[A-Z_]+__' "$1" 2>/dev/null | sort -u | tr '\n' ' ' || true)"
    [ -n "$left" ] || return 0
    printf 'Placeholder belum terisi di %s: %s\n' "$1" "$left" >&2
    return 1
}
