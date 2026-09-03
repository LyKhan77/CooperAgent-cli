#!/usr/bin/env bash
# Menjaga satu janji: `~/.omp/agent/models.yml` membawa TOKEN, bukan identitas.
#
# Ini bukan uji teoretis. Sampai 3 September 2026 kedua pemasang merender
# models.yml dengan `dev-${DEV_IDENTITY}` TANPA SYARAT, sementara jalur Grok di
# berkas yang sama sudah mendahulukan token. Gejalanya khas dan menyesatkan:
# `grok` jalan, `omp` dijawab 401, dan token yang sama berhasil login di
# dashboard -- karena dashboard memverifikasi token yang ditempel dev, sedangkan
# omp mengirim `Bearer dev-nama@device` yang gateway tolak sejak penegakan
# menyala 1 September 2026.
#
# Dev yang memilih "omp saja" tidak pernah punya ~/.grok/config.toml, sehingga
# setup-dev berhenti lebih awal dan tidak ada satu pun jalur yang membetulkannya.
set -uo pipefail
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FAIL=0
ok(){  printf "  \033[32m✔\033[0m %s\n" "$*"; }
bad(){ printf "  \033[31m✘\033[0m %s\n" "$*"; FAIL=1; }

TOK="ca_$(printf 'a%.0s' $(seq 48))"

# shellcheck source=../scripts/lib/omp_models.sh
. "$REPO/scripts/lib/omp_models.sh"

echo $'\033[1mKunci yang dipilih:\033[0m'
[ "$(omp_api_key 'lee@laptop-tuf' "$TOK")" = "$TOK" ] \
    && ok "token menang atas identitas" \
    || bad "identitas masih dipakai padahal token ada — inilah bug 401 itu"
[ "$(omp_api_key "$TOK" '')" = "$TOK" ] \
    && ok "identitas yang SUDAH token dipakai apa adanya" \
    || bad "token dibungkus jadi dev-ca_... — tidak akan pernah cocok"
[ "$(omp_api_key 'lee@laptop-tuf' '')" = 'dev-lee@laptop-tuf' ] \
    && ok "tanpa token, jalur mundur lama dipertahankan" \
    || bad "jalur mundur berubah — gateway lama ikut putus"

# ── kunci berbayar dev tidak boleh ikut tertimpa ──────────────────────────────
echo
echo $'\033[1mProvider milik dev:\033[0m'
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cat > "$T/models.yml" <<'YML'
providers:
  cooperagent:
    baseUrl: http://198.51.100.10:8987/v1
    apiKey: dev-lee@laptop-tuf
  cooperagent-localhost:
    baseUrl: http://127.0.0.1:8987/v1
    apiKey: dev-lee@laptop-tuf
  anthropic-saya:
    baseUrl: https://api.anthropic.com/v1
    apiKey: sk-ant-KUNCI-BERBAYAR-DEV
YML
omp_set_api_key "$T/models.yml" "$TOK" 'http://198.51.100.10:8987'
[ "$(grep -c "apiKey: $TOK" "$T/models.yml")" = 2 ] \
    && ok "kedua provider CooperAgent (LAN + localhost) diperbarui" \
    || bad "provider kita tidak diperbarui semua"
grep -q 'sk-ant-KUNCI-BERBAYAR-DEV' "$T/models.yml" \
    && ok "kunci berbayar dev utuh" \
    || bad "kunci berbayar dev TERTIMPA"

# ── pemasang tidak boleh menulis bentuk lama tanpa syarat ─────────────────────
#
# Diperiksa pada TEKS pemasang, bukan lewat menjalankannya: menjalankan cabang
# omp berarti mengunduh agent pihak ketiga, dan runner CI tidak melakukan itu.
echo
echo $'\033[1mKedua pemasang:\033[0m'
HITS=""
for f in setup.sh setup.ps1; do
    while IFS= read -r line; do
        case "$(printf '%s' "$line" | sed 's/^[[:space:]]*//')" in \#*) continue ;; esac
        case "$line" in
            *__API_KEY__*dev-*) HITS="$HITS
  $f: $line" ;;
        esac
    done < "$REPO/$f"
done
if [ -z "$HITS" ]; then
    ok "tidak ada render __API_KEY__ yang memaksa bentuk dev-"
else
    bad "bentuk lama masih dirender tanpa syarat:$HITS"
fi

grep -q 'omp_api_key' "$REPO/setup.sh" \
    && grep -q 'Get-OmpApiKey' "$REPO/setup.ps1" \
    && ok "keduanya memakai pustaka bersama untuk memilih kunci" \
    || bad "salah satu pemasang memilih kuncinya sendiri — sumber kebenaran terbelah"

grep -q 'omp_set_api_key' "$REPO/scripts/setup-dev.sh" \
    && grep -q 'Set-OmpApiKey' "$REPO/scripts/setup-dev.ps1" \
    && ok "penulis ulang apiKey hidup di satu tempat per platform" \
    || bad "setup-dev masih menyimpan salinannya sendiri"

# ── models.yml tidak boleh lahir dengan placeholder ───────────────────────────
#
# setup.sh merender template omp dengan `sed` mentah, melewatkan contract_render
# sepenuhnya -- sehingga `id: __MODEL_ID__` dan `contextWindow:
# __CONTEXT_WINDOW__` sampai ke berkas dev. Rusak jauh dari sini, saat omp gagal
# memuat provider.
echo
echo $'\033[1mRender template:\033[0m'
# shellcheck source=../scripts/lib/contract.sh
. "$REPO/scripts/lib/contract.sh"
contract_render "$REPO/templates/omp-models.yml" \
    | sed -e "s|__GATEWAY__|http://198.51.100.10:8987|g" -e "s|__API_KEY__|$TOK|g" \
    > "$T/rendered.yml"
if contract_assert_rendered "$T/rendered.yml" 2>/dev/null; then
    ok "tidak ada placeholder tersisa sesudah render"
else
    bad "placeholder tertinggal: $(grep -oE '__[A-Z_]+__' "$T/rendered.yml" | sort -u | tr '\n' ' ')"
fi
grep -q 'contract_render "\$OMP_TPL"' "$REPO/setup.sh" \
    && ok "setup.sh merender lewat kontrak, bukan sed mentah" \
    || bad "setup.sh masih memakai sed mentah — placeholder akan sampai ke dev"

echo
[ $FAIL -eq 0 ] && { printf "  \033[32mLULUS\033[0m — models.yml omp membawa token\n"; exit 0; }
printf "  \033[31mGAGAL\033[0m\n"; exit 1
