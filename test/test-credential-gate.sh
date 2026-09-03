#!/usr/bin/env bash
# Menjaga satu janji: setup BERHENTI bila kredensial tidak lolos, dan
# mengatakan SEBABNYA.
#
# Ini bukan uji teoretis. Sampai 3 September 2026 probe /api/auth/whoami sudah
# ada di kedua pemasang, tapi kegagalannya ditelan `catch {}` kosong: gateway
# tak terjangkau, token tidak dikenal, dan kredensial DICABUT sama-sama jatuh
# diam-diam ke prompt "ketik nama dan device Anda". Setup lalu berjalan sampai
# akhir, mencetak tanda centang, dan menulis config yang pasti dijawab 401 --
# yang baru dev temukan saat mencoba bekerja.
#
# Ketiga sebab itu jalan keluarnya berbeda, jadi uji ini menuntut tiga PESAN
# yang berbeda, bukan sekadar tiga kegagalan.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT=8996
T="$(mktemp -d)"
FAIL=0
ok(){  printf "  \033[32m✔\033[0m %s\n" "$*"; }
bad(){ printf "  \033[31m✘\033[0m %s\n" "$*"; FAIL=1; }
cleanup(){ [ -n "${GW_PID:-}" ] && kill "$GW_PID" 2>/dev/null; rm -rf "$T"; }
trap cleanup EXIT

VALID="ca_$(printf 'a%.0s' $(seq 48))"
REVOKED="ca_$(printf 'b%.0s' $(seq 48))"
UNKNOWN="ca_$(printf 'c%.0s' $(seq 48))"

# ── gateway tiruan ────────────────────────────────────────────────────────────
# Alamat memakai loopback; nilai kontrak sengaja berbeda dari produksi supaya
# angka yang kebetulan cocok tidak lolos sebagai bukti.
cat > "$T/gw.py" <<'PY'
import json, sys
from http.server import BaseHTTPRequestHandler, HTTPServer
VALID   = "ca_" + "a"*48
REVOKED = "ca_" + "b"*48
C = {"object":"list","data":[{"id":"model-uji","object":"model",
      "context_window":262144,"max_tokens":24576}],
     "cooperagent":{"contract_version":1,"model_id":"model-uji",
      "context_window":262144,"max_tokens":24576,
      "compaction":{"threshold_percent":75,"threshold_tokens":196608},
      "context_source":"upstream","upstreams":[],
      "endpoints":[{"id":"lan","label":"LAN Uji","url":"http://127.0.0.1:%d/api/v1"}]}}
class H(BaseHTTPRequestHandler):
    def reply(self, code, obj):
        b = json.dumps(obj).encode()
        self.send_response(code); self.send_header("Content-Type","application/json")
        self.send_header("Content-Length", str(len(b))); self.end_headers(); self.wfile.write(b)
    def do_GET(self):
        if self.path.startswith("/api/auth/whoami"):
            tok = (self.headers.get("Authorization") or "").replace("Bearer ","").strip()
            if not tok.startswith("ca_") or len(tok) != 51:
                return self.reply(400, {"error":"token tidak berbentuk ca_..."})
            if tok == VALID:
                return self.reply(200, {"name":"lee","device":"laptop-uji",
                                        "role":"dev","who":"lee@laptop-uji"})
            if tok == REVOKED:
                return self.reply(401, {"error":"kredensial telah dicabut"})
            return self.reply(401, {"error":"token tidak dikenal"})
        if self.path.startswith("/api/health"):
            return self.reply(200, {"status":"ok","gateway":"online"})
        return self.reply(200, C)
    def log_message(self, *a): pass
PORT = int(sys.argv[1])
C["cooperagent"]["endpoints"][0]["url"] = "http://127.0.0.1:%d/api/v1" % PORT
HTTPServer(("127.0.0.1", PORT), H).serve_forever()
PY
python3 "$T/gw.py" "$PORT" & GW_PID=$!
for _ in $(seq 25); do
    curl -sf -o /dev/null "http://127.0.0.1:$PORT/v1/models" && break
    sleep 0.2
