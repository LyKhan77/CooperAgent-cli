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

echo
echo "lulus $pass, gagal $fail"
[[ $fail -eq 0 ]]
