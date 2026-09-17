# Menjalankan suite uji lokal, dan menuliskan hasilnya sebagai checklist.
#
# KENAPA ADA. Sejak 17 September 2026 suite TIDAK lagi dijalankan di CI: ia
# dijalankan di sini, sebelum push. CI hanya memeriksa dua hal yang tidak bisa
# dipastikan dari mesin lokal -- bahwa pohon yang terkirim benar-benar mengurai,
# dan bahwa checklist ujinya menyebut SETIAP berkas uji yang ada di repo.
#
# Checklist itulah sambungan antara keduanya. Ia ditulis ke pesan commit, jadi ia
# ikut menjadi body PR (isian otomatis GitHub) dan bisa diperiksa CI dari sana.
# Satu berkas uji baru yang tidak pernah dijalankan karena itu tidak bisa lolos
# diam-diam: ia akan absen dari checklist, dan CI menyebut namanya.
#
# Satu pembacaan, satu tempat: hook pre-push dan scripts/pr.sh memanggil fungsi
# yang sama. Dua penjalan uji yang harus dijaga sinkron dengan tangan adalah
# persis penyakit yang berkali-kali menggigit repo ini.

# Uji yang SENGAJA tidak dijalankan otomatis, beserta sebabnya. Ia tetap wajib
# muncul di checklist -- ditandai `[ ]` dengan alasannya -- karena checklist yang
# boleh menghilangkan baris adalah checklist yang tidak membuktikan kelengkapan.
UJI_DILEWATI="test/test-setup-dev.sh"
UJI_SEBAB_DILEWATI="dijalankan tangan: memilih agent omp, sehingga setup.sh mengunduh biner dari internet"

UJI_PENANDA="Uji lokal (scripts/pr.sh):"

# uji_lokal_jalankan <berkas-checklist>
# Keluar dengan kode != 0 bila ada satu saja uji yang merah.
uji_lokal_jalankan() {
    local keluaran="$1" f nama out rc ringkas gagal=0
    : > "$keluaran"
    printf '%s\n' "$UJI_PENANDA" >> "$keluaran"

    for f in test/test-*.sh; do
        [ -f "$f" ] || continue
        nama="$f"
        case " $UJI_DILEWATI " in
            *" $nama "*)
                printf '  %-42s dilewati\n' "$(basename "$nama")" >&2
                printf -- '- [ ] %s — %s\n' "$nama" "$UJI_SEBAB_DILEWATI" >> "$keluaran"
                continue ;;
        esac

        printf '  %-42s ' "$(basename "$nama")" >&2
        out="$(timeout 600 bash "$nama" 2>&1)"; rc=$?
        # Angka diambil dari keluaran uji itu sendiri bila ia memberikannya;
        # yang tidak memberikannya dicatat sebagai LULUS/GAGAL apa adanya.
        ringkas="$(printf '%s' "$out" | grep -oE 'lulus [0-9]+, gagal [0-9]+' | tail -1)"
        [ -n "$ringkas" ] || ringkas="$([ $rc -eq 0 ] && echo LULUS || echo GAGAL)"
        if [ $rc -eq 0 ]; then
            printf 'LULUS  %s\n' "$ringkas" >&2
            printf -- '- [x] %s — %s\n' "$nama" "$ringkas" >> "$keluaran"
        else
            gagal=1
            printf 'GAGAL\n' >&2
            printf '%s\n' "$out" | tail -12 | sed 's/^/      /' >&2
            printf -- '- [!] %s — GAGAL\n' "$nama" >> "$keluaran"
        fi
    done
    return $gagal
}
