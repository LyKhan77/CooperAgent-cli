#!/usr/bin/env bash
# Buka PR dalam satu langkah: periksa judul, jalankan suite, push, cetak tautan.
#
# KENAPA ADA. Repo ini memakai squash merge, jadi judul PR menjadi SUBJEK commit
# di `main` -- satu-satunya yang dibaca release-please. Judul tanpa prefiks
# conventional berarti perubahan terbit tanpa entri CHANGELOG dan tanpa kenaikan
# versi, dan tidak ada yang merah di layar saat itu terjadi.
#
# JUDULNYA TIDAK DITERIMA SEBAGAI ARGUMEN, dan itu disengaja. Yang menentukan
# judul PR adalah isian otomatis GitHub, dan pada branch berisi tepat satu commit
# isian itu diambil dari SUBJEK COMMIT. Judul yang dititipkan lewat argumen atau
# query string hanya akan berbeda dari yang sebenarnya terpakai -- pemeriksaan
# yang memeriksa hal lain dari yang berlaku lebih buruk daripada tidak ada
# pemeriksaan. Ganti judul = `git commit --amend`.
#
# Karena alasan yang sama branch WAJIB berisi tepat satu commit: pada dua atau
# lebih, GitHub memakai nama branch sebagai judul.
#
# Polanya DIBACA dari .github/workflows/pr-title.yml, bukan disalin. Dua
# kebenaran yang harus dijaga sinkron dengan tangan adalah persis penyakit yang
# sedang dijaga pagar itu.
set -uo pipefail

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
WF="$ROOT/.github/workflows/pr-title.yml"
GREEN=$'\033[32m'; RED=$'\033[31m'; YEL=$'\033[33m'; DIM=$'\033[2m'; NC=$'\033[0m'

if [ "$#" -gt 0 ]; then
    echo "${RED}✘ pr.sh tidak menerima argumen judul.${NC}" >&2
    echo "  Judul PR diisi GitHub dari SUBJEK COMMIT; judul lain hanya akan berbeda" >&2
    echo "  dari yang benar-benar terpakai. Untuk menggantinya:" >&2
    echo "    ${DIM}git commit --amend${NC}" >&2
    exit 2
fi

BRANCH="$(git -C "$ROOT" symbolic-ref --quiet --short HEAD)" || {
    echo "${RED}✘ HEAD terlepas — pindah ke sebuah branch dulu.${NC}" >&2; exit 1; }
if [ "$BRANCH" = "main" ]; then
    echo "${RED}✘ Sedang di main.${NC} Buat branch dulu: git checkout -b <nama>" >&2
    exit 1
fi

# Disegarkan dulu: `origin/main` yang basi membuat hitungan di bawah MENGEMBANG
# -- commit yang sudah di-merge orang lain ikut terhitung, dan branch satu commit
# ditolak seolah berisi banyak. Gagal (offline) tidak fatal; ref yang ada dipakai.
git -C "$ROOT" fetch -q origin main 2>/dev/null || true
BASIS=main
git -C "$ROOT" rev-parse --verify --quiet origin/main >/dev/null && BASIS=origin/main

N="$(git -C "$ROOT" rev-list --count "$BASIS..HEAD" 2>/dev/null || echo 0)"
case "$N" in
    1) ;;
    0) echo "${RED}✘ Tidak ada commit di atas $BASIS — tidak ada yang di-PR-kan.${NC}" >&2
       exit 1 ;;
    *) echo "${RED}✘ Branch ini berisi $N commit; harus tepat satu.${NC}" >&2
       echo "  GitHub akan mengisi judul PR dari NAMA BRANCH, yang tidak conventional." >&2
       echo "  Gabungkan dulu:  ${DIM}git rebase -i $BASIS${NC}  atau  ${DIM}git reset --soft $BASIS && git commit${NC}" >&2
       exit 1 ;;
esac

JUDUL="$(git -C "$ROOT" log --format=%s -1 HEAD)"
echo "${DIM}judul dari subjek commit: $JUDUL${NC}"

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

  Perbaiki subjeknya:  git commit --amend

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

# Suite dijalankan DI SINI, bukan di CI, lalu hasilnya ditanam ke pesan commit.
# Pesan commit itu menjadi body PR lewat isian otomatis GitHub, dan dari sanalah
# CI memeriksa kelengkapan checklistnya. Satu berkas uji baru yang tidak pernah
# dijalankan karena itu tidak bisa lolos diam-diam.
CHECKLIST=""
if [ -d "$ROOT/test" ]; then
    . "$ROOT/scripts/lib/uji_lokal.sh"
    BLOK="$(mktemp)"
    echo "${DIM}menjalankan suite uji lokal${NC}"
    if ! ( cd "$ROOT" && uji_lokal_jalankan "$BLOK" ); then
        echo
        echo "${RED}✘ Tidak di-push${NC} — ada uji yang merah di atas."
        rm -f "$BLOK"
        exit 1
    fi
    CHECKLIST="$BLOK"
fi

