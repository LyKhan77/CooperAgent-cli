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

WAJIB="cooper-agent cooper-s1 cooper-s2"

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
    for n in s1 s2; do
        grep -q "upstream/$n" "$ROOT/$f" \
            || no "$f menyebut upstream/$n" "tidak ada"
    done
done
ok "kelima sumber menyebut /upstream/s1 dan /upstream/s2"

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

echo
echo "lulus $pass, gagal $fail"
[[ $fail -eq 0 ]]
