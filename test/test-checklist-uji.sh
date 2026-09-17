#!/usr/bin/env bash
# Uji validator checklist di CI.
#
# Yang diuji BUKAN salinan logikanya, melainkan skrip yang benar-benar dijalankan
# GitHub Actions: berkas workflow diurai, blok `run:` diambil apa adanya, lalu
# dieksekusi di direktori berisi berkas uji palsu. Menyalin logikanya ke sini
# akan melahirkan dua kebenaran yang harus dijaga sinkron dengan tangan.
#
# Validator ini satu-satunya yang tersisa di CI untuk sisi bash, jadi bila ia
# meloloskan apa pun, tidak ada lagi yang menahan di belakangnya.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF="$REPO/.github/workflows/test.yml"
pass=0; fail=0
ok(){ printf "  ok   %s\n" "$1"; pass=$((pass+1)); }
no(){ printf "  GAGAL %s — %s\n" "$1" "${2:-}"; fail=$((fail+1)); }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
python3 - "$WF" "$TMP/checklist.sh" <<'PY' || exit 1
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
langkah = [s for s in wf["jobs"]["periksa"]["steps"] if "Checklist" in str(s.get("name", ""))]
assert len(langkah) == 1, "langkah checklist tidak ditemukan / ganda"
s = langkah[0]
open(sys.argv[2], "w").write(s["run"])
# Hanya PR yang punya body; pada push ke main langkah ini harus dilewati, bukan
# gagal atas body kosong yang memang tidak pernah ada.
assert "pull_request" in str(s.get("if", "")), "penjaga event pull_request hilang"
# Body PR ditulis manusia mana pun yang bisa membuka PR. Ia harus lewat env.
assert "BODY" in s.get("env", {}), "body tidak diteruskan lewat env"
assert "${{" not in s["run"], "ekspresi ${{ }} menempel di badan skrip — injeksi"
PY
ok "langkah checklist terurai; penjaga event dan env body ada"

# Direktori uji palsu: validatornya membaca `test/test-*.sh` dari CWD.
mkdir -p "$TMP/kerja/test"
for n in satu dua tiga; do printf '#!/usr/bin/env bash\n' > "$TMP/kerja/test/test-$n.sh"; done

jalankan(){ # $1 = body; keluar dengan rc validator
    ( cd "$TMP/kerja" && BODY="$1" bash "$TMP/checklist.sh" 2>&1 )
}
uji(){ # nama, body, harus_gagal(1/0), pola-pesan(opsional)
    local nama="$1" body="$2" harus="$3" pola="${4:-}" out rc
    out="$(jalankan "$body")"; rc=$?
    local gagal=0; [ "$rc" -ne 0 ] && gagal=1
    if [ "$gagal" != "$harus" ]; then
        no "$nama" "$([ "$harus" = 1 ] && echo 'seharusnya gagal' || echo "seharusnya lolos: $out")"
        return
    fi
    if [ -n "$pola" ] && ! printf '%s' "$out" | grep -q "$pola"; then
        no "$nama" "gagal dengan sebab yang salah: $out"
        return
    fi
    ok "$nama"
}

LENGKAP='Uji lokal (scripts/pr.sh):
- [x] test/test-satu.sh — lulus 3, gagal 0
- [x] test/test-dua.sh — LULUS
- [ ] test/test-tiga.sh — dijalankan tangan: mengunduh biner'

uji "checklist lengkap lolos" "$LENGKAP" 0
uji "satu berkas uji tak disebut ditangkap" \
    "$(printf '%s\n' "$LENGKAP" | grep -v 'test-dua')" 1 'tidak menyebut.*test-dua'
uji "uji merah ditolak, bukan dilaporkan lulus" \
    "${LENGKAP/- \[x\] test\/test-dua.sh — LULUS/- [!] test/test-dua.sh — GAGAL}" 1 'MERAH'
uji "berkas hantu ditangkap" \
    "$LENGKAP
- [x] test/test-tidak-ada.sh — lulus 9, gagal 0" 1 'tidak ada'
uji "body kosong ditolak" "" 1 'tidak menyebut'
# Checklist yang disalin dari PR lain menyebut berkas yang benar tetapi juga
# berkas yang sudah dihapus; keduanya harus terlihat sekaligus.
uji "checklist basi disebut seluruhnya" \
    "$(printf '%s\n' "$LENGKAP" | grep -v 'test-satu')
- [x] test/test-lama.sh — lulus 1, gagal 0" 1 'test-satu'

