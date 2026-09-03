#!/usr/bin/env bash
# ==============================================================================
# Setup Script: CooperAgent (CooperxHarness - Grok Build & Oh My Pi)
# Platform: Linux & macOS Edition (Gateway port 8987)
# Repository: https://github.com/LyKhan77/CooperAgent-cli.git
# ==============================================================================
set -e

# --- keluaran: warna dan simbol ----------------------------------------------
#
# Tiga aturan yang berdiri sendiri, sengaja tidak digabung menjadi satu tebakan:
#
#   1. WARNA hanya ke terminal (`[ -t 1 ]`). Saat keluaran dialihkan ke berkas
#      atau pipa, kode escape ikut tertulis -- terukur 2 September 2026: 17 baris
#      ber-`^[[0;32m` pada satu jalankan yang diarahkan ke berkas. Itu justru
#      terjadi saat dev menyalin log untuk melaporkan masalah, yaitu saat
#      keterbacaan paling dibutuhkan.
#   2. NO_COLOR dihormati (no-color.org), begitu pula TERM=dumb.
#   3. SIMBOL Unicode hanya bila locale-nya UTF-8. `${S_OK}` di konsol non-UTF-8
#      menjadi mojibake, dan tanda "berhasil" yang tampak rusak lebih buruk
#      daripada `[v]` yang polos.
#
# `--no-color` dan `--ascii` memaksa keduanya, untuk CI dan terminal yang
# berbohong tentang kemampuannya.
UI_COLOR=auto
UI_SYMBOLS=auto
for _a in "$@"; do
    case "$_a" in
        --no-color) UI_COLOR=off ;;
        --ascii)    UI_COLOR=off; UI_SYMBOLS=ascii ;;
    esac
done

if [ "$UI_COLOR" = auto ] && [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
    GREEN=$'\033[0;32m'
    CYAN=$'\033[0;36m'
    YELLOW=$'\033[1;33m'
    RED=$'\033[0;31m'
    NC=$'\033[0m'
else
    GREEN=''; CYAN=''; YELLOW=''; RED=''; NC=''
fi

if [ "$UI_SYMBOLS" = auto ]; then
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *UTF-8*|*utf-8*|*UTF8*|*utf8*) UI_SYMBOLS=utf8 ;;
        *)                             UI_SYMBOLS=ascii ;;
    esac
fi
if [ "$UI_SYMBOLS" = utf8 ]; then
    S_OK='✔'; S_NO='✖'; S_WARN='!'; S_ARROW='→'; S_DOT='·'; S_PARTY='🎉'; S_ROCKET='🚀'
else
    S_OK='[v]'; S_NO='[x]'; S_WARN='[!]'; S_ARROW='->'; S_DOT='-'; S_PARTY='*'; S_ROCKET='*'
fi

# Alamat gateway TIDAK dipatok di sini.
#
# Sampai 2 September 2026 tiga baris di tempat ini memuat alamat LAN dan VPN
# kantor. Itu penyakit yang sama dengan `context_window`: fakta tentang SERVER
# yang hidup di KLIEN, dan karenanya tidak pernah tahu saat server pindah.
#
# Ia juga yang menghalangi skrip ini pindah ke repo pemasang yang publik --
# riwayat git tidak bisa dilupakan, jadi satu commit saja sudah menerbitkan
# topologi internal selamanya.
#
# Urutan penentuan alamat:
#   1. `--endpoint <url>`
#   2. $COOPERAGENT_GATEWAY
#   3. base_url pada config yang sudah ada
#   4. ditanyakan (ada di blok serah-terima bersama token)
# Alias `lan`/`vpn`/`local` diselesaikan lewat kontrak gateway, bukan tabel di
# sini. Lihat `cooperagent.endpoints` pada GET /v1/models.
COOPERAGENT_GATEWAY="${COOPERAGENT_GATEWAY:-}"

# Daftar alamat dari kontrak terakhir yang berhasil, di mesin dev -- bukan di
# repo. Dipakai HANYA saat koneksi gagal: tanpanya kita tidak punya apa pun
# untuk disarankan kepada dev yang mengetik alamat LAN sementara ia di rumah.
ENDPOINT_CACHE="$HOME/.cooper/gateway-endpoints"

# Menerima bentuk apa pun yang ditempel dev dan mengembalikan bentuk kanonik.
# `http://h:8987`, `.../api`, `.../v1`, dan `.../api/v1` semuanya sah -- menuntut
# satu bentuk saja berarti separuh dev salah di percobaan pertama.
normalize_endpoint() {
    local u="${1%/}"
    u="${u%/api/v1}"; u="${u%/v1}"; u="${u%/api}"
    printf '%s/api/v1' "$u"
}

# Menyimpan daftar alamat sesudah kontrak berhasil diambil.
cache_endpoints() {
    [ -n "$CONTRACT_ENDPOINTS" ] || return 0
    mkdir -p "$(dirname "$ENDPOINT_CACHE")" 2>/dev/null || return 0
    printf '%s\n' "$CONTRACT_ENDPOINTS" > "$ENDPOINT_CACHE" 2>/dev/null || true
}

# Membaca kembali daftar itu saat gateway tidak terjangkau.
cached_endpoints() {
    [ -f "$ENDPOINT_CACHE" ] && cat "$ENDPOINT_CACHE" 2>/dev/null || true
}
# Nama model DITANYAKAN ke gateway, tidak dipatok di sini.
#
# Sampai 1 September 2026 baris ini berbunyi "qwen35" dan menjadi salah begitu
# alias mesin berubah menjadi "intercon-agent" -- persis penyakit "sumber
# kebenaran ganda" yang /v1/models ada untuk menyembuhkan. Nilai di bawah hanya
# cadangan bila gateway tidak terjangkau saat setup berjalan.
DEFAULT_MODEL_NAME="intercon-agent"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OS_TYPE="$(uname -s)"

# Merge, bukan tulis-ulang. `~/.grok/config.toml` bukan milik skrip ini sendiri:
# dev menaruh server MCP, preferensi [ui], model tambahan, dan [marketplace] di
# berkas yang sama. Sampai 2026-08-27 skrip ini MENIMPA berkas itu, sehingga
# setiap pergantian endpoint menghapus semuanya.
# shellcheck source=scripts/lib/merge_toml.sh
. "${SCRIPT_DIR}/scripts/lib/merge_toml.sh"

# Nilai kontrak -- context_window, max_tokens, ambang compaction, nama model --
# DIAMBIL dari gateway, tidak dipatok di sini. Lihat berkasnya untuk alasan
# lengkapnya; ringkasnya: yang dipatok klien tidak pernah tahu saat server
# berubah.
# shellcheck source=scripts/lib/contract.sh
. "${SCRIPT_DIR}/scripts/lib/contract.sh"

# Kunci api pada models.yml omp -- satu implementasi, dipakai skrip ini DAN
# scripts/setup-dev.sh. Sampai 3 September 2026 keduanya menyimpang, dan yang
# di sini menulis bentuk lama yang dijawab 401.
# shellcheck source=scripts/lib/omp_models.sh
. "${SCRIPT_DIR}/scripts/lib/omp_models.sh"

# Gerbang kredensial. Ia yang mengubah "setup selesai lalu 401 belakangan"
# menjadi "setup berhenti sekarang, dengan sebabnya".
# shellcheck source=scripts/lib/credential.sh
. "${SCRIPT_DIR}/scripts/lib/credential.sh"

# --- mode ganti endpoint ------------------------------------------------------
# `setup.sh --endpoint vpn` hanya memindahkan alamat gateway: identitas dev
# dibaca ulang dari config yang ada, tidak ada prompt, tidak ada pemasangan.
# Inilah jalur untuk berpindah LAN <-> VPN, yang dulu menuntut setup penuh.
SWITCH_ONLY=""
DEV_TOKEN=""

# Token kredensial. Sejak penegakan menyala (1 September 2026) gateway MENOLAK
# identitas lama `dev-nama@device` dengan 401, jadi setup tanpa token
# menghasilkan config yang tidak bisa dipakai sama sekali.
while [ $# -gt 0 ]; do
    case "$1" in
        --token)   DEV_TOKEN="${2:-}"; shift 2 ;;
        --token=*) DEV_TOKEN="${1#--token=}"; shift ;;
        *) break ;;
    esac
done
if [ -n "$DEV_TOKEN" ]; then
    case "$DEV_TOKEN" in
        ca_*) ;;
        *) echo "Token harus diawali 'ca_'. Minta ke admin: cooper issue <nama> <device>" >&2; exit 2 ;;
    esac
    [ "${#DEV_TOKEN}" -eq 51 ] || {
        echo "Token harus 51 karakter (ca_ + 48 hex); yang ditempel ${#DEV_TOKEN}." >&2
        echo "Kemungkinan terpotong saat disalin." >&2; exit 2; }
fi

case "${1:-}" in
    --endpoint)
        SWITCH_ONLY="${2:-}"
        [ -n "$SWITCH_ONLY" ] || { echo "pakai: setup.sh --endpoint lan|vpn|local|<url>" >&2; exit 1; }
        ;;
    --info|--endpoint-info)
        # Gateway CooperAgent adalah endpoint OpenAI-compatible biasa. Tidak ada
        # alasan ia hanya bisa dipakai dari harness kita sendiri -- mode ini
        # mencetak apa yang dibutuhkan untuk menyambungkannya dari alat mana pun,
        # supaya dev cukup menyalin, bukan menebak.
        CFG_FILE="$HOME/.grok/config.toml"
        ID="$(grep -m1 '^[[:space:]]*api_key' "$CFG_FILE" 2>/dev/null | sed -E 's/.*["'"'"']([^"'"'"']*)["'"'"'].*/\1/')"
        URL="$(grep -m1 '^[[:space:]]*base_url' "$CFG_FILE" 2>/dev/null | sed -E 's/.*["'"'"']([^"'"'"']*)["'"'"'].*/\1/')"
        [ -n "$URL" ] || URL="$(normalize_endpoint "${COOPERAGENT_GATEWAY:-}")"
        if [ "$URL" = "/api/v1" ]; then
            echo "Belum ada endpoint yang tercatat di ~/.grok/config.toml." >&2
            echo "Jalankan setup dulu, atau setel COOPERAGENT_GATEWAY=http://<host>:8987" >&2
            exit 1
        fi
        [ -n "$ID" ] || ID="dev-<nama>@<device>"
        BASE="${URL%/api/v1}"

        # `--info` dulu TIDAK PERNAH menghubungi gateway: ia mencetak 131072 dan
        # 80% yang dipatok di skrip, lalu keluar. Justru inilah jalur yang paling
        # butuh angka benar -- ia dipakai dev yang membawa coding agent sendiri,
        # yang tidak punya skrip apa pun untuk mengoreksinya di kemudian hari.
        fetch_contract "$BASE" || true
        DEFAULT_MODEL_NAME="$CONTRACT_MODEL_ID"

        cat <<INFO
