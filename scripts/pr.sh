#!/usr/bin/env bash
# Jalankan suite, push, lalu cetak tautan PR yang sudah terisi.
#
# KENAPA ADA. Membuat PR butuh empat langkah manual: jalankan uji, push, salin
# tautan dari keluaran git, buka peramban. Skrip ini menjadikannya satu.
#
# TIDAK ADA ATURAN JUDUL. Pada 17 September 2026 release-please dilepas, dan
# bersamanya seluruh alasan judul PR harus berbentuk tertentu. Versi kini
# dinaikkan dengan tangan lewat `git tag`, jadi tidak ada mesin yang membaca
# judul PR dan tidak ada yang bisa digandakannya. Tulis judul yang jelas bagi
# manusia; itu saja syaratnya.
#
# Branch berisi satu commit tetap dianjurkan, karena GitHub lalu mengisi judul
# DAN body PR dari commit itu -- tidak ada yang perlu diketik. Tapi ini anjuran,
# bukan gerbang: dua commit atau lebih hanya berarti Anda mengisi judulnya
# sendiri di peramban.
set -uo pipefail

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; NC=$'\033[0m'

BRANCH="$(git -C "$ROOT" symbolic-ref --quiet --short HEAD)" || {
    echo "${RED}✘ HEAD terlepas — pindah ke sebuah branch dulu.${NC}" >&2; exit 1; }
if [ "$BRANCH" = "main" ]; then
    echo "${RED}✘ Sedang di main.${NC} Buat branch dulu: git checkout -b <nama>" >&2
    exit 1
fi

# Disegarkan dulu: `origin/main` yang basi membuat hitungan di bawah mengembang.
# Gagal (offline) tidak fatal; ref yang ada dipakai.
git -C "$ROOT" fetch -q origin main 2>/dev/null || true
BASIS=main
git -C "$ROOT" rev-parse --verify --quiet origin/main >/dev/null && BASIS=origin/main

N="$(git -C "$ROOT" rev-list --count "$BASIS..HEAD" 2>/dev/null || echo 0)"
if [ "$N" = 0 ]; then
    echo "${RED}✘ Tidak ada commit di atas $BASIS — tidak ada yang di-PR-kan.${NC}" >&2
    exit 1
fi
if [ "$N" = 1 ]; then
    echo "${DIM}judul & body PR akan terisi dari commit: $(git -C "$ROOT" log --format=%s -1 HEAD)${NC}"
else
    echo "${YEL}!${NC} Branch berisi $N commit — GitHub akan memakai nama branch sebagai judul."
    echo "  ${DIM}Tulis judulnya sendiri di peramban, atau gabungkan: git rebase -i $BASIS${NC}"
fi

if [ -n "$(git -C "$ROOT" status --porcelain)" ]; then
    echo "${YEL}!${NC} Ada perubahan yang belum di-commit — PR tidak akan memuatnya."
    git -C "$ROOT" status --short | sed 's/^/    /'
    echo
fi

# Suite dijalankan DI SINI, bukan di CI. Hasilnya dicetak ke terminal supaya
# bisa disalin ke badan commit atau PR sebagai bukti -- tidak ada mesin yang
# menuntutnya, dan tidak ada yang menanamnya diam-diam ke pesan commit Anda.
if [ -d "$ROOT/test" ]; then
    . "$ROOT/scripts/lib/uji_lokal.sh"
    RINGKAS="$(mktemp)"
    echo "${DIM}menjalankan suite uji lokal${NC}"
    if ! ( cd "$ROOT" && uji_lokal_jalankan "$RINGKAS" ); then
        echo
        echo "${RED}✘ Tidak di-push${NC} — ada uji yang merah di atas."
        rm -f "$RINGKAS"
        exit 1
    fi
    rm -f "$RINGKAS"
fi

echo "${DIM}push $BRANCH -> origin${NC}"
COOPER_UJI_SUDAH="$(git -C "$ROOT" rev-parse HEAD)" \
    git -C "$ROOT" push -u --force-with-lease origin "$BRANCH" || exit 1

# Remote bisa berbentuk SSH atau HTTPS; keduanya diringkas ke <pemilik>/<repo>.
REMOTE="$(git -C "$ROOT" remote get-url origin)"
SLUG="$(printf '%s' "$REMOTE" | sed -e 's#^git@[^:]*:##' -e 's#^https\?://[^/]*/##' -e 's#\.git$##')"

echo
echo "${GREEN}✔${NC} Buka tautan ini:"
echo
echo "  https://github.com/$SLUG/compare/main...$BRANCH?expand=1"
echo
echo "${DIM}Create pull request → merge. Rilis: lihat docs/versioning.md.${NC}"
