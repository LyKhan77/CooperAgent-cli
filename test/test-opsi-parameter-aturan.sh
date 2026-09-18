#!/usr/bin/env bash
# Lingkup pilihan "Perbarui parameter" dan "Aturan agent".
#
# KENAPA ADA. Keduanya dilaporkan menyentuh lebih banyak daripada yang diminta:
#
#   Pilihan 1 dulu jatuh ke jalur onboarding penuh, jadi menyegarkan jendela
#   konteks juga memasang ulang aturan agent dan skill. Dev yang sudah melepas
#   aturan mendapatkannya kembali tanpa diminta.
#
#   Pilihan 5 menyentuh KETIGA harness tanpa bertanya, padahal aturan adalah
#   pendapat tentang cara bekerja -- memaksakannya serempak bertentangan dengan
#   alasan ia dibuat opsional.
#
# Yang diuji di sini adalah APA YANG TERJADI PADA BERKAS, bukan apa yang dicetak.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok(){ printf "  ok   %s\n" "$1"; pass=$((pass+1)); }
no(){ printf "  GAGAL %s — %s\n" "$1" "${2:-}"; fail=$((fail+1)); }

T="$(mktemp -d)"; trap 'rm -rf "$T"; kill ${GW_PID:-0} 2>/dev/null' EXIT
PORT=8998
sed -n '/^cat > "\$T\/gw.py" <<.PY.$/,/^PY$/p' "$ROOT/test/test-credential-gate.sh" | sed '1d;$d' > "$T/gw.py"
python3 "$T/gw.py" "$PORT" & GW_PID=$!
for _ in $(seq 60); do curl -sf -o /dev/null "http://127.0.0.1:$PORT/v1/models" && break; sleep 0.1; done
VALID="ca_$(printf 'a%.0s' $(seq 48))"

siapkan() { # $1 = HOME
    local H="$1"
    mkdir -p "$H/.grok/skills/punya-dev" "$H/.omp/agent" "$H/.pi/agent/extensions"
    printf '[cli]\nauto_update = false\n\n[model.cooper-agent]\nmodel = "model-uji"\nbase_url = "http://127.0.0.1:%s/api/v1"\napi_key = "%s"\ncontext_window = 1\n\n[ui]\ntheme = "dracula"\n\n[mcp_servers.punya-dev]\ncommand = "npx"\n' "$PORT" "$VALID" > "$H/.grok/config.toml"
    printf 'providers:\n  cooper-agent:\n    baseUrl: http://127.0.0.1:%s/v1\n    apiKey: %s\n    models:\n      - id: lama\n        contextWindow: 1\n  ollama-dev:\n    baseUrl: http://localhost:11434/v1\n' "$PORT" "$VALID" > "$H/.omp/agent/models.yml"
    printf '{"providers":{"cooper-agent":{"baseUrl":"http://127.0.0.1:%s/v1","apiKey":"%s","models":[{"id":"lama","contextWindow":1}]}}}' "$PORT" "$VALID" > "$H/.pi/agent/models.json"
    printf '{"defaultProvider":"cooper-agent","compaction":{"enabled":true,"reserveTokens":1},"mcpServers":{"punya-dev":{"command":"npx"}},"extensions":["~/.pi/agent/extensions/dev.ts"]}' > "$H/.pi/agent/settings.json"
    echo dev > "$H/.grok/skills/punya-dev/SKILL.md"
    touch "$H/.pi/agent/extensions/dev.ts"
}

# ── 1. perbarui parameter: HANYA parameter ───────────────────────────────────
echo "pilihan 1 — perbarui parameter:"
H1="$T/h1"; siapkan "$H1"
printf '1\n' | HOME="$H1" COOPERAGENT_PI_BIN=/bin/true timeout 120 bash "$ROOT/setup.sh" > "$T/o1.out" 2>&1
rc=$?
[ "$rc" = 0 ] && ok "selesai tanpa galat" || no "selesai" "rc=$rc: $(tail -3 "$T/o1.out")"

# Kontrak gateway tiruan: context 262144. Ketiganya harus sampai di sana.
g="$(grep -m1 context_window "$H1/.grok/config.toml" | tr -dc '0-9')"
o="$(grep -m1 contextWindow "$H1/.omp/agent/models.yml" | tr -dc '0-9')"
p="$(python3 -c "import json;print(json.load(open('$H1/.pi/agent/models.json'))['providers']['cooper-agent']['models'][0].get('contextWindow',''))" 2>/dev/null)"
if [ "$g" = 262144 ] && [ "$o" = 262144 ] && [ "$p" = 262144 ]; then
    ok "ketiga harness konsisten di angka kontrak yang sama"
else
    no "ketiga harness konsisten" "grok=$g omp=$o pi=$p"
fi

# Yang TIDAK boleh tersentuh.
grep -q dracula "$H1/.grok/config.toml" && grep -q 'mcp_servers.punya-dev' "$H1/.grok/config.toml" \
    && ok "[ui] dan server MCP Grok utuh" || no "[ui]/MCP Grok" "hilang"
grep -q ollama-dev "$H1/.omp/agent/models.yml" \
    && ok "provider pihak ketiga omp utuh" || no "provider omp dev" "hilang"
python3 - "$H1" <<'PY' && ok "server MCP dan extension pi utuh" || no "MCP/extension pi" "hilang"
import json, sys
s = json.load(open(sys.argv[1] + "/.pi/agent/settings.json"))
sys.exit(0 if "punya-dev" in s.get("mcpServers", {}) and s.get("extensions") else 1)
PY
[ -f "$H1/.grok/skills/punya-dev/SKILL.md" ] && ok "skill milik dev utuh" || no "skill dev" "hilang"
[ -d "$H1/.cooper/skills" ] \
    && no "skill CooperAgent tidak dipasang" "ia dipasang — pilihan ini menyegarkan, bukan memasang" \
    || ok "skill CooperAgent tidak dipasang"
[ -f "$H1/.pi/agent/AGENTS.md" ] \
    && no "aturan agent tidak dipasang" "aturan dipasang tanpa diminta" \
    || ok "aturan agent tidak dipasang"

# ── 2. aturan agent: hanya harness yang dipilih ──────────────────────────────
echo "pilihan 5 — aturan agent per harness:"
H2="$T/h2"; siapkan "$H2"
for d in "$H2/.grok/AGENTS.md" "$H2/.omp/agent/AGENTS.md" "$H2/.pi/agent/AGENTS.md"; do
    cp "$ROOT/templates/agent-rules.md" "$d"
done
# Pilihan "1" = Grok saja (urutannya grok, omp, pi).
printf '5\n1\n' | HOME="$H2" timeout 120 bash "$ROOT/setup.sh" > "$T/o5.out" 2>&1
[ -f "$H2/.grok/AGENTS.md" ] \
    && no "aturan Grok dilepas" "masih ada" || ok "aturan Grok dilepas"
[ -f "$H2/.omp/agent/AGENTS.md" ] \
    && ok "aturan omp TIDAK ikut dilepas" || no "aturan omp utuh" "ikut terlepas"
[ -f "$H2/.pi/agent/AGENTS.md" ] \
    && ok "aturan pi TIDAK ikut dilepas" || no "aturan pi utuh" "ikut terlepas"
# Skill tidak boleh ikut terbawa: aturan adalah pendapat, skill adalah perkakas.
[ -f "$H2/.grok/skills/punya-dev/SKILL.md" ] \
    && ok "skill dev tidak terbawa saat aturan dilepas" || no "skill dev" "hilang"

echo
echo "lulus $pass, gagal $fail"
[ "$fail" -eq 0 ]
