#!/usr/bin/env bash
#
# Uji adapter pi sebagai harness TAMBAHAN.
#
# Gateway dan pi di sini tiruan. Gateway memakai kontrak yang sengaja berbeda
# dari cadangan, dan pi tiruan tetap melakukan POST OpenAI-compatible sehingga
# uji memeriksa rantai adapter, bukan sekadar keberadaan nama berkas.
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
FAIL=0
GW_PID=""

ok()  { printf "  \033[32m✔\033[0m %s\n" "$*"; }
bad() { printf "  \033[31m✘\033[0m %s\n" "$*"; FAIL=1; }

cleanup() {
    [ -n "$GW_PID" ] && kill "$GW_PID" 2>/dev/null || true
    rm -rf "$T"
}
trap cleanup EXIT

TOK="ca_$(printf 'a%.0s' $(seq 48))"

cat > "$T/gateway.py" <<'PY'
import json
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

port_file, log_file = sys.argv[1:3]
contract = {
    "object": "list",
    "data": [{"id": "pi-contract-model", "object": "model",
               "context_window": 262144, "max_tokens": 24576}],
    "cooperagent": {
        "contract_version": 1,
        "model_id": "pi-contract-model",
        "context_window": 262144,
        "max_tokens": 24576,
        "compaction": {"threshold_percent": 75, "threshold_tokens": 196608},
        "context_source": "upstream",
        "endpoints": [],
        "upstreams": [],
    },
}

