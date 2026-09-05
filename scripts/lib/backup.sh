# Retensi cadangan `.bak` — satu kebijakan, dipakai kedua installer.
#
# KENAPA ADA. Setiap "perbarui parameter" mencadangkan config yang disentuhnya
# ke `<berkas>.bak.<YYYYMMDD-HHMMSS>`, dan sampai 5 September 2026 tidak ada
# satu pun yang pernah membuangnya. Cadangannya sendiri kecil, jadi ini bukan
# soal ruang: ia soal direktori config dev yang lama-lama tidak terbaca, dan
# soal `config.toml.bak.20260812-094431` yang duduk di sana bertahun-tahun tanpa
# ada yang tahu apakah ia masih berarti.
#
# Di sisi server keputusannya JUSTRU SEBALIKNYA -- tidak ada pemangkasan, karena
# 17 cadangan di sana berjumlah 24 KB dan hidup di direktori yang hanya disentuh
# perkakas. Yang berbeda di sini: berkasnya menumpuk di mesin tiap dev, tumbuh
# mengikuti pemakaian, dan tidak ada operator yang mengawasinya.
#
# YANG TIDAK DILAKUKANNYA. Ia tidak pernah menyentuh berkas yang namanya tidak
# persis `<basis>.bak.<8 digit>-<6 digit>`. Pelajarannya dibayar di repo server:
# pemilih cadangan di sana memakai glob `.bak.*` yang lebar, dan sebuah berkas
# bernama `run-qwen.sh.bak.catatan` terbukti bisa terpilih sebagai sasaran
# rollback. Pola yang longgar pada perkakas yang MENGHAPUS jauh lebih mahal
# daripada pada perkakas yang membaca.

# Berapa cadangan terakhir yang disimpan per berkas. 0 mematikan pemangkasan
# sepenuhnya -- disediakan supaya dev yang mau menyimpan seluruh riwayatnya
# tidak perlu menambal skrip.
BAK_KEEP="${COOPERAGENT_BAK_KEEP:-5}"

# bak_prune <berkas-asli>
#
# Menyisakan $BAK_KEEP cadangan termuda milik berkas itu, membuang sisanya.
# SELALU mengembalikan 0: installer berjalan di bawah `set -e`, dan gagal
# merapikan cadangan bukan alasan untuk membatalkan pemasangan yang berhasil.
bak_prune() {
    [ -n "${1:-}" ] || return 0
    case "$BAK_KEEP" in ''|*[!0-9]*) return 0 ;; esac
    [ "$BAK_KEEP" -gt 0 ] || return 0

    local base dir pat n hapus f
    base="$(basename "$1")"; dir="$(dirname "$1")"
    [ -d "$dir" ] || return 0

    # Cap waktunya `%Y%m%d-%H%M%S`, jadi urutan leksikografis == urutan waktu.
    # Diurutkan dari NAMANYA, bukan mtime: `cp` membawa serta mtime berkas
    # sumber pada sebagian platform, sehingga mtime cadangan tidak selalu
    # bercerita kapan ia dibuat.
    pat="$dir/$base.bak.[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9][0-9][0-9]"
    n=0
    for f in $pat; do [ -e "$f" ] && n=$((n + 1)); done
    [ "$n" -gt "$BAK_KEEP" ] || return 0

    hapus=$((n - BAK_KEEP))
    for f in $(printf '%s\n' $pat | sort | head -n "$hapus"); do
        [ -e "$f" ] && rm -f "$f"
    done
    printf '     %s cadangan lama dibuang, %s terbaru disimpan (%s)\n' \
        "$hapus" "$BAK_KEEP" "$base" >&2
    return 0
}
