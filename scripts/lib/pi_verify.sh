# Verifikasi hasil pemasangan pi.
#
# Panggilan model dijalankan pada direktori dan agent dir sementara. Marker
# aturan ditambahkan hanya ke salinan sementara, sehingga uji tidak mengubah
# AGENTS.md milik dev. Panggilan kedua memaksa satu task boundary yang menulis
# checkpoint ke proyek sementara dan diverifikasi dari filesystem.

pi_verify() { # agent_dir models settings gateway token model who [pi_bin]
    local agent_dir="$1" models="$2" settings="$3" gateway="$4" token="$5"
    local model="$6" who="$7" pi_bin="${8:-${COOPERAGENT_PI_BIN:-}}"
    local tmp marker checkpoint_marker slug output rc checkpoint_file

    [ -n "$pi_bin" ] || pi_bin="$(command -v pi 2>/dev/null || true)"
    if [ -z "$pi_bin" ] || [ ! -x "$pi_bin" ]; then
        echo "  [x] pi tidak ditemukan — verify() tidak dijalankan." >&2
        return 1
    fi
    case "$who" in
        *@*) ;;
        *) echo "  [x] identitas gateway tidak berbentuk devName@device: ${who:-kosong}" >&2; return 1 ;;
    esac
    case "$who" in
        dev-*) echo "  [x] identitas lama dev-... ditolak sebagai identitas pi." >&2; return 1 ;;
    esac
    [ -f "$models" ] && [ -f "$settings" ] && [ -f "$agent_dir/AGENTS.md" ] || {
        echo "  [x] config pi atau AGENTS.md tidak lengkap — verify() berhenti." >&2
        return 1
    }
    [ "$(pi_json_get settings "$settings" compactionEnabled 2>/dev/null || true)" = true ] || {
        echo "  [x] compaction pi tidak aktif." >&2
        return 1
    }
    [ -n "$(pi_json_get settings "$settings" reserveTokens 2>/dev/null || true)" ] || {
        echo "  [x] reserveTokens pi tidak terbaca." >&2
        return 1
    }

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/cooperagent-pi-verify.XXXXXX")" || return 1
    mkdir -p "$tmp/agent" "$tmp/project"
    if ! cp "$models" "$tmp/agent/models.json" ||
       ! cp "$settings" "$tmp/agent/settings.json" ||
       ! cp "$agent_dir/AGENTS.md" "$tmp/agent/AGENTS.md"; then
        rm -rf "$tmp"
        echo "  [x] gagal menyiapkan salinan sementara verify()" >&2
        return 1
    fi

    marker="COOPER_PI_RULES_GATE_$(date +%s)-$RANDOM"
    printf '\n%s\n' "$marker" >> "$tmp/agent/AGENTS.md"
    checkpoint_marker="COOPER_PI_CHECKPOINT_GATE_$(date +%s)-$RANDOM"
    slug="pi-verify-$RANDOM"
    checkpoint_file="$tmp/project/.cooper/context/$slug.md"

    if output="$(
        cd "$tmp/project" || exit 1
        env PI_CODING_AGENT_DIR="$tmp/agent" PI_TELEMETRY=0 \
            COOPER_PI_VERIFY_CHECKPOINT_FILE="$checkpoint_file" \
            COOPER_PI_VERIFY_CHECKPOINT_MARKER="$checkpoint_marker" \
            "$pi_bin" --provider cooperagent --model "$model" --mode json \
            --no-session --print --no-extensions --no-prompt-templates --no-themes \
            'Read the global work rules. Return only the exact verification sentence appended to that global AGENTS.md.'
    )"; then
        rc=0
    else
        rc=$?
    fi
    if [ "$rc" -ne 0 ] ||
       ! printf '%s' "$output" | grep -Eq '"type"[[:space:]]*:[[:space:]]*"message_end"' ||
       ! printf '%s' "$output" | grep -Eq '"stopReason"[[:space:]]*:[[:space:]]*"stop"' ||
       ! printf '%s' "$output" | grep -Fq "$marker"; then
        rm -rf "$tmp"
        echo "  [x] POST /v1/chat/completions lewat pi tidak terverifikasi 200 atau marker AGENTS.md tidak muncul." >&2
        return 1
    fi
    echo "  [v] POST /v1/chat/completions lewat pi selesai (message_end/stop; HTTP 200)."
    echo "  [v] identitas gateway untuk leaderboard: $who"
    echo "  [v] pi membaca AGENTS.md global (marker sementara cocok: $marker)."

    if output="$(
        cd "$tmp/project" || exit 1
        env PI_CODING_AGENT_DIR="$tmp/agent" PI_TELEMETRY=0 \
            COOPER_PI_VERIFY_CHECKPOINT_FILE="$checkpoint_file" \
            COOPER_PI_VERIFY_CHECKPOINT_MARKER="$checkpoint_marker" \
            "$pi_bin" --provider cooperagent --model "$model" --mode json \
            --no-session --print --no-extensions --no-prompt-templates --no-themes \
            "Read the global work rules. This is a disposable project task boundary. Create .cooper/context/$slug.md using a temporary file and mv. Include the exact line $checkpoint_marker and do not write elsewhere. Reply checkpoint-written."
    )"; then
        rc=0
    else
        rc=$?
    fi
    if [ "$rc" -ne 0 ] ||
       ! printf '%s' "$output" | grep -Eq '"type"[[:space:]]*:[[:space:]]*"message_end"' ||
       ! printf '%s' "$output" | grep -Eq '"stopReason"[[:space:]]*:[[:space:]]*"stop"' ||
       [ ! -s "$checkpoint_file" ] || ! grep -Fq "$checkpoint_marker" "$checkpoint_file"; then
        rm -rf "$tmp"
        echo "  [x] task-boundary tidak menghasilkan .cooper/context checkpoint." >&2
        return 1
    fi
    echo "  [v] checkpoint task-boundary menghasilkan .cooper/context/$slug.md (marker cocok: $checkpoint_marker)."
    rm -rf "$tmp"
}