CooperAgent — endpoint untuk harness apa pun

  Base URL (OpenAI-compatible)  ${BASE}/v1
  API key                       ${ID}
  Model                         ${DEFAULT_MODEL_NAME}
  Context window                ${CONTRACT_CONTEXT_WINDOW}      (prompt DAN jawaban, plafon keras)
  Max output                    ${CONTRACT_MAX_TOKENS}
  Ambang compact yang disarankan ${CONTRACT_COMPACT_PCT}%        = $(contract_fmt "$CONTRACT_COMPACT_TOKENS") token
  Sumber angka di atas          $(contract_note)

Uji cepat:

  curl ${BASE}/v1/chat/completions \\
    -H 'Content-Type: application/json' \\
    -H 'Authorization: Bearer ${ID}' \\
    -d '{"model":"${DEFAULT_MODEL_NAME}","messages":[{"role":"user","content":"hi"}]}'

Variabel lingkungan gaya OpenAI SDK:

  export OPENAI_BASE_URL="${BASE}/v1"
  export OPENAI_API_KEY="${ID}"
  export OPENAI_MODEL="${DEFAULT_MODEL_NAME}"

Catatan yang perlu diketahui sebelum memakai alat lain:

  - api_key HARUS berupa token CooperAgent (ca_...). Sejak 1 September 2026
    gateway menolak identitas lama dev-<nama>@<device> dengan 401.
    Minta token ke admin: cooper issue <nama> <device>
  - Beri max_tokens minimal ~2000: model ini berpikir dulu, dan token yang
    habis untuk penalaran menghasilkan jawaban KOSONG.
  - Auto-compaction adalah fitur KLIEN. Alat yang tidak memilikinya akan tumbuh
    sampai menabrak $(contract_fmt "$CONTRACT_CONTEXT_WINDOW") lalu terpotong. Setel ambangnya
    sendiri di ${CONTRACT_COMPACT_PCT}%.
  - Ringkasan/compaction dari alat lain TIDAK dikenali gateway, jadi ia berjalan
    dengan reasoning penuh. Kirim "reasoning_effort":"none" pada request
    ringkasan untuk mematikannya.
  - Header X-Upstream pada respons menyebut server mana yang menjawab.
INFO
        exit 0
        ;;
    --help|-h)
        cat <<'USAGE'
setup.sh --token ca_...       onboarding penuh (interaktif)
setup.sh                      onboarding tanpa token (config akan ditolak gateway)
setup.sh --info               cetak endpoint + api key untuk harness lain
setup.sh --endpoint lan       pindah ke LAN kantor
setup.sh --endpoint vpn       pindah ke VPN kantor
setup.sh --endpoint local     pindah ke localhost (di server AI)
setup.sh --endpoint <url>     alamat lain

Mode --endpoint hanya menulis ulang alamat gateway. Server MCP, seksi [ui],
model tambahan, dan api_key Anda tidak disentuh.
USAGE
        exit 0
        ;;
esac



# --- membaca kondisi yang sudah terpasang -------------------------------------
# Seksi yang DIKELOLA CooperAgent. Apa pun di luar daftar ini milik dev --
# server MCP, preferensi [ui], model tambahan -- dan dipakai untuk memberi tahu
# dengan jujur apa yang akan hilang bila ia memilih tulis-ulang penuh.
MANAGED_SECTIONS="[cli] [features] [session] [memory] [models] [model.internal-qwen] [model.internal-qwen-s2]"

read_existing_endpoint() {
    awk '/^\[model\.internal-qwen\]/{f=1;next} /^\[/{f=0}
         f && /^base_url/{sub(/.*=[[:space:]]*/,""); gsub(/^["'"'"']|["'"'"']$/,""); print; exit}' \
        "$HOME/.grok/config.toml" 2>/dev/null
}

read_existing_identity() {
    grep -m1 '^api_key' "$HOME/.grok/config.toml" 2>/dev/null \
        | sed 's/.*=[[:space:]]*["'"'"']\?dev-//; s/["'"'"']$//'
}

list_unmanaged_sections() {
    grep '^\[' "$HOME/.grok/config.toml" 2>/dev/null | while read -r sec; do
        case " $MANAGED_SECTIONS " in *" $sec "*) ;; *) echo "$sec" ;; esac
    done
}

# Ringkasan kondisi + pilihan cara memperbarui. Menuliskan pilihan ke
# CONFIG_MODE, SERVER_URL, dan DEV_IDENTITY bila dev memilih mempertahankannya.
#
# Kenapa ini ada: sampai 2026-08-27 skrip langsung menanyakan semuanya lalu
# menimpa. Dev yang hanya ingin memperbarui parameter kehilangan server MCP-nya
# tanpa pernah diberi tahu bahwa itu akan terjadi.
prompt_config_mode() {
    CONFIG_MODE="fresh"
    [ -f "$HOME/.grok/config.toml" ] || return 0

    local cur_ep cur_id unmanaged
    cur_ep="$(read_existing_endpoint)"
    cur_id="$(read_existing_identity)"
    unmanaged="$(list_unmanaged_sections | paste -sd' ' -)"

    echo -e "\n${CYAN}--- Konfigurasi Grok yang sudah ada terdeteksi ---${NC}"
    echo -e "  berkas    : $HOME/.grok/config.toml"
    [ -n "$cur_ep" ] && echo -e "  endpoint  : ${cur_ep}"
    [ -n "$cur_id" ] && echo -e "  identitas : ${cur_id}"
    if [ -n "$unmanaged" ]; then
        echo -e "  milik Anda: ${YELLOW}${unmanaged}${NC}"
        echo -e "              (di luar kelolaan CooperAgent — mis. server MCP, setelan UI)"
    fi

    echo -e "\n${YELLOW}Bagaimana Anda ingin memperbarui?${NC}"
    echo -e "  1) ${GREEN}Perbarui parameter CooperAgent saja${NC} [disarankan]"
    echo -e "     Endpoint dan identitas dipertahankan. Milik Anda tidak disentuh."
    echo -e "  2) Ganti endpoint saja, sisanya dipertahankan"
    echo -e "  3) ${RED}Tulis ulang penuh dari template${NC}"
    if [ -n "$unmanaged" ]; then
        echo -e "     ${RED}Seksi di atas AKAN HILANG${NC} (cadangan tetap dibuat)."
    fi
    read -rp "Pilihan [1/2/3, default: 1]: " MODE_CHOICE
    MODE_CHOICE=${MODE_CHOICE:-1}

    case "$MODE_CHOICE" in
        2) CONFIG_MODE="merge"
           KEEP_IDENTITY="$cur_id" ;;
        3) CONFIG_MODE="overwrite" ;;
        *) CONFIG_MODE="merge"
           KEEP_IDENTITY="$cur_id"
           KEEP_ENDPOINT="$cur_ep" ;;
    esac
}

# --- penulisan config.toml ----------------------------------------------------
# Kunci di bawah adalah yang DIKELOLA skrip ini. Kunci lain di mesin dev --
# server MCP, [ui], [marketplace], model tambahan -- tidak disebut di sini dan
# karena itu tidak pernah tersentuh oleh merge.
write_grok_config() {
    local server_url="$1" identity="$2" mode="${3:-merge}"
    local gw="${server_url%/api/v1}"
    # Token menang bila ada. Identitas `dev-nama@device` dipertahankan hanya
    # sebagai jalur mundur untuk gateway yang belum menegakkan kredensial --
    # pada gateway yang sudah, ia dijawab 401.
    local api_key_value="dev-${identity}"
    # Yang SUDAH berupa token dipakai apa adanya. Tanpa cabang ini,
    # `--endpoint vpn` -- yang meneruskan api_key lama sebagai `identity` --
    # menghasilkan `dev-ca_...`, yaitu token yang tidak pernah cocok.
    case "$identity" in ca_*) api_key_value="$identity" ;; esac
    [ -n "${DEV_TOKEN:-}" ] && api_key_value="$DEV_TOKEN"
    local cfg="$HOME/.grok/config.toml"
    local tpl merged stamp
    mkdir -p "$HOME/.grok"
    tpl="$(mktemp)"

    # Aritmetika bantalan DIHITUNG dari kontrak. Sebelumnya ketiga barisnya
    # ditulis tangan, dan angka tangan menjadi salah tanpa suara begitu salah
    # satu sukunya berubah -- persis jenis komentar yang lebih berbahaya
    # daripada tidak ada komentar sama sekali.
    _peak=$(( CONTRACT_COMPACT_TOKENS + CONTRACT_MAX_TOKENS ))
    _slack=$(( CONTRACT_CONTEXT_WINDOW - _peak ))

    cat > "$tpl" <<EOF
[cli]
auto_update = false

[features]
telemetry = false

[session]
# Compaction dipicu di ${CONTRACT_COMPACT_PCT}% dari context_window = $(contract_fmt "$CONTRACT_COMPACT_TOKENS") token.
#   $(contract_fmt "$CONTRACT_COMPACT_TOKENS") (picu) + $(contract_fmt "$CONTRACT_MAX_TOKENS") (jawaban) = $(contract_fmt "$_peak") puncak
#   $(contract_fmt "$CONTRACT_CONTEXT_WINDOW") (plafon slot) - $(contract_fmt "$_peak") = $(contract_fmt "$_slack") sisa
# Bantalan itu menyerap selisih antara perkiraan token klien dan tokenizer
# server -- terukur 29 Agustus 2026: satu slot berjalan di 121.111 token.
#
# Semua angka di blok ini: $(contract_note).
auto_compact_threshold_percent = ${CONTRACT_COMPACT_PCT}
load_envrc = true

