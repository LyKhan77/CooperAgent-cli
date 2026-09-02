# Merge TOML berbasis "kunci terkelola" — satu implementasi, dipakai bersama
# oleh setup.sh (onboarding) dan scripts/setup-dev.sh (sinkronisasi).
#
# Kenapa merge, bukan tulis-ulang. `~/.grok/config.toml` bukan milik kita
# sendiri: dev menaruh server MCP, preferensi `[ui]`, model tambahan, dan
# `[marketplace]` di berkas yang sama. Menimpanya berarti menghapus pekerjaan
# orang lain setiap kali seseorang mengganti endpoint.
#
# Yang ditimpa HANYA kunci yang muncul di berkas template. Kunci lain, seksi
# lain, dan komentar dev dibiarkan utuh. Penanda `# @keep-existing` di atas
# sebuah kunci membuatnya hanya ditulis bila belum ada — dipakai untuk nilai
# per-mesin yang tidak boleh diubah dari pusat.
merge_toml() {
    # $1 = template (sumber kunci terkelola), $2 = config sekarang
    awk -v TPL="$1" '
    function flush(   i,j,last) {
        last = bn; while (last > 0 && buf[last] ~ /^[[:space:]]*$/) last--
        for (i = 1; i <= last; i++) print buf[i]
        for (j = 1; j <= n; j++) if (msec[j] == cur && !mdone[j]) { print mval[j]; mdone[j] = 1 }
        for (i = last + 1; i <= bn; i++) print buf[i]
        bn = 0
    }
    BEGIN {
        n = 0; cur = ""
        while ((getline line < TPL) > 0) {
            if (line ~ /^[[:space:]]*$/) continue
            if (line ~ /^[[:space:]]*#[[:space:]]*@keep-existing/) { keepnext = 1; continue }
            if (line ~ /^[[:space:]]*#/) continue
            if (line ~ /^\[.*\]$/) { cur = line; keepnext = 0; continue }
            if (line ~ /=/) {
                k = line; sub(/[[:space:]]*=.*/, "", k); gsub(/^[[:space:]]+/, "", k)
                n++; msec[n] = cur; mkey[n] = k; mval[n] = line; mdone[n] = 0
                mkeep[n] = keepnext; keepnext = 0
            }
        }
        close(TPL); cur = ""; bn = 0
    }
    /^\[.*\]$/ { flush(); cur = $0; print; next }
    {
        if ($0 ~ /^[[:space:]]*[A-Za-z0-9_.-]+[[:space:]]*=/) {
            k = $0; sub(/[[:space:]]*=.*/, "", k); gsub(/^[[:space:]]+/, "", k)
            for (j = 1; j <= n; j++)
                if (msec[j] == cur && mkey[j] == k && !mdone[j]) {
                    if (!mkeep[j]) $0 = mval[j]   # keep-existing: nilai dev dibiarkan
                    mdone[j] = 1; break
                }
        }
        buf[++bn] = $0
    }
    END {
        flush()
        for (j = 1; j <= n; j++) if (!mdone[j]) {
            if (!(msec[j] in emitted)) { print ""; print msec[j]; emitted[msec[j]] = 1 }
            print mval[j]; mdone[j] = 1
        }
    }' "$2"
}
