#!/usr/bin/env bash
# Uji hook pre-push.
#
# Sejak suite tidak lagi dijalankan CI, hook inilah satu-satunya yang menahan
# kode merah sampai ke origin. Hook yang diam saat uji merah lebih berbahaya
# daripada tidak ada hook sama sekali: ia memberi rasa aman yang tidak ia tebus.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$REPO/scripts/hooks/pre-push"
pass=0; fail=0
ok(){ printf "  ok   %s\n" "$1"; pass=$((pass+1)); }
no(){ printf "  GAGAL %s — %s\n" "$1" "${2:-}"; fail=$((fail+1)); }

[ -x "$HOOK" ] || { echo "hook tidak ada / tidak executable: $HOOK"; exit 1; }

# Hook DIPASANG lewat core.hooksPath yang ikut ter-commit, bukan disalin ke
# .git/hooks tiap mesin. Sekali setelan itu hilang, hook ini tidak pernah jalan
# di mesin siapa pun dan tidak ada yang memberi tahu.
[ "$(git -C "$REPO" config core.hooksPath)" = "$REPO/scripts/hooks" ] \
    && ok "core.hooksPath menunjuk scripts/hooks" \
    || no "core.hooksPath" "hook tidak akan pernah dijalankan git"

SBX="$(mktemp -d)"; trap 'rm -rf "$SBX"' EXIT
mkdir -p "$SBX/scripts/lib" "$SBX/scripts/hooks" "$SBX/test"
cp "$REPO/scripts/lib/uji_lokal.sh" "$SBX/scripts/lib/"
cp "$HOOK" "$SBX/scripts/hooks/"
git -C "$SBX" init -q -b main
git -C "$SBX" -c user.email=u@e -c user.name=u add -A
git -C "$SBX" -c user.email=u@e -c user.name=u commit -q -m awal

hijau(){ printf '#!/usr/bin/env bash\necho "lulus 2, gagal 0"\nexit 0\n' > "$SBX/test/$1"; }
merah(){ printf '#!/usr/bin/env bash\necho "lulus 1, gagal 1"\nexit 1\n' > "$SBX/test/$1"; }
SHA="$(git -C "$SBX" rev-parse HEAD)"
NOL=0000000000000000000000000000000000000000
jalankan(){ # $1 = stdin refs; $2.. = env
    ( cd "$SBX" && printf '%s\n' "$1" | env "${@:2}" bash scripts/hooks/pre-push origin git@x:y.git 2>&1 )
}

hijau test-satu.sh; hijau test-dua.sh
out="$(jalankan "refs/heads/b $SHA refs/heads/b $NOL")"; rc=$?
[ "$rc" -eq 0 ] && ok "suite hijau — push diteruskan" \
                || no "suite hijau" "push justru ditolak: $out"

merah test-dua.sh
out="$(jalankan "refs/heads/b $SHA refs/heads/b $NOL")"; rc=$?
{ [ "$rc" -ne 0 ] && printf '%s' "$out" | grep -q 'PUSH DITOLAK'; } \
    && ok "satu uji merah menahan push" \
    || no "uji merah menahan push" "push diteruskan (rc=$rc)"
printf '%s' "$out" | grep -q 'test-dua' \
    && ok "yang merah disebut namanya" || no "nama uji merah" "dev tidak diberi tahu yang mana"

# Penghapusan branch tidak mengirim kode apa pun; menjalankan suite untuknya
# hanya membuat `git push --delete` menunggu tiga menit tanpa sebab.
out="$(jalankan "(delete) $NOL refs/heads/b $SHA")"; rc=$?
[ "$rc" -eq 0 ] && ok "penghapusan branch tidak menjalankan suite" \
                || no "penghapusan branch" "ditolak hook (rc=$rc)"
printf '%s' "$out" | grep -q 'menjalankan suite' \
    && no "penghapusan branch melewati suite" "suite tetap dijalankan" \
    || ok "penghapusan branch melewati suite"

# pr.sh baru saja menjalankannya untuk commit yang sama.
out="$(jalankan "refs/heads/b $SHA refs/heads/b $NOL" "COOPER_UJI_SUDAH=$SHA")"; rc=$?
{ [ "$rc" -eq 0 ] && printf '%s' "$out" | grep -q 'sudah dijalankan pr.sh'; } \
    && ok "tidak menjalankan suite dua kali untuk commit yang sama" \
    || no "penanda pr.sh" "suite dijalankan ulang (rc=$rc)"

# Penanda yang menyebut commit LAIN tidak boleh dipercaya: itu justru keadaan
# saat commit diperbarui sesudah suite dijalankan.
out="$(jalankan "refs/heads/b $SHA refs/heads/b $NOL" "COOPER_UJI_SUDAH=$NOL")"; rc=$?
[ "$rc" -ne 0 ] && ok "penanda untuk commit lain diabaikan" \
                || no "penanda commit lain" "hook percaya penanda yang tidak cocok"

echo
echo "lulus $pass, gagal $fail"
[[ $fail -eq 0 ]]
