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
    "cooper-agent": {
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
  "skills": ["~/skills-dev"],
  "mcpServers": {"punya-dev": {"command": "npx", "args": ["-y", "server-dev"]}},
  "extensions": ["~/.pi/agent/extensions/milik-dev.ts"],
  "keybindings": {"submit": "ctrl+enter"}
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
# Verifikasi mendalam TIDAK berjalan secara baku (ia memanggil model dua kali).
# Di sini pi adalah stub, jadi menjalankannya gratis -- dan jalur itu tetap
# harus terjaga uji, bukan menjadi kode yang tidak pernah dieksekusi.
export COOPERAGENT_PI_VERIFY_DEEP=1

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
provider = models["providers"]["cooper-agent"]
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
# Yang TIDAK dikelola CooperAgent tidak boleh tersentuh sama sekali: server MCP,
# extension, dan keybinding milik dev hidup di berkas yang sama.
assert settings["mcpServers"]["punya-dev"]["command"] == "npx"
assert settings["mcpServers"]["punya-dev"]["args"] == ["-y", "server-dev"]
assert settings["extensions"] == ["~/.pi/agent/extensions/milik-dev.ts"]
assert settings["keybindings"]["submit"] == "ctrl+enter"
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
# Syarat sempit tidak boleh tersisa sama sekali: baik "perbarui parameter"
# maupun "lepas aturan agent" harus memperlakukan pi seperti harness lain.
# Baris komentar dibuang: penjelasan cacat ini di setup.sh MENGUTIP syarat
# lamanya, dan pemeriksa yang menghitung dokumentasinya sendiri akan segera
# dimatikan orang. Jebakan yang sama sudah kena dua kali hari ini.
sempit=$(grep -v '^[[:space:]]*#' "$REPO/setup.sh" |
         grep -c 'installed_pi && ! installed_grok && ! installed_omp')
if [ "$sempit" -eq 0 ] && grep -q 'if installed_pi; then' "$REPO/setup.sh"; then
    ok "setup.sh: perbarui parameter & lepas aturan menyentuh pi tanpa syarat harness lain"
else
    bad "setup.sh: masih ada jalur yang melewati pi bila Grok/omp ada (syarat sempit: $sempit)"
fi

# Non-ASCII di BARIS KODE .ps1 dilarang.
#
# Windows PowerShell 5.1 membaca berkas tanpa BOM memakai code page ANSI. Em
# dash UTF-8 (e2 80 94) terbaca sebagai tiga karakter, dan byte 0x94 menjadi
# U+201D -- karakter yang PowerShell TERIMA sebagai penutup string. Sebuah em
# dash di dalam string kode karena itu menutup string di tengah baris, dan sisa
# berkas berantakan. Terjadi 4 September 2026 di test/Test-PiModels.ps1 dan
# memakan tiga putaran CI.
#
# Di dalam KOMENTAR ia tidak berbahaya -- `#` berlaku sampai akhir baris -- dan
# seluruh .ps1 lain di repo ini memang hanya memakainya di sana.
if ps_kode_non_ascii="$(python3 - "$REPO" <<'PYEOF'
import glob, os, sys
repo = sys.argv[1]
buruk = []
for f in sorted(glob.glob(os.path.join(repo, "**", "*.ps1"), recursive=True)):
    if os.sep + ".git" + os.sep in f:
        continue
    for n, l in enumerate(open(f, encoding="utf-8"), 1):
        if l.lstrip().startswith("#"):
            continue
        if any(ord(c) > 127 for c in l):
            buruk.append(f"{os.path.relpath(f, repo)}:{n}")
print(" ".join(buruk))
PYEOF
)" && [ -z "$ps_kode_non_ascii" ]; then
    ok "tidak ada non-ASCII di baris kode .ps1"
else
    bad "non-ASCII di baris kode .ps1: $ps_kode_non_ascii"
fi

