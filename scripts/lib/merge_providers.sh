# Tambahkan provider yang HILANG ke models.yml omp — tanpa menyentuh yang ada.
#
# Kenapa ada. Sampai 12 September 2026 `setup-dev.sh` hanya menulis models.yml
# bila berkasnya BELUM ADA. Bila sudah ada, satu-satunya yang diperbarui adalah
# `apiKey`; sisanya dibiarkan dengan pesan "Tidak ditimpa."
#
# Alasannya benar — dev menaruh provider sendiri di sana, dan menimpanya
# menghapus pekerjaan orang. Tetapi akibatnya: profil BARU tidak pernah sampai
# ke dev yang sudah terpasang. Menambah `cooper-s1` ke template tidak mengubah
# apa pun di mesin mereka, dan armada berakhir dengan dua kosakata yang hidup
# bersamaan tanpa ada yang tahu.
#
# Fungsi ini menempuh jalan tengah yang sama dengan merge_toml.sh: yang ADA
# tidak disentuh sama sekali, yang HILANG ditambahkan di akhir. Ia tidak pernah
# menghapus, tidak pernah menyunting, dan tidak pernah mengurutkan ulang.
#
# Dijaga: test/test-omp-providers.sh

# Nama provider tingkat atas pada sebuah models.yml.
#
# Bentuk yang dikenali hanyalah yang kita tulis sendiri: `providers:` di kolom
# nol, lalu nama provider pada indentasi dua spasi. Berkas yang tidak berbentuk
# itu menghasilkan daftar kosong, dan pemanggil memperlakukannya sebagai
# "tidak bisa disimpulkan" — bukan sebagai "tidak ada provider".
provider_names() {
    awk '
        /^providers:[[:space:]]*$/ { inp = 1; next }
        /^[^[:space:]#]/          { inp = 0 }
        inp && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
            k = $1; sub(/:$/, "", k); print k
        }
    ' "$1" 2>/dev/null
}

# Potong satu blok provider dari template, lengkap dengan komentar di atasnya.
#
# Komentar ikut DISALIN dengan sengaja: di berkas ini komentarlah yang
# memberitahu dev bahwa profil langsung kehilangan failover. Menyalin
# konfigurasinya tanpa peringatan itu memindahkan jebakannya saja.
provider_block() {
    awk -v want="$2" '
        BEGIN { collecting = 0; pending = 0 }
        /^providers:[[:space:]]*$/ { inp = 1; next }
        /^[^[:space:]#]/           { if (inp && collecting) exit; inp = 0 }
        !inp { next }
        # Komentar dan baris kosong ditahan dulu: ia milik provider BERIKUTNYA,
        # dan baru dicetak kalau provider itu memang yang dicari.
        /^[[:space:]]*(#|$)/ {
            if (collecting) { print; next }
            hold[++pending] = $0; next
        }
        /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
            k = $1; sub(/:$/, "", k)
            if (k == want) {
                for (i = 1; i <= pending; i++) print hold[i]
                collecting = 1; print; next
            }
            if (collecting) exit
            pending = 0; next
        }
        collecting { print }
    ' "$1"
}

# merge_providers <template> <models.yml dev>  -> menulis hasil ke stdout
#
# Keluarannya adalah berkas dev APA ADANYA, ditambah blok provider yang belum
# ia punya. Bila berkas dev tidak memuat `providers:` sama sekali, fungsi ini
# menyerah dan mengembalikannya utuh: menebak struktur berkas yang tidak kita
# kenali adalah cara merusaknya.
merge_providers() {
    local tpl="$1" cur="$2" name found
    cat "$cur"

    local have; have="$(provider_names "$cur")"
    [ -n "$have" ] || return 0

    for name in $(provider_names "$tpl"); do
        found=0
        for existing in $have; do
            [ "$existing" = "$name" ] && { found=1; break; }
        done
        [ "$found" = 1 ] && continue
        printf '\n'
        provider_block "$tpl" "$name"
    done
}
