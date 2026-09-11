#!/usr/bin/env bash
# Buka PR dalam satu langkah: periksa judul, push, cetak tautan yang sudah terisi.
#
# KENAPA ADA. Membuat PR di repo ini butuh empat langkah manual: push, salin
# tautan dari keluaran git, buka peramban, ketik judul. Langkah keempat itulah
# yang berkali-kali salah -- GitHub mengisi judul PR SENDIRI dari subjek commit
# bila branch berisi tepat satu commit, dan subjek commit tentu berbentuk
# conventional. Hasilnya entri kembar di CHANGELOG; sudah tiga kali.
#
# `.github/workflows/pr-title.yml` menangkapnya, tetapi menangkapnya SESUDAH PR
# dibuat: cek merah, sunting judul, tunggu CI lagi. Skrip ini memindahkan
# pemeriksaan yang sama ke sebelum PR ada, lalu menyerahkan tautan yang judulnya
# sudah terisi benar -- jadi isian otomatis GitHub tidak pernah dipakai.
#
# Polanya DIBACA dari workflow, bukan disalin. Dua kebenaran yang harus dijaga
# sinkron dengan tangan adalah persis penyakit yang sedang dijaga pagar itu.
set -uo pipefail

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
WF="$ROOT/.github/workflows/pr-title.yml"
GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; NC=$'\033[0m'

JUDUL="${*:-}"
if [ -z "$JUDUL" ]; then
    echo "Pakai: ./scripts/pr.sh \"Judul deskriptif tanpa prefiks\"" >&2
    echo "  contoh: ./scripts/pr.sh \"Cadangan .bak tidak lagi menumpuk\"" >&2
    exit 2
fi

# Pola diambil dari baris `grep -qE '...'` di dalam workflow.
POLA="$(sed -n "s/.*grep -qE '\(.*\)' \/tmp\/judul.txt.*/\1/p" "$WF" | head -1)"
if [ -z "$POLA" ]; then
    echo "${RED}✘ Pola tidak terbaca dari $WF${NC}" >&2
    echo "  Pagar judul mungkin sudah berubah bentuk; perbarui skrip ini." >&2
    exit 1
fi

if printf '%s\n' "$JUDUL" | grep -qE "$POLA"; then
    echo "${RED}✘ Judul berawalan prefiks conventional-commit.${NC}" >&2
    echo "  ${DIM}$JUDUL${NC}" >&2
    cat >&2 <<'PESAN'

  GitHub menaruh judul PR ke badan merge commit, dan release-please
  membacanya sebagai commit tersendiri -- entri yang sama terbit dua kali.

  Tulis kalimat deskriptif biasa:

      fix(setup): pembaru Windows ikut bermigrasi
      -> Pembaru Windows ikut bermigrasi juga

PESAN
    exit 1
fi

BRANCH="$(git -C "$ROOT" symbolic-ref --quiet --short HEAD)" || {
    echo "${RED}✘ HEAD terlepas — pindah ke sebuah branch dulu.${NC}" >&2; exit 1; }
if [ "$BRANCH" = "main" ]; then
    echo "${RED}✘ Sedang di main.${NC} Buat branch dulu: git checkout -b <nama>" >&2
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
echo "${GREEN}✔${NC} Judul lolos pagar. Buka tautan ini — judulnya sudah terisi:"
echo
echo "  https://github.com/$SLUG/compare/main...$BRANCH?expand=1&title=$ENC"
echo
echo "${DIM}Sesudah CI hijau: merge. PR rilis mengurus dirinya sendiri.${NC}"