done
GW="http://127.0.0.1:$PORT/api/v1"

# ── 1. pustaka membedakan sebab ───────────────────────────────────────────────
echo $'\033[1mPustaka kredensial:\033[0m'
# shellcheck source=../scripts/lib/credential.sh
. "$REPO/scripts/lib/credential.sh"

cooper_verify_token "$GW" "$VALID" \
  && [ "$COOPER_WHO" = "lee@laptop-uji" ] && [ "$COOPER_ROLE" = dev ] \
  && ok "token sah -> identitas datang dari GATEWAY" \
  || bad "token sah tidak dikenali (state=$COOPER_VERIFY_STATE who=$COOPER_WHO)"

cooper_verify_token "$GW" "$REVOKED"
[ "$COOPER_VERIFY_STATE" = revoked ] \
  && ok "kredensial dicabut dibedakan dari token salah" \
  || bad "dicabut terbaca sebagai '$COOPER_VERIFY_STATE'"

cooper_verify_token "$GW" "$UNKNOWN"
[ "$COOPER_VERIFY_STATE" = unknown-token ] \
  && ok "token tidak dikenal dibedakan dari dicabut" \
  || bad "tidak dikenal terbaca sebagai '$COOPER_VERIFY_STATE'"

cooper_verify_token "$GW" "ca_pendek"
[ "$COOPER_VERIFY_STATE" = bad-form ] \
  && ok "token terpotong ditolak tanpa perjalanan jaringan" \
  || bad "bentuk salah terbaca sebagai '$COOPER_VERIFY_STATE'"

cooper_verify_token "http://127.0.0.1:9" "$VALID"
[ "$COOPER_VERIFY_STATE" = unreachable ] \
  && ok "gateway mati dibedakan dari token ditolak" \
  || bad "gateway mati terbaca sebagai '$COOPER_VERIFY_STATE'"

# Sebab yang berbeda WAJIB berbunyi berbeda: satu pesan untuk tiga masalah
# adalah pesan yang tidak menolong satu pun.
M1="$(cooper_verify_explain revoked "$GW")"
M2="$(cooper_verify_explain unknown-token "$GW")"
M3="$(cooper_verify_explain unreachable "$GW")"
[ "$M1" != "$M2" ] && [ "$M2" != "$M3" ] && [ "$M1" != "$M3" ] \
  && ok "tiga sebab, tiga pesan" || bad "pesan tidak dibedakan per sebab"
grep -qi 'dicabut' <<<"$M1" && ok "pesan 'dicabut' menyebut pencabutan" || bad "pesan dicabut tidak menyebutnya"
grep -qi 'cooper issue' <<<"$M1" && ok "pesan 'dicabut' menyebut jalan keluarnya" || bad "pesan dicabut tanpa jalan keluar"

# ── 2. setup.sh BERHENTI dan tidak menulis apa pun ────────────────────────────
#
# Pilihan agent 4 (manual) dipakai supaya tidak ada agent pihak ketiga yang
# diunduh -- gerbang berjalan sebelum pemasangan apa pun, jadi ini cukup.
echo
echo $'\033[1msetup.sh dengan kredensial dicabut:\033[0m'
H1="$T/home1"; mkdir -p "$H1"
OUT="$(printf '4\n' | HOME="$H1" COOPERAGENT_GATEWAY="$GW" \
        timeout 60 bash "$REPO/setup.sh" --token "$REVOKED" 2>&1)"
RC=$?
[ "$RC" -eq 3 ] && ok "keluar dengan kode 3" || bad "kode keluar $RC, seharusnya 3"
grep -qi 'DICABUT' <<<"$OUT" && ok "menyebut pencabutan, bukan pesan umum" || bad "sebab tidak disebut"
[ ! -f "$H1/.grok/config.toml" ] && [ ! -f "$H1/.omp/agent/models.yml" ] \
  && ok "tidak ada berkas config yang ditulis" \
  || bad "config TETAP ditulis padahal kredensial ditolak"
grep -qi 'Masukkan nama' <<<"$OUT" \
  && bad "MASIH jatuh ke prompt nama manual -- inilah bug 401 yang senyap" \
  || ok "tidak jatuh diam-diam ke identitas ketikan sendiri"

