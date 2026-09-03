#!/usr/bin/env bash
# Menjaga satu janji: setup TIDAK PERNAH menyentuh milik dev.
#
# Ini bukan uji teoretis. Pada 1 September 2026 dua bug dengan bentuk yang sama
# ditemukan sekaligus: pola `[model.` mencocokkan SETIAP blok model, dan `sed`
# pada models.yml mengganti SETIAP baris apiKey. Keduanya menimpa kunci BERBAYAR
# milik dev -- Anthropic, OpenAI, Ollama -- dengan token CooperAgent, tanpa
# peringatan apa pun.
#
# Kerusakan seperti itu tidak terlihat sampai dev mencoba memakai kunci lain dan
# menemukannya hilang. Uji ini membuatnya terlihat pada saat kode berubah.
set -uo pipefail
# Alamat di fixture memakai blok dokumentasi RFC 5737, bukan alamat kantor:
# berkas ini ikut pindah ke repo pemasang, dan setiap IP di dalamnya akan ikut
# terbit bersamanya.
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
trap 'rm -rf "$T"' EXIT
mkdir -p "$T/.grok" "$T/.omp/agent"
FAIL=0
ok(){ printf "  \033[32m✔\033[0m %s\n" "$*"; }
bad(){ printf "  \033[31m✘\033[0m %s\n" "$*"; FAIL=1; }

cat > "$T/.grok/config.toml" <<'CFG'
[ui]
theme = "dracula"

[session]
auto_compact_threshold_percent = 85

[model.internal-qwen]
model = "qwen35"
base_url = "http://198.51.100.10:8987/api/v1"
api_key = "dev-lee@laptop-tuf"

[model.claude-saya]
model = "claude-opus-4"
api_key = "sk-ant-KUNCI-BERBAYAR-DEV"

[mcp.filesystem]
command = "npx"
CFG

cat > "$T/.omp/agent/models.yml" <<'YML'
providers:
  cooperagent:
    baseUrl: http://198.51.100.10:8987/v1
    apiKey: dev-lee@laptop-tuf
  anthropic-saya:
    baseUrl: https://api.anthropic.com/v1
    apiKey: sk-ant-KUNCI-BERBAYAR-DEV
YML

TOK="ca_$(printf 'e%.0s' $(seq 48))"
HOME="$T" bash "$REPO/scripts/setup-dev.sh" --token "$TOK" >/dev/null 2>&1

echo "config.toml — milik dev:"
grep -q 'theme = "dracula"'          "$T/.grok/config.toml" && ok "[ui] utuh"            || bad "[ui] HILANG"
grep -q 'sk-ant-KUNCI-BERBAYAR-DEV'  "$T/.grok/config.toml" && ok "kunci Anthropic utuh" || bad "kunci Anthropic TERTIMPA"
grep -q 'mcp.filesystem'             "$T/.grok/config.toml" && ok "[mcp] utuh"           || bad "[mcp] HILANG"

echo "config.toml — milik CooperAgent:"
grep -q "api_key = \"$TOK\""              "$T/.grok/config.toml" && ok "token terpasang"    || bad "token TIDAK terpasang"
grep -q 'auto_compact_threshold_percent = 80' "$T/.grok/config.toml" && ok "ambang jadi 80" || bad "ambang tidak diperbarui"

echo "models.yml:"
grep -q 'sk-ant-KUNCI-BERBAYAR-DEV' "$T/.omp/agent/models.yml" && ok "provider dev utuh" || bad "provider dev TERTIMPA"
grep -q "apiKey: $TOK"              "$T/.omp/agent/models.yml" && ok "provider kita diperbarui" || bad "provider kita tidak diperbarui"

# --- config bertanda kutip TUNGGAL tetap terbaca ------------------------------
# setup.ps1 menulis nilai TOML dengan kutip tunggal sampai 1 September 2026,
# sementara pembacanya hanya menangkap kutip ganda. Akibatnya models.yml
# DILEWATI diam-diam pada mesin Windows -- terlihat di uji dev, bukan di sini.
echo
echo "config dengan kutip tunggal:"
T3="$(mktemp -d)"; mkdir -p "$T3/.grok" "$T3/.omp/agent"
cat > "$T3/.grok/config.toml" <<'CFG'
[model.internal-qwen]
model = 'intercon-agent'
base_url = 'http://198.51.100.10:8987/api/v1'
api_key = 'dev-lama@mesin'
CFG
cat > "$T3/.omp/agent/models.yml" <<'YML'
providers:
  cooperagent:
    baseUrl: http://198.51.100.10:8987/v1
    apiKey: dev-lama@mesin
YML
HOME="$T3" bash "$REPO/scripts/setup-dev.sh" --token "$TOK" >/dev/null 2>&1
grep -q "apiKey: $TOK" "$T3/.omp/agent/models.yml" \
  && ok "models.yml diperbarui meski config berkutip tunggal" \
  || bad "models.yml DILEWATI — pembaca tidak menerima kutip tunggal"
rm -rf "$T3"

# --- klaim kedua: token yang sudah ada dipertahankan tanpa bertanya ----------
# docs/onboarding.md menjanjikan ini. Sebuah janji yang tidak diuji adalah
# janji yang belum tentu benar -- itu pelajaran hari ini.
echo
echo "setup.sh dijalankan ulang, config sudah punya token:"
T2="$(mktemp -d)"; mkdir -p "$T2/.grok"
cp "$T/.grok/config.toml" "$T2/.grok/config.toml"
# Mesin yang sudah terpasang tidak diseret ke onboarding: setup.sh membuka menu
# keadaan, dan `5` keluar tanpa mengubah apa pun. Yang dijanjikan
# docs/onboarding.md dan diuji di sini: token yang sudah ada TIDAK diminta
# ditempel ulang.
OUT="$(printf '5\n' | HOME="$T2" timeout 40 bash "$REPO/setup.sh" 2>&1 || true)"
rm -rf "$T2"
grep -q "sudah terpasang" <<<"$OUT" \
  && ok "mesin terpasang dikenali, bukan diseret ke onboarding" \
  || bad "menjalankan ulang setup memulai onboarding dari nol"
grep -q "Tempel token" <<<"$OUT" \
  && bad "MASIH BERTANYA token padahal config sudah punya" \
  || ok "token yang ada dipertahankan tanpa bertanya"
grep -qi "Masukkan nama" <<<"$OUT" \
  && bad "MASIH menanyakan nama/device pada mesin yang sudah terpasang" \
  || ok "identitas tidak ditanyakan ulang"

echo
[[ $FAIL -eq 0 ]] && { printf "  \033[32mLULUS\033[0m — setup tidak menyentuh milik dev\n"; exit 0; }
printf "  \033[31mGAGAL\033[0m\n"; exit 1
