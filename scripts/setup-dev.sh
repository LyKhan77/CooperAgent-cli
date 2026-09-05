#!/usr/bin/env bash
#
# Pembaru konfigurasi SEMUA harness CooperAgent pada mesin developer.
#
# Bukan onboarding: ia tidak menanyakan apa pun dan tidak memasang agent.
# Identitas dan endpoint dibaca dari config yang sudah ada.
#
# Memasang tiga hal yang selama ini melenceng antar mesin:
#   ~/.grok/AGENTS.md        aturan kerja agent (Grok, dibaca di folder mana pun)
#   ~/.omp/agent/AGENTS.md   aturan yang SAMA untuk Oh My Pi -- terverifikasi
#                            2026-08-29: hanya path ini yang dibaca omp, bukan
#                            ~/.omp/AGENTS.md
#   ~/.grok/config.toml auto-compact + cadangan jatah output + memory
#   ~/.grok/skills/     skill CooperAgent, tersedia di luar repo ini
#
# config.toml di-MERGE, bukan ditimpa: hanya kunci yang dikelola template yang
# diubah. `api_key` dan pengaturan pribadi lain di mesin dev tetap utuh.
#
# Pemakaian:
#   ./scripts/setup-dev.sh              pasang
#   ./scripts/setup-dev.sh --dry-run    tampilkan perubahan, jangan tulis
#   ./scripts/setup-dev.sh --token ca_... pasang kredensial dari pemilik gateway
set -euo pipefail

# Warna dan simbol: aturan yang sama dengan setup.sh, dan alasan yang sama.
#
# Warna hanya ke terminal -- saat dialihkan ke berkas, kode escape ikut tertulis
# dan log yang dikirim dev untuk melaporkan masalah justru menjadi sulit dibaca.
# NO_COLOR (no-color.org) dan TERM=dumb dihormati. Simbol Unicode hanya bila
# locale-nya UTF-8; `${S_OK}` di konsol non-UTF-8 menjadi mojibake, dan tanda
# "berhasil" yang tampak rusak lebih buruk daripada `[v]` yang polos.
UI_COLOR=auto; UI_SYMBOLS=auto
for _a in "$@"; do
    case "$_a" in
        --no-color) UI_COLOR=off ;;
        --ascii)    UI_COLOR=off; UI_SYMBOLS=ascii ;;
    esac
done
if [ "$UI_COLOR" = auto ] && [ -t 1 ] && [ -z "${NO_COLOR:-}" ] && [ "${TERM:-}" != dumb ]; then
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'; YELLOW=$'\033[1;33m'; BOLD=$'\033[1m'; NC=$'\033[0m'
else
    RED=''; GREEN=''; YELLOW=''; BOLD=''; NC=''
fi
if [ "$UI_SYMBOLS" = auto ]; then
    case "${LC_ALL:-${LC_CTYPE:-${LANG:-}}}" in
        *UTF-8*|*utf-8*|*UTF8*|*utf8*) UI_SYMBOLS=utf8 ;;
        *)                             UI_SYMBOLS=ascii ;;
    esac
fi
if [ "$UI_SYMBOLS" = utf8 ]; then
    # Literal UTF-8, bukan `\u2714`: escape `\u` menuntut bash 4.2, sedangkan
    # /bin/bash bawaan macOS masih 3.2 dan skrip ini menyebut dirinya lintas
    # platform.
    S_OK='✔'; S_NO='✖'; S_DOT='·'; S_WARN='⚠'
else
    S_OK='[v]'; S_NO='[x]'; S_DOT='-'; S_WARN='[!]'
fi

DRY_RUN=0
TOKEN=""
# Aturan agent (`AGENTS.md`) OPSIONAL sejak 3 September 2026.
#
# Sebagian dev membangun aturan harness sendiri, dan sebagian lagi memang ingin
# agent mentah tanpa aturan apa pun. Memasangnya tanpa bertanya berarti menulis
# 6 KB pendapat ke direktori global mereka atas nama "pemasangan".
#
# Kosong = tanyakan (hanya bila interaktif DAN belum pernah ada); `yes`/`no`
# datang dari bendera. SKILL TIDAK IKUT: ia perkakas, bukan pendapat, dan tetap
# dipasang pada ketiga jalur.
RULES_MODE=""
REMOVE_RULES=0
while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1; shift ;;
        --token)   TOKEN="${2:-}"; shift 2 ;;
        --token=*) TOKEN="${1#--token=}"; shift ;;
        --rules)        RULES_MODE="yes"; shift ;;
        --no-rules)     RULES_MODE="no";  shift ;;
        --remove-rules) REMOVE_RULES=1;   shift ;;
        *) echo "opsi tidak dikenal: $1" >&2
           echo "penggunaan: setup-dev.sh [--dry-run] [--token ca_...]" >&2
           echo "            [--rules|--no-rules|--remove-rules]" >&2
           exit 2 ;;
    esac