echo
echo $'\033[1msetup.sh dengan gateway mati:\033[0m'
H2="$T/home2"; mkdir -p "$H2"
OUT2="$(printf '4\n' | HOME="$H2" COOPERAGENT_GATEWAY="http://127.0.0.1:9/api/v1" \
        timeout 60 bash "$REPO/setup.sh" --token "$VALID" 2>&1)"
RC2=$?
[ "$RC2" -eq 3 ] && ok "keluar dengan kode 3" || bad "kode keluar $RC2, seharusnya 3"
grep -qi 'tidak menjawab' <<<"$OUT2" && ok "menyebut gateway tak terjangkau" || bad "sebab jaringan tidak disebut"
[ ! -f "$H2/.grok/config.toml" ] && ok "tidak ada berkas config yang ditulis" || bad "config tetap ditulis"

# ── 3. token sah lolos, identitas dari gateway ────────────────────────────────
echo
echo $'\033[1msetup.sh dengan token sah:\033[0m'
H3="$T/home3"; mkdir -p "$H3"
OUT3="$(printf '4\n' | HOME="$H3" COOPERAGENT_GATEWAY="$GW" \
        timeout 60 bash "$REPO/setup.sh" --token "$VALID" 2>&1)"
grep -q 'lee@laptop-uji' <<<"$OUT3" \
  && ok "identitas diambil dari gateway, tidak ditanyakan" \
  || bad "identitas gateway tidak tampil"
grep -qi 'Masukkan nama' <<<"$OUT3" \
  && bad "masih menanyakan nama padahal token sah" \
  || ok "nama dan device tidak ditanyakan lagi"

# ── 4. mode "sudah terpasang" memeriksa ulang kredensial ──────────────────────
#
# Inilah yang menangkap pencabutan: token yang kemarin sah bisa dicabut hari
# ini, dan berkas di mesin dev tidak pernah tahu.
echo
echo $'\033[1mmode "sudah terpasang":\033[0m'
H4="$T/home4"; mkdir -p "$H4/.omp/agent"
cat > "$H4/.omp/agent/models.yml" <<YML
providers:
  cooperagent:
    baseUrl: http://127.0.0.1:$PORT/v1
    apiKey: $REVOKED
YML
OUT4="$(printf '5\n' | HOME="$H4" timeout 60 bash "$REPO/setup.sh" 2>&1)"
grep -qi 'sudah terpasang' <<<"$OUT4" \
  && ok "dev omp-saja dikenali sebagai sudah terpasang" \
  || bad "pemasangan omp-saja tidak terlihat -- diseret ke onboarding penuh"
grep -qi 'DITOLAK' <<<"$OUT4" && grep -qi 'dicabut' <<<"$OUT4" \
  && ok "pencabutan terdeteksi tanpa dev perlu menempel token" \
  || bad "kredensial tidak diperiksa ulang saat sudah terpasang"
# Prompt `read -p` hanya tampil di terminal, jadi yang diperiksa baris menunya.
grep -q 'Ganti alamat gateway' <<<"$OUT4" && grep -q 'Pasang / ganti token' <<<"$OUT4" \
  && ok "menu ubah parameter/gateway/token ditawarkan" \
  || bad "menu tidak muncul"

# Rekomendasi harus menunjuk pilihan yang benar-benar memperbaiki keadaan.
grep -q '3) Pasang / ganti token kredensial \[disarankan' <<<"$OUT4" \
  && ok "pilihan 3 disarankan saat kredensial ditolak" \
  || bad "masih menyarankan 'perbarui parameter' padahal itu tidak memperbaiki 401"

