#!/usr/bin/env bash
# Paritas bash <-> PowerShell, DIJALANKAN — bukan diperiksa pada teks.
#
# KENAPA ADA. Repo ini menjaga dua implementasi untuk setiap hal, dan selama ini
# paritasnya hanya bisa diklaim: tidak ada PowerShell di mesin dev mana pun, jadi
# yang bisa diperiksa dari sini cuma bahwa nama fungsinya ada. Dua cacat lolos
# justru lewat celah itu — `Test-CooperOmpInstalled` yang masih mencari nama
# pra-3.0.0, dan `Get-SectionMap` yang menunjuk seksi berbeda dari yang dibaca
# setiap pembaca.
#
# Sejak 18 September 2026 `pwsh` tersedia di mesin dev, jadi keduanya dijalankan
# atas masukan yang SAMA dan hasilnya dibandingkan byte per byte.
#
# pwsh di Linux adalah PowerShell 7, sedangkan target repo Windows PowerShell 5.1.
# Yang dibuktikan di sini LOGIKA, bukan kecocokan sintaks 5.1 — itu tetap milik
# job Windows di CI. Tanpa pwsh, uji ini melewati dirinya dan mengatakannya.
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
pass=0; fail=0
ok(){ printf "  ok   %s\n" "$1"; pass=$((pass+1)); }
no(){ printf "  GAGAL %s — %s\n" "$1" "${2:-}"; fail=$((fail+1)); }

if ! command -v pwsh >/dev/null 2>&1; then
    printf "  \033[33m—\033[0m pwsh tidak ada; paritas Windows tidak dijalankan di sini.\n"
    printf "    Pasang sekali:  sudo snap install powershell --classic\n"
    exit 0
fi

T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
cd "$ROOT" || exit 1

# ── 1. merge provider omp: bash vs PowerShell ────────────────────────────────
sed -e 's|__GATEWAY__|http://192.168.2.143:8987|g' \
    -e 's|__API_KEY__|ca_BARU|g' -e 's|__MODEL_ID__|intercon-agent|g' \
    -e 's|__CONTEXT_WINDOW__|131072|g' -e 's|__MAX_TOKENS__|12288|g' \
    templates/omp-models.yml > "$T/tpl.yml"

# Pemasangan dev yang khas: nama sendiri, endpoint lokal, model tambahan,
# supportsImages yang sengaja false, dan provider pihak ketiga.
cat > "$T/dev.yml" <<'YML'
providers:
  cooper-agent:
    name: Nama pilihan dev
    baseUrl: http://127.0.0.1:8996/v1
    apiKey: ca_LAMA
    api: openai-completions
    models:
      - id: model-lama
        name: nama model dev
        contextWindow: 8192
        maxTokens: 999
        supportsImages: false
      - id: model-tambahan-dev
        maxTokens: 100
  anthropic-saya:
    baseUrl: https://api.anthropic.com/v1
    apiKey: sk-ant-BERBAYAR
    models:
      - id: claude
YML

. "$ROOT/scripts/lib/merge_providers.sh"
merge_providers "$T/tpl.yml" "$T/dev.yml" > "$T/bash.yml"
OMP_KEEP_DEV_ENDPOINT=1 merge_providers "$T/tpl.yml" "$T/dev.yml" > "$T/bash-keep.yml"
pwsh -NoProfile -Command "
. '$ROOT/scripts/lib/OmpModels.ps1'
\$t = Get-Content -LiteralPath '$T/tpl.yml'
\$c = Get-Content -LiteralPath '$T/dev.yml'
(Merge-OmpProviders \$t \$c \$false) | Set-Content -LiteralPath '$T/ps.yml'
(Merge-OmpProviders \$t \$c \$true)  | Set-Content -LiteralPath '$T/ps-keep.yml'
" >/dev/null 2>&1

echo "merge provider omp identik di kedua platform:"
diff -q "$T/bash.yml" "$T/ps.yml" >/dev/null \
    && ok "mode baku (endpoint milik kami)" \
    || no "mode baku" "$(diff "$T/bash.yml" "$T/ps.yml" | head -6)"
