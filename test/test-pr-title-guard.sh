#!/usr/bin/env bash
# Uji pagar judul PR.
#
# Yang diuji BUKAN salinan regexnya, melainkan skrip yang benar-benar dijalankan
# GitHub Actions: berkas workflow diurai, blok `run:` diambil apa adanya, lalu
# dieksekusi. Menyalin polanya ke sini akan melahirkan dua kebenaran yang harus
# dijaga sinkron dengan tangan -- kelas kegagalan yang berkali-kali menggigit
# repo ini, dan yang justru sedang dijaga oleh pagar itu sendiri.
#
# Kasus ujinya bukan karangan: keenam yang harus DITOLAK adalah judul yang
# benar-benar terjadi dan benar-benar menggandakan entri CHANGELOG.
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

echo "judul yang BENAR-BENAR menggandakan entri CHANGELOG:"
uji "feat(setup): retensi cadangan .bak di kedua installer"   1   # v2.1.0
uji "docs(ops-02): prosa kembali ke satu arsip"               1   # v3.0.1
uji "docs: buang entri kembar di seksi CHANGELOG v2.1.0"      1   # v2.1.1
uji "docs: lipat prosa [Unreleased] ke dalam v2.0.0"          1   # v2.0.1
uji "refactor!: pensiunkan jalur render lama"                 1
uji "fix: sesuatu"                                            1

echo "judul deskriptif — harus lolos:"
uji "Cadangan .bak tidak lagi menumpuk selamanya"             0
uji "Refactor/pensiunkan jalur render lama"                   0   # isian otomatis GitHub
uji "Satu pintu menuju produksi: jalur render lama dipensiunkan" 0
uji "Konvensi merge PR ditulis di OPS-02"                     0
# Titik dua di tengah kalimat Indonesia bukan prefiks. Regex yang menolak ini
# akan membuat pagar terasa sewenang-wenang, dan pagar yang terasa sewenang-
# wenang adalah pagar yang akan dimatikan orang.
uji "Perbaikan: cadangan rollback dipilih dari nama"          0
uji "Fitur baru: retensi cadangan"                            0

echo "scripts/pr.sh memakai pagar yang SAMA, bukan salinannya:"
# Pemeriksaan lokal yang polanya disalin akan menyimpang dari CI tanpa ada yang
# tahu, lalu memberi lampu hijau pada judul yang ditolak di server -- persis
# jenis selisih yang pagar ini ada untuk mencegahnya.
PR_SH="$REPO/scripts/pr.sh"
if [ -f "$PR_SH" ]; then
    grep -q "feat|fix|docs|chore" "$PR_SH" \
        && no "pr.sh tidak menyalin pola" "polanya dipatok di dalam skrip" \
        || ok "pr.sh membaca pola dari workflow, tidak menyalinnya"

    out="$("$PR_SH" "fix(setup): sesuatu" 2>&1)"; rc=$?
    [ "$rc" -ne 0 ] && ok "pr.sh menolak judul conventional sebelum push" \
                    || no "pr.sh menolak judul conventional" "ia meloloskannya (rc=0)"
    printf '%s' "$out" | grep -q 'git push' \
        && no "pr.sh menolak SEBELUM push" "ia sempat push lebih dulu" \
        || ok "pr.sh menolak SEBELUM menyentuh remote"

    # Judul yang benar dijalankan di KOTAK PASIR, bukan di repo ini.
    # Menjalankannya di sini akan mem-push branch yang sedang dikerjakan --
    # sebuah uji yang menyentuh remote adalah uji yang tidak bisa dijalankan
    # dengan tenang, dan uji yang tidak bisa dijalankan dengan tenang lama-lama
    # tidak dijalankan sama sekali.
    SBX="$(mktemp -d)"
    mkdir -p "$SBX/scripts" "$SBX/.github/workflows"
    cp "$PR_SH" "$SBX/scripts/pr.sh"
    cp "$WF" "$SBX/.github/workflows/pr-title.yml"
    git -C "$SBX" init -q -b main
    git -C "$SBX" -c user.email=u@e -c user.name=u commit -q --allow-empty -m awal
    git -C "$SBX" checkout -q -b cabang-uji
    out="$(cd "$SBX" && bash scripts/pr.sh "Judul deskriptif biasa" 2>&1)"
    printf '%s' "$out" | grep -q 'prefiks conventional-commit' \
        && no "pr.sh meloloskan judul deskriptif" "ia menolaknya" \
        || ok "pr.sh meloloskan judul deskriptif"
    # Tanpa remote, push gagal -- dan itu memang yang harus terjadi: skrip tidak
    # boleh mencetak tautan PR untuk branch yang tidak pernah sampai ke origin.
    printf '%s' "$out" | grep -q 'compare/main' \
        && no "pr.sh diam saat push gagal" "ia tetap mencetak tautan PR" \
        || ok "pr.sh tidak mencetak tautan bila push gagal"
    rm -rf "$SBX"
else
    no "scripts/pr.sh ada" "hilang — jalur cepat membuat PR tidak terjaga"
fi

echo
echo "lulus $pass, gagal $fail"
[[ $fail -eq 0 ]]