# ── 4b. dev omp-saja dengan kunci lama, memilih pilihan default ───────────────
#
# Keadaan PERSIS yang dilaporkan klien: models.yml memakai `dev-nama@device`,
# tidak ada ~/.grok/config.toml sama sekali. setup-dev membaca alamat gateway
# dari config Grok, jadi tanpa alamat yang diteruskan ia berhenti dengan
# "Tidak ada alamat gateway" -- pada pilihan yang justru default.
echo
echo $'\033[1mdev omp-saja, kunci lama, pilihan default:\033[0m'
H5="$T/home5"; mkdir -p "$H5/.omp/agent"
cat > "$H5/.omp/agent/models.yml" <<YML
providers:
  cooperagent:
    baseUrl: http://127.0.0.1:$PORT/v1
    apiKey: dev-lee@laptop-uji
YML
OUT5="$(printf '1\n' | HOME="$H5" timeout 60 bash "$REPO/setup.sh" 2>&1)"
grep -qi 'Tidak ada alamat gateway' <<<"$OUT5" \
  && bad "buntu: alamat gateway tidak diteruskan ke setup-dev" \
  || ok "alamat diteruskan — pilihan default tidak buntu"
grep -qi 'tidak ada token di config' <<<"$OUT5" \
  && ok "kunci lama dikatakan bukan kredensial, bukan didiamkan" \
  || bad "kunci `dev-nama@device` diterima seolah token"

# ── 5. sisi Windows tidak boleh tertinggal ────────────────────────────────────
#
# Diperiksa pada TEKS, bukan dengan menjalankannya: runner ini Linux, dan
# PowerShell tidak ada di sini. Yang dijaga adalah PARITAS -- setiap perbaikan
# di repo ini pernah dipasang di satu platform saja, lalu ditemukan berbulan
# kemudian oleh dev di platform yang lain.
echo
echo $'\033[1mParitas setup.ps1:\033[0m'
grep -q 'Test-CooperCredential $SERVER_URL $Token' "$REPO/setup.ps1" \
  && ok "gerbang kredensial ada di jalur onboarding Windows" \
  || bad "setup.ps1 tidak memverifikasi token sebelum menulis"
grep -q 'exit 3' "$REPO/setup.ps1" \
  && ok "berhenti dengan kode 3, sama seperti setup.sh" \
  || bad "setup.ps1 tidak punya jalur keluar untuk kredensial ditolak"
grep -q 'Test-CooperGrokInstalled' "$REPO/setup.ps1" \
  && grep -q 'Get-OmpStoredKey' "$REPO/scripts/lib/OmpModels.ps1" \
  && ok "mode 'sudah terpasang' ada di Windows" \
  || bad "setup.ps1 tidak mengenali mesin yang sudah terpasang"
grep -q 'Set-CooperAllHarness' "$REPO/setup.ps1" \
  && ok "-Endpoint menyentuh SEMUA harness, bukan Grok saja" \
  || bad "-Endpoint Windows masih hanya menulis config Grok"

# `catch {}` KOSONG di sekitar probe whoami adalah bug aslinya: kegagalan
# ditelan, lalu setup berjalan terus seolah tidak terjadi apa-apa.
if grep -Pzoq '(?s)whoami.{0,600}?catch \{\s*\}' "$REPO/setup.ps1" 2>/dev/null; then
    bad "masih ada catch{} kosong di sekitar probe whoami"
else
    ok "tidak ada catch{} kosong yang menelan kegagalan whoami"
fi

# Kurung tidak seimbang adalah satu-satunya kerusakan PowerShell yang bisa
# ditangkap tanpa PowerShell. Ia tidak membuktikan skripnya benar; ia menangkap
# suntingan yang terpotong.
for f in setup.ps1 scripts/setup-dev.ps1 scripts/lib/OmpModels.ps1 scripts/lib/Credential.ps1; do
    nl="$(tr -cd '{' < "$REPO/$f" | wc -c)"; nr="$(tr -cd '}' < "$REPO/$f" | wc -c)"
    [ "$nl" = "$nr" ] && ok "$f: kurung kurawal seimbang ($nl)" \
        || bad "$f: kurung kurawal TIDAK seimbang ($nl buka, $nr tutup)"
done

echo
[ $FAIL -eq 0 ] && { printf "  \033[32mLULUS\033[0m — gerbang kredensial berhenti dengan sebabnya\n"; exit 0; }
printf "  \033[31mGAGAL\033[0m\n"; exit 1
