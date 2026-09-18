# Selaraskan provider CooperAgent di models.yml omp dengan template.
#
# KENAPA ADA. Sampai 18 September 2026 omp adalah satu-satunya harness yang
# TIDAK pernah di-merge dari template. Grok dirender ulang penuh, pi di-merge
# per kunci, sedangkan omp hanya di-`sed` bedah: `baseUrl` dan `apiKey` diganti
# di tempat. Akibatnya dua hal yang sama-sama senyap:
#
#   1. profil BARU tidak pernah sampai ke pemasangan yang sudah ada -- menambah
#      `cooper-s3` ke template tidak mengubah apa pun di mesin dev;
#   2. `sed` itu melewati setiap baris yang memuat 127.0.0.1, jadi dev yang
#      gatewaynya localhost tidak pernah bisa berpindah sama sekali.
#
# Fungsi ini memakai doktrin yang sama dengan scripts/lib/merge_toml.sh: yang
# ditimpa HANYA kunci yang muncul di template, dan kunci bertanda
# `# @keep-existing` hanya ditulis bila dev belum punya. Provider di luar
# template tidak disentuh sama sekali -- server Ollama dan kunci berbayar dev
# hidup di berkas yang sama.
#
# SIAPA yang memiliki `baseUrl` dan `apiKey` adalah pilihan PEMANGGIL, bukan
# kebijakan berkas ini:
#
#   setup.sh        -- MILIK KAMI. Mengganti gateway harus menyentuh ketiga
#                      harness sekaligus; omp yang tertinggal di alamat lama
#                      adalah bug yang dilaporkan 18 September 2026.
#   setup-dev.sh    -- MILIK DEV. Pembaru dev sejak awal menghormati endpoint
#                      suntingan dev ("Tidak ditimpa. Sunting baris baseUrl...")
#                      dan itu tetap berlaku; ia menyetel OMP_KEEP_DEV_ENDPOINT=1.
#
# Setelan itu hanya menyentuh `baseUrl`. `apiKey` SELALU disegarkan -- ia
# kredensial, dan setup-dev.sh pun menulisnya sendiri. Sisanya -- id model,
# jendela konteks, maxTokens -- diturunkan dari kontrak dan selalu disegarkan.
#
# Dijaga: test/test-omp-providers.sh