[memory]
enabled = true

[models]
default = "internal-qwen"
stream_tool_calls = true
temperature = 1.0
top_p = 0.95
min_p = 0.0
repeat_penalty = 1.0
max_completion_tokens = ${CONTRACT_MAX_TOKENS}
max_tokens = ${CONTRACT_MAX_TOKENS}
max_output_tokens = ${CONTRACT_MAX_TOKENS}

[model.internal-qwen]
model = "${DEFAULT_MODEL_NAME}"
base_url = "${server_url}"
name = "CooperAgent Qwen3.8-27B (routing otomatis)"
description = "Gateway memilih server; header X-Upstream menyebut mana yang menjawab"
api_backend = "chat_completions"
# Plafon SATU slot llama-server (--ctx-size / --parallel), sama di kedua server.
# Ditanyakan ke gateway saat setup, bukan dipatok: nilainya berubah setiap kali
# --parallel dinaikkan. Bantalannya diatur oleh ambang ${CONTRACT_COMPACT_PCT}% di [session].
context_window = ${CONTRACT_CONTEXT_WINDOW}
max_completion_tokens = ${CONTRACT_MAX_TOKENS}
max_tokens = ${CONTRACT_MAX_TOKENS}
max_output_tokens = ${CONTRACT_MAX_TOKENS}
temperature = 1.0
top_p = 0.95
min_p = 0.0
repeat_penalty = 1.0
presence_penalty = 0.0
api_key = "${api_key_value}"

# Menembus routing, langsung ke server 2 (bobot UD-Q4_K_XL).
# ALAT PEMBANDING, bukan cara kerja sehari-hari: sesi yang memakainya kehilangan
# failover otomatis -- kalau server 2 mati, request-nya gagal, tidak berpindah.
[model.internal-qwen-s2]
model = "${DEFAULT_MODEL_NAME}"
base_url = "${gw}/api/v1/upstream/s2"
name = "CooperAgent Qwen3.8-27B @ server 2 (UD-Q4_K_XL)"
description = "Langsung ke server 2, menembus routing gateway"
api_backend = "chat_completions"
context_window = ${CONTRACT_CONTEXT_WINDOW}
max_completion_tokens = ${CONTRACT_MAX_TOKENS}
max_tokens = ${CONTRACT_MAX_TOKENS}
max_output_tokens = ${CONTRACT_MAX_TOKENS}
temperature = 1.0
top_p = 0.95
min_p = 0.0
repeat_penalty = 1.0
presence_penalty = 0.0
api_key = "${api_key_value}"
EOF

    if [ -f "$cfg" ] && [ "$mode" != "overwrite" ]; then
        merged="$(merge_toml "$tpl" "$cfg")"
        if [ "$merged" == "$(cat "$cfg")" ]; then
            echo -e "${GREEN}${S_OK}${NC} config.toml sudah sesuai — tidak ada perubahan."
        else
            stamp="$(date +%Y%m%d-%H%M%S)"
            cp "$cfg" "$cfg.bak.$stamp"
            printf '%s\n' "$merged" > "$cfg"
            echo -e "${GREEN}${S_OK}${NC} config.toml diperbarui (cadangan: config.toml.bak.$stamp)."
            echo -e "  ${YELLOW}Server MCP, [ui], dan model tambahan Anda dibiarkan utuh.${NC}"
        fi
    elif [ -f "$cfg" ]; then
        # Tulis ulang penuh — hanya bila dev memilihnya secara sadar.
        stamp="$(date +%Y%m%d-%H%M%S)"
        cp "$cfg" "$cfg.bak.$stamp"
        cp "$tpl" "$cfg"
        echo -e "${GREEN}${S_OK}${NC} config.toml ditulis ulang (cadangan: config.toml.bak.$stamp)."
        echo -e "  ${YELLOW}Seksi di luar kelolaan CooperAgent tidak ikut dibawa — ada di cadangan.${NC}"
    else
        cp "$tpl" "$cfg"
        echo -e "${GREEN}${S_OK}${NC} config.toml dibuat: $cfg"
    fi
    rm -f "$tpl"
}

# --- mode "sudah terpasang" ---------------------------------------------------
#
# Skrip ini adalah SATU pintu masuk, dan yang dilihat dev berbeda menurut
# keadaan mesinnya: onboarding penuh hanya untuk yang belum terpasang. Yang
# sudah terpasang tidak butuh ditanya harness dan endpoint lagi -- ia butuh
# tahu keadaannya sekarang, dan mengubah satu hal.
#
# Kredensial diperiksa di SINI, setiap kali, bahkan ketika dev hanya ingin
# memperbarui parameter. Pencabutan terjadi di sisi server tanpa memberi tahu
# klien; kalau bukan kita yang bertanya, dev baru mengetahuinya lewat 401 di
# tengah kerja.
GROK_CFG="$HOME/.grok/config.toml"
OMP_YML_PATH="$HOME/.omp/agent/models.yml"

installed_grok() {
    [ -f "$GROK_CFG" ] && grep -q '^\[model\.internal-qwen' "$GROK_CFG" 2>/dev/null
}
installed_omp() {
    [ -f "$OMP_YML_PATH" ] && grep -qE '^  cooperagent:' "$OMP_YML_PATH" 2>/dev/null
}

# Alamat dan token dibaca dari MANA PUN yang ada. Dev yang memilih omp saja
# tidak punya config.toml, dan sampai 3 September 2026 ia karena itu tidak
# pernah terlihat sebagai "sudah terpasang".
stored_gateway() {
    local v=""
    if installed_grok; then
        v="$(grep -m1 -E '^[[:space:]]*base_url' "$GROK_CFG" 2>/dev/null \
             | sed -E 's/.*["'"'"']([^"'"'"']*)["'"'"'].*/\1/' || true)"
    fi
    [ -z "$v" ] && installed_omp && v="$(omp_gateway_of "$OMP_YML_PATH" || true)"
    printf '%s' "$v"
}
stored_token() {
    local v=""
    if installed_grok; then
        v="$(grep -m1 -E '^[[:space:]]*api_key' "$GROK_CFG" 2>/dev/null \
             | sed -E 's/.*["'"'"']([^"'"'"']*)["'"'"'].*/\1/' || true)"
    fi
    case "$v" in ca_*) ;; *) v="" ;; esac
    if [ -z "$v" ] && installed_omp; then
        v="$(omp_api_key_of "$OMP_YML_PATH" || true)"
        case "$v" in ca_*) ;; *) v="" ;; esac
    fi
    printf '%s' "$v"
}

# Menulis kredensial dan alamat ke SEMUA harness yang terpasang.
#
# Satu tempat, karena inilah yang selalu terlewat: sampai 3 September 2026
# `--endpoint` hanya menyentuh config Grok, sehingga dev yang memakai keduanya
# berpindah jaringan di Grok dan tetap menunjuk alamat lama di omp.
apply_to_all_harness() { # $1 = gateway baru  $2 = kredensial  $3 = identitas
    local new_url="$1" tok="$2" ident="$3" key old_gw stamp
    # Yang BUKAN token tidak boleh menyamar sebagai token: config lama berisi
    # `dev-nama@device`, dan meneruskannya sebagai DEV_TOKEN akan menulis
    # `api_key = "dev-nama@device"` menjadi `nama@device` -- bentuk ketiga yang
    # tidak pernah benar di mana pun.
    case "$tok" in ca_*) ;; *) tok="" ;; esac
    key="$(omp_api_key "$ident" "$tok")"
    if installed_grok; then
        DEV_TOKEN="$tok" write_grok_config "$new_url" "$ident"
    fi
    if installed_omp; then
        stamp="$(date +%Y%m%d-%H%M%S)"
        cp "$OMP_YML_PATH" "$OMP_YML_PATH.bak.$stamp"
        old_gw="$(omp_gateway_of "$OMP_YML_PATH" || true)"
        if [ -n "$old_gw" ] && [ "$old_gw" != "$(cooper_gateway_base "$new_url")" ]; then
            omp_set_base_url "$OMP_YML_PATH" "$old_gw" "$(cooper_gateway_base "$new_url")" || true
        fi
        omp_set_api_key "$OMP_YML_PATH" "$key" "$(cooper_gateway_base "$new_url")" || true
        echo -e "${GREEN}${S_OK}${NC} models.yml omp diperbarui (cadangan: models.yml.bak.$stamp)"
    fi
}

