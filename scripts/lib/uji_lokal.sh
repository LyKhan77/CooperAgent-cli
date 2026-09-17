# Menjalankan suite uji lokal, dan meringkas hasilnya.
#
# KENAPA ADA. Suite tidak dijalankan di GitHub: ia dijalankan di mesin dev,
# sebelum push, oleh `scripts/hooks/pre-push` dan `scripts/pr.sh`. Satu
# pembacaan, satu tempat -- dua penjalan uji yang harus dijaga sinkron dengan
# tangan adalah persis penyakit yang berkali-kali menggigit repo ini.
#
# Daftar ujinya adalah isi `test/`, bukan daftar yang disalin ke suatu berkas.

# Uji yang SENGAJA tidak dijalankan otomatis, beserta sebabnya. Ia tetap wajib
# muncul di checklist -- ditandai `[ ]` dengan alasannya -- karena checklist yang
# boleh menghilangkan baris adalah checklist yang tidak membuktikan kelengkapan.
UJI_DILEWATI="test/test-setup-dev.sh"
UJI_SEBAB_DILEWATI="dijalankan tangan: memilih agent omp, sehingga setup.sh mengunduh biner dari internet"

UJI_PENANDA="Uji lokal:"

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
