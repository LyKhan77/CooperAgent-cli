#!/usr/bin/env bash
# Uji keseragaman profil model di SELURUH harness dan kedua platform.
#
# KENAPA ADA. Sampai 12 September 2026 setiap harness memakai kosakata sendiri:
# Grok `internal-qwen*`, omp `cooperagent*`, dan pi hanya punya satu dari tiga.
# Tidak ada yang salah di satu berkas pun -- yang salah adalah selisih antar
# berkas, dan tidak ada satu pun uji yang melihat lebih dari satu berkas.
#
# Definisi profil hidup di ENAM tempat: tiga template, dua pemasang yang memuat
# salinan inline sendiri (setup.sh dan setup.ps1), dan pembaru. Selisih di
# antaranya tidak memutus apa pun secara langsung -- ia hanya membuat dev yang
# berpindah harness menemukan nama yang berbeda, dan itu tidak pernah tampak
# sebagai kegagalan.
set -uo pipefail
ROOT=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
pass=0; fail=0
ok(){ printf "  ok   %s\n" "$1"; pass=$((pass+1)); }
no(){ printf "  GAGAL %s — %s\n" "$1" "${2:-}"; fail=$((fail+1)); }

WAJIB="cooper-agent cooper-s1 cooper-s2 cooper-s3"

echo "ketiga profil ada di setiap sumber:"

grok_tpl="$(grep -oE '^\[model\.[A-Za-z0-9_-]+\]' "$ROOT/templates/config.toml" \
            | sed 's/^\[model\.//; s/\]$//' | sort | tr '\n' ' ')"
omp_tpl="$(awk '/^providers:/{p=1;next} /^[^[:space:]#]/{p=0} p && /^  [A-Za-z0-9_-]+:/{k=$1;sub(/:$/,"",k);print k}' \
            "$ROOT/templates/omp-models.yml" | sort | tr '\n' ' ')"
pi_tpl="$(grep -oE '^    "[A-Za-z0-9_-]+": \{' "$ROOT/templates/pi-models.json" \
            | sed 's/^ *"//; s/": {$//' | sort | tr '\n' ' ')"
sh_inline="$(grep -oE '^\[model\.[A-Za-z0-9_-]+\]' "$ROOT/setup.sh" \
            | sed 's/^\[model\.//; s/\]$//' | sort | tr '\n' ' ')"
