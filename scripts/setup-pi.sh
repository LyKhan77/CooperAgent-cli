#!/usr/bin/env bash
#
# Pembaru dan pemasang TERISOLASI untuk pi. Jalur ini tidak memanggil Grok atau
# Oh My Pi; pi hanya ditambahkan bila dev memilihnya secara eksplisit.
set -euo pipefail

UI_COLOR=auto
UI_SYMBOLS=auto
DRY_RUN=0
TOKEN=""
ENDPOINT=""
RULES_MODE=""
REMOVE_RULES=0

for _a in "$@"; do
    case "$_a" in
        --no-color) UI_COLOR=off ;;
        --ascii) UI_COLOR=off; UI_SYMBOLS=ascii ;;
    esac
done
if [ "$UI_COLOR" = auto ] && [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; CYAN=$'\033[0;36m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; CYAN=''; NC=''
fi
if [ "$UI_SYMBOLS" = auto ]; then
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *UTF-8*|*utf-8*|*UTF8*|*utf8*) UI_SYMBOLS=utf8 ;;
        *)                             UI_SYMBOLS=ascii ;;
    esac
fi
if [ "$UI_SYMBOLS" = utf8 ]; then
    S_OK='✔'; S_NO='✖'; S_WARN='⚠'
else
    S_OK='[v]'; S_NO='[x]'; S_WARN='[!]'
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --token) TOKEN="${2:-}"; shift 2 ;;
        --token=*) TOKEN="${1#--token=}"; shift ;;
        --endpoint) ENDPOINT="${2:-}"; shift 2 ;;
        --endpoint=*) ENDPOINT="${1#--endpoint=}"; shift ;;
        --rules) RULES_MODE=yes; shift ;;
        --no-rules) RULES_MODE=no; shift ;;
        --remove-rules) REMOVE_RULES=1; shift ;;
        --no-color|--ascii) shift ;;
        *) echo "Opsi tidak dikenal: $1" >&2; exit 2 ;;
    esac
done

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL_DIR="$REPO_ROOT/templates"
PI_AGENT_DIR="${PI_AGENT_DIR:-$HOME/.pi/agent}"
PI_MODELS_JSON="$PI_AGENT_DIR/models.json"
PI_SETTINGS_JSON="$PI_AGENT_DIR/settings.json"
COOPER_SKILLS="$HOME/.cooper/skills"
STAMP="$(date +%Y%m%d-%H%M%S)"

. "$REPO_ROOT/scripts/lib/contract.sh"
. "$REPO_ROOT/scripts/lib/credential.sh"
. "$REPO_ROOT/scripts/lib/backup.sh"
. "$REPO_ROOT/scripts/lib/pi_models.sh"
. "$REPO_ROOT/scripts/lib/pi_verify.sh"

normalize_pi_endpoint() {
    local u="${1%/}"
    u="${u%/api/v1}"; u="${u%/v1}"; u="${u%/api}"
    printf '%s/api/v1' "$u"
}

pi_rules_are_ours() {
    [ -f "$1" ] || return 1
    cmp -s "$TPL_DIR/agent-rules.md" "$1"
}

pi_rules_wanted() {
    case "$RULES_MODE" in
        yes) return 0 ;;
        no)  return 1 ;;
    esac
    [ -f "$PI_AGENT_DIR/AGENTS.md" ] && return 0
    [ -t 0 ] || return 0
    echo "${CYAN}--- Aturan kerja agent (CooperxHarness) ---${NC}"
    echo "  pi membutuhkan AGENTS.md global agar checkpoint dan aturan kerja terbaca."
    printf 'Pasang aturan CooperAgent ke ~/.pi/agent/AGENTS.md? [Y/n]: '
    read -r answer || answer=""
    case "$answer" in [Nn]*) return 1 ;; *) return 0 ;; esac
}