# --- eksekusi mode ganti endpoint --------------------------------------------
if [ -n "$SWITCH_ONLY" ]; then
    # Alias diselesaikan oleh GATEWAY, bukan oleh tabel di skrip ini.
    #
    # Sampai 2 September 2026 `lan`, `vpn`, dan `local` dipetakan ke tiga
    # konstanta di kepala berkas. Sekarang alamatnya ditanyakan ke gateway yang
    # sedang terpasang; bila tidak terjangkau, dipakai daftar yang tersimpan dari
    # kontrak terakhir yang berhasil. Keduanya gagal = katakan, jangan tebak.
    case "$SWITCH_ONLY" in
        http://*|https://*)
            NEW_URL="$(normalize_endpoint "$SWITCH_ONLY")" ;;
        *)
            CUR_URL="$(grep -m1 -E '^[[:space:]]*base_url' "$HOME/.grok/config.toml" 2>/dev/null \
                | sed -E 's/.*["'"'"']([^"'"'"']*)["'"'"'].*/\1/' || true)"
            NEW_URL=""
            if [ -n "$CUR_URL" ] && fetch_contract "${CUR_URL%/api/v1}"; then
                NEW_URL="$(contract_endpoint_url "$SWITCH_ONLY")"
                cache_endpoints
            fi
            if [ -z "$NEW_URL" ]; then
                NEW_URL="$(cached_endpoints | awk -F"$(printf '\t')" -v k="$SWITCH_ONLY" '$1==k {print $3; exit}')"
                [ -n "$NEW_URL" ] && echo -e "${YELLOW}! Gateway tidak terjangkau — memakai alamat tersimpan.${NC}"
            fi
            if [ -z "$NEW_URL" ]; then
                echo -e "${RED}${S_NO} Alias '${SWITCH_ONLY}' tidak dikenal gateway.${NC}"
                if [ -n "$CONTRACT_ENDPOINTS" ]; then
                    echo -e "${YELLOW}  Yang diumumkan gateway:${NC}"
                    printf '%s\n' "$CONTRACT_ENDPOINTS" | while IFS="$(printf '\t')" read -r eid elabel eurl; do
                        [ -n "$eid" ] && echo -e "    ${CYAN}${eid}${NC}  ${eurl}  (${elabel})"
                    done
                else
                    echo -e "${YELLOW}  Gateway tidak mengumumkan alamat alternatif, dan tidak ada yang tersimpan.${NC}"
                    echo -e "  Pakai alamat lengkap: ${CYAN}./setup.sh --endpoint http://<host>:8987/api/v1${NC}"
                fi
                exit 1
            fi ;;
    esac

    # Identitas dibaca ulang dari config, bukan ditanya lagi: mengganti jaringan
    # tidak mengubah siapa Anda, dan salah ketik di sini akan memecah leaderboard.
    # Ambil NILAI di dalam kutip, apa pun bentuknya.
    #
    # Bentuk sebelumnya -- `sed 's/.*=[[:space:]]*"\?dev-//'` -- dibangun untuk
    # identitas lama `dev-nama@device` dan tidak pernah diperbarui saat token
    # datang. Pada config bertoken polanya TIDAK cocok, sehingga seluruh baris
    # lolos apa adanya dan ditulis ulang sebagai `api_key = "dev-api_key = "ca_..."`:
    # token hancur, TOML rusak, dan dev dijawab 401 tepat setelah berpindah
    # jaringan. Terbukti 2 September 2026 dengan menjalankan `--endpoint vpn`
    # pada config bertoken.
    EXISTING_KEY="$(grep -m1 -E '^[[:space:]]*api_key' "$HOME/.grok/config.toml" 2>/dev/null \
        | sed -E 's/.*["'"'"']([^"'"'"']*)["'"'"'].*/\1/' || true)"
    if [ -z "$EXISTING_KEY" ]; then
        echo -e "${RED}${S_NO} Tidak menemukan api_key di ~/.grok/config.toml.${NC}"
        echo -e "${YELLOW}Jalankan setup penuh dulu: bash setup.sh${NC}"
        exit 1
    fi

    echo -e "${CYAN}Memindahkan endpoint ke:${NC} $NEW_URL"

    # Diverifikasi SEBELUM ditulis. Berpindah ke alamat yang tidak menjawab
    # berarti dev kehilangan gateway yang tadinya bekerja, dan sampai
    # 3 September 2026 blok ini menulis dulu lalu memeriksa kesehatan sesudahnya
    # -- urutan yang membuat pemeriksaannya tidak bisa mencegah apa pun.
    case "$EXISTING_KEY" in
        ca_*)
            if cooper_verify_token "$NEW_URL" "$EXISTING_KEY"; then
                echo -e "${GREEN}${S_OK} Kredensial sah di alamat baru${NC} — identitas: ${CYAN}${COOPER_WHO}${NC}"
                EXISTING_ID="$COOPER_WHO"
            else
                echo -e "${RED}${S_NO} Alamat baru TIDAK dipakai — kredensial tidak lolos di sana.${NC}"
                cooper_verify_explain "$COOPER_VERIFY_STATE" "$NEW_URL" | sed 's/^/    /'
                echo -e "\n    ${YELLOW}Config lama dibiarkan utuh.${NC}"
                exit 3
            fi ;;
        *)
            # Config lama tanpa token: tidak ada yang bisa diverifikasi, dan itu
            # dikatakan, bukan didiamkan.
            echo -e "${YELLOW}! Config ini belum memakai token — perpindahan tidak dapat diverifikasi.${NC}"
            echo -e "${YELLOW}  Gateway akan menjawab 401 sampai token dipasang: bash setup.sh${NC}"
            # Awalan `dev-` dilepas: yang disimpan write_grok_config adalah
            # IDENTITAS, dan ia yang memasang awalannya kembali.
            EXISTING_ID="${EXISTING_KEY#dev-}" ;;
    esac

    fetch_contract "$(cooper_gateway_base "$NEW_URL")" || true
    # SEMUA harness, bukan hanya Grok. Sampai 3 September 2026 baris ini hanya
    # menulis config.toml, sehingga dev yang memakai keduanya berpindah jaringan
    # di Grok dan tetap menunjuk alamat lama di omp -- gagal hanya di satu alat,
    # yang paling sulit ditebak sebabnya.
    apply_to_all_harness "$NEW_URL" "$EXISTING_KEY" "$EXISTING_ID"
    cache_endpoints
    exit 0
fi

