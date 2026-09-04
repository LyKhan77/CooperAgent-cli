# Verifikasi hasil pemasangan pi.
#
# Panggilan model dijalankan pada direktori dan agent dir sementara. Marker
# aturan ditambahkan hanya ke salinan sementara, sehingga uji tidak mengubah
# AGENTS.md milik dev. Panggilan kedua memaksa satu task boundary yang menulis
# checkpoint ke proyek sementara dan diverifikasi dari filesystem.

# Batas waktu tiap panggilan model di dalam verify(). Bisa ditimpa lewat
# lingkungan bila mesin inferensi sedang padat.
PI_VERIFY_TIMEOUT="${PI_VERIFY_TIMEOUT:-240}"

# Saat gagal, direktori sementara berisi salinan config, aturan bertanda, dan
# keluaran mentah pi. Menghapusnya berarti setiap diagnosis harus mengulang
# panggilan model dari nol -- mahal, dan bergantung pada beban mesin saat itu.
# Setel COOPER_PI_KEEP_TMP=1 untuk menyimpannya.
pi_verify_cleanup() { # $1 = tmp dir
    if [ "${COOPER_PI_KEEP_TMP:-0}" = 1 ]; then
        echo "      bukti kegagalan disimpan: $1" >&2
    else
        rm -rf "$1"
    fi
}

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

    # ── Verifikasi KONFIGURASI: murah, tanpa memanggil model ────────────────
    #
    # Inilah yang dijalankan secara baku. Ia menjawab pertanyaan yang memang
    # milik pemasang -- "apakah parameter dan aturan sudah sesuai kontrak?" --
    # dan menjawabnya dalam hitungan milidetik.
    local want_base got_base got_key want_reserve got_reserve
    # `pi_gateway_of` sudah memangkas /v1 dan /api, jadi keduanya dibandingkan
    # sebagai ASAL (origin) -- bukan sebagai URL lengkap.
    want_base="$(cooper_gateway_base "$gateway")"
    got_base="$(pi_gateway_of "$models" 2>/dev/null || true)"
    [ "$got_base" = "$want_base" ] || {
        echo "  [x] baseUrl pi menunjuk gateway lain: '$got_base', seharusnya '$want_base'" >&2
        return 1
    }
    got_key="$(pi_api_key_of "$models" 2>/dev/null || true)"
    [ "$got_key" = "$token" ] || {
        echo "  [x] apiKey pi bukan token yang baru diverifikasi ke gateway." >&2
        return 1
    }
    case "$got_key" in
        ca_*) ;;
        *) echo "  [x] apiKey pi bukan kredensial 'ca_...'." >&2; return 1 ;;
    esac
    want_reserve="$(pi_compaction_reserve 2>/dev/null || true)"
    got_reserve="$(pi_json_get settings "$settings" reserveTokens 2>/dev/null || true)"
    if [ -n "$want_reserve" ] && [ "$got_reserve" != "$want_reserve" ]; then
        echo "  [x] reserveTokens pi $got_reserve, seharusnya $want_reserve (turunan kontrak)." >&2
        return 1
    fi
    echo "  [v] konfigurasi pi sesuai kontrak: baseUrl, token, compaction $got_reserve, model $model."
    # Aturan yang BERBEDA adalah peringatan, bukan kegagalan.
    #
    # Installer sengaja mempertahankan AGENTS.md yang sudah disunting dev;
    # menggagalkan verify karenanya berarti menghukum dev atas keputusan yang
    # kita ambil sendiri untuk melindunginya -- dan membuat pemasangan mustahil
    # diselesaikan olehnya. Yang WAJIB ada hanyalah berkasnya, karena pi memuat
    # aturan global dari sana.
    if [ -f "$TPL_DIR/agent-rules.md" ] && cmp -s "$TPL_DIR/agent-rules.md" "$agent_dir/AGENTS.md"; then
        echo "  [v] aturan agent global sesuai templates/agent-rules.md."
    else
        echo "  [!] aturan agent global adalah milik dev, bukan template CooperAgent."
        echo "      Dipertahankan apa adanya; jalankan dengan --rules bila ingin menggantinya."
    fi
    echo "  [v] identitas gateway untuk leaderboard: $who"

    # ── Verifikasi MENDALAM: menjalankan pi sungguhan ───────────────────────
    #
    # Tidak dijalankan secara baku, dan itu keputusan sadar. Ia memanggil model
    # DUA kali pada mesin yang disetel --reasoning-effort xhigh dengan
    # --reasoning-budget 6144, jadi ongkosnya menit -- bukan detik -- dan naik
    # tiga sampai lima kali lipat saat mesin sedang melayani dev lain.
    #
    # Nilainya nyata: empat cacat khusus Windows pada 4 September 2026 ketahuan
    # justru karena jalur ini MENJALANKAN sesuatu alih-alih membaca berkas. Ia
    # dipertahankan sebagai gerbang yang dipanggil sengaja, bukan pajak yang
    # dibayar setiap pemasangan.
    if [ "${COOPERAGENT_PI_VERIFY_DEEP:-0}" != 1 ]; then
        echo "  [-] verifikasi mendalam dilewati (setel COOPERAGENT_PI_VERIFY_DEEP=1 untuk menjalankannya)."
        return 0
    fi

    tmp="$(mktemp -d "${TMPDIR:-/tmp}/cooperagent-pi-verify.XXXXXX")" || return 1
    mkdir -p "$tmp/agent" "$tmp/project"
    if ! cp "$models" "$tmp/agent/models.json" ||
       ! cp "$settings" "$tmp/agent/settings.json" ||
       ! cp "$agent_dir/AGENTS.md" "$tmp/agent/AGENTS.md"; then
        rm -rf "$tmp"
        echo "  [x] gagal menyiapkan salinan sementara verify()" >&2
        return 1
    fi

    # Marker DIBERI LABEL, bukan token telanjang.
    #
    # Sebelumnya ia ditempel sebagai baris acak tanpa konteks, lalu model
    # diminta "the exact verification sentence". Model tidak punya cara
    # mengenali baris mana yang dimaksud, jadi ia berkelana: terukur 4 giliran
    # dan 3 tool call -- membaca ~/.grok/AGENTS.md dan ~/.omp/agent/AGENTS.md
    # lebih dulu -- sebelum akhirnya meng-grep berkas yang benar. Jawabannya
    # akhirnya betul, tetapi panjangnya membuat gerbang ini rapuh: di bawah
    # beban, panggilan sepanjang itu putus sebelum selesai dan kegagalannya
    # terbaca seolah "aturan tidak dibaca".
    marker="COOPER_PI_RULES_GATE_$(date +%s)-$RANDOM"
    printf '\n## Verifikasi pemasangan\n\nVERIFICATION SENTENCE: %s\n' \
        "$marker" >> "$tmp/agent/AGENTS.md"
    checkpoint_marker="COOPER_PI_CHECKPOINT_GATE_$(date +%s)-$RANDOM"
    slug="pi-verify-$RANDOM"
    checkpoint_file="$tmp/project/.cooper/context/$slug.md"

    if output="$(
        cd "$tmp/project" || exit 1
        env PI_CODING_AGENT_DIR="$tmp/agent" PI_TELEMETRY=0 \
            COOPER_PI_VERIFY_CHECKPOINT_FILE="$checkpoint_file" \
            COOPER_PI_VERIFY_CHECKPOINT_MARKER="$checkpoint_marker" \
            timeout "$PI_VERIFY_TIMEOUT" \
            "$pi_bin" --provider cooperagent --model "$model" --mode json \
            --no-session --print --no-extensions --no-prompt-templates --no-themes \
            'The global work rules contain one line that starts with "VERIFICATION SENTENCE:". Reply with that entire line verbatim and nothing else. Do not use any tools.'
    )"; then
        rc=0
    else
        rc=$?
    fi
    # Tiga sebab kegagalan yang berbeda dilaporkan terpisah. Satu pesan gabungan
    # untuk ketiganya membuat gerbang ini mahal didiagnosis: yang terbaca hanya
    # "gagal", padahal mesin sibuk, kontrak putus, dan aturan tak terbaca
    # menuntut tindakan yang sama sekali berbeda.
    # Keluaran ditulis ke berkas lebih dulu, lalu di-grep dari berkas.
    #
    # `printf '%s' "$output" | grep -q PATTERN` TIDAK aman di sini: grep keluar
    # begitu cocok dan menutup pipa, printf kena SIGPIPE dan keluar 141, dan
    # `set -o pipefail` di setup-pi.sh menjadikan 141 status pipeline. Akibatnya
    # assertion gagal PERSIS KETIKA polanya ditemukan, dan hanya bila keluaran
    # cukup besar sehingga printf belum selesai menulis -- kegagalan yang
    # tampak acak dan berpindah-pindah titik. Terukur 4 September 2026 pada
    # keluaran 34 KB. Jebakan yang sama sudah tercatat di repo server.
    printf '%s' "$output" > "$tmp/call1.jsonl" 2>/dev/null || true
    if [ "$rc" -eq 124 ]; then
        pi_verify_cleanup "$tmp"
        echo "  [x] verify() habis waktu setelah ${PI_VERIFY_TIMEOUT}s -- mesin inferensi kemungkinan sedang penuh." >&2
        echo "      Ini BUKAN bukti pemasangan salah. Ulangi saat mesin lebih lengang," >&2
        echo "      atau naikkan PI_VERIFY_TIMEOUT." >&2
        return 1
    fi
    if [ "$rc" -ne 0 ]; then
        pi_verify_cleanup "$tmp"
        echo "  [x] pi keluar dengan kode $rc -- panggilan ke gateway tidak selesai." >&2
        return 1
    fi
    if ! grep -Eq '"type"[[:space:]]*:[[:space:]]*"message_end"' "$tmp/call1.jsonl" ||
       ! grep -Eq '"stopReason"[[:space:]]*:[[:space:]]*"stop"' "$tmp/call1.jsonl"; then
        pi_verify_cleanup "$tmp"
        echo "  [x] pi tidak menyelesaikan satu pesan pun (message_end/stop tidak muncul)." >&2
        return 1
    fi
    if ! grep -Fq "$marker" "$tmp/call1.jsonl"; then
        pi_verify_cleanup "$tmp"
        echo "  [x] pi TIDAK membaca aturan kerja global: marker di ~/.pi/agent/AGENTS.md tidak muncul." >&2
        echo "      Gateway dan kredensial sendiri sudah terbukti bekerja pada langkah ini." >&2
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
            timeout "$PI_VERIFY_TIMEOUT" \
            "$pi_bin" --provider cooperagent --model "$model" --mode json \
            --no-session --print --no-extensions --no-prompt-templates --no-themes \
            "Read the global work rules. This is a disposable project task boundary. Create .cooper/context/$slug.md using a temporary file and mv. Include the exact line $checkpoint_marker and do not write elsewhere. Reply checkpoint-written."
    )"; then
        rc=0
    else
        rc=$?
    fi
    printf '%s' "$output" > "$tmp/call2.jsonl" 2>/dev/null || true
    if [ "$rc" -ne 0 ] ||
       ! grep -Eq '"type"[[:space:]]*:[[:space:]]*"message_end"' "$tmp/call2.jsonl" ||
       ! grep -Eq '"stopReason"[[:space:]]*:[[:space:]]*"stop"' "$tmp/call2.jsonl" ||
       [ ! -s "$checkpoint_file" ] || ! grep -Fq "$checkpoint_marker" "$checkpoint_file"; then
        pi_verify_cleanup "$tmp"
        if [ "$rc" -eq 124 ]; then
            echo "  [x] verify() checkpoint habis waktu setelah ${PI_VERIFY_TIMEOUT}s -- mesin kemungkinan penuh." >&2
        else
            echo "  [x] task-boundary tidak menghasilkan .cooper/context checkpoint." >&2
        fi
        return 1
    fi
    echo "  [v] checkpoint task-boundary menghasilkan .cooper/context/$slug.md (marker cocok: $checkpoint_marker)."
    rm -rf "$tmp"
}
