#!/usr/bin/env bash
# Menjaga satu janji: nilai kontrak DIAMBIL dari gateway, tidak dipatok klien.
#
# Ini bukan uji teoretis. Sampai 1 September 2026 `context_window = 131072`,
# `max_tokens = 12288`, dan ambang compaction `80` ditulis tangan di sepuluh
# tempat, sementara gateway sudah menyajikan keempatnya lewat `/v1/models`.
# Angkanya kebetulan cocok, jadi tidak ada yang rusak -- cocoknya karena
# kebetulan, bukan karena konstruksi.
#
# Yang paling berbahaya bukan config yang salah, melainkan VERIFIKASI yang
# salah: `setup-dev.sh` mencocokkan config dengan 131072 yang dipatok di dirinya
# sendiri, sehingga ia akan mencetak tanda centang dengan yakin justru pada saat
# nilainya sudah basi.
#
# Uji ini menyalakan gateway TIRUAN yang menyajikan angka yang sengaja berbeda,
# lalu menuntut seluruh rantai mengikutinya.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT=8994
T="$(mktemp -d)"
FAIL=0
ok(){  printf "  \033[32m✔\033[0m %s\n" "$*"; }
bad(){ printf "  \033[31m✘\033[0m %s\n" "$*"; FAIL=1; }