class Handler(BaseHTTPRequestHandler):
    def reply(self, code, obj):
        body = json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path.startswith("/api/auth/whoami"):
            with open(log_file, "a", encoding="utf-8") as f:
                f.write("whoami " + self.headers.get("Authorization", "") + "\n")
            return self.reply(200, {"name": "lee", "device": "pi-uji",
                                    "role": "dev", "who": "lee@pi-uji"})
        if self.path.startswith("/v1/models"):
            return self.reply(200, contract)
        return self.reply(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/v1/chat/completions":
            return self.reply(404, {"error": "not found"})
        length = int(self.headers.get("Content-Length", "0"))
        self.rfile.read(length)
        with open(log_file, "a", encoding="utf-8") as f:
            f.write("chat " + self.headers.get("Authorization", "") + "\n")
        payload = {
            "id": "chatcmpl-pi-test",
            "object": "chat.completion.chunk",
            "choices": [{"index": 0, "delta": {"content": "ok"},
                          "finish_reason": "stop"}],
        }
        body = ("data: " + json.dumps(payload) + "\n\n" +
                "data: [DONE]\n\n").encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass

server = HTTPServer(("127.0.0.1", 0), Handler)
with open(port_file, "w", encoding="utf-8") as f:
    f.write(str(server.server_port))
server.serve_forever()
PY

python3 "$T/gateway.py" "$T/port" "$T/gateway.log" &
GW_PID=$!
for _ in $(seq 50); do
    [ -s "$T/port" ] && break
    sleep 0.1
done
PORT="$(cat "$T/port" 2>/dev/null || true)"
if [ -z "$PORT" ]; then
    bad "gateway tiruan tidak mulai"
    exit 1
fi
GW="http://127.0.0.1:$PORT"

echo "Kontrak dan template pi:"
if [ -f "$REPO/scripts/lib/pi_models.sh" ] &&
   [ -f "$REPO/scripts/lib/pi_verify.sh" ] &&
   [ -f "$REPO/templates/pi-models.json" ] &&
   [ -f "$REPO/templates/pi-settings.json" ]; then
    . "$REPO/scripts/lib/contract.sh"
    . "$REPO/scripts/lib/pi_models.sh"
    . "$REPO/scripts/lib/pi_verify.sh"
    if fetch_contract "$GW" &&
       [ "$(pi_compaction_reserve)" = 65536 ] &&
       [ "$(pi_api_key 'lee@pi-uji' '')" = "" ] &&
       [ "$(pi_api_key 'lee@pi-uji' "$TOK")" = "$TOK" ]; then
        ok "reserve compaction dan kunci pi diturunkan dengan benar"
    else
        bad "reserve/kunci pi masih menebak atau memakai identitas lama"
    fi
else
    bad "pustaka/template pi belum tersedia"
    exit 1
fi

echo
echo "Merge JSON milik dev:"
mkdir -p "$T/home/.pi/agent" "$T/home/.cooper/skills" "$T/bin"
cat > "$T/home/.pi/agent/models.json" <<'JSON'
{
  "providers": {
    "anthropic-saya": {
      "baseUrl": "https://api.anthropic.com/v1",
      "api": "anthropic-messages",
      "apiKey": "sk-ant-KUNCI-BERBAYAR-DEV",
      "models": [{"id": "claude-dev"}]
    },
    "cooperagent": {
      "baseUrl": "http://198.51.100.20:8987/v1",
      "api": "openai-completions",
      "apiKey": "dev-lee@pi-uji",
      "customProviderSetting": "keep-me",
      "models": [{"id": "custom-pi-model", "name": "Model tambahan dev"}]
    }
  },
  "developerTopLevel": {"keep": true}
}
JSON
cat > "$T/home/.pi/agent/settings.json" <<'JSON'
{
  "theme": "dracula",
  "defaultProvider": "anthropic-saya",
  "defaultModel": "claude-dev",
  "compaction": {"enabled": false, "reserveTokens": 1234, "keepRecentTokens": 4321},
  "skills": ["~/skills-dev"]
}
JSON

cat > "$T/bin/pi" <<'PI'
#!/usr/bin/env bash
set -eu

: "${COOPER_PI_TEST_GATEWAY:?}"
: "${PI_CODING_AGENT_DIR:?}"
body='{"model":"pi-test","messages":[{"role":"user","content":"verification"}]}'
curl -fsS -X POST "$COOPER_PI_TEST_GATEWAY/v1/chat/completions" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${COOPER_PI_TEST_TOKEN}" \
  -d "$body" >/dev/null

# Marker kini DIBERI LABEL di berkas aturan; stub mengikuti kontrak yang sama
# seperti model sungguhan -- ia mengembalikan baris berlabel itu apa adanya.
marker="$(grep -m1 '^VERIFICATION SENTENCE: COOPER_PI_RULES_GATE_' "$PI_CODING_AGENT_DIR/AGENTS.md" || true)"
[ -n "$marker" ] && printf '%s\n' "$marker"
printf '%s\n' '{"type":"message_end","message":{"stopReason":"stop"}}'
if [ -n "${COOPER_PI_VERIFY_CHECKPOINT_FILE:-}" ]; then
  mkdir -p "$(dirname "$COOPER_PI_VERIFY_CHECKPOINT_FILE")"
  printf '%s\n' "${COOPER_PI_VERIFY_CHECKPOINT_MARKER}" > "$COOPER_PI_VERIFY_CHECKPOINT_FILE"
fi
PI
chmod +x "$T/bin/pi"

cat > "$T/home/.pi/agent/AGENTS.md" <<'RULES'
# Aturan pi milik dev yang akan diganti dengan aturan CooperAgent.
RULES

export HOME="$T/home"
export PATH="$T/bin:$PATH"
export COOPER_PI_TEST_GATEWAY="$GW"
export COOPER_PI_TEST_TOKEN="$TOK"
export COOPERAGENT_PI_BIN="$T/bin/pi"

if HOME="$HOME" PATH="$PATH" bash "$REPO/scripts/setup-pi.sh" \
       --endpoint "$GW/api/v1" --token "$TOK" --rules >"$T/setup.out" 2>&1; then
    ok "setup-pi selesai setelah verifikasi nyata"
else
    bad "setup-pi gagal: $(tail -n 8 "$T/setup.out")"
fi

if python3 - "$HOME/.pi/agent/models.json" "$HOME/.pi/agent/settings.json" "$GW" "$TOK" <<'PY'
import json
import sys

models_path, settings_path, gw, tok = sys.argv[1:]
models = json.load(open(models_path, encoding="utf-8"))
settings = json.load(open(settings_path, encoding="utf-8"))
provider = models["providers"]["cooperagent"]
model = next(m for m in provider["models"] if m["id"] == "pi-contract-model")
assert provider["baseUrl"] == gw + "/v1"
assert provider["api"] == "openai-completions"
assert provider["authHeader"] is True
assert provider["apiKey"] == tok
assert model["contextWindow"] == 262144
assert model["maxTokens"] == 24576
assert any(m["id"] == "custom-pi-model" for m in provider["models"])
assert models["providers"]["anthropic-saya"]["apiKey"] == "sk-ant-KUNCI-BERBAYAR-DEV"
assert models["developerTopLevel"]["keep"] is True
assert settings["theme"] == "dracula"
assert settings["defaultProvider"] == "anthropic-saya"
assert settings["defaultModel"] == "claude-dev"
assert settings["compaction"]["enabled"] is True
assert settings["compaction"]["reserveTokens"] == 65536
assert settings["compaction"]["keepRecentTokens"] == 4321
assert "~/skills-dev" in settings["skills"]
assert "~/.cooper/skills" in settings["skills"]
PY
then
    ok "models.json/settings.json di-merge; provider dan kunci dev utuh"
else
    bad "merge pi menghapus milik dev atau tidak mengikuti kontrak"
fi

cmp -s "$REPO/templates/agent-rules.md" "$HOME/.pi/agent/AGENTS.md" \
    && ok "aturan penuh dipasang di ~/.pi/agent/AGENTS.md" \
    || bad "aturan pi bukan salinan penuh templates/agent-rules.md"

if grep -q "chat Bearer $TOK" "$T/gateway.log" &&
   grep -q "whoami Bearer $TOK" "$T/gateway.log"; then
    ok "POST chat dan whoami memakai Authorization Bearer ca_..."
else
    bad "pi tidak melewati POST/chat atau whoami dengan token CooperAgent"
fi

grep -q 'COOPER_PI_RULES_GATE_' "$T/setup.out" \
    && ok "verify() menemukan marker dari AGENTS.md global" \
    || bad "verify() tidak membuktikan pi membaca AGENTS.md"
grep -q 'checkpoint' "$T/setup.out" \
    && ok "verify() melaporkan task-boundary checkpoint" \
    || bad "verify() tidak melaporkan checkpoint"

echo
echo "Paritas dan batas default:"
grep -q '3) Pi' "$REPO/setup.sh" && grep -q '3) Pi' "$REPO/setup.ps1" \
    && ok "pi ditambahkan sebagai pilihan baru" \
    || bad "pi tidak ditambahkan sebagai pilihan baru di kedua installer"

# Baris menu harus dicetak SEBELUM prompt membaca jawaban.
#
# Keberadaan string saja tidak cukup: pada setup.ps1, `Write-Host "  3) Pi ..."`
# sempat berada SESUDAH `Read-Host`. Read-Host memblokir, jadi pilihan 5 baru
# muncul setelah dev menjawab -- di layar, pilihan itu tidak ada. Uji lama lolos
# karena hanya memeriksa stringnya ada di berkas, bukan letaknya.
menu_before_prompt() { # berkas, pola menu, pola prompt
    local m p
    m="$(grep -n "$2" "$1" | head -1 | cut -d: -f1)"
    p="$(grep -n "$3" "$1" | head -1 | cut -d: -f1)"
    [ -n "$m" ] && [ -n "$p" ] && [ "$m" -lt "$p" ]
}
menu_before_prompt "$REPO/setup.sh"  '3) Pi' 'Pilihan \[1/2/3/4,' \
    && ok "setup.sh: menu pilihan pi dicetak sebelum prompt" \
    || bad "setup.sh: pilihan pi tidak terlihat sebelum dev diminta menjawab"
menu_before_prompt "$REPO/setup.ps1" '3) Pi' 'Pilihan \[1/2/3/4,' \
    && ok "setup.ps1: menu pilihan pi dicetak sebelum prompt" \
    || bad "setup.ps1: pilihan pi tidak terlihat sebelum dev diminta menjawab"
grep -q 'default: 1' "$REPO/setup.sh" && grep -q 'default: 1' "$REPO/setup.ps1" \
    && ok "default lama tetap pilihan 1" \
    || bad "default installer berubah"
# Header "sudah terpasang" harus MENYEBUT pi.
#
# Di kedua installer, pi sempat ditambahkan ke daftar harness SESUDAH barisnya
# dicetak, sehingga header selamanya berbunyi "Grok Build, Oh My Pi (omp)" pada
# mesin yang jelas-jelas punya ketiganya.
menu_before_prompt "$REPO/setup.sh"  'Pi Agent (pi)' 'harness   :' \
    && ok "setup.sh: pi masuk daftar harness sebelum dicetak" \
    || bad "setup.sh: pi ditambahkan sesudah header dicetak"
menu_before_prompt "$REPO/setup.ps1" 'Pi Agent (pi)' 'harness   :' \
    && ok "setup.ps1: pi masuk daftar harness sebelum dicetak" \
    || bad "setup.ps1: pi ditambahkan sesudah header dicetak"

# Pilihan "Perbarui parameter" harus menyegarkan pi yang SUDAH terpasang,
# apa pun harness lain yang ada -- syarat lama menuntut Grok/omp TIDAK ada.
# Pilihan "Perbarui parameter" harus menyegarkan pi yang SUDAH terpasang, apa
# pun harness lain yang ada. Syarat lamanya menuntut Grok/omp TIDAK ada, jadi
# dev dengan ketiganya tidak pernah melihat pi-nya disegarkan.
#
# Satu kemunculan syarat sempit masih SAH: cabang 5 (lepas aturan) memakainya,
# dan itu cacat terpisah yang belum diputuskan. Lebih dari satu berarti jalur
# "perbarui parameter" ikut memakainya lagi.
# Baris komentar dibuang: penjelasan cacat ini di setup.sh MENGUTIP syarat
# lamanya, dan pemeriksa yang menghitung dokumentasinya sendiri akan segera
# dimatikan orang. Jebakan yang sama sudah kena dua kali hari ini.
sempit=$(grep -v '^[[:space:]]*#' "$REPO/setup.sh" |
         grep -c 'installed_pi && ! installed_grok && ! installed_omp')
if [ "$sempit" -le 1 ] && grep -q 'if installed_pi; then' "$REPO/setup.sh"; then
    ok "setup.sh: perbarui parameter menyegarkan pi tanpa syarat harness lain"
else
    bad "setup.sh: perbarui parameter masih melewati pi bila Grok/omp ada (syarat sempit: $sempit)"
fi

grep -q 'PiModels.ps1' "$REPO/scripts/setup-pi.ps1" &&
grep -q 'models.json' "$REPO/scripts/setup-pi.ps1" \
    && ok "jalur PowerShell pi tersedia" \
    || bad "jalur PowerShell pi belum paralel"

echo
if [ "$FAIL" -eq 0 ]; then
    printf "  \033[32mLULUS\033[0m — adapter pi mengikuti kontrak dan aturan CooperAgent\n"
else
    printf "  \033[31mGAGAL\033[0m\n"
fi
exit "$FAIL"
