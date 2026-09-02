#!/usr/bin/env bash
# Menjaga satu janji: keluaran skrip terbaca di tempat ia benar-benar dibaca.
#
# Ini bukan soal estetika. Terukur 2 September 2026: satu jalankan `setup.sh`
# yang diarahkan ke berkas menulis 17 baris ber-`^[[0;32m`. Itu justru terjadi
# saat dev menyalin log untuk MELAPORKAN masalah -- yaitu saat keterbacaan
# paling dibutuhkan. Beberapa log yang dikirim ke pemilik gateway memang tampak
# begitu.
#
# Tiga aturan, masing-masing diuji sendiri:
#   1. warna hanya ke terminal            (`[ -t 1 ]`)
#   2. NO_COLOR dan TERM=dumb dihormati   (no-color.org)
#   3. simbol Unicode hanya bila locale-nya UTF-8; selain itu ASCII
#
# Aturan 3 ada karena `✔` di konsol non-UTF-8 menjadi mojibake, dan tanda
# "berhasil" yang tampak rusak lebih buruk daripada `[v]` yang polos.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
FAIL=0
ok(){  printf "  \033[32m✔\033[0m %s\n" "$*"; }
bad(){ printf "  \033[31m✘\033[0m %s\n" "$*"; FAIL=1; }

# Jalankan setup.sh sampai selesai pada HOME sekali pakai. Jawaban `4` memilih
# mode manual: ia menyentuh semua jalur pencetakan tanpa memasang apa pun.
run_setup() { # $1 = berkas keluaran, sisanya = env tambahan
    local out="$1"; shift
    local h; h="$(mktemp -d -p "$T")"
    printf '4\n\nuji\nmesin\nN\n' \
        | env HOME="$h" COOPERAGENT_GATEWAY="http://127.0.0.1:1" "$@" \
          timeout 40 bash "$REPO/setup.sh" > "$out" 2>&1
}

echo $'\033[1mKeluaran dialihkan ke berkas:\033[0m'
run_setup "$T/redir.txt"
n="$(grep -c $'\033' "$T/redir.txt" || true)"
[ "$n" = 0 ] && ok "tidak ada kode escape ANSI (0 baris)" \
             || bad "$n baris masih memuat kode escape"

grep -q '✔' "$T/redir.txt" \
    && ok "simbol UTF-8 tetap dipakai — locale mendukungnya" \
    || bad "simbol UTF-8 hilang padahal locale UTF-8"

echo
echo $'\033[1mLocale bukan UTF-8:\033[0m'
run_setup "$T/ascii.txt" LANG=C LC_ALL=C
grep -q '\[v\]' "$T/ascii.txt" \
    && ok "jatuh ke penanda ASCII [v]" \
    || bad "tidak jatuh ke ASCII"
grep -q '✔' "$T/ascii.txt" \
    && bad "masih mencetak simbol UTF-8 di locale C" \
    || ok "tidak ada simbol UTF-8 yang tersisa"

echo
echo $'\033[1mBendera eksplisit:\033[0m'
# `--ascii` harus menang atas locale yang mendukung UTF-8. Ia ada untuk terminal
# yang MENGAKU mampu padahal tidak -- kasus yang tidak bisa dideteksi.
h="$(mktemp -d -p "$T")"
printf '4\n\nuji\nmesin\nN\n' | HOME="$h" COOPERAGENT_GATEWAY="http://127.0.0.1:1" \
    timeout 40 bash "$REPO/setup.sh" --ascii > "$T/flag.txt" 2>&1
grep -q '\[v\]' "$T/flag.txt" && ! grep -q '✔' "$T/flag.txt" \
    && ok "--ascii memaksa ASCII meski locale UTF-8" \
    || bad "--ascii tidak berpengaruh"

# setup-dev.sh memakai aturan yang sama; kalau keduanya menyimpang, salah satu
# akan mengejutkan dev yang menjalankan keduanya berurutan.
echo
echo $'\033[1msetup-dev.sh mengikuti aturan yang sama:\033[0m'
bash "$REPO/scripts/setup-dev.sh" --dry-run > "$T/dev.txt" 2>&1
n="$(grep -c $'\033' "$T/dev.txt" || true)"
[ "$n" = 0 ] && ok "tidak ada kode escape saat dialihkan" \
             || bad "$n baris ber-escape"
LANG=C LC_ALL=C bash "$REPO/scripts/setup-dev.sh" --dry-run > "$T/devc.txt" 2>&1
grep -q '✔' "$T/devc.txt" \
    && bad "masih mencetak UTF-8 di locale C" \
    || ok "jatuh ke ASCII di locale C"

# Penjaga sumber: `\u` menuntut bash 4.2, sedangkan /bin/bash bawaan macOS masih
# 3.2 -- dan skrip ini menyebut dirinya berjalan di Linux DAN macOS.
echo
echo $'\033[1mKecocokan bash 3.2 (macOS):\033[0m'
# Baris komentar dikecualikan: yang menjelaskan KENAPA `\u` dihindari justru
# harus menyebutnya, dan penjaga yang menangkap dokumentasinya sendiri hanya
# mengajari orang untuk mematikannya.
UHITS=""
for f in setup.sh scripts/setup-dev.sh; do
    while IFS= read -r line; do
        case "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')" in \#*) continue ;; esac
        printf '%s' "$line" | grep -qE '\\u[0-9a-fA-F]{4}' && UHITS="$UHITS $f"
    done < "$REPO/$f"
done
[ -z "$UHITS" ] && ok "tidak ada escape \\u — literal UTF-8 dipakai langsung" \
                || bad "escape \\u (butuh bash 4.2) di:$UHITS"

echo
if [ "$FAIL" = 0 ]; then
    printf "  \033[32mLULUS\033[0m — keluaran terbaca di berkas, pipa, dan konsol non-UTF-8\n"
else
    printf "  \033[31mGAGAL\033[0m\n"
fi
exit "$FAIL"
