#!/usr/bin/env bash
# Uji pagar judul PR.
#
# Yang diuji BUKAN salinan regexnya, melainkan skrip yang benar-benar dijalankan
# GitHub Actions: berkas workflow diurai, blok `run:` diambil apa adanya, lalu
# dieksekusi. Menyalin polanya ke sini akan melahirkan dua kebenaran yang harus
# dijaga sinkron dengan tangan -- kelas kegagalan yang berkali-kali menggigit
# repo ini, dan yang justru sedang dijaga oleh pagar itu sendiri.
#
# Polaritasnya DIBALIK pada 17 September 2026 bersama perpindahan ke squash
# merge: judul PR kini menjadi subjek commit di `main`, jadi prefiks conventional
# WAJIB ada, bukan dilarang. Keenam judul yang dulu harus ditolak kini harus
# lolos -- dan itu bukan pelonggaran: judul deskriptif yang dulu benar sekarang
# membuat release-please tidak melihat apa pun.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WF="$REPO/.github/workflows/pr-title.yml"
pass=0; fail=0
ok(){ printf "  ok   %s\n" "$1"; pass=$((pass+1)); }
no(){ printf "  GAGAL %s — %s\n" "$1" "${2:-}"; fail=$((fail+1)); }

[[ -r "$WF" ]] || { echo "workflow tidak ada: $WF"; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
python3 - "$WF" "$TMP/check.sh" <<'PY' || exit 1
import sys, yaml
wf = yaml.safe_load(open(sys.argv[1]))
job = wf["jobs"]["periksa"]
open(sys.argv[2], "w").write(job["steps"][0]["run"])
# Pagar strukturnya, bukan hanya isinya: sekali `edited` hilang, judul yang
# sudah diperbaiki tidak pernah diperiksa ulang dan ceknya menggantung merah.
assert "edited" in wf[True]["pull_request"]["types"], "pemicu 'edited' hilang"
# Dan sekali pengecualian release-please hilang, setiap rilis ikut terblokir.
assert "release-please--" in job["if"], "pengecualian release-please hilang"
PY
ok "workflow terurai; pemicu 'edited' dan pengecualian release-please ada"

uji(){ # judul, harus_ditolak(1/0)
    local judul="$1" harus="$2" rc
    JUDUL="$judul" bash "$TMP/check.sh" >/dev/null 2>&1; rc=$?
    local ditolak=0; [[ $rc -ne 0 ]] && ditolak=1
    if [[ "$ditolak" == "$harus" ]]; then
        ok "$([[ $harus == 1 ]] && echo 'ditolak' || echo 'lolos  ') — $judul"
    else
        no "$judul" "$([[ $harus == 1 ]] && echo 'seharusnya ditolak' || echo 'seharusnya lolos')"
    fi
}

echo "judul conventional — inilah yang dibaca release-please:"
uji "feat(setup): retensi cadangan .bak di kedua installer"   0
uji "docs(ops-02): prosa kembali ke satu arsip"               0
uji "docs: buang entri kembar di seksi CHANGELOG v2.1.0"      0
uji "refactor!: pensiunkan jalur render lama"                 0
uji "feat(setup)!: satu profil model untuk ketiga harness"      0   # MAJOR
uji "fix: sesuatu"                                            0
uji "chore(main): release 3.1.2"                              0   # PR rilis

echo "judul tanpa prefiks — release-please tidak akan melihat apa pun:"
uji "Cadangan .bak tidak lagi menumpuk selamanya"             1
# Ini isian otomatis GitHub saat branch berisi DUA commit atau lebih: nama
# branch, bukan subjek commit. Satu-satunya jebakan yang tersisa di bawah
# squash, dan satu-satunya alasan pagar ini masih ada.
uji "Refactor/pensiunkan jalur render lama"                   1
uji "Satu pintu menuju produksi: jalur render lama dipensiunkan" 1
# `Perbaikan:` dan `Fitur baru:` BUKAN tipe conventional-commit. Keduanya ada di
# sini supaya tidak ada yang melonggarkan regexnya menjadi "apa pun sebelum
# titik dua" -- yang akan meloloskan judul yang release-please tetap abaikan.
uji "Perbaikan: cadangan rollback dipilih dari nama"          1
uji "Fitur baru: retensi cadangan"                            1

echo "scripts/pr.sh memakai pagar yang SAMA, bukan salinannya:"
# Pemeriksaan lokal yang polanya disalin akan menyimpang dari CI tanpa ada yang
# tahu, lalu memberi lampu hijau pada judul yang ditolak di server -- persis
# jenis selisih yang pagar ini ada untuk mencegahnya.
PR_SH="$REPO/scripts/pr.sh"
if [ -f "$PR_SH" ]; then
    grep -q "feat|fix|docs|chore" "$PR_SH" \
        && no "pr.sh tidak menyalin pola" "polanya dipatok di dalam skrip" \
        || ok "pr.sh membaca pola dari workflow, tidak menyalinnya"

    # Yang dijalankan di repo INI hanyalah kasus yang DITOLAK -- ia berhenti
    # sebelum menyentuh remote. Kasus yang lolos berlanjut ke `git push`, jadi
    # ia hanya boleh dijalankan di kotak pasir; uji yang mem-push branch yang
    # sedang dikerjakan adalah uji yang tidak bisa dijalankan dengan tenang, dan
    # yang tidak bisa dijalankan dengan tenang lama-lama tidak dijalankan.
    out="$("$PR_SH" "Judul deskriptif tanpa prefiks" 2>&1)"; rc=$?
    [ "$rc" -ne 0 ] && ok "pr.sh menolak judul tanpa prefiks sebelum push" \
                    || no "pr.sh menolak judul tanpa prefiks" "ia meloloskannya (rc=0)"
    printf '%s' "$out" | grep -q 'git push' \
        && no "pr.sh menolak SEBELUM push" "ia sempat push lebih dulu" \
        || ok "pr.sh menolak SEBELUM menyentuh remote"

    SBX="$(mktemp -d)"
    mkdir -p "$SBX/scripts" "$SBX/.github/workflows"
    cp "$PR_SH" "$SBX/scripts/pr.sh"
    cp "$WF" "$SBX/.github/workflows/pr-title.yml"
    git -C "$SBX" init -q -b main
    git -C "$SBX" -c user.email=u@e -c user.name=u commit -q --allow-empty -m awal
    git -C "$SBX" checkout -q -b cabang-uji
    git -C "$SBX" -c user.email=u@e -c user.name=u commit -q --allow-empty \
        -m 'fix(uji): satu commit conventional'

    out="$(cd "$SBX" && bash scripts/pr.sh "fix(setup): sesuatu" 2>&1)"
    # Dibuktikan dengan SAMPAI ke tahap push, bukan dengan absennya pesan
    # penolakan: `Pola tidak terbaca` juga membuat pesan itu absen, dan ujinya
    # akan hijau atas skrip yang tidak memeriksa apa pun.
    printf '%s' "$out" | grep -q 'push cabang-uji -> origin' \
        && ok "pr.sh meloloskan judul conventional sampai tahap push" \
        || no "pr.sh meloloskan judul conventional" "ia tidak pernah sampai push: $(printf '%s' "$out" | head -2 | tr '\n' ' ')"
    # Tanpa remote, push gagal -- dan itu memang yang harus terjadi: skrip tidak
    # boleh mencetak tautan PR untuk branch yang tidak pernah sampai ke origin.
    printf '%s' "$out" | grep -q 'compare/main' \
        && no "pr.sh diam saat push gagal" "ia tetap mencetak tautan PR" \
        || ok "pr.sh tidak mencetak tautan bila push gagal"

    # Tanpa argumen, judulnya diambil dari subjek commit -- persis yang akan
    # diisi GitHub sendiri. Inilah yang membuat "buat PR lalu merge" tidak
    # menuntut pengetikan apa pun.
    out="$(cd "$SBX" && bash scripts/pr.sh 2>&1)"
    printf '%s' "$out" | grep -q 'judul dari subjek commit: fix(uji): satu commit conventional' \
        && ok "pr.sh tanpa argumen memakai subjek commit sebagai judul" \
        || no "pr.sh tanpa argumen" "judul tidak diturunkan dari subjek commit"
    printf '%s' "$out" | grep -q 'push cabang-uji -> origin' \
        && ok "judul turunan lolos pagar yang sama" \
        || no "judul turunan lolos pagar" "judul turunan tidak sampai push"

    # Dua commit: GitHub akan mengisi judul dari NAMA BRANCH, jadi menurunkannya
    # dari salah satu commit akan berbohong tentang apa yang akan terpakai.
    git -C "$SBX" -c user.email=u@e -c user.name=u commit -q --allow-empty \
        -m 'fix(uji): commit kedua'
    out="$(cd "$SBX" && bash scripts/pr.sh 2>&1)"; rc=$?
    { [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'berisi 2 commit'; } \
        && ok "pr.sh menolak menurunkan judul dari branch dua commit" \
        || no "pr.sh pada branch dua commit" "ia menebak judul yang tidak akan terpakai"
    rm -rf "$SBX"
else
    no "scripts/pr.sh ada" "hilang — jalur cepat membuat PR tidak terjaga"
fi

echo
echo "lulus $pass, gagal $fail"
[[ $fail -eq 0 ]]