diff -q "$T/bash-keep.yml" "$T/ps-keep.yml" >/dev/null \
    && ok "mode hormati-endpoint-dev" \
    || no "mode hormati-endpoint-dev" "$(diff "$T/bash-keep.yml" "$T/ps-keep.yml" | head -6)"

# Dan hasilnya memang yang dimaksud, bukan sekadar sama-sama salah.
grep -q "192.168.2.143:8987/v1/upstream/s3" "$T/bash.yml" \
    && ok "profil baru (cooper-s3) sampai ke pemasangan lama" \
    || no "cooper-s3 sampai" "profil baru tidak pernah tiba"
grep -q "127.0.0.1:8996" "$T/bash.yml" \
    && no "endpoint localhost ikut pindah" "baris ber-127.0.0.1 masih dilewati" \
    || ok "endpoint localhost ikut pindah"
grep -q "supportsImages: false" "$T/bash.yml" \
    && ok "pilihan sadar dev (supportsImages: false) dihormati" \
    || no "supportsImages: false dihormati" "ditimpa template"
grep -q "sk-ant-BERBAYAR" "$T/bash.yml" \
    && ok "provider pihak ketiga dev tidak tersentuh" || no "provider dev" "hilang"

# ── 2. seksi TOML ganda ──────────────────────────────────────────────────────
#
# Inilah bug yang dilaporkan dari Windows: penulis menyentuh seksi TERAKHIR,
# setiap pembaca melihat yang PERTAMA. Merge melaporkan "sudah sesuai", layar
# menampilkan alamat basi, dan tidak ada yang merah.
echo "seksi TOML ganda:"
pwsh -NoProfile -Command "
. '$ROOT/scripts/lib/MergeToml.ps1'
\$tpl = '$T/t.toml'
@('[model.cooper-agent]','base_url = \"http://baru/api/v1\"') | Set-Content \$tpl
\$cfg = @('[model.cooper-agent]','base_url = \"http://lama/api/v1\"','','[ui]','x = 1','',
          '[model.cooper-agent]','base_url = \"http://baru/api/v1\"')
