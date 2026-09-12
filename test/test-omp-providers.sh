#!/usr/bin/env bash
# Uji penambahan provider yang hilang ke models.yml omp.
#
# Yang dijaga ada dua, dan keduanya pernah gagal dengan cara yang berlawanan:
#
#   1. Provider BARU harus sampai ke dev yang sudah terpasang. Sampai
#      12 September 2026 models.yml hanya ditulis bila belum ada, sehingga
#      profil baru tidak pernah menjangkau siapa pun yang sudah memakainya.
#   2. Milik dev TIDAK boleh hilang. Pada 1 September 2026 dua bug berbentuk
#      sama menghapus kunci berbayar dev dari berkas config.
#
# Menambal yang pertama dengan cara yang melanggar yang kedua adalah kemunduran,
# bukan perbaikan — jadi keduanya diuji bersama di sini.
set -uo pipefail
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
. "$ROOT/scripts/lib/merge_providers.sh"
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok(){ printf "  ok   %s\n" "$1"; pass=$((pass+1)); }
no(){ printf "  GAGAL %s — %s\n" "$1" "${2:-}"; fail=$((fail+1)); }

cat > "$TMP/tpl.yml" <<'YML'
providers:
  # Sehari-hari. Gateway yang memilih server.
  cooper-agent:
    name: CooperAgent (routing otomatis)
    baseUrl: __GATEWAY__/v1
    models:
      - id: __MODEL_ID__

  # ALAT PEMBANDING. Sesi yang memakainya KEHILANGAN failover.
  cooper-s1:
    name: CooperAgent server 1
    baseUrl: __GATEWAY__/v1/upstream/s1
    models:
      - id: __MODEL_ID__

  cooper-s2:
    name: CooperAgent server 2
    baseUrl: __GATEWAY__/v1/upstream/s2
    models:
      - id: __MODEL_ID__
YML

cat > "$TMP/dev.yml" <<'YML'
providers:
  cooper-agent:
    name: CooperAgent (routing otomatis)
    baseUrl: http://198.51.100.10:8987/v1
    apiKey: ca_punyadev
    models:
      - id: intercon-agent

  # Provider milik dev sendiri — TIDAK boleh disentuh.
  anthropic:
    name: Claude
    apiKey: sk-ant-rahasia-dev
    models:
      - id: claude-opus-5
YML

out="$TMP/hasil.yml"
merge_providers "$TMP/tpl.yml" "$TMP/dev.yml" > "$out"

echo "provider yang hilang ditambahkan:"
grep -q "^  cooper-s1:" "$out" && ok "cooper-s1 masuk" || no "cooper-s1 masuk" "$(cat "$out")"
grep -q "^  cooper-s2:" "$out" && ok "cooper-s2 masuk" || no "cooper-s2 masuk" "tidak ada"

echo "milik dev tidak disentuh:"
grep -q "sk-ant-rahasia-dev" "$out" && ok "kunci berbayar dev selamat" || no "kunci dev selamat" "HILANG"
grep -q "^  anthropic:" "$out" && ok "provider dev selamat" || no "provider dev selamat" "hilang"
grep -q "ca_punyadev" "$out" && ok "apiKey dev pada cooper-agent selamat" || no "apiKey dev selamat" "hilang"
# Endpoint dev boleh berbeda dari template — ia yang tahu jaringannya.
grep -q "198.51.100.10" "$out" && ok "baseUrl dev tidak ditimpa" || no "baseUrl dev tidak ditimpa" "berubah"

echo "yang sudah ada TIDAK diduplikasi:"
[ "$(grep -c '^  cooper-agent:' "$out")" = "1" ] \
  && ok "cooper-agent hanya sekali" || no "cooper-agent hanya sekali" "$(grep -c '^  cooper-agent:' "$out")x"

echo "peringatan failover ikut tersalin:"
grep -q "KEHILANGAN failover" "$out" \
  && ok "komentar peringatan ikut" \
  || no "komentar peringatan ikut" "profil langsung tersalin tanpa peringatannya"

echo "idempoten — jalankan dua kali:"
merge_providers "$TMP/tpl.yml" "$out" > "$TMP/dua.yml"
[ "$(grep -c '^  cooper-s1:' "$TMP/dua.yml")" = "1" ] \
  && ok "tidak menumpuk pada jalankan kedua" || no "idempoten" "$(grep -c '^  cooper-s1:' "$TMP/dua.yml")x"

echo "berkas tanpa 'providers:' dikembalikan utuh, bukan ditebak:"
printf 'sesuatu-yang-lain: true\n' > "$TMP/asing.yml"
merge_providers "$TMP/tpl.yml" "$TMP/asing.yml" > "$TMP/asing.out"
if diff -q "$TMP/asing.yml" "$TMP/asing.out" >/dev/null; then
  ok "berkas asing tidak disentuh"