if [ -z "$SWITCH_ONLY" ] && { installed_grok || installed_omp; }; then
    CUR_GATEWAY="$(stored_gateway)"
    CUR_TOKEN="$(stored_token)"
    [ -n "$DEV_TOKEN" ] && CUR_TOKEN="$DEV_TOKEN"

    echo -e "${CYAN}================================================================${NC}"
    echo -e "${CYAN}   CooperAgent — sudah terpasang di mesin ini                    ${NC}"
    echo -e "${CYAN}================================================================${NC}"
    echo -e "  gateway   : ${CUR_GATEWAY:-(tidak terbaca)}"
    HARNESS_LIST=""
    installed_grok && HARNESS_LIST="Grok Build"
    installed_omp  && HARNESS_LIST="${HARNESS_LIST:+$HARNESS_LIST, }Oh My Pi (omp)"
    echo -e "  harness   : ${HARNESS_LIST}"

    # Kredensial: SELALU ditanyakan ke gateway, tidak pernah disimpulkan dari
    # berkas. Berkas hanya tahu apa yang pernah benar.
    CRED_OK=0
    if [ -z "$CUR_TOKEN" ]; then
        echo -e "  kredensial: ${YELLOW}tidak ada token di config${NC}"
        echo -e "              Permintaan ke gateway akan dijawab 401."
    elif [ -z "$CUR_GATEWAY" ]; then
        echo -e "  kredensial: ${YELLOW}tidak dapat diperiksa — alamat gateway tidak terbaca${NC}"
    elif cooper_verify_token "$CUR_GATEWAY" "$CUR_TOKEN"; then
        CRED_OK=1
        echo -e "  identitas : ${CYAN}${COOPER_WHO}${NC} (peran: ${COOPER_ROLE:-dev})"
        echo -e "  kredensial: ${GREEN}sah${NC} — diverifikasi ke gateway barusan"
    else
        echo -e "  kredensial: ${RED}DITOLAK${NC} (${COOPER_VERIFY_STATE})"
        echo ""
        cooper_verify_explain "$COOPER_VERIFY_STATE" "$CUR_GATEWAY" | sed 's/^/    /'
    fi

    # Kontrak ditampilkan hanya bila benar-benar terambil: angka tebakan yang
    # tampil seperti angka pasti adalah cara repo ini pernah kehilangan waktu.
    if [ -n "$CUR_GATEWAY" ] && fetch_contract "$(cooper_gateway_base "$CUR_GATEWAY")"; then
        echo -e "  kontrak   : context $(contract_fmt "$CONTRACT_CONTEXT_WINDOW") ${S_DOT} output ${CONTRACT_MAX_TOKENS} ${S_DOT} compact ${CONTRACT_COMPACT_PCT}% ${S_DOT} model ${CONTRACT_MODEL_ID}"
        cache_endpoints
    else
        echo -e "  kontrak   : ${YELLOW}tidak terambil — nilai cadangan yang berlaku${NC}"
    fi

    echo ""
    echo -e "${YELLOW}Apa yang ingin Anda lakukan?${NC}"
    # Rekomendasi mengikuti KEADAAN, bukan kebiasaan. Menyarankan "perbarui
    # parameter" kepada dev yang kredensialnya ditolak berarti menyarankan
    # satu-satunya pilihan yang tidak memperbaiki apa pun.
    if [ "$CRED_OK" = 1 ]; then
        echo -e "  ${GREEN}1) Perbarui parameter dari kontrak gateway [disarankan]${NC}"
    else
        echo -e "  1) Perbarui parameter dari kontrak gateway"
    fi
    echo -e "     aturan agent, skill, ambang compaction, context_window"
    echo -e "  2) Ganti alamat gateway (pindah LAN <-> VPN)"
    if [ "$CRED_OK" = 1 ]; then
        echo -e "  3) Pasang / ganti token kredensial"
    else
        echo -e "  ${GREEN}3) Pasang / ganti token kredensial [disarankan — inilah yang memperbaiki 401]${NC}"
    fi
    echo -e "  4) Pasang harness tambahan (Grok / omp yang belum ada)"
    echo -e "  5) Keluar"
    read -rp "Pilihan [1/2/3/4/5, default: 1]: " HOME_CHOICE || HOME_CHOICE=""
    HOME_CHOICE="${HOME_CHOICE:-1}"

    case "$HOME_CHOICE" in
        2)
            # Alamat baru diverifikasi SEBELUM ditulis: berpindah ke alamat yang
            # tidak menjawab berarti dev kehilangan gateway yang tadinya bekerja.
            echo -e "\n${CYAN}--- Alamat gateway baru ---${NC}"
            if [ -n "$CONTRACT_ENDPOINTS" ]; then
                echo -e "${YELLOW}Yang diumumkan gateway:${NC}"
                printf '%s\n' "$CONTRACT_ENDPOINTS" | while IFS="$(printf '\t')" read -r eid elabel eurl; do
                    [ -n "$eid" ] && echo -e "    ${CYAN}${eid}${NC}  ${eurl}  (${elabel})"
                done
            fi
            read -rp "Alias (lan/vpn/local) atau alamat lengkap: " NEW_EP || NEW_EP=""
            [ -z "$NEW_EP" ] && { echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0; }
            case "$NEW_EP" in
                http://*|https://*) NEW_URL="$(normalize_endpoint "$NEW_EP")" ;;
                *) NEW_URL="$(contract_endpoint_url "$NEW_EP")"
                   [ -z "$NEW_URL" ] && NEW_URL="$(cached_endpoints | awk -F"$(printf '\t')" -v k="$NEW_EP" '$1==k {print $3; exit}')" ;;
            esac
            if [ -z "$NEW_URL" ]; then
                echo -e "${RED}${S_NO} Alias '${NEW_EP}' tidak dikenal gateway dan tidak ada di daftar tersimpan.${NC}"
                exit 1
            fi
            if [ -z "$CUR_TOKEN" ]; then
                echo -e "${RED}${S_NO} Tidak ada token untuk diverifikasi di alamat baru.${NC}"
                echo -e "${YELLOW}    Jalankan pilihan 3 lebih dulu.${NC}"
                exit 3
            fi
            echo -e "${YELLOW}Memverifikasi kredensial di alamat baru...${NC}"
            if ! cooper_verify_token "$NEW_URL" "$CUR_TOKEN"; then
                echo -e "${RED}${S_NO} Alamat baru tidak dipakai — kredensial tidak lolos di sana.${NC}"
                cooper_verify_explain "$COOPER_VERIFY_STATE" "$NEW_URL" | sed 's/^/    /'
                echo -e "\n    ${YELLOW}Config lama dibiarkan utuh.${NC}"
                exit 3
            fi
            fetch_contract "$(cooper_gateway_base "$NEW_URL")" || true
            apply_to_all_harness "$NEW_URL" "$CUR_TOKEN" "$COOPER_WHO"
            cache_endpoints
            echo -e "\n${GREEN}${S_OK} Gateway dipindahkan ke:${NC} $NEW_URL"
            echo -e "${GREEN}${S_OK} Identitas:${NC} $COOPER_WHO"
            exit 0 ;;
        3)
            echo -e "\n${CYAN}--- Token CooperAgent ---${NC}"
            echo -e "Minta ke admin bila belum punya: ${CYAN}cooper issue <nama> <device>${NC}"
            read -rp "Tempel token baru (ca_...): " NEW_TOK || NEW_TOK=""
            NEW_TOK="$(printf '%s' "$NEW_TOK" | tr -d '[:space:]')"
            [ -z "$NEW_TOK" ] && { echo -e "${YELLOW}Dibatalkan.${NC}"; exit 0; }
            GW_FOR_TOK="${CUR_GATEWAY}"
            if [ -z "$GW_FOR_TOK" ]; then
                read -rp "Alamat gateway: " GW_FOR_TOK || GW_FOR_TOK=""
                [ -z "$GW_FOR_TOK" ] && { echo -e "${RED}${S_NO} Alamat wajib diisi.${NC}"; exit 1; }
            fi
            if ! cooper_verify_token "$GW_FOR_TOK" "$NEW_TOK"; then
                echo -e "${RED}${S_NO} Token tidak lolos pemeriksaan — tidak ada yang ditulis.${NC}"
                cooper_verify_explain "$COOPER_VERIFY_STATE" "$GW_FOR_TOK" | sed 's/^/    /'
                exit 3
            fi
            fetch_contract "$(cooper_gateway_base "$GW_FOR_TOK")" || true
            apply_to_all_harness "$GW_FOR_TOK" "$NEW_TOK" "$COOPER_WHO"
            echo -e "\n${GREEN}${S_OK} Token dipasang ke semua harness.${NC}"
            echo -e "${GREEN}${S_OK} Identitas:${NC} $COOPER_WHO"
            exit 0 ;;
        4)
            # Jatuh ke onboarding di bawah. Token dan alamat yang sudah ada
            # dibawa serta, jadi dev tidak ditanya ulang.
            echo -e "\n${CYAN}Melanjutkan ke pemasangan harness tambahan.${NC}"
            [ -z "$DEV_TOKEN" ] && DEV_TOKEN="$CUR_TOKEN"
            [ -n "$CUR_GATEWAY" ] && COOPERAGENT_GATEWAY="${COOPERAGENT_GATEWAY:-$CUR_GATEWAY}"
            ;;
        5)
            echo -e "${GREEN}Tidak ada yang diubah.${NC}"
            exit 0 ;;
        *)
            # Pilihan 1 dan apa pun yang tidak dikenal: jalur paling aman, yang
            # hanya memperbarui parameter dan tidak menyentuh kredensial.
            if [ "$CRED_OK" != 1 ]; then
                echo -e "\n${YELLOW}! Parameter tetap diperbarui, tapi kredensial di atas belum sah —${NC}"
                echo -e "${YELLOW}  permintaan ke gateway akan tetap dijawab 401 sampai pilihan 3 dijalankan.${NC}"
            fi
            echo ""
            if [ -f "$SCRIPT_DIR/scripts/setup-dev.sh" ]; then
                # Alamat DITERUSKAN. setup-dev membacanya dari config Grok, dan
                # dev yang memilih omp saja tidak punya berkas itu -- tanpa ini
                # ia berhenti dengan "tidak ada alamat gateway" pada pilihan
                # yang justru default.
                if [ -n "$CUR_TOKEN" ]; then
                    COOPERAGENT_GATEWAY="${CUR_GATEWAY:-${COOPERAGENT_GATEWAY:-}}" \
                        bash "$SCRIPT_DIR/scripts/setup-dev.sh" --token "$CUR_TOKEN"
                else
                    COOPERAGENT_GATEWAY="${CUR_GATEWAY:-${COOPERAGENT_GATEWAY:-}}" \
                        bash "$SCRIPT_DIR/scripts/setup-dev.sh"
                fi
            else
                echo -e "${RED}${S_NO} scripts/setup-dev.sh tidak ditemukan.${NC}"
                exit 1
            fi
            exit 0 ;;
    esac
fi

echo -e "${CYAN}================================================================${NC}"
echo -e "${CYAN}   ${S_ROCKET} CooperAgent Multi-Harness Onboarding (Linux & macOS)     ${NC}"
echo -e "${CYAN}================================================================${NC}\n"

# 1. Pilihan Coding Agent Harness
echo -e "${YELLOW}Pilih Coding Agent yang ingin dipasang/dikonfigurasi:${NC}"
echo -e "  1) Grok Build (Fullscreen Rust TUI, Visual Diff Viewer) [Rekomendasi Utama]"
echo -e "  2) Oh My Pi / omp (coding agent CLI: 31 tool, LSP, session resume)"
echo -e "  3) Keduanya (Grok Build + Oh My Pi)"
echo -e "  4) Manual — endpoint gateway saja (pakai coding agent Anda sendiri)"
read -rp "Pilihan [1/2/3/4, default: 1]: " AGENT_CHOICE
AGENT_CHOICE=${AGENT_CHOICE:-1}

# Apa yang sudah terpasang di mesin ini? Ditanyakan SEBELUM prompt lain, karena
# jawabannya menentukan pertanyaan mana yang tidak perlu diajukan sama sekali.
CONFIG_MODE="fresh"
KEEP_IDENTITY=""
KEEP_ENDPOINT=""
if [ "$AGENT_CHOICE" == "1" ] || [ "$AGENT_CHOICE" == "3" ]; then
    if command -v grok &> /dev/null; then
        echo -e "${GREEN}${S_OK} Grok CLI sudah terpasang:${NC} $(grok --version 2>/dev/null || echo 'terdeteksi')"
    else
        echo -e "${YELLOW}Grok CLI belum terpasang — akan diunduh pada langkah pemasangan.${NC}"
    fi
    prompt_config_mode
fi

# 2. Token kredensial (identitas berasal dari sini)
#
# DITANYAKAN bila tidak diberikan lewat --token. Sampai 1 September 2026 skrip
# ini diam saja dan menulis `dev-<nama>@<device>` -- config yang PASTI dijawab
# 401, dan dev baru mengetahuinya saat mencoba bekerja. Prompt yang bertanya
# lebih baik daripada berkas yang berbohong.
if [ -z "$DEV_TOKEN" ]; then
    # Token yang sudah ada di config dipertahankan tanpa bertanya: menjalankan
    # ulang setup untuk memperbarui parameter tidak boleh menuntut token
    # ditempel ulang.
    EXISTING_TOKEN="$(grep -m1 -E '^[[:space:]]*api_key' "$HOME/.grok/config.toml" 2>/dev/null \
        | sed 's/.*["'"'"']\(ca_[a-f0-9]*\)["'"'"'].*/\1/')"
    case "$EXISTING_TOKEN" in
        ca_*) DEV_TOKEN="$EXISTING_TOKEN"
              echo -e "\n${GREEN}${S_OK} Token dipertahankan dari config:${NC} ...${DEV_TOKEN: -4}" ;;
        *)
            echo -e "\n${CYAN}--- Token CooperAgent ---${NC}"
            echo -e "Gateway menuntut token, dan identitas Anda berasal dari sana —"
            echo -e "nama serta perangkat tidak perlu diketik bila token diberikan."
            echo -e "Minta ke admin bila belum punya:"
            echo -e "  ${CYAN}cooper issue <nama-anda> <nama-perangkat>${NC}"
            read -rp "Tempel token (ca_...), atau Enter untuk melewati: " DEV_TOKEN
            DEV_TOKEN="$(printf '%s' "$DEV_TOKEN" | tr -d '[:space:]')"
            ;;
    esac
fi

if [ -n "$DEV_TOKEN" ]; then
    case "$DEV_TOKEN" in
        ca_*) ;;
        *) echo -e "${RED}${S_NO} Token harus diawali 'ca_'.${NC}"; exit 2 ;;
    esac
    if [ "${#DEV_TOKEN}" -ne 51 ]; then
        echo -e "${RED}${S_NO} Token harus 51 karakter (ca_ + 48 hex); yang ditempel ${#DEV_TOKEN}.${NC}"
        echo -e "${YELLOW}  Kemungkinan terpotong saat disalin — minta ulang ke admin.${NC}"
        exit 2
    fi