\$m = Merge-Toml (Get-ManagedKeys \$tpl) \$cfg
\$dup = Test-TomlDuplicateSections \$cfg
'DUP=' + (\$dup -join ',')
'BERUBAH=' + (-not ((\$cfg -join \"\`n\") -eq (\$m -join \"\`n\")))
'PERTAMA=' + (\$m | Select-String 'base_url' | Select-Object -First 1).Line
" > "$T/dup.out" 2>&1
grep -q "DUP=\[model.cooper-agent\]" "$T/dup.out" \
    && ok "seksi ganda terdeteksi dan dilaporkan" || no "deteksi seksi ganda" "$(cat "$T/dup.out")"
grep -q "BERUBAH=True" "$T/dup.out" \
    && ok "merge tidak lagi mengaku 'sudah sesuai' atas seksi basi" \
    || no "merge melaporkan perubahan" "masih mengaku sudah sesuai"
grep -q "PERTAMA=base_url = \"http://baru" "$T/dup.out" \
    && ok "seksi PERTAMA yang diperbarui — yang dilihat semua pembaca" \
    || no "seksi pertama diperbarui" "$(grep PERTAMA= "$T/dup.out")"

# ── 3. encoding: mojibake yang menggandakan berkas ───────────────────────────
#
# Windows PowerShell 5.1 membaca ANSI secara BAWAAN, pwsh 7 membaca UTF-8, dan
# semua penulis di repo ini menulis UTF-8. Pada 5.1 setiap siklus baca-tulis
# karena itu mengurai salah setiap karakter non-ASCII lalu menuliskannya kembali
# lebih panjang: `—` menjadi `â€”`, lalu masing-masingnya menjadi tiga lagi.
#
# Terukur di mesin Windows: models.yml tumbuh TEPAT 2,226x setiap kali setup
# jalan -- 57 MB, 127, 283, 631, 1404 -- sampai 1,47 GB dengan 51 baris, lalu
# setup mati dengan OutOfMemoryException.
#
# Uji ini MENYABOTASE bawaan encoding menjadi ANSI, lalu menjalankan setup.ps1
# sungguhan. Skrip yang memaksa UTF-8 sendiri akan selamat; yang tidak, tidak.
# Tanpa sabotase ini pwsh 7 akan lolos meski perbaikannya dicabut.
echo "encoding tidak menggandakan berkas:"
GW_PORT=9061
python3 - "$GW_PORT" <<'PYGW' > "$T/gw.py"
import sys
print(open("test/test-credential-gate.sh").read().split('cat > "$T/gw.py" <<\'PY\'\n')[1].split("\nPY\n")[0])
PYGW
python3 "$T/gw.py" "$GW_PORT" & GWPID=$!
for _ in $(seq 60); do curl -sf -o /dev/null "http://127.0.0.1:$GW_PORT/v1/models" && break; sleep 0.1; done
VALID="ca_$(printf 'a%.0s' $(seq 48))"
HW="$T/winhome"; mkdir -p "$HW/.grok" "$HW/.omp/agent"
printf '[cli]\nauto_update = false\n\n[model.cooper-agent]\nmodel = "model-uji"\nbase_url = "http://127.0.0.1:%s/api/v1"\napi_key = "%s"\ncontext_window = 262144\n' "$GW_PORT" "$VALID" > "$HW/.grok/config.toml"
# Nama model memuat em dash -- persis bentuk yang menggandakan diri.
printf 'providers:\n  cooper-agent:\n    name: CooperAgent — routing otomatis\n    baseUrl: http://127.0.0.1:%s/v1\n    apiKey: %s\n    models:\n      - id: model-uji\n' "$GW_PORT" "$VALID" > "$HW/.omp/agent/models.yml"

for putaran in 1 2 3; do
    printf '1\n' | USERPROFILE="$HW" HOME="$HW" COOPERAGENT_PI_BIN=/bin/true \
        pwsh -NoProfile -Command "
            \$PSDefaultParameterValues['Get-Content:Encoding'] = [System.Text.Encoding]::GetEncoding(1252).WebName
            & '$ROOT/setup.ps1'" >/dev/null 2>&1
    eval "ukuran$putaran=\$(wc -c < '$HW/.omp/agent/models.yml')"
done
kill $GWPID 2>/dev/null

if [ "$ukuran2" = "$ukuran3" ]; then
    ok "ukuran models.yml stabil saat dijalankan ulang ($ukuran3 byte)"
else
    no "ukuran stabil" "tumbuh $ukuran2 -> $ukuran3 byte — berkas menggandakan diri"
fi
if grep -q 'â€' "$HW/.omp/agent/models.yml"; then
    no "tidak ada mojibake" "karakter non-ASCII terurai salah lalu ditulis ulang"
else
    ok "tidak ada mojibake — non-ASCII bertahan utuh"
fi
grep -q '—' "$HW/.omp/agent/models.yml" \
    && ok "em dash asli masih ada" || no "em dash bertahan" "hilang atau berubah"

# ── 3. uji runtime PowerShell yang sebelumnya hanya jalan di CI ──────────────
echo "uji runtime PowerShell:"
for t in test/Test-PiModels.ps1 test/Test-OmpModels.ps1; do
    [ -f "$t" ] || { no "$t ada" "hilang"; continue; }
    if out="$(pwsh -NoProfile -File "$t" 2>&1)"; then
        ok "$(basename "$t") — $(printf '%s' "$out" | grep -oE 'lulus [0-9]+, gagal [0-9]+' | tail -1)"
    else
        no "$(basename "$t")" "$(printf '%s' "$out" | tail -3)"
    fi
done

echo
echo "lulus $pass, gagal $fail"
[ "$fail" -eq 0 ]
