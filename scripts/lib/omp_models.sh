# Kunci API pada `~/.omp/agent/models.yml` — sumber tunggal.
#
# KENAPA PUSTAKA, BUKAN DISALIN. Sampai 3 September 2026 logika ini hidup HANYA
# di `scripts/setup-dev.sh`, sementara `setup.sh` merender models.yml dengan
# `dev-${DEV_IDENTITY}` tanpa syarat — bentuk lama yang dijawab 401 oleh gateway
# sejak penegakan menyala 1 September 2026. Dev yang memilih "omp saja" tidak
# pernah punya `~/.grok/config.toml`, sehingga setup-dev berhenti lebih awal dan
# tidak ada satu pun jalur yang membetulkannya: `omp` 401 sementara token yang
# sama berhasil login di dashboard.

# Kunci yang HARUS masuk ke models.yml. Token menang; identitas `nama@device`
# hanya jalur mundur untuk gateway yang belum menegakkan kredensial.
#
# Cabang `ca_*` ada karena `--endpoint vpn` meneruskan api_key lama sebagai
# identitas: tanpa itu hasilnya `dev-ca_...`, token yang tidak pernah cocok.
omp_api_key() { # $1 = identitas (nama@device atau ca_...)  $2 = token (boleh kosong)
    if [ -n "${2:-}" ]; then printf '%s' "$2"; return; fi
    case "${1:-}" in
        ca_*) printf '%s' "$1" ;;
        *)    printf 'dev-%s' "${1:-}" ;;
    esac
}

# Menulis ulang `apiKey:` HANYA pada provider yang menunjuk gateway kita.
#
# `sed` polos mengganti SETIAP baris apiKey di berkas — termasuk milik
# Anthropic, OpenAI, atau Ollama yang ditambahkan dev sendiri. omp mendukung 60+
# provider, dan menimpa kunci berbayar mereka jauh lebih mahal daripada masalah
# yang sedang diperbaiki. Blok dibuffer, dan apiKey hanya diganti bila blok itu
# memuat baseUrl yang menunjuk gateway.
omp_set_api_key() { # $1 = models.yml  $2 = kunci  $3 = gateway (tanpa /api/v1)
    local file="$1" tok="$2" gw="$3" tmp
    [ -f "$file" ] || return 1
    tmp="$(mktemp)" || return 1
    awk -v tok="$tok" -v gw="$gw" '
        function flush(   i) {
            if (n == 0) return
            for (i = 1; i <= n; i++) {
                if (mine && buf[i] ~ /^[[:space:]]*apiKey:/) {
                    match(buf[i], /^[[:space:]]*/)
                    print substr(buf[i], 1, RLENGTH) "apiKey: " tok
                } else print buf[i]
            }
            n = 0; mine = 0
        }
        /^  [A-Za-z0-9_-]+:[[:space:]]*$/ { flush(); buf[++n] = $0; next }
        {
            if (n == 0) { print; next }
            if ($0 ~ /baseUrl:/ && (index($0, gw) > 0 || $0 ~ /127\.0\.0\.1/)) mine = 1
            buf[++n] = $0
        }
        END { flush() }
    ' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
    mv "$tmp" "$file"
}

# ── pembacaan ────────────────────────────────────────────────────────────────
# Dipakai mode "sudah terpasang": dev yang memilih omp saja tidak punya
# `~/.grok/config.toml`, jadi satu-satunya tempat alamat dan kredensialnya
# tercatat adalah berkas ini. Sampai 3 September 2026 tidak ada satu pun jalur
# yang membacanya, sehingga dev omp-saja tidak terlihat oleh pemasang sebagai
# "sudah terpasang" dan selalu diseret ke onboarding penuh.

# apiKey dan alamat provider CooperAgent.
#
# Provider dikenali dari NAMANYA (`cooperagent`, `cooperagent-localhost`,
# `cooperagent-s2` -- persis yang ditulis templates/omp-models.yml), bukan dari
# bentuk alamatnya. Menebak dari alamat akan salah menyebut Ollama milik dev
# (`http://localhost:11434`) sebagai provider kita, dan yang terbaca lalu
# dilaporkan sebagai "kredensial Anda" adalah kunci orang lain.
omp_api_key_of() { # $1 = models.yml
    [ -f "${1:-}" ] || return 1
    awk '
        /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
            name = $0
            sub(/^[[:space:]]*/, "", name); sub(/:.*$/, "", name)
            mine = (name ~ /^cooperagent/)
            next
        }
        mine && /^[[:space:]]*apiKey:/ {
            sub(/^[[:space:]]*apiKey:[[:space:]]*/, ""); print; exit
        }
    ' "$1"
}

# Skema+host+port provider CooperAgent.
#
# Yang BUKAN localhost didahulukan: itulah alamat yang berpindah saat dev
# berganti LAN <-> VPN. Tapi localhost dipakai bila ia satu-satunya -- dev yang
# bekerja langsung di host GPU memang hanya punya itu, dan mengembalikan kosong
# di sana berarti pemasangannya tidak terlihat sama sekali.
omp_gateway_of() { # $1 = models.yml
    [ -f "${1:-}" ] || return 1
    awk '
        /^  [A-Za-z0-9_-]+:[[:space:]]*$/ {
            name = $0
            sub(/^[[:space:]]*/, "", name); sub(/:.*$/, "", name)
            mine = (name ~ /^cooperagent/)
            next
        }
        mine && /^[[:space:]]*baseUrl:/ {
            u = $0
            sub(/^[[:space:]]*baseUrl:[[:space:]]*/, "", u)
            sub(/\/(api\/)?v1.*$/, "", u)
            if (u !~ /127\.0\.0\.1/) { print u; exit }
            if (local == "") local = u
        }
        END { if (local != "") print local }
    ' "$1"
}

# Memindahkan HANYA provider yang menunjuk gateway lama.
#
# Mengganti setiap baseUrl akan menyeret provider pihak ketiga milik dev
# (Anthropic, Ollama) ke gateway kita; localhost sengaja dilewati karena ia sama
# di mesin mana pun dan bukan bagian dari perpindahan LAN <-> VPN.
omp_set_base_url() { # $1 = models.yml  $2 = gateway lama  $3 = gateway baru
    local file="$1" old="$2" new="$3" esc
    [ -f "$file" ] || return 1
    [ -n "$old" ] || return 1
    esc="$(printf '%s' "$old" | sed 's/[.[\*^$/]/\\&/g')"
    sed -i.bak_tmp -E "/127\.0\.0\.1/! s|baseUrl: ${esc}|baseUrl: ${new}|" "$file" || return 1
    rm -f "$file.bak_tmp"
}