# Lint jalur PowerShell — dijalankan DI SINI, bukan di Test-PiModels.ps1.
#
# Ia membaca berkas sebagai teks dan tidak butuh PowerShell sama sekali.
# Versi pertamanya ditaruh di uji PowerShell, dan regexnya sendiri memakai
# backtick sebagai escape di dalam string berkutip-ganda — sehingga uji itu
# gagal di-parse di CI. Kode yang tidak bisa dijalankan penulisnya sebaiknya
# tidak ditulis di tempat itu.
#
# Yang dicari: `Join-Path $x 'agentmodels.json'` — nama direktori disambung ke
# nama berkas TANPA pemisah. Baris komentar dibuang dulu; penjelasan cacatnya
# di PiModels.ps1 mengutip contohnya.
if grep -v '^[[:space:]]*#' "$REPO/scripts/lib/PiModels.ps1" |
   grep -qE "Join-Path[[:space:]]+\\\$[A-Za-z_]+[[:space:]]+'agent[A-Za-z]"; then
    bad "PiModels.ps1: Join-Path menyambung 'agent' ke nama berkas tanpa pemisah"
else
    ok "PiModels.ps1: tidak ada segmen jalur yang tersambung tanpa pemisah"
fi

grep -q 'PiModels.ps1' "$REPO/scripts/setup-pi.ps1" &&
grep -q 'models.json' "$REPO/scripts/setup-pi.ps1" \
    && ok "jalur PowerShell pi tersedia" \
    || bad "jalur PowerShell pi belum paralel"

# ── vision harus diumumkan ke pi ─────────────────────────────────────────────
#
# Kedua node memuat mmproj dan preset-nya menyatakan capabilities "vision";
# gambar terbukti tembus lewat gateway ke s1 maupun s2. Tetapi template pi
# sempat menyatakan `"input": ["text"]`, dan pi mempercayainya: ia menolak
# mengirim gambar ke model, lalu diam-diam memanggil subagent vision dan
# menuliskan "my model can't see images directly" di blok thinking-nya.
#
# Tidak ada yang galat. Jawabannya tetap datang, hanya saja dari model lain --
# kelas kegagalan yang paling mahal, karena ia terlihat seperti berhasil.
echo "vision diumumkan ke pi:"
render_pi() {
    sed -e 's|__GATEWAY__|http://x:8987|g; s|__API_KEY__|k|g; s|__MODEL_ID__|m|g' \
        -e 's|__CONTEXT_WINDOW__|131072|g; s|__MAX_TOKENS__|12288|g' \
        "$REPO/templates/pi-models.json"
}
kurang="$(render_pi | python3 -c '
import json,sys
d = json.load(sys.stdin)
print(" ".join(n for n, p in d["providers"].items()
                if "image" not in p["models"][0].get("input", [])))
' 2>/dev/null)"
if [ -z "$kurang" ]; then
    ok "ketiga provider pi menyatakan input image"
else
    bad "provider pi TANPA input image: $kurang — pi akan memakai subagent vision"
fi

# Pembaruan harus MENIMPA nilai lama. Dev yang sudah memasang punya
# `["text"]` di berkasnya; template yang benar tidak menolong bila merge
# memperlakukan provider yang sudah ada sebagai milik dev dan melewatinya.
if command -v node >/dev/null 2>&1; then
    SBX="$(mktemp -d)"
    render_pi > "$SBX/tpl.json"
    python3 - "$SBX/lama.json" <<'LAMA'
import json, sys
json.dump({"providers": {"cooper-agent": {
    "name": "CooperAgent (routing otomatis)", "baseUrl": "http://x:8987/v1",
    "apiKey": "kunci-dev-lama",
    "models": [{"id": "m", "name": "CooperAgent — routing otomatis",
                "input": ["text"], "contextWindow": 131072, "maxTokens": 12288}]}}},
          open(sys.argv[1], "w"))
LAMA
    node "$REPO/scripts/lib/pi_json.mjs" merge-models "$SBX/lama.json" "$SBX/tpl.json" > "$SBX/hasil.json" 2>/dev/null
    got="$(python3 -c '
import json,sys
d = json.load(open(sys.argv[1]))
print(",".join(d["providers"]["cooper-agent"]["models"][0].get("input", [])))
' "$SBX/hasil.json" 2>/dev/null)"
    case "$got" in
        *image*) ok "merge menimpa input lama [\"text\"] menjadi text+image" ;;
        "")      bad "merge pi gagal dijalankan — input lama tidak terperiksa" ;;
        *)       bad "merge MEMPERTAHANKAN input lama ($got) — dev lama tetap tanpa vision" ;;
    esac
    rm -rf "$SBX"
else
    printf "  \033[33m—\033[0m node tidak ada; merge input tidak diuji\n"
fi