done

# Token diperiksa BENTUKNYA di sini, bukan diserahkan ke gateway. Salah tempel
# adalah kesalahan paling umum saat onboarding, dan menemukannya sekarang jauh
# lebih murah daripada menemukannya lewat 401 di tengah kerja.
if [ -n "$TOKEN" ]; then
    case "$TOKEN" in
        ca_*) ;;
        *) echo "Token harus diawali 'ca_'. Yang Anda tempel diawali '$(printf '%.3s' "$TOKEN")'." >&2
           exit 2 ;;
    esac
    if [ "${#TOKEN}" -ne 51 ]; then
        echo "Token harus 51 karakter (ca_ + 48 hex); yang ditempel ${#TOKEN}." >&2
        echo "Kemungkinan terpotong saat disalin. Minta ulang ke pemilik gateway." >&2
        exit 2
    fi
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TPL_DIR="$REPO_ROOT/templates"
GROK_HOME="${GROK_HOME:-$HOME/.grok}"
STAMP="$(date +%Y%m%d-%H%M%S)"

[ -d "$TPL_DIR" ] || { echo "${RED}${S_NO} Template tidak ditemukan: $TPL_DIR${NC}" >&2; exit 1; }
command -v awk >/dev/null || { echo "${RED}${S_NO} awk tidak tersedia${NC}" >&2; exit 1; }

echo "${BOLD}Template CooperAgent -> $GROK_HOME${NC}"
[ "$DRY_RUN" = 1 ] && echo "${YELLOW}Mode dry-run: tidak ada berkas yang ditulis.${NC}"
echo

# Dua tujuan, satu sumber: Grok membaca ~/.grok/AGENTS.md, omp membaca
# ~/.omp/agent/AGENTS.md.
RULES_PATHS="$GROK_HOME/AGENTS.md $HOME/.omp/agent/AGENTS.md"
# Baris pertama template. Dipakai untuk mengenali berkas MILIK KAMI yang sudah
# tertinggal versi -- `cmp` terhadap template saat ini akan menyebut aturan kami
# sendiri dari rilis lalu sebagai "milik dev", lalu menolak melepasnya.
RULES_MARK="$(head -1 "$TPL_DIR/agent-rules.md")"

rules_are_ours() { # $1 = berkas
    [ -f "$1" ] || return 1
    cmp -s "$TPL_DIR/agent-rules.md" "$1" && return 0
    [ "$(head -1 "$1")" = "$RULES_MARK" ]
}

# ── melepas aturan: --remove-rules ────────────────────────────────────────────
#
# Hanya berkas yang BISA DIBUKTIKAN milik CooperAgent yang dilepas. Aturan
# tulisan dev sendiri tidak pernah disentuh -- itu aturan repo #3, dan di sini
# taruhannya berkas yang tidak bisa ia ambil kembali.
#
# Cadangan tetap dibuat meski berkasnya milik kami: dev bisa saja menambahkan
# beberapa baris sendiri di bawahnya, dan penanda baris pertama tidak
# mengetahuinya.
if [ "$REMOVE_RULES" = 1 ]; then
    echo "${BOLD}Melepas aturan agent CooperAgent${NC}"
    FOUND=0; GONE=0
    for dst in $RULES_PATHS; do
        [ -f "$dst" ] || continue
        FOUND=$((FOUND + 1))
        if rules_are_ours "$dst"; then
            if [ "$DRY_RUN" = 0 ]; then
                cp "$dst" "$dst.bak.$STAMP"
                bak_prune "$dst"
                rm -f "$dst"
            fi
            echo "  ${GREEN}${S_OK}${NC} dilepas: $dst"
            echo "     cadangan: $(basename "$dst").bak.$STAMP"
            GONE=$((GONE + 1))
        else
            echo "  ${YELLOW}${S_WARN}${NC} BUKAN aturan CooperAgent: $dst"
            echo "     Isinya aturan Anda sendiri — tidak disentuh. Hapus manual bila memang mau."
        fi
    done
    [ "$FOUND" = 0 ] && echo "  ${YELLOW}${S_WARN}${NC} Tidak ada aturan agent yang terpasang."
    echo
    echo "  ${GREEN}${S_OK}${NC} Skill TIDAK ikut dilepas — ia perkakas, bukan pendapat."
    echo "     Pasang kembali kapan saja: ./scripts/setup-dev.sh --rules"
    exit 0