install_pi_rules() {
    local dst="$PI_AGENT_DIR/AGENTS.md" tmp
    # Kepemilikan diperiksa LEBIH DULU, sebelum apa pun diklaim.
    #
    # Urutannya dulu terbalik: berkas yang ADA dan tanpa --rules langsung
    # dilaporkan "milik dev" tanpa pernah dibandingkan. Akibatnya "Perbarui
    # parameter" melewati AGENTS.md milik KAMI SENDIRI sambil menyebutnya milik
    # dev -- pesan yang mengklaim sesuatu yang tidak pernah diperiksa. Terlihat
    # di log Windows 4 September 2026, bersebelahan dengan verify() yang justru
    # melaporkan berkas itu sesuai template.
    if [ -f "$dst" ] && cmp -s "$TPL_DIR/agent-rules.md" "$dst"; then
        echo "  ${GREEN}${S_OK}${NC} aturan agent pi sudah mutakhir."
        return 0
    fi
    if [ -f "$dst" ] && [ "$RULES_MODE" != yes ]; then
        echo "  ${YELLOW}${S_WARN}${NC} aturan pi BERBEDA dari template CooperAgent — dipertahankan: $dst"
        echo "     Jalankan dengan --rules bila memang ingin menggantinya."
        return 0
    fi
    mkdir -p "$(dirname "$dst")"
    if [ "$DRY_RUN" = 0 ]; then
        if [ -f "$dst" ]; then
            cp "$dst" "$dst.bak.$STAMP"
            [ -s "$dst.bak.$STAMP" ] || { echo "${RED}${S_NO}${NC} cadangan aturan pi kosong." >&2; return 1; }
            bak_prune "$dst"
        fi
        tmp="$(mktemp)"
        cp "$TPL_DIR/agent-rules.md" "$tmp"
        [ -s "$tmp" ] || { rm -f "$tmp"; return 1; }
        mv "$tmp" "$dst"
    fi
    echo "  ${GREEN}${S_OK}${NC} aturan agent pi dipasang ($(wc -c < "$TPL_DIR/agent-rules.md") karakter)."
}