# ── defaultProvider lama harus dipindah ──────────────────────────────────────
#
# `cooperagent` (tanpa strip) tidak pernah menjadi provider di pi-models.json,
# dan merge hanya mengelola provider yang ADA di template -- jadi nilai itu tidak
# pernah tersentuh siapa pun. Pemasangan pra-3.0.0 menunjuk provider yatim yang
# baseUrl-nya beku; pemasangan sesudahnya menunjuk provider yang tidak ada dan
# dijawab `Unknown provider "cooperagent"`. Kedua gejalanya senyap.
#
# Cerminan dari kasus yang sama di test/Test-PiModels.ps1. Jalur ini yang jalan
# di Linux/macOS, dan uji PowerShell hanya dieksekusi oleh job Windows -- satu
# suite saja berarti separuh dev tidak terjaga.
echo "defaultProvider lama dipindah:"
render_pi_settings() {
    sed -e 's|__MODEL_ID__|m|g; s|__PI_COMPACTION_RESERVE__|26215|g' \
        "$REPO/templates/pi-settings.json"
}

# Yang dipatok bukan namanya, melainkan KONTRAKNYA: apa pun yang ditunjuk
# settings harus benar-benar ada di models.json. Memeriksa string 'cooper-agent'
# akan lolos pada hari nama itu berubah lagi dan models.json ikut pindah.
if render_pi_settings | python3 -c '
import json, sys
tpl_settings = json.load(sys.stdin)
raw = open(sys.argv[1], encoding="utf-8").read()
for ph in ("__CONTEXT_WINDOW__", "__MAX_TOKENS__"):
    raw = raw.replace(ph, "1")
providers = json.loads(raw)["providers"]
dp = tpl_settings.get("defaultProvider")
sys.exit(0 if dp in providers else 1)
' "$REPO/templates/pi-models.json" 2>/dev/null; then
    ok "defaultProvider template menunjuk provider yang ada di pi-models.json"
else
    bad "defaultProvider template menunjuk provider yang TIDAK ada — pi menjawab Unknown provider"
fi

if command -v node >/dev/null 2>&1; then
    SBX="$(mktemp -d)"
    render_pi_settings > "$SBX/tpl.json"
    dp_of() { # $1 = berkas hasil merge
        python3 -c '
import json, sys
print(json.load(open(sys.argv[1])).get("defaultProvider", ""))
' "$1" 2>/dev/null
    }

    printf '%s' '{"defaultProvider":"cooperagent","defaultModel":"model-lama","theme":"dracula"}' \
        > "$SBX/lama.json"
    node "$REPO/scripts/lib/pi_json.mjs" merge-settings "$SBX/lama.json" "$SBX/tpl.json" \
        > "$SBX/lama.hasil.json" 2>/dev/null
    case "$(dp_of "$SBX/lama.hasil.json")" in
        cooper-agent) ok "defaultProvider cooperagent dipindah ke cooper-agent" ;;
        "")           bad "merge-settings gagal dijalankan — migrasi tidak terperiksa" ;;
        *)            bad "defaultProvider lama DIPERTAHANKAN ($(dp_of "$SBX/lama.hasil.json")) — pi tetap menunjuk provider yatim" ;;
    esac

    # Migrasinya harus sempit. Provider pilihan dev adalah keputusan sadar, dan
    # satu-satunya yang membuat nilai lama boleh ditimpa adalah bahwa nilai itu
    # tidak pernah bisa benar.
    printf '%s' '{"defaultProvider":"anthropic-saya","defaultModel":"claude-dev"}' \
        > "$SBX/dev.json"
    node "$REPO/scripts/lib/pi_json.mjs" merge-settings "$SBX/dev.json" "$SBX/tpl.json" \
        > "$SBX/dev.hasil.json" 2>/dev/null
    if [ "$(dp_of "$SBX/dev.hasil.json")" = 'anthropic-saya' ]; then
        ok "defaultProvider pilihan dev tidak ikut dipindah"
    else
        bad "provider pilihan dev ditimpa menjadi $(dp_of "$SBX/dev.hasil.json")"
    fi
    rm -rf "$SBX"
else
    printf "  \033[33m—\033[0m node tidak ada; migrasi defaultProvider tidak diuji\n"
fi

echo
if [ "$FAIL" -eq 0 ]; then
    printf "  \033[32mLULUS\033[0m — adapter pi mengikuti kontrak dan aturan CooperAgent\n"
else
    printf "  \033[31mGAGAL\033[0m\n"
fi
exit "$FAIL"
