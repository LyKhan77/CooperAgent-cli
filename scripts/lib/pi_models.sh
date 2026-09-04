# Pembantu konfigurasi pi — satu-satunya penulis models.json/settings.json.
#
# JSON milik dev di-merge oleh pi_json.mjs. Shell ini hanya menangani kontrak,
# endpoint, token, dan backup; ia tidak boleh menimpa provider atau setting lain.

PI_LIB_DIR="${PI_LIB_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}"
PI_JSON_HELPER="${PI_JSON_HELPER:-$PI_LIB_DIR/pi_json.mjs}"

pi_api_key() { # $1 = identitas; $2 = token (boleh kosong)
    case "${2:-}" in
        ca_*) printf '%s' "$2" ;;
        '')   case "${1:-}" in ca_*) printf '%s' "$1" ;; *) printf '' ;; esac ;;
        *)    printf '' ;;
    esac
}

pi_compaction_reserve() {
    contract_compaction_reserve
}

_pi_sed_escape() {
    printf '%s' "$1" | sed 's/[&|\\]/\\&/g'
}

pi_render_template() { # $1 = template; $2 = gateway base; $3 = api key
    local tpl="$1" gateway="$2" key="$3" eg ek
    eg="$(_pi_sed_escape "$gateway")"
    ek="$(_pi_sed_escape "$key")"
    contract_render "$tpl" \
        | sed -e "s|__GATEWAY__|$eg|g" -e "s|__API_KEY__|$ek|g"
}

pi_merge_json() { # $1 = models|settings; $2 = existing; $3 = rendered template; $4 = output
    local kind="$1" existing="$2" rendered="$3" output="$4" command
    [ -f "$PI_JSON_HELPER" ] || {
        printf 'Helper JSON pi tidak ditemukan: %s\n' "$PI_JSON_HELPER" >&2
        return 1
    }
    command="merge-$kind"
    command -v node >/dev/null 2>&1 || {
        printf 'Node.js diperlukan untuk merge konfigurasi pi: %s\n' "$output" >&2
        return 1
    }
    node "$PI_JSON_HELPER" "$command" "$existing" "$rendered" > "$output"
}

pi_json_get() { # $1 = models|settings; $2 = file; $3 = field
    [ -f "$PI_JSON_HELPER" ] || return 1
    command -v node >/dev/null 2>&1 || return 1
    node "$PI_JSON_HELPER" get "$1" "$2" "$3"
}

pi_provider_present() {
    [ "$(pi_json_get models "$1" present 2>/dev/null || true)" = yes ]
}

pi_api_key_of() {
    local value
    value="$(pi_json_get models "$1" apiKey 2>/dev/null || true)"
    case "$value" in ca_*) printf '%s' "$value" ;; *) printf '' ;; esac
}

pi_gateway_of() {
    local value
    value="$(pi_json_get models "$1" gateway 2>/dev/null || true)"
    value="${value%/v1}"
    value="${value%/api}"
    printf '%s' "$value"
}