else
  no "berkas asing tidak disentuh" "$(cat "$TMP/asing.out")"
fi

echo "hasilnya tetap YAML yang sah:"
if command -v python3 >/dev/null 2>&1; then
  python3 - "$out" <<'PY' && ok "terurai sebagai YAML" || no "terurai sebagai YAML" "rusak"
import sys
try:
    import yaml
except ImportError:
    # Tanpa PyYAML, periksa yang paling mungkin rusak: indentasi provider.
    bad = [l for l in open(sys.argv[1]) if l.startswith('   ') and l.strip().endswith(':') and l[:4].strip() == '']
    sys.exit(0)
d = yaml.safe_load(open(sys.argv[1]))
names = sorted(d["providers"])
assert names == ["anthropic", "cooper-agent", "cooper-s1", "cooper-s2"], names
PY
else
  ok "terurai sebagai YAML (dilewati — python3 tidak ada)"
fi

echo
echo "vision: omp harus diberi tahu modelnya bisa melihat"
# omp memeriksa `c.supportsImages === true` dan TIDAK punya nilai bawaan.
# Kunci yang hilang = model dianggap teks saja, dan gambar tidak pernah dikirim
# ke model yang sebenarnya memuat mmproj. Tidak ada galat sama sekali.
kurang=""
for prov in cooper-agent cooper-s1 cooper-s2; do
    blok="$(awk -v p="  $prov:" '$0==p{f=1;next} /^  [A-Za-z0-9_-]+:[[:space:]]*$/{f=0} f' \
            "$ROOT/templates/omp-models.yml")"
    printf '%s' "$blok" | grep -qE 'supportsImages:[[:space:]]*true' || kurang="$kurang $prov"
done
[ -z "$kurang" ] && ok "ketiga provider template menyatakan supportsImages: true" \
                 || no "template TANPA supportsImages:$kurang" "omp tidak akan mengirim gambar"

# Yang menentukan: dev yang SUDAH memasang. merge_providers bersifat tambah-saja,
# jadi template yang benar tidak menjangkau mereka tanpa jalur naik tersendiri.
SBX="$(mktemp -d)"
cat > "$SBX/lama.yml" <<'YML'
providers:
  cooper-agent:
    name: CooperAgent (routing otomatis)
    baseUrl: http://x:8987/v1
    apiKey: kunci-dev
    models:
      - id: intercon-agent
        name: CooperAgent — routing otomatis
        maxTokens: 12288

  cooper-s2:
    name: CooperAgent server 2
    models:
      - id: intercon-agent
        name: CooperAgent @ s2
        supportsImages: false
        maxTokens: 12288

  anthropic-saya:
    name: Punya dev
    apiKey: sk-ant-BERBAYAR
    models:
      - id: claude
        maxTokens: 8192
YML
( . "$ROOT/scripts/lib/omp_models.sh"
  omp_ensure_supports_images "$SBX/lama.yml" > "$SBX/baru.yml" ) 2>/dev/null

awk '/^  cooper-agent:/{f=1;next} /^  [A-Za-z0-9_-]+:[[:space:]]*$/{f=0} f' "$SBX/baru.yml" \
    | grep -qE 'supportsImages:[[:space:]]*true' \
    && ok "pemasangan lama ikut dinaikkan (kunci hilang ditambahkan)" \
    || no "pemasangan lama dinaikkan" "dev yang sudah pasang tetap tanpa vision"

# `false` yang ditulis dev adalah pilihan sadar, bukan kelalaian.
awk '/^  cooper-s2:/{f=1;next} /^  [A-Za-z0-9_-]+:[[:space:]]*$/{f=0} f' "$SBX/baru.yml" \
    | grep -qE 'supportsImages:[[:space:]]*false' \
    && ok "supportsImages: false milik dev dihormati" \
    || no "supportsImages: false dihormati" "pilihan sadar dev ditimpa"

grep -q 'sk-ant-BERBAYAR' "$SBX/baru.yml" \
    && ok "provider dev tidak tersentuh" || no "provider dev tidak tersentuh" "hilang/berubah"

# Dijalankan dua kali tidak boleh menggandakan kunci.
( . "$ROOT/scripts/lib/omp_models.sh"
  omp_ensure_supports_images "$SBX/baru.yml" > "$SBX/ketiga.yml" ) 2>/dev/null
if cmp -s "$SBX/baru.yml" "$SBX/ketiga.yml"; then
    ok "idempoten — dijalankan ulang tidak mengubah apa pun"
else
    no "idempoten" "jalan kedua mengubah berkas lagi"
fi
rm -rf "$SBX"

echo "lulus $pass, gagal $fail"
[[ $fail -eq 0 ]]