# Nama provider tingkat atas pada sebuah models.yml.
#
# Bentuk yang dikenali hanyalah yang kita tulis sendiri: `providers:` di kolom
# nol, lalu nama provider pada indentasi dua spasi. Berkas yang tidak berbentuk
# itu menghasilkan daftar kosong, dan pemanggil memperlakukannya sebagai
# "tidak bisa disimpulkan" -- bukan sebagai "tidak ada provider".
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
#
# Penanda `# @keep-existing` DIBUANG saat menyalin: ia instruksi untuk merge,
# bukan keterangan untuk pembaca berkas hasil.
provider_block() {
    awk -v want="$2" '
        # Komentar dan baris kosong SELALU ditahan, bahkan saat sedang
        # mengumpulkan blok. Sebabnya: komentar yang muncul sesudah isi sebuah
        # provider sebenarnya milik provider BERIKUTNYA. Versi sebelumnya
        # mencetaknya begitu saja, sehingga blok cooper-s1 ikut membawa komentar
        # pembuka cooper-s2 -- dan saat cooper-s2 juga ditambahkan, komentar itu
        # tercetak dua kali. Terlihat 18 September 2026.
        #
        # Yang ditahan baru dikeluarkan bila ada baris ISI yang menyusul di
        # dalam blok yang sama; bila yang menyusul adalah provider lain, tahanan
        # itu dibuang karena ia bukan milik kita.
        function keluarkan(   i) {
            for (i = 1; i <= pending; i++) print hold[i]
            pending = 0
        }
        BEGIN { collecting = 0; pending = 0 }
        /^providers:[[:space:]]*$/ { inp = 1; next }
        /^[^[:space:]#]/           { if (inp && collecting) exit; inp = 0 }
        !inp { next }
        /^[[:space:]]*#[[:space:]]*@keep-existing[[:space:]]*$/ { next }
        /^[[:space:]]*(#|$)/ { hold[++pending] = $0; next }
        /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
            k = $1; sub(/:$/, "", k)
            if (k == want) { keluarkan(); collecting = 1; print; next }
            if (collecting) exit
            pending = 0; next
        }
        # Baris ISI milik provider lain: tahanan komentar dibuang.
        #
        # Tanpa baris ini, komentar di dalam blok provider LAIN tetap tertahan
        # sampai header provider yang dicari tiba, lalu tercetak seolah komentar
        # pembuka milik kita. Itulah kenapa setiap blok yang ditambahkan sempat
        # membawa komentar mmproj milik provider sebelumnya.
        !collecting { pending = 0; next }
        { keluarkan(); print }
    ' "$1"
}

# merge_providers <template terender> <models.yml dev>  -> hasil ke stdout
#
# Provider template yang HILANG ditambahkan utuh di akhir. Provider template
# yang SUDAH ADA diselaraskan per kunci. Sisanya dibiarkan apa adanya.
merge_providers() {
    local tpl="$1" cur="$2"

    # Berkas dev yang tidak memuat `providers:` tidak kita kenali bentuknya;
    # menebak struktur berkas asing adalah cara merusaknya.
    local have; have="$(provider_names "$cur")"
    if [ -z "$have" ]; then cat "$cur"; return 0; fi

    awk -v tplfile="$tpl" -v keep_endpoint="${OMP_KEEP_DEV_ENDPOINT:-0}" '
        function simpan(nama, lvl, kunci, baris, keep) {
            if (!((nama SUBSEP lvl SUBSEP kunci) in nilai)) {
                urut[nama SUBSEP lvl, ++jml[nama SUBSEP lvl]] = kunci
            }
            nilai[nama, lvl, kunci] = baris
            tahan[nama, lvl, kunci] = keep
        }
        BEGIN {
            # --- baca kunci terkelola dari template ---
            prov = ""; lvl = ""; keep = 0
            while ((getline b < tplfile) > 0) {
                if (b ~ /^[[:space:]]*#[[:space:]]*@keep-existing[[:space:]]*$/) { keep = 1; continue }
                if (b ~ /^[[:space:]]*#/ || b ~ /^[[:space:]]*$/) { continue }
                if (b ~ /^  [A-Za-z0-9_-]+:[[:space:]]*$/) {
                    prov = b; sub(/^  /, "", prov); sub(/:[[:space:]]*$/, "", prov)
                    ada_tpl[prov] = 1; urutan_tpl[++ntpl] = prov
                    lvl = "p"; keep = 0; continue
                }
                if (prov == "") { keep = 0; continue }
                if (b ~ /^    models:[[:space:]]*$/) { lvl = "m"; keep = 0; continue }
                if (b ~ /^      - [A-Za-z0-9_]+:/) {
                    k = b; sub(/^      - /, "", k); sub(/:.*$/, "", k)
                    simpan(prov, "m", k, b, keep); keep = 0; continue
                }
                if (b ~ /^        [A-Za-z0-9_]+:/) {
                    k = b; sub(/^[[:space:]]+/, "", k); sub(/:.*$/, "", k)
                    simpan(prov, "m", k, b, keep); keep = 0; continue
                }
                if (b ~ /^    [A-Za-z0-9_]+:/) {
                    k = b; sub(/^[[:space:]]+/, "", k); sub(/:.*$/, "", k)
                    if (keep_endpoint && k == "baseUrl") keep = 1
                    simpan(prov, "p", k, b, keep); keep = 0; continue
                }
                keep = 0
            }
            close(tplfile)
        }

        # --- tulis kunci terkelola yang belum ada di blok dev ---
        function sisipkan(nama, lvl,    i, k, pre) {
            for (i = 1; i <= jml[nama SUBSEP lvl]; i++) {
                k = urut[nama SUBSEP lvl, i]
                if (terlihat[nama, lvl, k]) continue
                pre = nilai[nama, lvl, k]
                # Item model pertama ditulis dengan `- ` hanya oleh kunci `id`;
                # kunci lain yang menyusul memakai indentasi lanjutan.
                if (lvl == "m" && pre ~ /^      - / && k != "id") {
                    sub(/^      - /, "        ", pre)
                }
                print pre
            }
        }

        /^providers:[[:space:]]*$/ { inp = 1; print; next }
        /^[^[:space:]#]/ { tutup(); inp = 0; print; next }

        inp && /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
            tutup()
            prov = $1; sub(/:$/, "", prov)
            kelola = (prov in ada_tpl) ? 1 : 0
            sudah_ada[prov] = 1
            lvl = "p"; model_ke = 0
            print; next
        }

        !inp || !kelola { print; next }

        # `models:` menutup bagian kunci provider -- yang hilang disisipkan di sini.
        /^    models:[[:space:]]*$/ { sisipkan(prov, "p"); lvl = "m"; print; next }

        # Item model berikutnya milik dev; item PERTAMA saja yang kita kelola.
        /^      - / {
            model_ke++
            if (model_ke == 2) sisipkan(prov, "m")
            if (model_ke == 1) {
                k = $0; sub(/^      - /, "", k); sub(/:.*$/, "", k)
                if ((prov SUBSEP "m" SUBSEP k) in nilai) {
                    terlihat[prov, "m", k] = 1
                    if (!tahan[prov, "m", k]) { print nilai[prov, "m", k]; next }
                }
            }
            print; next
        }

        model_ke == 1 && /^        [A-Za-z0-9_]+:/ {
            k = $0; sub(/^[[:space:]]+/, "", k); sub(/:.*$/, "", k)
            if ((prov SUBSEP "m" SUBSEP k) in nilai) {
                terlihat[prov, "m", k] = 1
                if (!tahan[prov, "m", k]) {
                    b = nilai[prov, "m", k]; sub(/^      - /, "        ", b)
                    print b; next
                }
            }
            print; next
        }

        lvl == "p" && /^    [A-Za-z0-9_]+:/ {
            k = $0; sub(/^[[:space:]]+/, "", k); sub(/:.*$/, "", k)
            if ((prov SUBSEP "p" SUBSEP k) in nilai) {
                terlihat[prov, "p", k] = 1
                if (!tahan[prov, "p", k]) { print nilai[prov, "p", k]; next }
            }
            print; next
        }

        { print }

        function tutup() {
            if (prov == "" || !kelola) { prov = ""; return }
            if (lvl == "m" && model_ke >= 1) sisipkan(prov, "m")
            else if (lvl == "p") sisipkan(prov, "p")
            prov = ""
        }

        END {
            tutup()
            # Provider template yang belum dimiliki dev sama sekali.
            for (i = 1; i <= ntpl; i++) {
                if (sudah_ada[urutan_tpl[i]]) continue
                print "__TAMBAH__" urutan_tpl[i]
            }
        }
    ' "$cur" | while IFS= read -r baris; do
        case "$baris" in
            __TAMBAH__*) printf '\n'; provider_block "$tpl" "${baris#__TAMBAH__}" ;;
            *) printf '%s\n' "$baris" ;;
        esac
    done
}

# omp_merge_into <template> <models.yml> <keluaran>
#   rc 0 = hasilnya BERBEDA dari berkas sekarang (pemanggil menyalin & mencadangkan)
#   rc 1 = sudah sesuai, tidak ada yang perlu ditulis
#   rc 2 = gagal (template tidak terender penuh)
#
# Pemindahan berkas sengaja diserahkan ke pemanggil: cadangan harus diambil
# SEBELUM berkas berubah, dan hanya bila memang ada yang berubah. Cadangan yang
# diambil setiap kali setup jalan hanya mengubur cadangan yang berguna.
#
# Templatenya diterima SUDAH TERENDER -- fungsi ini tidak tahu apa-apa soal
# kontrak gateway, dan tidak perlu tahu.
omp_merge_into() {
    local rtpl="$1" cur="$2" out="$3"
    [ -f "$rtpl" ] || return 2
    if [ ! -f "$cur" ]; then cp "$rtpl" "$out" && return 0 || return 2; fi
    merge_providers "$rtpl" "$cur" > "$out" || return 2
    cmp -s "$out" "$cur" && return 1
    return 0
}