else
    # Dilewati dengan sadar. Pemasangan agent tetap berguna; yang tidak akan
    # bekerja adalah permintaan ke gateway, dan itu dikatakan sekarang -- bukan
    # dibiarkan ditemukan sebagai 401 yang tidak jelas sebabnya.
    echo -e "${YELLOW}! Tanpa token, config yang ditulis AKAN DITOLAK gateway (401).${NC}"
    echo -e "  Agent tetap dipasang. Tambahkan tokennya nanti dengan:"
    echo -e "    ${CYAN}./scripts/setup-dev.sh --token ca_...${NC}"
fi


# 3. Alamat gateway — DITENTUKAN SEBELUM identitas
#
# Urutannya penting. Probe /api/auth/whoami di bawah membutuhkan alamat, dan
# sampai 2 September 2026 ia diam-diam bersandar pada alamat LAN yang dipatok
# di kepala berkas. Begitu patokan itu dilepas, probe pada pemasangan BARU
# tidak punya apa pun untuk ditanya, dan dev kembali diminta mengetik nama
# serta perangkat -- persis yang dihapus commit 6c392af.

if [ -n "$KEEP_ENDPOINT" ]; then
    SERVER_URL="$KEEP_ENDPOINT"
    echo -e "\n${GREEN}${S_OK} Endpoint dipertahankan:${NC} ${SERVER_URL}"
    echo -e "  ${YELLOW}Untuk memindahkannya nanti:${NC} ./setup.sh --endpoint vpn|lan|local"
elif [ -n "$COOPERAGENT_GATEWAY" ]; then
    SERVER_URL="$(normalize_endpoint "$COOPERAGENT_GATEWAY")"
    echo -e "\n${GREEN}${S_OK} Endpoint dari \$COOPERAGENT_GATEWAY:${NC} ${SERVER_URL}"
else
    # DITANYAKAN, bukan ditawarkan dari daftar.
    #
    # Menu lama menawarkan "1) LAN Kantor (<ip-lan>)" -- nyaman, tapi berarti
    # skrip ini memuat alamat internal, dan itu yang menghalanginya pindah ke repo
    # publik. Alamatnya sudah ada di tangan dev: `cooper issue` mencetaknya
    # bersama token, di blok yang sama.
    #
    # Sesudah tersambung, gateway sendiri yang mengumumkan alamat alternatifnya,
    # jadi `--endpoint vpn` tetap bekerja tanpa satu pun alamat tertulis di sini.
    echo -e "\n${CYAN}--- Alamat CooperAgent Gateway ---${NC}"
    echo -e "Ada di blok serah-terima yang Anda terima bersama token."
    echo -e "${YELLOW}Bentuknya:${NC} http://<host>:8987/api/v1"
    if [ -n "$(cached_endpoints)" ]; then
        echo -e "\n${YELLOW}Yang pernah bekerja di mesin ini:${NC}"
        cached_endpoints | while IFS="$(printf '\t')" read -r eid elabel eurl; do
            [ -n "$eurl" ] && echo -e "  ${CYAN}${eurl}${NC}  (${elabel})"
        done
        echo
    fi
    read -rp "Tempel alamat gateway: " SERVER_URL
    SERVER_URL="$(printf '%s' "$SERVER_URL" | tr -d '[:space:]')"
    if [ -z "$SERVER_URL" ]; then
        echo -e "${RED}${S_NO} Alamat gateway wajib diisi.${NC}"
        echo -e "${YELLOW}  Minta ke admin bila tidak menemukannya:${NC} cooper issue <nama> <device>"
        exit 1
    fi
    SERVER_URL="$(normalize_endpoint "$SERVER_URL")"
fi


# 2b. GERBANG KREDENSIAL — diperiksa SEBELUM satu berkas pun ditulis
#
# Gateway mencatat identitas dari TOKEN (`cred.devName`, `cred.device`), bukan
# dari config klien, jadi pemeriksaan ini sekaligus menjawab "siapa Anda".
#
# Sampai 3 September 2026 kegagalan di sini DITELAN: gateway tak terjangkau,
# token tidak dikenal, dan kredensial dicabut sama-sama jatuh diam-diam ke
# prompt nama manual di bawah, lalu setup berjalan sampai akhir dan menulis
# config yang pasti dijawab 401. Sekarang ia berhenti, dengan sebabnya.
DEV_IDENTITY=""
if [ -n "$DEV_TOKEN" ]; then
    echo -e "\n${CYAN}--- Verifikasi kredensial ---${NC}"
    echo -e "  gateway : $(cooper_gateway_base "$SERVER_URL")"
    echo -e "  token   : ...${DEV_TOKEN: -4}"
    if cooper_verify_token "$SERVER_URL" "$DEV_TOKEN"; then
        DEV_IDENTITY="$COOPER_WHO"
        echo -e "${GREEN}${S_OK} Kredensial sah${NC} — identitas: ${CYAN}${DEV_IDENTITY}${NC} (peran: ${COOPER_ROLE:-dev})"
        echo -e "  ${YELLOW}Inilah yang tercatat di dashboard — tidak perlu diketik.${NC}"
    else
        echo -e "${RED}${S_NO} Kredensial tidak lolos pemeriksaan.${NC}"
        cooper_verify_explain "$COOPER_VERIFY_STATE" "$SERVER_URL" | sed 's/^/    /'
        echo -e "\n    ${YELLOW}Tidak ada satu berkas pun yang ditulis.${NC}"
        exit 3
    fi
fi