if [ -n "$CHECKLIST" ]; then
    # Blok lama dibuang lebih dulu, jadi menjalankan ulang pr.sh memperbarui
    # hasilnya alih-alih menumpuknya. Ditanam SEBELUM trailer, karena trailer
    # (Co-Authored-By dan kawannya) harus tetap menjadi baris terakhir.
    PESAN_BARU="$(mktemp)"; GALAT="$(mktemp)"
    # BLOK lewat ENV, bukan sebagai argumen sesudah `-c`: yang ditaruh sesudah
    # skrip menjadi sys.argv, dan os.environ["BLOK"] melempar KeyError. Terjadi
    # 17 September 2026 -- dan `2>/dev/null` menelan sebabnya, sehingga yang
    # terlihat hanya "checklist tidak dapat ditanam (python3?)" pada mesin yang
    # python3-nya baik-baik saja.
    if git -C "$ROOT" log --format=%B -1 HEAD |
       PENANDA="$UJI_PENANDA" BLOK="$CHECKLIST" python3 -c '
import os, re, sys
pesan = sys.stdin.read().rstrip("\n") + "\n"
penanda = os.environ["PENANDA"]
# Buang blok lama: baris penandanya dan setiap baris checklist sesudahnya.
baris = [b for b in pesan.split("\n")
         if b != penanda and not re.match(r"^- \[[x !]\] test/", b)]
while baris and baris[-1] == "": baris.pop()
blok = open(os.environ["BLOK"]).read().rstrip("\n")
# Trailer harus tetap terakhir.
i = len(baris)
while i > 0 and re.match(r"^[A-Za-z][A-Za-z-]*: ", baris[i-1]): i -= 1
if i < len(baris):
    keluar = baris[:i] + [blok, ""] + baris[i:]
else:
    keluar = baris + ["", blok]
sys.stdout.write("\n".join(keluar).rstrip("\n") + "\n")
' > "$PESAN_BARU" 2>"$GALAT" && [ -s "$PESAN_BARU" ]; then
        # --no-verify: yang berubah hanya PESAN, dan isinya sudah dipindai saat
        # commit aslinya dibuat. --allow-empty: commit tanpa perubahan berkas
        # tetap punya pesan yang perlu diperbarui.
        git -C "$ROOT" commit -q --amend --allow-empty -F "$PESAN_BARU" --no-verify 2>>"$GALAT"
        # Diperiksa dari HASILNYA, bukan dari kode keluar perintahnya. Pada
        # 17 September 2026 amend ditolak git ("would make it empty") sementara
        # pr.sh tetap mencetak tanda centang -- melapor sukses berdasarkan niat,
        # persis yang dilarang AGENTS.md.
        #
        # Dan dibandingkan dengan pesan yang DIMAKSUD, bukan sekadar dicari
        # penandanya: pada jalan kedua commit sudah memuat penanda dari jalan
        # pertama, sehingga pencarian penanda meloloskan amend yang gagal.
        if diff -q <(git -C "$ROOT" log --format=%B -1 HEAD | sed -e :a -e '/^$/{$d;N;ba' -e '}') \
                   <(sed -e :a -e '/^$/{$d;N;ba' -e '}' "$PESAN_BARU") >/dev/null 2>&1; then
            echo "${GREEN}✔${NC} checklist uji ditanam ke pesan commit"
            rm -f "$PESAN_BARU" "$GALAT" "$CHECKLIST"
        else
            echo "${RED}✘ Amend tidak mengubah pesan commit — tidak di-push.${NC}" >&2
            sed 's/^/    /' "$GALAT" >&2
            rm -f "$PESAN_BARU" "$GALAT" "$CHECKLIST"
            exit 1
        fi
    else
        echo "${RED}✘ Checklist gagal ditanam ke pesan commit — tidak di-push.${NC}" >&2
        sed 's/^/    /' "$GALAT" >&2
        echo "  Body PR tanpa checklist pasti ditolak validator CI; mem-push-nya" >&2
        echo "  hanya memindahkan kegagalan ke tempat yang lebih lambat terlihat." >&2
        rm -f "$PESAN_BARU" "$GALAT" "$CHECKLIST"
        exit 1
    fi
fi

echo "${DIM}push $BRANCH -> origin${NC}"
COOPER_UJI_SUDAH="$(git -C "$ROOT" rev-parse HEAD)" \
    git -C "$ROOT" push -u --force-with-lease origin "$BRANCH" || exit 1

# Remote bisa berbentuk SSH atau HTTPS; keduanya diringkas ke <pemilik>/<repo>.
REMOTE="$(git -C "$ROOT" remote get-url origin)"
SLUG="$(printf '%s' "$REMOTE" | sed -e 's#^git@[^:]*:##' -e 's#^https\?://[^/]*/##' -e 's#\.git$##')"

echo
echo "${GREEN}✔${NC} Buka tautan ini — judul dan body sudah terisi dari commit:"
echo
echo "  https://github.com/$SLUG/compare/main...$BRANCH?expand=1"
echo
echo "${DIM}Create pull request → CI hijau → Squash and merge.${NC}"
