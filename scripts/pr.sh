#!/usr/bin/env bash
# Buka PR dalam satu langkah: periksa judul, push, cetak tautan yang sudah terisi.
#
# KENAPA ADA. Repo ini memakai squash merge, jadi judul PR menjadi SUBJEK commit
# di `main` -- satu-satunya yang dibaca release-please. Judul tanpa prefiks
# conventional berarti perubahan terbit tanpa entri CHANGELOG dan tanpa kenaikan
# versi, dan tidak ada yang merah di layar saat itu terjadi.
#
# `.github/workflows/pr-title.yml` menangkapnya, tetapi menangkapnya SESUDAH PR
# dibuat: cek merah, sunting judul, tunggu CI lagi. Skrip ini memindahkan
# pemeriksaan yang sama ke sebelum PR ada.
#
# Judulnya boleh TIDAK diisi. Bila branch berisi tepat satu commit, subjek
# commit itu dipakai -- persis yang akan diisi GitHub sendiri, jadi yang
# diperiksa di sini adalah judul yang benar-benar akan terpakai.
#
# Polanya DIBACA dari workflow, bukan disalin. Dua kebenaran yang harus dijaga
# sinkron dengan tangan adalah persis penyakit yang sedang dijaga pagar itu.
set -uo pipefail

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
WF="$ROOT/.github/workflows/pr-title.yml"
GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; NC=$'\033[0m'

BRANCH="$(git -C "$ROOT" symbolic-ref --quiet --short HEAD)" || {
    echo "${RED}✘ HEAD terlepas — pindah ke sebuah branch dulu.${NC}" >&2; exit 1; }
if [ "$BRANCH" = "main" ]; then
    echo "${RED}✘ Sedang di main.${NC} Buat branch dulu: git checkout -b <nama>" >&2
    exit 1
fi

# Basis pembanding: `origin/main` bila ada, `main` lokal bila tidak. Yang dihitung
# adalah commit yang akan dibawa PR, bukan seluruh riwayat branch.
# Disegarkan dulu: `origin/main` yang basi membuat hitungan di bawah MENGEMBANG
# -- commit yang sudah di-merge orang lain ikut terhitung, dan branch satu commit
# ditolak seolah berisi banyak. Gagal (offline) tidak fatal; ref yang ada dipakai.
git -C "$ROOT" fetch -q origin main 2>/dev/null || true
BASIS=main
git -C "$ROOT" rev-parse --verify --quiet origin/main >/dev/null && BASIS=origin/main

JUDUL="${*:-}"
if [ -z "$JUDUL" ]; then
    N="$(git -C "$ROOT" rev-list --count "$BASIS..HEAD" 2>/dev/null || echo 0)"
    case "$N" in
        1) JUDUL="$(git -C "$ROOT" log --format=%s -1 HEAD)"
           echo "${DIM}judul dari subjek commit: $JUDUL${NC}" ;;
        0) echo "${RED}✘ Tidak ada commit di atas $BASIS — tidak ada yang di-PR-kan.${NC}" >&2
           exit 1 ;;
        *) echo "${RED}✘ Branch ini berisi $N commit.${NC}" >&2
           echo "  GitHub akan mengisi judul PR dari NAMA BRANCH, yang tidak conventional." >&2
           echo "  Beri judulnya sendiri, atau gabungkan commit-nya menjadi satu:" >&2
           echo "    ./scripts/pr.sh \"tipe(cakupan): ringkasan perubahan\"" >&2
           exit 1 ;;
    esac
fi

# Pola diambil dari baris `grep -qE '...'` di dalam workflow.
POLA="$(sed -n "s/.*grep -qE '\(.*\)' \/tmp\/judul.txt.*/\1/p" "$WF" | head -1)"
if [ -z "$POLA" ]; then
    echo "${RED}✘ Pola tidak terbaca dari $WF${NC}" >&2
    echo "  Pagar judul mungkin sudah berubah bentuk; perbarui skrip ini." >&2
    exit 1
fi

if ! printf '%s\n' "$JUDUL" | grep -qE "$POLA"; then
    echo "${RED}✘ Judul tidak berawalan prefiks conventional-commit.${NC}" >&2
    echo "  ${DIM}$JUDUL${NC}" >&2
    cat >&2 <<'PESAN'

  Squash merge membuat judul ini menjadi subjek commit di `main`, dan
  release-please hanya membaca yang berprefiks. Tanpa prefiks, perubahan
  terbit tanpa entri CHANGELOG dan tanpa kenaikan versi.

  Tulis dengan prefiks yang sesuai:

      Retensi cadangan .bak di kedua installer
      -> fix(setup): retensi cadangan .bak di kedua installer

PESAN
    exit 1
fi

if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
    echo "${YEL}!${NC} Ada perubahan yang belum di-commit — PR tidak akan memuatnya."
    git -C "$ROOT" status --short | sed 's/^/    /'
    echo
fi

echo "${DIM}push $BRANCH -> origin${NC}"
git -C "$ROOT" push -u origin "$BRANCH" || exit 1

# Remote bisa berbentuk SSH atau HTTPS; keduanya diringkas ke <pemilik>/<repo>.
REMOTE="$(git -C "$ROOT" remote get-url origin)"
SLUG="$(printf '%s' "$REMOTE" | sed -e 's#^git@[^:]*:##' -e 's#^https\?://[^/]*/##' -e 's#\.git$##')"

# Judul di-URL-encode supaya spasi dan tanda baca selamat.
ENC="$(JUDUL="$JUDUL" python3 -c \
    'import os,urllib.parse;print(urllib.parse.quote(os.environ["JUDUL"], safe=""))' 2>/dev/null)"
[ -n "$ENC" ] || ENC="$(printf '%s' "$JUDUL" | sed 's/ /%20/g')"

echo
echo "${GREEN}✔${NC} Judul lolos pagar. Buka tautan ini:"
echo
echo "  https://github.com/$SLUG/compare/main...$BRANCH?expand=1&title=$ENC"
echo
echo "${DIM}Judul dan body sudah terisi. Sesudah CI hijau: Squash and merge.${NC}"