echo "pr.sh menanam checklist ke pesan commit:"
# Kotak pasir ini SENGAJA punya direktori test/, dan itulah bedanya dengan kotak
# pasir di test-pr-title-guard.sh. Tanpa test/, pr.sh melewati seluruh jalur
# penanaman -- dan jalur itulah yang pernah rusak diam-diam pada 17 September
# 2026: variabel BLOK diteruskan sebagai ARGUMEN alih-alih env, python3 melempar
# KeyError, `2>/dev/null` menelannya, dan pr.sh mem-push dengan body PR kosong
# sambil mencetak peringatan yang menuduh python3.
PR_SH="$REPO/scripts/pr.sh"
if [ -f "$PR_SH" ] && command -v python3 >/dev/null 2>&1; then
    SBX="$(mktemp -d)"
    mkdir -p "$SBX/scripts/lib" "$SBX/.github/workflows" "$SBX/test"
    cp "$PR_SH" "$SBX/scripts/pr.sh"
    cp "$REPO/scripts/lib/uji_lokal.sh" "$SBX/scripts/lib/"
    cp "$REPO/.github/workflows/pr-title.yml" "$SBX/.github/workflows/"
    printf '#!/usr/bin/env bash\necho "lulus 4, gagal 0"\n' > "$SBX/test/test-contoh.sh"
    git -C "$SBX" init -q -b main
    git -C "$SBX" config user.email u@e; git -C "$SBX" config user.name u
    git -C "$SBX" add -A; git -C "$SBX" commit -q -m awal
    git -C "$SBX" checkout -q -b cabang-uji
    printf 'perubahan nyata\n' > "$SBX/berkas.txt"
    git -C "$SBX" add berkas.txt
    git -C "$SBX" commit -q -F - <<'PESAN'
fix(uji): subjek conventional

Badan commit yang harus selamat.

Co-Authored-By: Seseorang <a@b>
PESAN

    ( cd "$SBX" && bash scripts/pr.sh >/dev/null 2>&1 )
    PESAN_BARU="$(git -C "$SBX" log --format=%B -1 HEAD)"

    printf '%s' "$PESAN_BARU" | grep -q -- '- \[x\] test/test-contoh.sh — lulus 4, gagal 0' \
        && ok "checklist ditanam ke pesan commit" \
        || no "checklist ditanam" "body PR akan kosong dan validator CI menolaknya"
    printf '%s' "$PESAN_BARU" | grep -q 'Badan commit yang harus selamat' \
        && ok "badan commit asli selamat" || no "badan commit" "prosa hilang saat penanaman"
    printf '%s' "$PESAN_BARU" | head -1 | grep -q '^fix(uji): subjek conventional$' \
        && ok "subjek tidak tersentuh" || no "subjek" "judul PR ikut berubah"
    # Trailer harus tetap baris terakhir; release-please dan git membacanya dari
    # sana, dan checklist yang mendarat sesudahnya memutus keduanya.
    printf '%s' "$PESAN_BARU" | grep -v '^$' | tail -1 | grep -q '^Co-Authored-By:' \
        && ok "trailer tetap di baris terakhir" || no "trailer" "checklist mendarat sesudah trailer"

    # Dijalankan dua kali tidak boleh menumpuk blok.
    ( cd "$SBX" && bash scripts/pr.sh >/dev/null 2>&1 )
    n="$(git -C "$SBX" log --format=%B -1 HEAD | grep -c -- '- \[x\] test/test-contoh.sh')"
    [ "$n" = 1 ] && ok "dijalankan ulang memperbarui, bukan menumpuk" \
                 || no "idempoten" "blok checklist muncul $n kali"
    # Dan yang menangkap bug aslinya: sukses dilaporkan dari HASIL, bukan dari
    # niat. Amend dipatahkan dengan mengunci penyimpanan objek git -- commit
    # barunya tidak bisa ditulis, jadi pesan commit TIDAK berubah. pr.sh harus
    # berhenti dan mengatakannya, bukan mencetak centang lalu mem-push.
    #
    # Polanya dicocokkan TANPA simbol centang: keluaran pr.sh menyisipkan kode
    # warna di antaranya, dan pola yang memuat simbol itu tidak akan pernah cocok
    # -- ia lalu "lulus" atas keluaran apa pun, termasuk keluaran yang salah.
    SEBELUM="$(git -C "$SBX" log --format=%B -1 HEAD)"
    chmod -R a-w "$SBX/.git/objects"
    out="$( cd "$SBX" && bash scripts/pr.sh 2>&1 )"; rc=$?
    chmod -R u+w "$SBX/.git/objects"

    printf '%s' "$out" | grep -q 'checklist uji ditanam' \
        && no "amend gagal tidak dicentang" "pr.sh melaporkan sukses atas amend yang tidak terjadi" \
        || ok "amend gagal tidak dicentang"
    [ "$rc" -ne 0 ] && ok "keluar dengan kode galat saat amend gagal" \
                    || no "kode keluar saat amend gagal" "rc=0"
    printf '%s' "$out" | grep -q 'push cabang-uji -> origin' \
        && no "berhenti sebelum push saat amend gagal" "ia tetap mem-push" \
        || ok "berhenti sebelum push saat amend gagal"
    [ "$(git -C "$SBX" log --format=%B -1 HEAD)" = "$SEBELUM" ] \
        && ok "pesan commit memang tidak berubah (injeksinya nyata)" \
        || no "injeksi kegagalan" "amend ternyata berhasil — ujinya tidak menguji apa pun"
    rm -rf "$SBX"
else
    printf "  \033[33m—\033[0m pr.sh/python3 tidak ada; penanaman checklist tidak diuji\n"
fi

echo
echo "lulus $pass, gagal $fail"
[[ $fail -eq 0 ]]