# 2c. Identitas manual — hanya bila token tidak ada atau gateway tak terjangkau
if [ -z "$DEV_IDENTITY" ]; then
    if [ -n "$KEEP_IDENTITY" ]; then
        DEV_IDENTITY="$KEEP_IDENTITY"
        echo -e "\n${GREEN}${S_OK} Identitas dipertahankan:${NC} ${DEV_IDENTITY}"
    else
    echo -e "\n${CYAN}--- Identitas Developer (CooperxTelemetry) ---${NC}"
    read -rp "Masukkan nama/nickname Anda (contoh: lee, alex, budi, vincent) [default: dev-user]: " DEV_NAME
    DEV_NAME=${DEV_NAME:-dev-user}
    DEV_NAME=$(echo "$DEV_NAME" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')
    [ -z "$DEV_NAME" ] && DEV_NAME="dev-user"

    # Device dipakai sebagai kunci pengelompokan di leaderboard. Tanpa ini identitas
    # hanya bersandar pada IP -- dan IP DHCP yang berubah memecah satu orang menjadi
    # beberapa baris terpisah (contoh nyata: satu device muncul 4x di leaderboard).
    DEFAULT_DEVICE=$(hostname 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')
    [ -z "$DEFAULT_DEVICE" ] && DEFAULT_DEVICE="device"
    echo -e "${YELLOW}Nama device memisahkan pemakaian antar perangkat Anda (laptop vs PC).${NC}"
    read -rp "Masukkan nama device (contoh: laptop-tuf, pc-kantor, macbook) [default: ${DEFAULT_DEVICE}]: " DEV_DEVICE
    DEV_DEVICE=${DEV_DEVICE:-$DEFAULT_DEVICE}
    DEV_DEVICE=$(echo "$DEV_DEVICE" | tr '[:upper:]' '[:lower:]' | tr -cd 'a-z0-9_-')
    [ -z "$DEV_DEVICE" ] && DEV_DEVICE="$DEFAULT_DEVICE"

    # Format `nama@device` inilah yang dibaca gateway sebagai identitas.
    DEV_IDENTITY="${DEV_NAME}@${DEV_DEVICE}"
    echo -e "${GREEN}${S_OK} Identitas tersimpan:${NC} ${DEV_IDENTITY}"
    fi

fi

# 4. Test Koneksi ke Server (Health Check)
HEALTH_URL="${SERVER_URL%/api/v1}/api/health"
echo -e "\n${YELLOW}Menguji koneksi ke CooperAgent Gateway: ${HEALTH_URL}...${NC}"

if curl -s --connect-timeout 5 "$HEALTH_URL" | grep -q "ok"; then
    echo -e "${GREEN}${S_OK} Koneksi Berhasil! CooperAgent Gateway & GPU Backend aktif & sehat.${NC}"
    # SELURUH kontrak ditanyakan, bukan ditebak: nama model, context_window,
    # max_tokens, dan ambang compaction sekaligus.
    #
    # Sampai 1 September 2026 hanya nama model yang ditanyakan di sini. Tiga
    # sisanya dipatok di skrip, jadi ketika --ctx-size server berubah tidak ada
    # satu pun dari sebelas config dev yang tahu -- dan yang lebih buruk,
    # setup-dev.sh MEMVERIFIKASI config terhadap angka patok yang sama itu,
    # sehingga ia mencetak tanda centang justru saat nilainya sudah basi.
    if fetch_contract "${SERVER_URL%/api/v1}"; then
        if [ "$CONTRACT_MODEL_ID" != "$DEFAULT_MODEL_NAME" ]; then
            echo -e "${YELLOW}  Model yang disajikan gateway: ${CONTRACT_MODEL_ID}${NC} (bukan ${DEFAULT_MODEL_NAME})"
        fi
        DEFAULT_MODEL_NAME="$CONTRACT_MODEL_ID"
        echo -e "${GREEN}${S_OK}${NC} Kontrak diambil: context $(contract_fmt "$CONTRACT_CONTEXT_WINDOW") ${S_DOT} output ${CONTRACT_MAX_TOKENS} ${S_DOT} compact ${CONTRACT_COMPACT_PCT}%"
        # Disimpan di mesin dev supaya `--endpoint vpn` tetap bisa dijawab nanti
        # ketika gateway justru sedang TIDAK terjangkau -- yaitu persis saat dev
        # paling butuh tahu alamat alternatifnya.
        cache_endpoints
        if [ -n "$CONTRACT_ENDPOINTS" ]; then
            echo -e "  ${YELLOW}Alamat lain yang diumumkan gateway:${NC}"
            printf '%s\n' "$CONTRACT_ENDPOINTS" | while IFS="$(printf '\t')" read -r eid elabel eurl; do
                [ -n "$eid" ] && echo -e "    ${CYAN}./setup.sh --endpoint ${eid}${NC}  ->  ${eurl}  (${elabel})"
            done
        fi
        if [ "$CONTRACT_UPSTREAM_SOURCE" = "env-fallback" ]; then
            echo -e "${YELLOW}  Catatan: gateway memakai nilai env — tidak ada slot upstream sehat saat ditanya.${NC}"
        fi
    else
        # Gateway sehat tapi kontraknya tidak terurai berarti bentuk /v1/models
        # berubah. Itu harus TERLIHAT. Jatuh diam-diam ke angka cadangan adalah
        # cara sebuah config menjadi salah tanpa seorang pun tahu kapan.
        echo -e "${YELLOW}! Kontrak tidak terbaca dari ${SERVER_URL%/api/v1}/v1/models — memakai nilai cadangan.${NC}"
    fi
else
    echo -e "${RED}${S_NO} Peringatan: Tidak dapat terhubung ke ${HEALTH_URL}.${NC}"
    echo -e "${YELLOW}Pastikan Anda berada di jaringan Wi-Fi/VPN kantor atau server AI sedang aktif.${NC}"
    # Alamat alternatif datang dari kontrak yang PERNAH berhasil di mesin ini,
    # bukan dari tabel di skrip. Dev yang mengetik alamat LAN sementara ia di
    # rumah adalah kasus paling sering, dan ia butuh jawaban justru saat gateway
    # tidak menjawab.
    if [ -n "$(cached_endpoints)" ]; then
        echo -e "${YELLOW}Bila Anda sedang di jaringan lain, coba alamat yang pernah bekerja di mesin ini:${NC}"
        cached_endpoints | while IFS="$(printf '\t')" read -r eid elabel eurl; do
            [ -n "$eurl" ] && echo -e "  ${CYAN}./setup.sh --endpoint ${eid}${NC}  ->  ${eurl}  (${elabel})"
        done
    else
        echo -e "${YELLOW}Alamat lain ada di blok serah-terima bersama token Anda.${NC}"
    fi
fi

# 4b. Mode manual: endpoint saja, tidak memasang agent apa pun
#
# Gateway ini endpoint OpenAI-compatible biasa. Dev yang sudah punya coding
# agent pilihannya tidak perlu dipaksa memakai punya kita -- yang mereka
# butuhkan hanya alamat, kunci, dan aturan mainnya.
if [ "$AGENT_CHOICE" == "4" ]; then
    GW="${SERVER_URL%/api/v1}"
    # Yang dicetak harus yang BENAR-BENAR dipakai. Sampai 1 September 2026 blok
    # ini mencetak `dev-<nama>@<device>` tepat di atas peringatan bahwa bentuk
    # itu ditolak 401 -- petunjuk yang membantah dirinya sendiri, pada jalur
    # yang paling butuh petunjuk benar karena tidak ada skrip yang menolong.
    SHOW_KEY="${DEV_TOKEN:-<minta token ke admin: cooper issue $DEV_IDENTITY>}"
    echo -e "\n${CYAN}--- Endpoint CooperAgent untuk coding agent Anda ---${NC}\n"
    cat <<INFO
  Base URL (OpenAI-compatible)  ${GW}/v1
  API key                       ${SHOW_KEY}
  Model                         ${DEFAULT_MODEL_NAME}
  Context window                ${CONTRACT_CONTEXT_WINDOW}      (prompt DAN jawaban, plafon keras)
  Max output                    ${CONTRACT_MAX_TOKENS}
  Ambang compact yang disarankan ${CONTRACT_COMPACT_PCT}%        = $(contract_fmt "$CONTRACT_COMPACT_TOKENS") token
  Sumber angka di atas          $(contract_note)

  export OPENAI_BASE_URL="${GW}/v1"
  export OPENAI_API_KEY="${SHOW_KEY}"
  export OPENAI_MODEL="${DEFAULT_MODEL_NAME}"

Yang perlu diketahui:
  - api_key HARUS token CooperAgent (ca_...); identitas lama ditolak 401.
  - Auto-compaction adalah fitur KLIEN. Alat tanpa itu akan tumbuh sampai
    menabrak $(contract_fmt "$CONTRACT_CONTEXT_WINDOW") lalu terpotong. Setel ambangnya sendiri
    di ${CONTRACT_COMPACT_PCT}%.
  - Ringkasan/compaction dari alat lain berjalan dengan reasoning penuh.
    Kirim "reasoning_effort":"none" pada request ringkasan.
  - Header X-Upstream pada respons menyebut server mana yang menjawab.

  Cetak ulang kapan saja: ./setup.sh --info
INFO

    # Aturan kerja CooperAgent bersifat opsional di sini -- dev mungkin sudah
    # punya aturannya sendiri, dan menimpanya tanpa bertanya adalah kesalahan.
    echo
    read -rp "Salin aturan kerja CooperAgent ke sebuah proyek? [y/N]: " COPY_RULES
    if [[ "$COPY_RULES" =~ ^[Yy] ]]; then
        read -rp "Path proyek [default: direktori saat ini]: " RULES_DIR
        RULES_DIR="${RULES_DIR:-$PWD}"
        if [ ! -d "$RULES_DIR" ]; then
            echo -e "${RED}${S_NO} Direktori tidak ada: ${RULES_DIR}${NC}"
        else
            SRC="${SCRIPT_DIR}/templates/agent-rules.md"
            DEST="${RULES_DIR}/AGENTS.md"
            if [ -f "$DEST" ]; then
                # Cadangan diperiksa ADA sebelum diklaim: menimpa AGENTS.md
                # milik dev sambil mengaku sudah mencadangkannya adalah
                # kehilangan yang tidak bisa dibatalkan.
                BAK="${DEST}.bak.$(date +%Y%m%d-%H%M%S)"
                if cp "$DEST" "$BAK" 2>/dev/null && [ -s "$BAK" ]; then
                    echo -e "${YELLOW}AGENTS.md sudah ada — dicadangkan: $(basename "$BAK")${NC}"
                else
                    echo -e "${RED}${S_NO} Gagal mencadangkan $DEST — tidak menimpa.${NC}"
                    SKIP_RULES=1
                fi
            fi
            if [ -z "${SKIP_RULES:-}" ]; then
              if cp "$SRC" "$DEST" 2>/dev/null && [ -s "$DEST" ]; then
                echo -e "${GREEN}${S_OK} Aturan tersalin:${NC} ${DEST} ($(wc -c < "$DEST") karakter)"
              else
                echo -e "${RED}${S_NO} Gagal menyalin aturan ke ${DEST}.${NC}"
              fi
            fi
            echo -e "${YELLOW}  Dibaca otomatis oleh Oh My Pi, Grok, Cursor, Claude Code, dan Cline.${NC}"
        fi
    fi

    echo -e "\n${GREEN}${S_PARTY} Selesai. Tidak ada agent yang dipasang — sesuai pilihan Anda.${NC}"
    exit 0
fi

# 5. Instalasi & Konfigurasi Grok Build (jika opsi 1 atau 3)
if [ "$AGENT_CHOICE" == "1" ] || [ "$AGENT_CHOICE" == "3" ]; then
    echo -e "\n${CYAN}--- Mengonfigurasi Grok Build (Rust TUI) ---${NC}"
    if command -v grok &> /dev/null; then
        echo -e "${GREEN}${S_OK} Grok CLI terdeteksi:${NC} $(grok --version 2>/dev/null || echo 'Installed')"
    else
        echo -e "${YELLOW}Mengunduh binary Grok CLI resmi...${NC}"
        curl -fsSL https://x.ai/cli/install.sh | bash || true
        export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH"

        if [ "$OS_TYPE" == "Darwin" ]; then
            [ -f "$HOME/.zshrc" ] && echo 'export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
            [ -f "$HOME/.bash_profile" ] && echo 'export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH"' >> "$HOME/.bash_profile"
        else
            [ -f "$HOME/.bashrc" ] && echo 'export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            [ -f "$HOME/.zshrc" ] && echo 'export PATH="$HOME/.grok/bin:$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
        fi
    fi

    write_grok_config "$SERVER_URL" "$DEV_IDENTITY" "$CONFIG_MODE"
fi

# 6. Konfigurasi Oh My Pi (omp) (jika opsi 2 atau 3)
if [ "$AGENT_CHOICE" == "2" ] || [ "$AGENT_CHOICE" == "3" ]; then
    echo -e "\n${CYAN}--- Mengonfigurasi Oh My Pi (omp) ---${NC}"

    # Menggantikan Pi Agent (2026-08-29). Yang lama adalah klien chat ~120 baris
    # buatan sendiri tanpa tool, tanpa edit berkas, tanpa memory. omp adalah
    # coding agent sungguhan: 31 tool, LSP, bash persisten, session resume, dan
    # memory yang dikurasi agent. Ia juga menemukan AGENTS.md sendiri, sehingga
    # aturan kerja kita sampai tanpa mekanisme tambahan.
    if command -v omp &> /dev/null; then
        echo -e "${GREEN}${S_OK} omp sudah terpasang:${NC} $(omp --version 2>/dev/null || echo 'terdeteksi')"
    else
        echo -e "${YELLOW}Memasang omp (biner siap pakai, tidak butuh Bun)...${NC}"
        # `--binary` memakai biner siap pakai dan MELEWATI Bun sepenuhnya.
        # Tanpa itu installer memilih jalur source bila Bun terpasang, lalu
        # menolak bila versinya di bawah 1.3.14 -- beda satu patch sudah cukup.
        if ! curl -fsSL https://omp.sh/install | sh -s -- --binary; then
            echo -e "${RED}${S_NO} Pemasangan omp gagal.${NC} Coba salah satu:"
            echo -e "    curl -fsSL https://omp.sh/install | sh -s -- --binary   (biner siap pakai)"
            echo -e "    bun install -g @oh-my-pi/pi-coding-agent          (bila Bun sudah ada)"
            echo -e "    https://github.com/can1357/oh-my-pi               (unduh rilis)"
        fi
        export PATH="$HOME/.local/bin:$HOME/.bun/bin:$PATH"
    fi

    mkdir -p "$HOME/.omp/agent"

    # Dirender dari templates/omp-models.yml -- satu sumber, sama seperti
    # config.toml milik Grok.
    #
    # Bila berkasnya SUDAH ADA, dev ditanya lebih dulu -- sejajar dengan
    # perlakuan config.toml pada opsi 1. Sampai 30 Agustus 2026 blok ini
    # menimpanya diam-diam, padahal omp mendukung 60+ provider dan dev bisa
    # menambahkan miliknya sendiri di sana.
    OMP_TPL="${SCRIPT_DIR}/templates/omp-models.yml"
    OMP_YML="$HOME/.omp/agent/models.yml"
    OMP_GW="${SERVER_URL%/api/v1}"

    # Kunci dari TOKEN, bukan dari `dev-${DEV_IDENTITY}`.
    #
    # Sampai 3 September 2026 baris ini menulis `dev-nama@device` tanpa syarat --
    # bentuk yang gateway jawab 401 sejak 1 September. Jalur Grok di
    # `write_grok_config` sudah benar sejak awal, jadi gejalanya khas: `grok`
    # jalan, `omp` 401, dan token yang sama berhasil login di dashboard.
    OMP_API_KEY="$(omp_api_key "$DEV_IDENTITY" "${DEV_TOKEN:-}")"

    render_omp_models() {
        # contract_render, bukan `sed` mentah: template memuat __MODEL_ID__,
        # __CONTEXT_WINDOW__, dan __MAX_TOKENS__ yang hanya kontrak gateway bisa
        # isi. Tanpa ini models.yml lahir dengan placeholder yang belum terganti.
        local tmp
        tmp="$(mktemp)" || return 1
        contract_render "$OMP_TPL" \
            | sed -e "s|__GATEWAY__|${OMP_GW}|g" -e "s|__API_KEY__|${OMP_API_KEY}|g" > "$tmp"
        contract_assert_rendered "$tmp" || { rm -f "$tmp"; return 1; }
        mv "$tmp" "$OMP_YML"
    }

    if [ ! -f "$OMP_TPL" ]; then
        echo -e "${RED}${S_NO} Template tidak ditemukan: $OMP_TPL${NC}"
    elif [ ! -f "$OMP_YML" ]; then
        if render_omp_models; then
            echo -e "${GREEN}${S_OK} models.yml dibuat${NC} (3 provider: otomatis, localhost, server 2)"
        else
            echo -e "${RED}${S_NO} models.yml gagal dirender${NC} — jalankan ulang saat gateway terjangkau."
        fi
    else
        CUR_GW="$(grep -m1 -E '^\s+baseUrl:' "$OMP_YML" | sed -E 's|.*baseUrl: (https?://[^/]*).*|\1|')"
        OTHER="$(grep -cE '^  [a-z0-9-]+:' "$OMP_YML")"
        echo -e "\n${CYAN}--- models.yml omp sudah ada ---${NC}"
        echo -e "  berkas   : $OMP_YML"
        echo -e "  endpoint : ${CUR_GW:-(tidak terbaca)}"
        echo -e "  provider : $OTHER terdaftar"
        echo -e "${YELLOW}Bagaimana Anda ingin memperbarui?${NC}"
        echo -e "  ${GREEN}1) Pertahankan apa adanya [disarankan]${NC}"
        echo -e "  2) Ganti alamat gateway saja, provider Anda dipertahankan"
        echo -e "  3) Tulis ulang penuh dari template ${RED}(provider tambahan Anda AKAN HILANG)${NC}"
        read -rp "Pilihan [1/2/3, default: 1]: " OMP_MODE
        case "${OMP_MODE:-1}" in
            2)  cp "$OMP_YML" "$OMP_YML.bak.$(date +%Y%m%d-%H%M%S)"
                # HANYA baris yang menunjuk gateway LAMA yang dipindahkan.
                #
                # Percobaan pertama mengganti setiap baseUrl non-localhost, dan
                # itu menyeret provider pihak ketiga milik dev (Anthropic,
                # Ollama, dll) ke gateway kita -- kerusakan yang justru ingin
                # dicegah blok ini. Path seperti /upstream/s2 tetap utuh karena
                # yang diganti hanya bagian skema+host+port.
                OLD_ESC="$(printf '%s' "$CUR_GW" | sed 's/[.[\*^$]/\\&/g')"
                if [ -n "$CUR_GW" ]; then
                    sed -i -E "/127\.0\.0\.1/! s|baseUrl: ${OLD_ESC}|baseUrl: ${OMP_GW}|" "$OMP_YML"
                    echo -e "${GREEN}${S_OK} Alamat gateway diganti${NC} ${CUR_GW} -> ${OMP_GW} (cadangan dibuat)"
                else
                    echo -e "${YELLOW}! Alamat lama tidak terbaca — tidak ada yang diubah.${NC}"
                fi ;;
            3)  cp "$OMP_YML" "$OMP_YML.bak.$(date +%Y%m%d-%H%M%S)"
                if render_omp_models; then
                    echo -e "${GREEN}${S_OK} models.yml ditulis ulang dari template${NC} (cadangan dibuat)"
                else
                    echo -e "${RED}${S_NO} models.yml gagal dirender${NC} — berkas lama dipertahankan."
                fi ;;
            *)  echo -e "${GREEN}${S_OK} models.yml dipertahankan${NC} — tidak ada yang disentuh." ;;
        esac

        # apiKey DIPERBARUI apa pun pilihan di atas. Pilihan 1--3 mengatur
        # provider dan alamat -- itu memang milik dev. apiKey bukan: ia
        # kredensial terbitan admin, dan models.yml yang tertinggal berarti
        # `omp` 401 sementara `grok` jalan normal. Yang disentuh hanya provider
        # yang menunjuk gateway kita; kunci berbayar dev tidak ikut.
        if [ -n "${DEV_TOKEN:-}" ] && ! grep -q "apiKey: *${OMP_API_KEY}" "$OMP_YML"; then
            # Cadangan hanya bila pilihan 2/3 belum membuatnya pada detik yang
            # sama: menyalin lagi akan MENIMPA cadangan asli dengan berkas yang
            # sudah diubah -- cadangan yang tidak mencadangkan apa pun.
            OMP_BAK="$OMP_YML.bak.$(date +%Y%m%d-%H%M%S)"
            [ -f "$OMP_BAK" ] || cp "$OMP_YML" "$OMP_BAK"
            if omp_set_api_key "$OMP_YML" "$OMP_API_KEY" "$OMP_GW" \
               && grep -q "apiKey: *${OMP_API_KEY}" "$OMP_YML"; then
                echo -e "${GREEN}${S_OK} apiKey diperbarui ke token${NC} (cadangan dibuat)"
            else
                echo -e "${YELLOW}! Gagal memperbarui apiKey di $OMP_YML — sunting manual.${NC}"
            fi
        fi
    fi

    echo -e "${GREEN}${S_OK} Provider:${NC} $OMP_YML"
    echo -e "${YELLOW}  Pilih modelnya saat pertama menjalankan \`omp\`, atau set di ~/.omp/agent/config.yml${NC}"