fi

# Apakah aturan diinginkan? Bendera menang; selain itu keadaan yang menjawab.
rules_wanted() {
    case "$RULES_MODE" in
        yes) return 0 ;;
        no)  return 1 ;;
    esac
    # Sudah ada = pilihan sudah pernah dibuat. Menanyakannya setiap kali skrip
    # pembaru berjalan adalah pertanyaan yang jawabannya sudah kita tahu.
    for dst in $RULES_PATHS; do
        [ -f "$dst" ] && return 0
    done
    # Belum pernah ada. Tanpa terminal, perilaku lama dipertahankan: pemanggilan
    # terskrip tidak boleh berubah diam-diam hanya karena promptnya ditambahkan.
    [ -t 0 ] || return 0

    echo "${CYAN}--- Aturan kerja agent (CooperxHarness) ---${NC}"
    echo "  Aturan global: checkpoint, surgical changes, goal-driven execution."
    echo "  Ukuran: $(wc -c < "$TPL_DIR/agent-rules.md") karakter, dipasang ke ~/.grok/ dan ~/.omp/agent/."
    echo "  ${YELLOW}Opsional.${NC} Anda boleh memakai aturan sendiri, atau tanpa aturan sama sekali."
    echo "  Skill CooperAgent tetap dipasang apa pun jawabannya."
    printf "Pasang aturan CooperAgent? [Y/n]: "
    read -r ans || ans=""
    case "$ans" in
        [Nn]*) return 1 ;;
        *)     return 0 ;;
    esac
}

mkdir -p "$GROK_HOME/skills"

# ── config.toml: merge ────────────────────────────────────────────────────────
# Implementasinya di pustaka bersama supaya setup.sh dan skrip ini tidak pernah
# menyimpang. Sebelumnya setup.sh justru MENIMPA config.toml, sehingga hasil
# kerja kedua skrip bertolak belakang.
# shellcheck source=scripts/lib/merge_toml.sh
. "$REPO_ROOT/scripts/lib/merge_toml.sh"
# shellcheck source=scripts/lib/contract.sh
. "$REPO_ROOT/scripts/lib/contract.sh"
# shellcheck source=scripts/lib/omp_models.sh
. "$REPO_ROOT/scripts/lib/omp_models.sh"
. "$REPO_ROOT/scripts/lib/backup.sh"

CFG="$GROK_HOME/config.toml"

# Kontrak DULU, merge kemudian.
#
# Template memuat placeholder yang hanya gateway bisa isi. Alamatnya dibaca dari
# config yang sudah ada -- skrip ini pembaru, bukan onboarding, jadi ia tidak
# menanyakan apa pun.
GW_BASE="$(grep -m1 -E '^[[:space:]]*base_url' "$CFG" 2>/dev/null \
    | sed -E 's/.*["'"'"']([^"'"'"']*)["'"'"'].*/\1/' || true)"
GW_BASE="${GW_BASE%/api/v1}"; GW_BASE="${GW_BASE%/v1}"
# Jalur mundur untuk mesin yang belum punya config sama sekali.
[ -n "$GW_BASE" ] || GW_BASE="${COOPERAGENT_GATEWAY:-}"
GW_BASE="${GW_BASE%/}"; GW_BASE="${GW_BASE%/api/v1}"; GW_BASE="${GW_BASE%/v1}"
if [ -n "$GW_BASE" ] && fetch_contract "$GW_BASE"; then
    echo "  ${GREEN}${S_OK}${NC} kontrak dari gateway: context $(contract_fmt "$CONTRACT_CONTEXT_WINDOW") ${S_DOT} output ${CONTRACT_MAX_TOKENS} ${S_DOT} compact ${CONTRACT_COMPACT_PCT}% ${S_DOT} model ${CONTRACT_MODEL_ID}"
    if [ "$CONTRACT_UPSTREAM_SOURCE" = "env-fallback" ]; then
        echo "  ${YELLOW}!${NC} gateway memakai nilai env — tidak ada slot upstream sehat saat ditanya."
    fi
