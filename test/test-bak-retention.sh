#!/usr/bin/env bash
# Uji retensi cadangan .bak.
#
# Yang dijaga bukan "berkasnya terbuang", melainkan BATASNYA: perkakas yang
# menghapus harus menolak menyentuh apa pun yang bukan miliknya. Di repo server
# pola `.bak.*` yang lebar terbukti bisa memilih berkas nyasar sebagai sasaran
# rollback; di sini taruhannya lebih besar karena yang berjalan adalah rm.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
pass=0; fail=0
ok(){ printf "  ok   %s\n" "$1"; pass=$((pass+1)); }
no(){ printf "  GAGAL %s — %s\n" "$1" "${2:-}"; fail=$((fail+1)); }

# shellcheck source=../scripts/lib/backup.sh
. "$REPO/scripts/lib/backup.sh"

siapkan() { # $1 = dir, $2.. = cap waktu
    local d="$1"; shift
    rm -rf "$d"; mkdir -p "$d"
    echo asli > "$d/config.toml"
    local t; for t in "$@"; do echo "isi $t" > "$d/config.toml.bak.$t"; done
}
ada() { [ -e "$1" ]; }

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT

echo "menyisakan yang termuda, membuang yang tertua:"
siapkan "$T/a" 20260901-101010 20260902-101010 20260903-101010 \
                20260904-101010 20260905-101010 20260906-101010 20260907-101010
BAK_KEEP=5 bak_prune "$T/a/config.toml" 2>/dev/null
n=$(find "$T/a" -name 'config.toml.bak.*' | wc -l)
[ "$n" = "5" ] && ok "sisa 5 dari 7" || no "sisa 5 dari 7" "sisa $n"
ada "$T/a/config.toml.bak.20260907-101010" && ok "yang termuda disimpan" \
    || no "yang termuda disimpan" "terbuang"
ada "$T/a/config.toml.bak.20260901-101010" && no "yang tertua dibuang" "masih ada" \
    || ok "yang tertua dibuang"
ada "$T/a/config.toml" && ok "berkas aslinya tidak disentuh" \
    || no "berkas aslinya tidak disentuh" "IKUT TERHAPUS"

echo "menolak menyentuh yang bukan cadangan bercap waktu:"
siapkan "$T/b" 20260901-101010 20260902-101010 20260903-101010 \
                20260904-101010 20260905-101010 20260906-101010
echo catatan > "$T/b/config.toml.bak.catatan"
echo lain    > "$T/b/config.toml.bak.20260101"          # cap waktu separuh
echo tetangga> "$T/b/models.yml.bak.20260101-101010"    # milik berkas lain
BAK_KEEP=5 bak_prune "$T/b/config.toml" 2>/dev/null
ada "$T/b/config.toml.bak.catatan"          && ok "'.bak.catatan' tidak disentuh" \
    || no "'.bak.catatan' tidak disentuh" "TERHAPUS"
ada "$T/b/config.toml.bak.20260101"         && ok "cap waktu separuh tidak disentuh" \
    || no "cap waktu separuh tidak disentuh" "TERHAPUS"
ada "$T/b/models.yml.bak.20260101-101010"   && ok "cadangan berkas lain tidak disentuh" \
    || no "cadangan berkas lain tidak disentuh" "TERHAPUS"

echo "tidak melakukan apa pun bila belum melewati batas:"
siapkan "$T/c" 20260901-101010 20260902-101010
BAK_KEEP=5 bak_prune "$T/c/config.toml" 2>/dev/null
n=$(find "$T/c" -name 'config.toml.bak.*' | wc -l)
[ "$n" = "2" ] && ok "2 cadangan dibiarkan" || no "2 cadangan dibiarkan" "sisa $n"

echo "dapat dimatikan sepenuhnya:"
siapkan "$T/d" 20260901-101010 20260902-101010 20260903-101010 \
                20260904-101010 20260905-101010 20260906-101010
BAK_KEEP=0 bak_prune "$T/d/config.toml" 2>/dev/null
n=$(find "$T/d" -name 'config.toml.bak.*' | wc -l)
[ "$n" = "6" ] && ok "BAK_KEEP=0 mematikan pemangkasan" || no "BAK_KEEP=0 mematikan pemangkasan" "sisa $n"

echo "tidak pernah menjatuhkan pemanggilnya (installer jalan di bawah set -e):"
# Argumen kosong, direktori tidak ada, dan nilai batas yang bukan angka: tidak
# satu pun boleh menghasilkan rc bukan-nol. Installer yang batal di tengah jalan
# karena gagal MERAPIKAN cadangan jauh lebih buruk daripada cadangan menumpuk.
( set -e; . "$REPO/scripts/lib/backup.sh"
  bak_prune ""                       >/dev/null 2>&1
  bak_prune "$T/tidak-ada/berkas"    >/dev/null 2>&1
  BAK_KEEP=abc bak_prune "$T/a/config.toml" >/dev/null 2>&1
  BAK_KEEP=-3  bak_prune "$T/a/config.toml" >/dev/null 2>&1
  exit 0 ) && ok "masukan rusak tetap rc=0" || no "masukan rusak tetap rc=0" "rc bukan-nol"

echo "kedua installer benar-benar memanggilnya:"
for f in setup.sh scripts/setup-dev.sh scripts/setup-pi.sh; do
    c=$(grep -c 'bak_prune' "$REPO/$f")
    [ "$c" -ge 1 ] && ok "$f memanggil bak_prune ($c×)" || no "$f memanggil bak_prune" "nol"
    grep -q 'lib/backup.sh' "$REPO/$f" && ok "$f men-source lib-nya" \
        || no "$f men-source lib-nya" "bak_prune akan 'command not found'"
done

echo "sisi Windows punya kembarannya:"
# Bukan uji perilaku -- PowerShell tidak ada di runner Linux, dan parse-nya
# dijaga job ps-parse. Yang dijaga di sini: kebijakannya tidak boleh hidup di
# satu platform saja, karena config dev Windows menumpuk dengan cara yang sama.
[ -r "$REPO/scripts/lib/Backup.ps1" ] && ok "scripts/lib/Backup.ps1 ada" \
    || no "scripts/lib/Backup.ps1 ada" "kebijakan hanya berlaku di Linux/macOS"
c=$(grep -c 'Invoke-CooperBakPrune' "$REPO/setup.ps1")
[ "$c" -ge 2 ] && ok "setup.ps1 memanggilnya ($c×)" || no "setup.ps1 memanggilnya" "$c×"
grep -q 'lib\\Backup.ps1' "$REPO/setup.ps1" && ok "setup.ps1 men-source lib-nya" \
    || no "setup.ps1 men-source lib-nya" "akan gagal saat dipanggil"
# Batas defaultnya harus SAMA di kedua platform; kalau tidak, dua dev dengan
# perkakas yang sama melihat hasil berbeda dan tidak ada yang tahu kenapa.
grep -q 'BAK_KEEP="${COOPERAGENT_BAK_KEEP:-5}"' "$REPO/scripts/lib/backup.sh" \
  && grep -q '\$keep = 5' "$REPO/scripts/lib/Backup.ps1" \
  && ok "batas default sama (5) di kedua platform" \
  || no "batas default sama di kedua platform" "bash dan PowerShell berbeda"

echo
echo "lulus $pass, gagal $fail"
[ "$fail" -eq 0 ]