fi

# 6b. Aturan agent, skill, dan penyetelan omp
#
# DIDELEGASIKAN, tidak disalin. `scripts/setup-dev.sh` sudah melakukan persis
# ini -- memasang AGENTS.md untuk Grok dan omp, menyalin skill, menyetel
# skills.customDirectories dan ambang compaction omp, lalu memverifikasi
# hasilnya. Menuliskannya ulang di sini berarti dua salinan yang harus dijaga
# sinkron dengan tangan, dan itu kelas kegagalan yang sudah berkali-kali
# menggigit repo ini.
#
# Pembagiannya: setup.sh memasang agent dan memilih endpoint (dev BARU),
# setup-dev.sh memperbarui aturan dan parameter (dev yang SUDAH ada). Yang
# kedua tetap bisa dijalankan sendiri kapan saja.
if [ -x "${SCRIPT_DIR}/scripts/setup-dev.sh" ]; then
    echo -e "\n${CYAN}--- Aturan agent, skill, dan penyetelan omp ---${NC}"
    if [ -n "$DEV_TOKEN" ]; then
        bash "${SCRIPT_DIR}/scripts/setup-dev.sh" --token "$DEV_TOKEN" || true
    else
        bash "${SCRIPT_DIR}/scripts/setup-dev.sh" || true
    fi
fi

# 7. Pasang Git Hooks Otomatis (jika git diinisialisasi)
if [ -d "${SCRIPT_DIR}/.git" ]; then
    git config core.hooksPath "${SCRIPT_DIR}/scripts/hooks" 2>/dev/null || true
    echo -e "${GREEN}${S_OK} Git pre-commit secret protection hooks diaktifkan.${NC}"
fi

# 8. Pasang command standardize & pi ke ~/.local/bin
mkdir -p "$HOME/.local/bin"

echo -e "\n${CYAN}================================================================${NC}"
echo -e "${GREEN}${S_PARTY} Setup Selesai! Selamat datang di CooperAgent!${NC}"
echo -e "  - Menjalankan Grok Build: Ketik ${CYAN}grok${NC} di folder project Anda."
echo -e "  - Menjalankan Oh My Pi:   Ketik ${CYAN}omp${NC} — buka terminal baru dulu bila baru dipasang."
echo -e "  - Handoff saat context penuh: ${YELLOW}/handoff${NC}"
echo -e "  - Checkpoint sesi:       ${CYAN}.cooper/context/${NC} di proyek Anda; ${YELLOW}/handoff${NC} saat context penuh."
echo -e "  - Pantau Dashboard:      Buka ${CYAN}${SERVER_URL%/api/v1}/${NC}"
echo -e "${CYAN}================================================================${NC}\n"