cleanup(){ [ -n "${GW_PID:-}" ] && kill "$GW_PID" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

# ── gateway tiruan ────────────────────────────────────────────────────────────
# Angkanya sengaja TIDAK ada yang sama dengan produksi. Nilai yang kebetulan
# cocok tidak membuktikan apa pun -- itu justru kesalahan yang sedang dicegah.
cat > "$T/gw.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
C = {"object":"list","data":[{"id":"model-uji","object":"model",
      "context_window":262144,"max_tokens":24576}],
     "cooperagent":{"contract_version":1,"model_id":"model-uji",
      "context_window":262144,"max_tokens":24576,
      "compaction":{"threshold_percent":75,"threshold_tokens":196608},
      "context_source":"upstream","upstreams":[]}}
class H(BaseHTTPRequestHandler):
    def reply(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type","application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        # Sejak 3 September 2026 pemasang memverifikasi token sebelum menulis,
        # jadi gateway tiruan harus bisa menjawab siapa pemiliknya.
        if self.path.startswith("/api/auth/whoami"):
            return self.reply(200, {"name":"lee","device":"laptop-uji",
                                    "role":"dev","who":"lee@laptop-uji"})
        return self.reply(200, C)
    def log_message(self, *a): pass
HTTPServer(("127.0.0.1", int(sys.argv[1])), H).serve_forever()
PY
python3 "$T/gw.py" "$PORT" & GW_PID=$!
for _ in $(seq 20); do
    curl -sf -o /dev/null "http://127.0.0.1:$PORT/v1/models" && break
    sleep 0.2
done

GW="http://127.0.0.1:$PORT"

# ── 1. pustaka mengambil dan memvalidasi ──────────────────────────────────────
echo $'\033[1mPustaka kontrak:\033[0m'
# shellcheck source=../scripts/lib/contract.sh
. "$REPO/scripts/lib/contract.sh"
if fetch_contract "$GW" \
   && [ "$CONTRACT_CONTEXT_WINDOW" = 262144 ] && [ "$CONTRACT_MAX_TOKENS" = 24576 ] \
   && [ "$CONTRACT_COMPACT_PCT" = 75 ] && [ "$CONTRACT_MODEL_ID" = "model-uji" ] \
   && [ "$CONTRACT_SOURCE" = gateway ]; then
    ok "kontrak terbaca utuh dari gateway"
else
    bad "kontrak tidak terbaca: cw=$CONTRACT_CONTEXT_WINDOW pct=$CONTRACT_COMPACT_PCT id=$CONTRACT_MODEL_ID src=$CONTRACT_SOURCE"
fi

# Gateway mati harus jatuh ke cadangan, dan MENGAKUINYA.
( . "$REPO/scripts/lib/contract.sh"
  if fetch_contract "http://127.0.0.1:9" ; then exit 1; fi
  [ "$CONTRACT_SOURCE" = cadangan ] && [ "$CONTRACT_CONTEXT_WINDOW" = 131072 ] ) \
    && ok "gateway mati -> nilai cadangan, sumber diakui 'cadangan'" \
    || bad "jatuh ke cadangan tanpa mengakuinya"

# Respons 200 yang bukan gateway CooperAgent harus DITOLAK, bukan diurai
# sebagian. Proxy perusahaan yang mengembalikan halaman login adalah kasus
# nyatanya.
( . "$REPO/scripts/lib/contract.sh"
  printf '{"object":"list","data":[]}' > "$T/bukan.json"
  if fetch_contract "file://$T" ; then exit 1; fi
  [ "$CONTRACT_SOURCE" = cadangan ] ) \
    && ok "respons tanpa penanda cooperagent ditolak" \
    || bad "respons asing diterima sebagai kontrak"

# ── 2. render template ────────────────────────────────────────────────────────
echo
echo $'\033[1mRender template:\033[0m'
. "$REPO/scripts/lib/contract.sh"; fetch_contract "$GW" >/dev/null
# `__GATEWAY__` juga milik pemanggil, sama seperti pada omp-models.yml: alamat
# bukan bagian kontrak, dan pustaka kontrak tidak boleh ikut memegangnya.
contract_render "$REPO/templates/config.toml" | sed -e "s|__GATEWAY__|$GW|g" > "$T/cfg.toml"
# `__GATEWAY__` dan `__API_KEY__` sengaja BUKAN urusan contract_render -- alamat
# dan kredensial bukan bagian kontrak, dan pustaka itu tidak boleh ikut memegang
# rahasia. Pemanggil yang mengisinya, jadi uji ini menirukan pemanggil.
contract_render "$REPO/templates/omp-models.yml" \
    | sed -e "s|__GATEWAY__|$GW|g" -e "s|__API_KEY__|ca_uji|g" > "$T/models.yml"

contract_assert_rendered "$T/cfg.toml" 2>/dev/null \
    && ok "config.toml terender penuh — tidak ada placeholder tersisa" \
    || bad "masih ada placeholder di config.toml hasil render"
contract_assert_rendered "$T/models.yml" 2>/dev/null \
    && ok "omp-models.yml terender penuh" \
    || bad "masih ada placeholder di models.yml hasil render"

# Penjaga arah sebaliknya: template MENTAH wajib ditolak. Tanpa ini, sebuah
# `merge` yang lupa merender akan menulis `context_window = __CONTEXT_WINDOW__`
# ke config dev -- rusak dengan cara yang baru terlihat jauh dari sini.
contract_assert_rendered "$REPO/templates/config.toml" 2>/dev/null \
    && bad "template mentah LOLOS pemeriksaan placeholder" \
    || ok "template mentah ditolak"

grep -q 'context_window = 262144' "$T/cfg.toml" && grep -q 'max_tokens = 24576' "$T/cfg.toml" \
    && grep -q 'auto_compact_threshold_percent = 75' "$T/cfg.toml" \
    && grep -q 'model = "model-uji"' "$T/cfg.toml" \
    && ok "config.toml memakai nilai gateway, bukan nilai produksi" \
    || bad "config.toml hasil render tidak mengikuti gateway"

grep -q 'contextWindow: 262144' "$T/models.yml" && grep -q 'id: model-uji' "$T/models.yml" \
    && ok "models.yml memakai nilai gateway" \
    || bad "models.yml hasil render tidak mengikuti gateway"

# ── 3. rantai penuh: setup-dev.sh ─────────────────────────────────────────────
echo
echo $'\033[1msetup-dev.sh terhadap gateway tiruan:\033[0m'
H="$T/home"; mkdir -p "$H/.grok" "$H/.omp/agent"
cat > "$H/.grok/config.toml" <<CFG
[ui]
theme = "dracula"

[session]
auto_compact_threshold_percent = 85

[model.internal-qwen]
base_url = "$GW/api/v1"
api_key = "ca_000102030405060708090a0b0c0d0e0f101112131415161718"
context_window = 131072
CFG
OUT="$(HOME="$H" GROK_HOME="$H/.grok" bash "$REPO/scripts/setup-dev.sh" --dry-run 2>&1)"

printf '%s' "$OUT" | grep -q 'context_window = 262144' \
    && ok "config yang di-merge memakai context_window gateway" \
    || bad "config yang di-merge masih memakai angka patok"

# Inti uji ini: verifikasi harus mengukur terhadap SERVER, bukan terhadap
# keyakinan skrip sendiri.
printf '%s' "$OUT" | sed -n '/Verifikasi/,$p' | grep -q 'context_window = 262144' \
    && ok "verifikasi mengukur terhadap kontrak gateway" \
    || bad "verifikasi masih mengukur terhadap angka yang dipatok di skrip"
printf '%s' "$OUT" | sed -n '/Verifikasi/,$p' | grep -q 'auto_compact_threshold_percent = 75' \
    && ok "ambang compaction diverifikasi terhadap kontrak" \
    || bad "ambang compaction masih diverifikasi terhadap 80 yang dipatok"

printf '%s' "$OUT" | grep -q 'theme = "dracula"' \
    && ok "milik dev tetap utuh" \
    || bad "seksi milik dev hilang"

# ── 4. tidak ada angka kontrak yang dipatok di jalur setup ────────────────────
#
# Penjaga yang paling penting, karena ia menangkap kekambuhan pada saat kode
# ditulis, bukan berbulan-bulan kemudian saat --ctx-size berubah. Baris komentar
# dikecualikan: sejarahnya justru perlu tetap tertulis.
echo
echo $'\033[1mTidak ada angka kontrak yang dipatok:\033[0m'
HITS=""
for f in setup.sh setup.ps1 scripts/setup-dev.sh scripts/setup-dev.ps1 \
         templates/config.toml templates/omp-models.yml; do
    while IFS= read -r line; do
        case "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')" in \#*) continue ;; esac
        case "$line" in *131072*|*12288*) HITS="$HITS
  $f: $line" ;; esac
    done < "$REPO/$f"
done
if [ -z "$HITS" ]; then
    ok "131072 dan 12288 tidak muncul di baris kode mana pun"
else
    bad "angka kontrak masih dipatok:$HITS"
fi

# Nilai cadangan di pustaka justru HARUS ada -- ia yang dipakai saat gateway
# tidak terjangkau. Uji ini menegaskan letaknya: satu tempat, bukan sepuluh.
grep -q 'CONTRACT_CONTEXT_WINDOW=131072' "$REPO/scripts/lib/contract.sh" \
    && grep -q 'ContractContextWindow = 131072' "$REPO/scripts/lib/Contract.ps1" \
    && ok "nilai cadangan hidup di satu tempat per platform" \
    || bad "nilai cadangan tidak ditemukan di pustaka kontrak"

# ── 5. tidak ada alamat internal di jalur pemasang ────────────────────────────
#
# Penjaga yang memutuskan apakah berkas-berkas ini boleh tinggal di repo publik.
# Riwayat git tidak bisa dilupakan: SATU commit dengan IP internal sudah cukup
# untuk menerbitkannya selamanya. Aturannya sederhana dan bisa diperiksa mesin:
# tidak ada literal IPv4 selain 127.0.0.1 (localhost sama di mesin mana pun).
echo
echo $'\033[1mTidak ada alamat internal di jalur pemasang:\033[0m'
IPHITS=""
for f in setup.sh setup.ps1 scripts/setup-dev.sh scripts/setup-dev.ps1 \
         scripts/lib/contract.sh scripts/lib/Contract.ps1 \
         templates/config.toml templates/omp-models.yml; do
    while IFS= read -r line; do
        case "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')" in \#*) continue ;; esac
        hit="$(printf '%s' "$line" | grep -oE '\b([0-9]{1,3}\.){3}[0-9]{1,3}\b' | grep -v '^127\.0\.0\.1$' || true)"
        [ -n "$hit" ] && IPHITS="$IPHITS
  $f: $hit"
    done < "$REPO/$f"
done
if [ -z "$IPHITS" ]; then
    ok "tidak ada literal IPv4 selain 127.0.0.1"
else
    bad "alamat internal masih tertulis:$IPHITS"
fi

# ── 6. berpindah jaringan tidak boleh merusak token ───────────────────────────
#
# Bug nyata, ditemukan 2 September 2026 saat menguji alias endpoint. Ekstraktor
# api_key dibangun untuk identitas lama `dev-nama@device` dan tidak pernah
# diperbarui saat token datang: pada config bertoken polanya tidak cocok,
# seluruh baris lolos apa adanya, dan hasilnya ditulis kembali sebagai
#   api_key = "dev-api_key = "ca_..."
# Token hancur, TOML rusak, dan dev dijawab 401 tepat setelah berpindah jaringan
# -- yaitu tepat ketika ia paling tidak bisa menebak sebabnya.
echo
echo $'\033[1mBerpindah jaringan mempertahankan token:\033[0m'
SW="$T/switch"; mkdir -p "$SW/.grok" "$SW/.cooper"
# 48 heksadesimal, bukan 50. Bentuk yang sah adalah `ca_` + 48 = 51 karakter,
# dan sejak 3 September 2026 pemasang memeriksanya sebelum menghubungi gateway
# -- fixture yang panjangnya salah akan ditolak, dengan benar.
TOK="ca_000102030405060708090a0b0c0d0e0f1011121314151617"
# Alias menunjuk gateway tiruan yang HIDUP: sejak 3 September 2026 perpindahan
# diverifikasi lebih dulu, jadi alamat yang tidak menjawab memang ditolak --
# itu diuji terpisah di bawah.
printf 'vpn\tVPN Kantor\thttp://127.0.0.1:%s/api/v1\n' "$PORT" > "$SW/.cooper/gateway-endpoints"
cat > "$SW/.grok/config.toml" <<CFG
[model.internal-qwen]
base_url = "http://127.0.0.1:9/api/v1"
api_key = "$TOK"
CFG
HOME="$SW" bash "$REPO/setup.sh" --endpoint vpn >/dev/null 2>&1 || true
if [ "$(grep -c "api_key = \"$TOK\"" "$SW/.grok/config.toml")" -ge 1 ]; then
    ok "token utuh sesudah --endpoint vpn"
else
    bad "token rusak: $(grep -m1 api_key "$SW/.grok/config.toml")"
fi
grep -q "base_url = \"http://127.0.0.1:$PORT/api/v1\"" "$SW/.grok/config.toml" \
    && ok "alamat berpindah ke alias dari daftar tersimpan" \
    || bad "alamat tidak berpindah"

# Alamat yang TIDAK menjawab harus ditolak, bukan ditulis lalu diperiksa
# sesudahnya. Sampai 3 September 2026 urutannya terbalik, sehingga satu perintah
# salah ketik cukup untuk membuang gateway yang tadinya bekerja.
SW2="$T/switch-mati"; mkdir -p "$SW2/.grok" "$SW2/.cooper"
printf 'vpn\tVPN Kantor\thttp://127.0.0.1:9/api/v1\n' > "$SW2/.cooper/gateway-endpoints"
cat > "$SW2/.grok/config.toml" <<CFG
[model.internal-qwen]
base_url = "http://127.0.0.1:$PORT/api/v1"
api_key = "$TOK"
CFG
HOME="$SW2" bash "$REPO/setup.sh" --endpoint vpn >/dev/null 2>&1
RC_SW=$?
[ "$RC_SW" -eq 3 ] && ok "pindah ke gateway mati ditolak (kode 3)" \
    || bad "pindah ke gateway mati tidak ditolak (kode $RC_SW)"
grep -q "base_url = \"http://127.0.0.1:$PORT/api/v1\"" "$SW2/.grok/config.toml" \
    && ok "config lama dibiarkan utuh" \
    || bad "config lama TERTIMPA oleh alamat yang tidak menjawab"

echo
if [ "$FAIL" = 0 ]; then
    printf "  \033[32mLULUS\033[0m — kontrak datang dari gateway, bukan dari skrip\n"
else
    printf "  \033[31mGAGAL\033[0m\n"
fi
exit "$FAIL"