else
    echo "  ${YELLOW}!${NC} kontrak tidak terambil dari ${GW_BASE:-(alamat tidak terbaca)} — memakai nilai cadangan."
    echo "     Nilai yang ditulis bisa tertinggal dari server. Jalankan ulang saat gateway terjangkau."
fi
echo

# Yang di-merge SELALU hasil render, tidak pernah template mentah:
# `context_window = __CONTEXT_WINDOW__` di config dev adalah kerusakan yang baru
# terlihat jauh dari sini, saat harness-nya gagal start.
TPL_CFG="$(mktemp)"
trap 'rm -f "$TPL_CFG"' EXIT
# `__GATEWAY__` diisi dari alamat yang SEDANG dipakai dev, bukan dari konstanta.
# Skrip ini pembaru, bukan onboarding: bila belum ada alamat, ia menolak
# menuliskan config yang pasti salah.
if [ -z "$GW_BASE" ]; then
    echo "${RED}${S_NO} Tidak ada alamat gateway di $CFG.${NC}" >&2
    echo "  Jalankan onboarding dulu: ./setup.sh --token ca_..." >&2
    echo "  Atau setel: COOPERAGENT_GATEWAY=http://<host>:8987 ./scripts/setup-dev.sh" >&2
    exit 1
fi
contract_render "$TPL_DIR/config.toml" | sed -e "s|__GATEWAY__|${GW_BASE}|g" > "$TPL_CFG"
contract_assert_rendered "$TPL_CFG" || exit 1

if [ -f "$CFG" ]; then
    MERGED="$(merge_toml "$TPL_CFG" "$CFG")"
else
    echo "${YELLOW}config.toml belum ada — dibuat dari template.${NC}"
    MERGED="$(cat "$TPL_CFG")"
fi