install_pi_skills() {
    local src name dst
    for src in "$TPL_DIR"/skills/*/; do
        [ -d "$src" ] || continue
        name="$(basename "$src")"
        dst="$COOPER_SKILLS/$name"
        if [ -d "$dst" ] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
            continue
        fi
        if [ "$DRY_RUN" = 0 ]; then
            mkdir -p "$COOPER_SKILLS"
            mkdir -p "$dst"
            cp -r "$src"/. "$dst"/
            for managed in "$src"/*; do
                [ -e "$managed" ] || continue
                [ -e "$dst/$(basename "$managed")" ] || return 1
            done
        fi
    done
    # Skill lama tidak dihapus: direktori ini boleh memuat tambahan milik
    # dev. Nama baru cukup ditambahkan dan versi lama dibiarkan tersedia.
    echo "  ${GREEN}${S_OK}${NC} skill CooperAgent tersedia melalui $COOPER_SKILLS."
}

install_pi_json() { # $1 = kind; $2 = target; $3 = rendered merged JSON
    local kind="$1" target="$2" rendered="$3" bak
    if [ -f "$target" ] && cmp -s "$rendered" "$target"; then
        echo "  ${GREEN}${S_OK}${NC} $(basename "$target") sudah sesuai — tidak ada perubahan."
        return 0
    fi
    if [ "$DRY_RUN" = 0 ]; then
        mkdir -p "$(dirname "$target")"
        if [ -f "$target" ]; then
            bak="$target.bak.$STAMP"
            cp "$target" "$bak"
            [ -s "$bak" ] || { echo "${RED}${S_NO}${NC} cadangan $kind kosong." >&2; return 1; }
            echo "  cadangan: $bak"
            bak_prune "$target"
        fi
        umask 077
        cp "$rendered" "$target.tmp.$$.json"
        mv "$target.tmp.$$.json" "$target"
        chmod 600 "$target"
        cmp -s "$rendered" "$target" || return 1
    fi
    echo "  ${GREEN}${S_OK}${NC} $(basename "$target") diperbarui."
}

if [ "$REMOVE_RULES" = 1 ]; then
    if [ -f "$PI_AGENT_DIR/AGENTS.md" ] && pi_rules_are_ours "$PI_AGENT_DIR/AGENTS.md"; then
        if [ "$DRY_RUN" = 0 ]; then
            cp "$PI_AGENT_DIR/AGENTS.md" "$PI_AGENT_DIR/AGENTS.md.bak.$STAMP"
            [ -s "$PI_AGENT_DIR/AGENTS.md.bak.$STAMP" ] || exit 1
            bak_prune "$PI_AGENT_DIR/AGENTS.md"
            rm -f "$PI_AGENT_DIR/AGENTS.md"
        fi
        echo "${GREEN}${S_OK}${NC} aturan agent pi dilepas (cadangan dibuat)."
    else
        echo "${YELLOW}${S_WARN}${NC} aturan pi milik dev atau tidak ada — tidak disentuh."
    fi
    exit 0
fi

if ! pi_rules_wanted; then
    echo "${RED}${S_NO}${NC} Pemasangan pi dibatalkan: verify() mensyaratkan AGENTS.md global." >&2
    echo "    Jalankan lagi dengan --rules bila ingin memakai aturan CooperAgent." >&2
    exit 4
fi

SERVER_URL=""
if [ -n "$ENDPOINT" ]; then
    SERVER_URL="$(normalize_pi_endpoint "$ENDPOINT")"
elif [ -n "${COOPERAGENT_GATEWAY:-}" ]; then
    SERVER_URL="$(normalize_pi_endpoint "$COOPERAGENT_GATEWAY")"
else
    EXISTING_PI_GATEWAY="$(pi_gateway_of "$PI_MODELS_JSON" 2>/dev/null || true)"
    [ -n "$EXISTING_PI_GATEWAY" ] && SERVER_URL="$(normalize_pi_endpoint "$EXISTING_PI_GATEWAY")"
fi
if [ -z "$SERVER_URL" ] || [ "$SERVER_URL" = "/api/v1" ]; then
    echo "${RED}${S_NO}${NC} Tidak ada alamat gateway pi." >&2
    echo "    Pakai --endpoint, COOPERAGENT_GATEWAY, atau config pi yang sudah ada." >&2
    exit 1
fi

if [ -z "$TOKEN" ]; then
    TOKEN="$(pi_api_key_of "$PI_MODELS_JSON" 2>/dev/null || true)"
fi
if ! cooper_token_form_ok "$TOKEN"; then
    echo "${RED}${S_NO}${NC} Pi membutuhkan token ca_...; identitas dev-... tidak digunakan." >&2
    exit 3
fi

echo "${CYAN}--- Gerbang kredensial pi ---${NC}"
if ! cooper_verify_token "$SERVER_URL" "$TOKEN"; then
    echo "${RED}${S_NO}${NC} Kredensial pi tidak lolos pemeriksaan." >&2
    cooper_verify_explain "$COOPER_VERIFY_STATE" "$SERVER_URL" | sed 's/^/    /' >&2
    echo "    Tidak ada berkas pi yang ditulis." >&2
    exit 3
fi
PI_WHO="$COOPER_WHO"
echo "${GREEN}${S_OK}${NC} token sah — identitas: ${PI_WHO}"

BASE="$(cooper_gateway_base "$SERVER_URL")"
if fetch_contract "$BASE"; then
    echo "${GREEN}${S_OK}${NC} kontrak dari gateway: context $(contract_fmt "$CONTRACT_CONTEXT_WINDOW") - output $CONTRACT_MAX_TOKENS - compact $CONTRACT_COMPACT_PCT%"
else
    echo "${YELLOW}${S_WARN}${NC} kontrak tidak terambil — memakai nilai cadangan; periksa ulang setelah tersambung."
fi
echo "  sumber angka pi: $(contract_note)"

PI_BIN="${COOPERAGENT_PI_BIN:-$(command -v pi 2>/dev/null || true)}"
if [ -z "$PI_BIN" ] || [ ! -x "$PI_BIN" ]; then
    echo "${RED}${S_NO}${NC} biner pi tidak ditemukan; tidak ada berkas yang ditulis." >&2
    exit 1
fi
command -v node >/dev/null 2>&1 || {
    echo "${RED}${S_NO}${NC} Node.js diperlukan untuk merge models.json/settings.json." >&2
    exit 1
}

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/cooperagent-pi-setup.XXXXXX")"
cleanup_tmp() { rm -rf "$TMP_DIR"; }
trap cleanup_tmp EXIT

pi_render_template "$TPL_DIR/pi-models.json" "$BASE" "$TOKEN" > "$TMP_DIR/models.template.json"
pi_render_template "$TPL_DIR/pi-settings.json" "$BASE" "$TOKEN" > "$TMP_DIR/settings.template.json"
contract_assert_rendered "$TMP_DIR/models.template.json"
contract_assert_rendered "$TMP_DIR/settings.template.json"
pi_merge_json models "$PI_MODELS_JSON" "$TMP_DIR/models.template.json" "$TMP_DIR/models.merged.json"
pi_merge_json settings "$PI_SETTINGS_JSON" "$TMP_DIR/settings.template.json" "$TMP_DIR/settings.merged.json"

echo "${CYAN}--- Menulis konfigurasi pi ---${NC}"
install_pi_rules
install_pi_skills
install_pi_json models "$PI_MODELS_JSON" "$TMP_DIR/models.merged.json"
install_pi_json settings "$PI_SETTINGS_JSON" "$TMP_DIR/settings.merged.json"

if [ "$DRY_RUN" = 1 ]; then
    echo "${YELLOW}${S_WARN}${NC} Dry-run selesai — verify() tidak dijalankan karena tidak ada config yang dipasang."
    exit 0
fi

echo "${CYAN}--- Verify pi ---${NC}"
pi_verify "$PI_AGENT_DIR" "$PI_MODELS_JSON" "$PI_SETTINGS_JSON" \
    "$SERVER_URL" "$TOKEN" "$CONTRACT_MODEL_ID" "$PI_WHO" "$PI_BIN"
echo "${GREEN}${S_OK}${NC} pi terpasang dan seluruh verify() lulus."