ps_inline="$(grep -oE '"\[model\.[A-Za-z0-9_-]+\]"' "$ROOT/setup.ps1" \
            | sed 's/^"\[model\.//; s/\]"$//' | sort | tr '\n' ' ')"

HARAP="$(printf '%s\n' $WAJIB | sort | tr '\n' ' ')"
for pair in "template Grok|$grok_tpl" "template omp|$omp_tpl" "template pi|$pi_tpl" \
            "setup.sh inline|$sh_inline" "setup.ps1 inline|$ps_inline"; do
    label="${pair%%|*}"; got="${pair#*|}"
    [ "$got" = "$HARAP" ] && ok "$label: $got" || no "$label" "dapat '$got', harus '$HARAP'"
done

echo "profil langsung menembus routing, bukan menyalin endpoint auto:"
# cooper-s1 yang menunjuk /api/v1 biasa BUKAN alat banding -- ia diam-diam
# ikut routing, dan hasil bandingnya bohong tanpa ada yang tahu.
for f in templates/config.toml templates/omp-models.yml templates/pi-models.json setup.sh setup.ps1; do
    for n in s1 s2 s3; do
        grep -q "upstream/$n" "$ROOT/$f" \
            || no "$f menyebut upstream/$n" "tidak ada"
    done
done
ok "kelima sumber menyebut /upstream/s1, /upstream/s2, dan /upstream/s3"

echo "peringatan kehilangan failover ikut di tiap sumber:"
for f in templates/config.toml templates/omp-models.yml setup.sh setup.ps1; do
    grep -qiE "kehilangan failover|tanpa failover" "$ROOT/$f" \
        && ok "$(basename "$f") memperingatkan" \
        || no "$(basename "$f") memperingatkan" "profil langsung tanpa peringatannya"
done

echo "tidak ada alamat internal yang bocor (aturan #1 AGENTS.md):"
# Hanya 127.0.0.1 yang boleh. Repo ini publik dan riwayat git tidak bisa
# dilupakan; satu commit sudah cukup menerbitkan topologi internal selamanya.
bocor="$(grep -rhoE '\b(10|192\.168|172\.(1[6-9]|2[0-9]|3[01]))\.[0-9]+\.[0-9]+\.[0-9]+\b' \
          "$ROOT/templates" "$ROOT/setup.sh" "$ROOT/setup.ps1" "$ROOT/scripts" 2>/dev/null \
          | sort -u | tr '\n' ' ')"
[ -z "$bocor" ] && ok "tidak ada IPv4 internal di jalur pemasang" \
                || no "IPv4 internal bocor" "$bocor"

echo "nama lama tetap DIKENALI, supaya pemasangan lama terbaca:"
grep -q 'internal-qwen' "$ROOT/scripts/setup-dev.sh" \
    && ok "setup-dev.sh masih mengenali internal-qwen (jalur migrasi)" \
    || no "jalur migrasi hilang" "dev lama tidak akan bermigrasi"
grep -q 'cooperagent' "$ROOT/scripts/lib/omp_models.sh" \
    && ok "omp_models.sh masih mengenali cooperagent (token dev lama)" \
    || no "pengenalan omp lama hilang" "token dev lama tidak akan diperbarui"

echo "config lama tetap terbaca oleh KEDUA jalur pemasangan:"
# Regresi 12 September 2026: `read_existing_endpoint` diganti membaca
# `[model.cooper-agent]` saja, sehingga dev yang belum bermigrasi kehilangan
# alamatnya dan pemasang menanyakannya ulang. Config-nya tidak rusak -- yang
# rusak adalah pemasang yang berpura-pura tidak pernah mengenalnya.
SBX="$(mktemp -d)"; trap 'rm -rf "$SBX"' EXIT
mkdir -p "$SBX/.grok"
printf '[model.internal-qwen]\nbase_url = "http://198.51.100.10:8987/api/v1"\n' > "$SBX/.grok/config.toml"
FN="$(mktemp)"; awk '/^read_existing_endpoint\(\) \{/,/^\}/' "$ROOT/setup.sh" > "$FN"
got="$({ cat "$FN"; echo "HOME=$SBX; read_existing_endpoint"; } | bash 2>/dev/null)"
[ "$got" = "http://198.51.100.10:8987/api/v1" ] \
    && ok "setup.sh membaca endpoint dari nama LAMA" \
    || no "setup.sh membaca endpoint dari nama lama" "dapat '${got:-kosong}'"

printf '[model.cooper-agent]\nbase_url = "http://198.51.100.20:8987/api/v1"\n' > "$SBX/.grok/config.toml"
got="$({ cat "$FN"; echo "HOME=$SBX; read_existing_endpoint"; } | bash 2>/dev/null)"
[ "$got" = "http://198.51.100.20:8987/api/v1" ] \
    && ok "setup.sh membaca endpoint dari nama BARU" \
    || no "setup.sh membaca endpoint dari nama baru" "dapat '${got:-kosong}'"
rm -f "$FN"

echo "KEEMPAT jalur pemasangan punya migrasi yang sama:"
# Dua pemasang (setup.sh, setup.ps1) dan DUA pembaru (scripts/setup-dev.sh,
# scripts/setup-dev.ps1). Yang terakhir sempat terlewat pada 12 September 2026
# justru saat jalur lain diperbaiki -- padahal itulah jalur yang dianjurkan
# docs/dev_setup.md kepada dev Windows yang SUDAH terpasang, yakni satu-satunya
# populasi yang pasti memegang config lama.
#
# Polanya menuntut `[model.cooper-agent]` sebagai literal SESUDAH internal-qwen,
# bukan sekadar kedua kata di satu baris: `scripts/setup-dev.ps1` punya regex
# penyuntik token yang menyebut keduanya sekaligus dan tidak mengganti apa pun.
for f in setup.sh setup.ps1 scripts/setup-dev.sh scripts/setup-dev.ps1; do
    grep -qE 'internal-qwen.*\[model\.cooper-agent\]' "$ROOT/$f" \
        && ok "$f: internal-qwen -> [model.cooper-agent]" \
        || no "$f: internal-qwen -> [model.cooper-agent]" "jalur ini meninggalkan seksi yatim"
    grep -qE 'internal-qwen-s2.*\[model\.cooper-s2\]' "$ROOT/$f" \
        && ok "$f: -s2 -> [model.cooper-s2]" \
        || no "$f: -s2 -> [model.cooper-s2]" "seksi s2 lama tertinggal"
done
grep -q "internal-qwen" "$ROOT/setup.ps1" \
    && ok "setup.ps1 masih mengenali nama lama" \
    || no "setup.ps1 masih mengenali nama lama" "dev Windows lama kehilangan alamatnya"

echo "migrasi setup.sh BENAR-BENAR dijalankan, bukan sekadar disebut:"
# Uji di atas hanya membuktikan teksnya ada. Yang penting adalah hasilnya:
# seksi lama berganti nama DI TEMPAT dengan isinya terbawa, kunci berbayar dev
# selamat, dan cadangan merekam keadaan SEBELUM migrasi -- cadangan yang sudah
# ikut bermigrasi tidak bisa dipakai mundur, dan itu baru ketahuan saat
# seseorang membutuhkannya.
mkdir -p "$SBX/run/.grok"
cat > "$SBX/run/.grok/config.toml" <<'CFG'
[ui]
theme = "dracula"

[model.internal-qwen]
model = "qwen35"
base_url = "http://198.51.100.10:8987/api/v1"
api_key = "dev-lee@laptop-tuf"

[model.internal-qwen-s2]
model = "qwen35"

[model.internal-qwen-localhost]
model = "qwen35"

[model.claude-saya]
api_key = "sk-ant-KUNCI-BERBAYAR-DEV"
CFG

DRV="$SBX/drv.sh"
{
    echo 'set -e'
    echo 'GREEN=""; YELLOW=""; NC=""; S_OK="ok"'
    echo 'CONTRACT_MODEL_ID=qwen35; CONTRACT_CONTEXT_WINDOW=262144'
    echo 'CONTRACT_MAX_TOKENS=32768; CONTRACT_COMPACT_PCT=75'
    echo 'CONTRACT_COMPACT_TOKENS=196608'
    echo 'contract_fmt(){ printf "%s" "$1"; }'
    echo 'bak_prune(){ :; }'
    echo ". '$ROOT/scripts/lib/merge_toml.sh'"
    awk '/^list_unmanaged_sections\(\) \{/,/^\}/' "$ROOT/setup.sh"
    awk '/^write_grok_config\(\) \{/,/^\}/'      "$ROOT/setup.sh"
    echo 'write_grok_config "http://198.51.100.10:8987/api/v1" "lee@laptop-tuf" merge'
} > "$DRV"
out="$(HOME="$SBX/run" bash "$DRV" 2>&1)"; rc=$?
cfg="$SBX/run/.grok/config.toml"

[ $rc -eq 0 ] && ok "write_grok_config selesai tanpa galat" \
               || no "write_grok_config selesai" "rc=$rc: $(printf '%s' "$out" | tail -3)"

grep -q '^\[model\.internal-qwen\]' "$cfg" \
    && no "seksi lama diganti nama" "[model.internal-qwen] masih ada sebagai seksi yatim" \
    || ok "seksi lama tidak lagi tertinggal"
grep -q '^\[model\.cooper-agent\]' "$cfg" \
    && ok "[model.cooper-agent] ada" || no "[model.cooper-agent] ada" "tidak ditemukan"
grep -q 'dev-lee@laptop-tuf' "$cfg" \
    && ok "api_key dev terbawa oleh rename" || no "api_key dev terbawa" "kunci hilang saat rename"
grep -q 'sk-ant-KUNCI-BERBAYAR-DEV' "$cfg" \
    && ok "kunci berbayar dev selamat" || no "kunci berbayar dev selamat" "TERTIMPA"
grep -q 'theme = "dracula"' "$cfg" \
    && ok "[ui] milik dev utuh" || no "[ui] milik dev utuh" "hilang"
grep -q '^\[model\.internal-qwen-localhost\]' "$cfg" \
    && ok "-localhost dibiarkan (tidak ada padanannya)" \
    || no "-localhost dibiarkan" "pemasang menghapus config yang masih bekerja"
printf '%s' "$out" | grep -q 'internal-qwen-localhost' \
    && ok "dev diberi tahu -localhost kini di luar kelolaan" \
    || no "dev diberi tahu soal -localhost" "ia tertinggal diam-diam"

bak="$(ls "$cfg".bak.* 2>/dev/null | head -1)"
if [ -n "$bak" ]; then
    grep -q '^\[model\.internal-qwen\]' "$bak" \
        && ok "cadangan merekam keadaan SEBELUM migrasi" \
        || no "cadangan merekam keadaan sebelum migrasi" "cadangan sudah ikut bermigrasi"
else
    no "cadangan dibuat" "config berubah tanpa cadangan"
fi

echo
echo "lulus $pass, gagal $fail"
[[ $fail -eq 0 ]]