# Token dipasang SESUDAH merge, supaya template tetap bebas rahasia. Setiap
# blok [model.*] mendapat api_key yang sama: ketiganya menunjuk gateway yang
# sama, dan membiarkan salah satunya tertinggal berarti dev terputus begitu ia
# berpindah antara endpoint LAN, localhost, dan s2.
if [ -n "$TOKEN" ]; then
    # Satu lintasan yang MEMBUFFER tiap blok. Versi dua-lintasan sebelumnya
    # hanya menambal blok TERAKHIR: aturan `/^\[model\./` menelan transisi
    # dari satu blok model ke blok model berikutnya sebelum aturan penyisipan
    # sempat berjalan, sehingga dua dari tiga blok tetap tanpa api_key.
    # Ketahuan saat pengujian 31 Agustus 2026; tanpa itu dev akan terputus
    # begitu berpindah antara endpoint LAN, localhost, dan s2.
    MERGED="$(printf '%s\n' "$MERGED" | awk -v tok="$TOKEN" '
        function emit(   i) {
            if (nb == 0) return
            print buf[1]
            if (ismodel && !has) print "api_key = \"" tok "\""
            for (i = 2; i <= nb; i++) print buf[i]
            nb = 0; has = 0
        }
        # HANYA blok yang DIKELOLA CooperAgent.
        #
        # `/^\[model\./` cocok dengan SETIAP blok model, termasuk
        # `[model.claude-saya]` atau `[model.gpt-4o]` milik dev -- dan menimpa
        # api_key di sana berarti menghapus kunci BERBAYAR miliknya dengan token
        # kita. Ditemukan lewat pengujian 1 September 2026 dengan config yang
        # memuat kunci Anthropic: kunci itu hilang tanpa peringatan apa pun.
        /^\[/ { emit(); ismodel = ($0 ~ /^\[model\.internal-qwen/); buf[++nb] = $0; next }
        {
            if (nb == 0) { print; next }
            if (ismodel && $0 ~ /^[[:space:]]*api_key[[:space:]]*=/) {
                buf[++nb] = "api_key = \"" tok "\""; has = 1; next
            }
            buf[++nb] = $0
        }
        END { emit() }
    ')"
    NBLOK="$(printf '%s\n' "$MERGED" | grep -c '^api_key = "'"$TOKEN"'"' || true)"
    echo "${GREEN}${S_OK}${NC} token dipasang ke $NBLOK blok [model.*] (…${TOKEN#"${TOKEN%????}"})"
fi

if [ -f "$CFG" ] && diff -q <(printf '%s\n' "$MERGED") "$CFG" >/dev/null 2>&1; then
    echo "${GREEN}${S_OK}${NC} config.toml sudah sesuai template — tidak ada perubahan."
else
    echo "${BOLD}config.toml — perubahan:${NC}"
    diff -u "${CFG:-/dev/null}" <(printf '%s\n' "$MERGED") 2>/dev/null | sed -n '4,$p' | sed 's/^/  /' || true
    if [ "$DRY_RUN" = 0 ]; then
        [ -f "$CFG" ] && cp "$CFG" "$CFG.bak.$STAMP" && echo "  cadangan: config.toml.bak.$STAMP"
        bak_prune "$CFG"
        tmp="$(mktemp)"; printf '%s\n' "$MERGED" > "$tmp"; mv "$tmp" "$CFG"
        echo "${GREEN}${S_OK}${NC} config.toml diperbarui."
    fi
fi
echo

# ── Aturan agent: satu sumber, dua tujuan ─────────────────────────────────────
#
# Grok membaca ~/.grok/AGENTS.md; Oh My Pi membaca ~/.omp/agent/AGENTS.md.
# Keduanya global -- terverifikasi 2026-08-29 dengan kata sandi unik: omp
# menemukannya di ~/.omp/agent/ dan TIDAK menemukannya di ~/.omp/. Karena
# keduanya global, aturan tidak perlu disalin ke tiap proyek.
install_rules() {
    dst="$1"; label="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -f "$dst" ] && cmp -s "$TPL_DIR/agent-rules.md" "$dst"; then
        echo "${GREEN}${S_OK}${NC} $label sudah mutakhir."
    else
        if [ "$DRY_RUN" = 0 ]; then
            [ -f "$dst" ] && cp "$dst" "$dst.bak.$STAMP" && echo "  cadangan: $(basename "$dst").bak.$STAMP"
            bak_prune "$dst"
            tmp="$(mktemp)"; cp "$TPL_DIR/agent-rules.md" "$tmp"; mv "$tmp" "$dst"
        fi
        echo "${GREEN}${S_OK}${NC} $label dipasang ($(wc -c < "$TPL_DIR/agent-rules.md") karakter, batas 10.000)."
    fi
}

if rules_wanted; then
    install_rules "$GROK_HOME/AGENTS.md" "Aturan agent (Grok)"
    # Dipasang tanpa syarat: dev bisa memasang omp kapan saja setelah ini, dan
    # berkas 5 KB di direktori yang belum dipakai tidak merugikan siapa pun.
    install_rules "$HOME/.omp/agent/AGENTS.md" "Aturan agent (Oh My Pi)"
else
    echo "${YELLOW}${S_WARN}${NC} Aturan agent DILEWATI — Anda memakai aturan sendiri."
    echo "   Pasang kapan saja: ./scripts/setup-dev.sh --rules"
fi

echo

# ── skills: hanya milik CooperAgent, skill lain tidak disentuh ────────────────
echo "${BOLD}Skills:${NC}"
for src in "$TPL_DIR"/skills/*/; do
    name="$(basename "$src")"
    dst="$GROK_HOME/skills/$name"
    if [ -d "$dst" ] && diff -rq "$src" "$dst" >/dev/null 2>&1; then
        echo "  ${GREEN}${S_OK}${NC} $name (mutakhir)"
    else
        [ "$DRY_RUN" = 0 ] && { rm -rf "$dst"; cp -r "$src" "$dst"; }
        echo "  ${GREEN}${S_OK}${NC} $name dipasang"
    fi
done
# Skill juga dipasang untuk Oh My Pi.
#
# omp TIDAK membaca ~/.grok/skills -- terverifikasi 30 Agustus 2026 lewat
# `omp config list`: skills.customDirectories kosong secara bawaan, dan lokasi
# yang dibacanya adalah milik Claude/Codex/Pi, bukan Grok. Tanpa langkah ini
# `/cooper-handoff` hanya ada di Grok, padahal seluruh gunanya justru bekerja
# di keduanya.
#
# Direktori TERPISAH, bukan menunjuk omp ke ~/.grok/skills: direktori itu memuat
# skill pihak ketiga milik dev, dan menyeretnya ke omp adalah efek samping yang
# tidak diminta. Pola yang sama dengan agent-rules.md -- satu sumber, dua tujuan.
COOPER_SKILLS="$HOME/.cooper/skills"
for src in "$TPL_DIR"/skills/*/; do
    name="$(basename "$src")"
    dst="$COOPER_SKILLS/$name"
    if [ -d "$dst" ] && diff -rq "$src" "$dst" >/dev/null 2>&1; then continue; fi
    [ "$DRY_RUN" = 0 ] && { mkdir -p "$COOPER_SKILLS"; rm -rf "$dst"; cp -r "$src" "$dst"; }
done
echo "  ${GREEN}${S_OK}${NC} skill juga dipasang untuk omp di ~/.cooper/skills"

# Skill yang PERNAH kami kirim lalu dipensiunkan.
#
# Skrip ini hanya mengelola skill yang ada di template dan membiarkan sisanya --
# perilaku yang benar untuk skill milik dev, tetapi salah untuk skill kami
# sendiri yang sudah dihapus. Tanpa daftar ini, dev yang pernah menjalankan
# setup lama akan tetap melihat `/standardization` tersedia sesudah memperbarui,
# menjalankan wizard yang menulis aturan ke proyek, dan bertentangan dengan
# aturan global yang baru saja dipasang.
#
# Hanya nama-nama di bawah yang dihapus. Skill lain tidak disentuh.
# `handoff` diganti nama menjadi `cooper-handoff` pada 3 September 2026 supaya
# seluruh skill kami hidup di satu awalan dan tidak bertabrakan dengan skill
# milik dev. Tanpa baris ini dev melihat KEDUANYA sesudah memperbarui.
RETIRED="standardization init-changelog checkpoint handoff"
#
# KEDUA lokasi disapu. Skill dipasang ke ~/.grok/skills DAN ~/.cooper/skills
# (yang dibaca omp), jadi menyapu satu saja meninggalkan yang lain hidup di
# harness sebelah -- persis kelas kegagalan yang membuat `omp` dan `grok`
# berperilaku berbeda tanpa sebab yang terlihat.
for name in $RETIRED; do
    for base in "$GROK_HOME/skills" "$HOME/.cooper/skills"; do
        old="$base/$name"
        [ -d "$old" ] || continue
        [ "$DRY_RUN" = 0 ] && rm -rf "$old"
        echo "  ${YELLOW}−${NC} $name dihapus dari $base (dipensiunkan)"
    done
done

# Dihitung dengan loop, bukan pipeline: `grep` tanpa kecocokan mengembalikan 1,
# dan dengan `set -o pipefail` itu mematikan skrip sebelum verifikasi berjalan.
OTHER=0
for d in "$GROK_HOME"/skills/*/; do
    [ -d "$d" ] || continue
    [ -d "$TPL_DIR/skills/$(basename "$d")" ] || OTHER=$((OTHER + 1))
done
if [ "$OTHER" -gt 0 ]; then
    echo "  ($OTHER skill lain di ~/.grok/skills/ dibiarkan apa adanya)"
fi
echo

# ── Oh My Pi: ambang compaction + pemeriksaan endpoint ────────────────────────
#
# Aturan agent sudah dipasang di atas. Yang belum: `models.yml` dan ambang
# compaction, yang sampai sekarang HANYA disentuh setup.sh yang interaktif.
# Akibatnya terlihat 29 Agustus 2026 -- seorang dev punya models.yml menunjuk
# VPN sementara ia di kantor, dan tidak ada satu pun perintah yang memberi tahu.
#
# Identitas dan endpoint TIDAK ditanyakan: keduanya dibaca dari config Grok yang
# sudah ada, karena skrip ini pembaru, bukan onboarding.
OMP_DIR="$HOME/.omp/agent"
OMP_BIN="$(command -v omp 2>/dev/null || true)"
[ -n "$OMP_BIN" ] || [ -d "$OMP_DIR" ] || SKIP_OMP=1

if [ -z "${SKIP_OMP:-}" ]; then
    echo "${BOLD}Oh My Pi:${NC}"

    if [ -n "$OMP_BIN" ]; then
        if [ "$DRY_RUN" = 0 ]; then
            # Tanpa ini omp tidak menemukan /cooper-handoff sama sekali.
            "$OMP_BIN" config set skills.customDirectories '["~/.cooper/skills"]' >/dev/null 2>&1 \
                && echo "  ${GREEN}${S_OK}${NC} direktori skill terdaftar (~/.cooper/skills)" \
                || echo "  ${YELLOW}!${NC} gagal mendaftarkan direktori skill"
            "$OMP_BIN" config set compaction.thresholdPercent "$CONTRACT_COMPACT_PCT" >/dev/null 2>&1 \
                && echo "  ${GREEN}${S_OK}${NC} ambang compaction ${CONTRACT_COMPACT_PCT}%" \
                || echo "  ${YELLOW}!${NC} gagal menyetel ambang — jalankan: omp config set compaction.thresholdPercent ${CONTRACT_COMPACT_PCT}"
        else
            echo "  ${GREEN}${S_OK}${NC} ambang compaction ${CONTRACT_COMPACT_PCT}% (dry-run)"
        fi
    else
        echo "  ${YELLOW}!${NC} biner omp tidak di PATH — ambang compaction tidak dapat disetel dari sini."
        echo "    Buka terminal baru lalu: omp config set compaction.thresholdPercent ${CONTRACT_COMPACT_PCT}"
    fi

    # models.yml: dibuat bila belum ada; bila sudah ada, TIDAK ditimpa -- dev
    # bisa menambahkan provider sendiri di sana. Yang dilakukan hanya
    # membandingkan endpoint dan identitasnya dengan config Grok, lalu berkata
    # bila menyimpang. Menimpanya diam-diam akan menghapus pekerjaan dev.
    GCFG="$GROK_HOME/config.toml"
    ID="$(grep -m1 -E '^[[:space:]]*api_key' "$GCFG" 2>/dev/null | sed -E 's/.*["'"'"']([^"'"'"']*)["'"'"'].*/\1/' || true)"
    # `--token` MENANG atas apa pun yang masih tertulis di config Grok. Tanpa
    # ini, memutar token lewat `--token` memperbarui config.toml tapi
    # meninggalkan models.yml pada kunci lama -- `grok` jalan, `omp` 401.
    if [ -n "${TOKEN:-}" ]; then ID="$TOKEN"; fi
    URL="$(grep -m1 -E '^[[:space:]]*base_url' "$GCFG" 2>/dev/null | sed -E 's/.*["'"'"']([^"'"'"']*)["'"'"'].*/\1/' || true)"
    WANT_URL="${URL%/api/v1}/v1"
    MY="$OMP_DIR/models.yml"

    if [ -z "$ID" ] || [ -z "$URL" ]; then
        echo "  ${YELLOW}!${NC} identitas/endpoint tidak terbaca dari $GCFG — models.yml dilewati."
    elif [ ! -f "$MY" ]; then
        if [ "$DRY_RUN" = 0 ]; then
            mkdir -p "$OMP_DIR"
            tmp="$(mktemp)"
            contract_render "$TPL_DIR/omp-models.yml" \
                | sed -e "s|__GATEWAY__|${URL%/api/v1}|g" -e "s|__API_KEY__|$ID|g" > "$tmp"
            contract_assert_rendered "$tmp" || { rm -f "$tmp"; exit 1; }
            mv "$tmp" "$MY"
        fi
        echo "  ${GREEN}${S_OK}${NC} models.yml dibuat -> $WANT_URL"
    else
        if grep -q "baseUrl: *$WANT_URL" "$MY"; then
            echo "  ${GREEN}${S_OK}${NC} models.yml endpoint sesuai ($WANT_URL)"
        else
            CUR="$(grep -m1 'baseUrl:' "$MY" | sed 's/.*baseUrl: *//' || true)"
            echo "  ${YELLOW}!${NC} models.yml menunjuk ${CUR:-\(tidak terbaca\)}, config Grok menunjuk $WANT_URL"
            echo "    Tidak ditimpa. Sunting baris baseUrl di $MY bila perlu."
        fi
        # apiKey DIPERBARUI, tidak sekadar diperingatkan.
        #
        # Baris baseUrl memang milik dev -- ia boleh menunjuk endpoint lain, dan
        # menimpanya menghapus pekerjaannya. Tapi apiKey bukan pilihan dev: ia
        # kredensial yang diterbitkan admin, dan setiap kali token diputar,
        # models.yml yang tertinggal berarti omp berhenti bekerja sementara Grok
        # jalan normal. Peringatan saja membuat dev harus menyunting YAML dengan
        # tangan -- persis yang seharusnya dihapus oleh `--token`.
        if grep -q "apiKey: *$ID" "$MY"; then
            echo "  ${GREEN}${S_OK}${NC} models.yml identitas sesuai"
        elif [ "$DRY_RUN" = 0 ]; then
            cp "$MY" "$MY.bak.$STAMP"
            bak_prune "$MY"
            # Implementasinya di scripts/lib/omp_models.sh -- dipakai juga oleh
            # setup.sh. Dua salinan yang harus dijaga sinkron dengan tangan
            # adalah kelas kegagalan yang sudah berkali-kali menggigit repo ini.
            omp_set_api_key "$MY" "$ID" "${URL%/api/v1}" || true
            if grep -q "apiKey: *$ID" "$MY"; then
                echo "  ${GREEN}${S_OK}${NC} models.yml identitas diperbarui (cadangan: models.yml.bak.$STAMP)"
            else
                echo "  ${YELLOW}!${NC} gagal memperbarui apiKey di $MY — sunting manual"
            fi
        else
            echo "  ${GREEN}${S_OK}${NC} models.yml identitas akan diperbarui (dry-run)"
        fi
    fi
    echo
fi

# ── verifikasi ────────────────────────────────────────────────────────────────
echo "${BOLD}Verifikasi:${NC}"
CHECK="${CFG}"; [ "$DRY_RUN" = 1 ] && { CHECK="$(mktemp)"; printf '%s\n' "$MERGED" > "$CHECK"; }
# Diperiksa terhadap KONTRAK, bukan terhadap angka yang dipatok di skrip ini.
#
# Sampai 1 September 2026 baris ini berbunyi `"context_window|131072"`. Artinya
# begitu --ctx-size server berubah, skrip ini akan mencetak "${S_OK} context_window =
# 131072" dengan yakin justru pada saat nilainya sudah salah -- memverifikasi
# config terhadap keyakinannya sendiri, bukan terhadap servernya.
for pair in "auto_compact_threshold_percent|${CONTRACT_COMPACT_PCT}" \
            "context_window|${CONTRACT_CONTEXT_WINDOW}" \
            "enabled|true"; do
    key="${pair%%|*}"; want="${pair##*|}"
    got=$(grep -E "^[[:space:]]*$key[[:space:]]*=" "$CHECK" | head -1 | sed 's/.*=[[:space:]]*//' || true)
    if [ "$got" = "$want" ]; then echo "  ${GREEN}${S_OK}${NC} $key = $got"
    else echo "  ${RED}${S_NO}${NC} $key = ${got:-(tidak ada)}, seharusnya $want"; fi
done

CUR_KEY="$(grep -m1 -E '^[[:space:]]*api_key' "$CHECK" 2>/dev/null | sed -E 's/.*["'"'"']([^"'"'"']*)["'"'"'].*/\1/' || true)"
if [ -z "$CUR_KEY" ]; then
    echo
    echo "${YELLOW}${S_WARN} Tidak ada api_key di config.toml.${NC}"
    echo "  Mintalah token kepada pemilik gateway, lalu jalankan:"
    echo "    ./scripts/setup-dev.sh --token ca_..."
elif [ "${CUR_KEY#ca_}" = "$CUR_KEY" ]; then
    echo
    echo "${YELLOW}${S_WARN} api_key masih berupa nama (\"$CUR_KEY\"), bukan token.${NC}"
    echo "  Nama bisa diketik siapa saja, jadi ia bukan autentikasi. Gateway"
    echo "  akan menolaknya begitu penegakan dinyalakan."
    echo "  Mintalah token kepada pemilik gateway, lalu jalankan:"
    echo "    ./scripts/setup-dev.sh --token ca_..."
else
    echo "  ${GREEN}${S_OK}${NC} api_key berupa token (…${CUR_KEY#"${CUR_KEY%????}"})"
fi

echo
if [ "$DRY_RUN" = 1 ]; then
    echo "${YELLOW}Dry-run selesai — tidak ada yang ditulis.${NC}"
else
    echo "${GREEN}Selesai.${NC} Berlaku pada sesi grok berikutnya (sesi yang sedang jalan tidak terpengaruh)."
fi
