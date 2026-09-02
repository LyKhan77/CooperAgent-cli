#!/usr/bin/env bash
#
# Uji regresi scripts/setup-dev.sh.
#
# Semua uji berjalan di GROK_HOME sementara — ~/.grok milik pengguna TIDAK
# pernah disentuh. Jalankan dari root repo:  ./test/test_setup-dev.sh
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."
SB="$(mktemp -d)"
SETUP=./scripts/setup-dev.sh
pass=0; fail=0

# Gateway TIRUAN, bukan gateway produksi.
#
# Sejak 2 September 2026 setup-dev.sh menuntut alamat gateway: nilai kontrak
# dan `base_url` tidak lagi dipatok di template, jadi tanpa alamat ia menolak
# menuliskan config yang pasti salah. Uji ini menyediakan alamatnya sendiri --
# menunjuk ke produksi akan membuat hasilnya bergantung pada keadaan server.
GWPORT=8996
python3 "$(dirname "${BASH_SOURCE[0]}")/fixtures/fake-gateway.py" "$GWPORT" & GW_PID=$!
cleanup() { [ -n "${GW_PID:-}" ] && kill "$GW_PID" 2>/dev/null; rm -rf "$SB"; }
trap cleanup EXIT
for _ in $(seq 20); do curl -sf -o /dev/null "http://127.0.0.1:$GWPORT/v1/models" && break; sleep 0.2; done
export COOPERAGENT_GATEWAY="http://127.0.0.1:$GWPORT"
GW_URL="http://127.0.0.1:$GWPORT/api/v1"

t() { # nama, dapat, harusnya
    if [ "$2" = "$3" ]; then echo "  ✔ $1"; pass=$((pass + 1))
    else echo "  ✖ $1 — dapat '$2', harusnya '$3'"; fail=$((fail + 1)); fi
}

# Config dev yang lengkap dan mutakhir, dipakai beberapa uji.
mk_full_config() {
    cat > "$1" <<'CFG'
[cli]
auto_update = false

[session]
auto_compact_threshold_percent = 85
load_envrc = true

[model.internal-qwen]
model = "qwen35"
context_window = 118784
temperature = 1.0
api_key = "dev-uji"

[memory]
enabled = true
CFG
}

echo "═══ A: GROK_HOME kosong (developer baru) ═══"
mkdir -p "$SB/fresh"
out=$(GROK_HOME="$SB/fresh" $SETUP 2>&1); t "exit code" "$?" "0"
t "peringatan api_key muncul"  "$(grep -c 'Tidak ada api_key' <<<"$out")" "1"
t "verifikasi berjalan"        "$(grep -c 'auto_compact_threshold_percent = 80' <<<"$out")" "1"
t "AGENTS.md terpasang"        "$([ -f "$SB/fresh/AGENTS.md" ] && echo ya)" "ya"

echo "═══ B: config minimal — hanya [cli] ═══"
mkdir -p "$SB/min"; printf '[cli]\nauto_update = false\n' > "$SB/min/config.toml"
GROK_HOME="$SB/min" $SETUP >/dev/null 2>&1; t "exit code" "$?" "0"
t "TOML hasil valid" "$(python3 -c "import tomllib;tomllib.load(open('$SB/min/config.toml','rb'));print('ya')" 2>/dev/null)" "ya"

echo "═══ C: config dev lengkap + skill pihak lain ═══"
mkdir -p "$SB/full/skills/brainstorming"; mk_full_config "$SB/full/config.toml"; echo x > "$SB/full/skills/brainstorming/SKILL.md"
out=$(GROK_HOME="$SB/full" $SETUP 2>&1); t "exit code" "$?" "0"
t "api_key dipertahankan"      "$(grep -c 'api_key = "dev-uji"' "$SB/full/config.toml")" "1"
t "temperature tidak disentuh" "$(grep -c 'temperature = 1.0' "$SB/full/config.toml")" "1"
# Diperiksa lewat TOML terurai: `context_window` sengaja ada di dua seksi model
# (internal-qwen dan internal-qwen-localhost), jadi mencacah baris menyesatkan.
val() { python3 -c "
import tomllib
d = tomllib.load(open('$SB/full/config.toml','rb'))
cur = d
for k in '$1'.split('.'): cur = cur[k]
print(cur)" 2>/dev/null; }
t "ambang jadi 80"             "$(val session.auto_compact_threshold_percent)" "80"
t "context_window jadi 131072" "$(val model.internal-qwen.context_window)" "131072"
t "localhost ikut 131072"      "$(val model.internal-qwen-localhost.context_window)" "131072"
t "memory tetap aktif"         "$(val memory.enabled)" "True"
t "skill lain tidak disentuh"  "$(cat "$SB/full/skills/brainstorming/SKILL.md")" "x"
t "skill lain dilaporkan"      "$(grep -c '1 skill lain' <<<"$out")" "1"

# Alamat di fixture memakai blok dokumentasi RFC 5737 (198.51.100.0/24), bukan
# alamat kantor. Uji hanya butuh dua alamat yang BERBEDA; memakai yang asli
# berarti berkas ini menerbitkan topologi internal begitu ia pindah ke repo
# pemasang -- dan satu di antaranya benar-benar terjangkau dari server, sehingga
# uji diam-diam menembak gateway produksi alih-alih gateway tiruannya sendiri.
echo "═══ C2: base_url per-jaringan tidak boleh ditimpa ═══"
mkdir -p "$SB/vpn"
cat > "$SB/vpn/config.toml" <<'CFG'
[model.internal-qwen]
model = "qwen35"
base_url = "http://198.51.100.20:8987/api/v1"
context_window = 118784
api_key = "dev-vpn"
CFG
GROK_HOME="$SB/vpn" $SETUP >/dev/null 2>&1; t "exit code" "$?" "0"
vpn() { python3 -c "
import tomllib
d = tomllib.load(open('$SB/vpn/config.toml','rb'))
cur = d
for k in '$1'.split('.'): cur = cur[k]
print(cur)" 2>/dev/null; }
t "base_url VPN bertahan"   "$(vpn model.internal-qwen.base_url)" "http://198.51.100.20:8987/api/v1"
t "context_window tetap naik" "$(vpn model.internal-qwen.context_window)" "131072"

echo "═══ C3: tanpa alamat gateway, MENOLAK menulis ═══"
# Janji ini BERUBAH pada 2 September 2026.
#
# Sebelumnya: "dev baru tetap dapat base_url default" -- dan defaultnya adalah IP
# LAN kantor yang dipatok di templates/config.toml. Itu yang menghalangi berkas
# ini pindah ke repo pemasang yang publik.
#
# Sekarang: alamat datang dari dev (env atau config yang sudah ada), dan bila
# tidak ada sama sekali skrip MENOLAK -- menulis config yang pasti salah lebih
# buruk daripada berhenti dengan pesan yang jelas.
mkdir -p "$SB/newdev"
GROK_HOME="$SB/newdev" $SETUP >/dev/null 2>&1; t "exit code" "$?" "0"
t "base_url dari alamat dev" "$(python3 -c "
import tomllib
print(tomllib.load(open('$SB/newdev/config.toml','rb'))['model']['internal-qwen']['base_url'])" 2>/dev/null)" "$GW_URL"

mkdir -p "$SB/noaddr"
out=$(env -u COOPERAGENT_GATEWAY GROK_HOME="$SB/noaddr" $SETUP 2>&1); rc=$?
t "tanpa alamat: menolak"      "$rc" "1"
t "tanpa alamat: menjelaskan"  "$(grep -c 'Jalankan onboarding dulu' <<<"$out")" "1"
t "tanpa alamat: tidak menulis" "$([ -f "$SB/noaddr/config.toml" ] && echo ada || echo tidak)" "tidak"

echo "═══ D: idempoten — jalankan ulang ═══"
out=$(GROK_HOME="$SB/full" $SETUP 2>&1); t "exit code" "$?" "0"
t "tidak ada perubahan" "$(grep -c 'sudah sesuai template' <<<"$out")" "1"
t "cadangan tetap 1"    "$(ls "$SB/full"/config.toml.bak.* 2>/dev/null | wc -l)" "1"

echo "═══ E: --dry-run tidak menulis apa pun ═══"
mkdir -p "$SB/dry"; mk_full_config "$SB/dry/config.toml"
before=$(find "$SB/dry" -type f -exec md5sum {} \; | sort | md5sum)
GROK_HOME="$SB/dry" $SETUP --dry-run >/dev/null 2>&1; t "exit code" "$?" "0"
t "berkas tidak berubah" "$before" "$(find "$SB/dry" -type f -exec md5sum {} \; | sort | md5sum)"

echo "═══ F: aturan agent terpasang ke KEDUA harness ═══"
# Terverifikasi 2026-08-29 dengan kata sandi unik: omp membaca
# ~/.omp/agent/AGENTS.md dan TIDAK membaca ~/.omp/AGENTS.md. Tes ini menjaga
# path itu supaya tidak diam-diam bergeser.
mkdir -p "$SB/both"
HOME="$SB/both" GROK_HOME="$SB/both/.grok" $SETUP >/dev/null 2>&1; t "exit code" "$?" "0"
t "aturan Grok terpasang"  "$([ -f "$SB/both/.grok/AGENTS.md" ] && echo ya)" "ya"
t "aturan omp terpasang"   "$([ -f "$SB/both/.omp/agent/AGENTS.md" ] && echo ya)" "ya"
t "keduanya identik"       "$(cmp -s "$SB/both/.grok/AGENTS.md" "$SB/both/.omp/agent/AGENTS.md" && echo ya)" "ya"
n=$(wc -c < "$SB/both/.grok/AGENTS.md" 2>/dev/null || echo 99999)
t "di bawah batas 10.000"  "$([ "$n" -lt 10000 ] && echo ya)" "ya"

echo "═══ G: konfigurasi omp ikut diperbarui ═══"
mkdir -p "$SB/omp/.grok"
cat > "$SB/omp/.grok/config.toml" <<'CFG'
[model.internal-qwen]
base_url = "http://198.51.100.10:8987/api/v1"
api_key = "dev-uji@mesin"
CFG
HOME="$SB/omp" GROK_HOME="$SB/omp/.grok" $SETUP >/dev/null 2>&1
t "models.yml dibuat"      "$([ -f "$SB/omp/.omp/agent/models.yml" ] && echo ya)" "ya"
# Cocokkan baris PENUH: entri s2 berawalan sama, jadi pencocokan awalan
# menghitungnya dua kali.
t "endpoint routing otomatis" "$(grep -cx '    baseUrl: http://198.51.100.10:8987/v1' "$SB/omp/.omp/agent/models.yml")" "1"
t "entri s2 ikut dirender"    "$(grep -cx '    baseUrl: http://198.51.100.10:8987/v1/upstream/s2' "$SB/omp/.omp/agent/models.yml")" "1"
t "tiga provider terpasang"   "$(grep -cE '^  [a-z0-9-]+:' "$SB/omp/.omp/agent/models.yml")" "3"

# models.yml milik dev TIDAK boleh ditimpa -- ia bisa memuat provider lain.
sed -i 's|baseUrl: .*|baseUrl: http://198.51.100.20:8987/v1|' "$SB/omp/.omp/agent/models.yml"
out=$(HOME="$SB/omp" GROK_HOME="$SB/omp/.grok" $SETUP 2>&1)
t "penyimpangan dilaporkan" "$(grep -c 'menunjuk http://198.51.100.20' <<<"$out")" "1"
t "berkas dev tidak ditimpa" "$(grep -c '198.51.100.20' "$SB/omp/.omp/agent/models.yml")" "3"

echo "═══ H: models.yml konsisten dengan entri Grok ═══"
# Dev Grok mendapat tiga entri model; dev omp harus mendapat tiga provider yang
# sepadan. Sebelum 30 Agustus 2026 ia hanya mendapat satu.
t "template omp ada"        "$([ -f templates/omp-models.yml ] && echo ya)" "ya"
t "tiga provider di template" "$(grep -cE '^  [a-z0-9-]+:' templates/omp-models.yml)" "3"
t "entri s2 ada"            "$(grep -c 'upstream/s2' templates/omp-models.yml)" "1"
# Tidak ada skrip yang boleh menulis YAML-nya sendiri -- empat salinan menyimpang.
t "tidak ada YAML tertanam" "$(grep -lE '^\s+providers:' setup.sh setup.ps1 scripts/setup-dev.sh scripts/setup-dev.ps1 2>/dev/null | wc -l)" "0"

echo "═══ I: setup.sh tidak menimpa models.yml tanpa bertanya ═══"
# Sejajar dengan perlakuan config.toml pada opsi Grok. omp mendukung 60+
# provider; menimpa diam-diam menghapus milik dev.
mkdir -p "$SB/keep/.omp/agent"
cat > "$SB/keep/.omp/agent/models.yml" <<'YML'
providers:
  cooperagent:
    baseUrl: http://198.51.100.20:8987/v1
  punya-saya:
    baseUrl: https://api.anthropic.com/v1
YML
# Baris kosong kedua MELEWATI prompt token.
#
# Sampai 1 September 2026 urutan ini berbunyi '2\nuji\nmesin\n1\n1\n' dan uji
# ini gagal diam-diam sejak commit 6c392af menyisipkan prompt token di depan:
# 'uji' masuk ke sana, ditolak karena tidak diawali 'ca_', dan skrip keluar
# sebelum menyentuh models.yml sama sekali. Prompt nama+device tetap ada pada
# jalur TANPA token -- identitas dari gateway hanya berlaku bila tokennya ada.
out=$(printf '2\n\nuji\nmesin\n1\n' | HOME="$SB/keep" bash setup.sh 2>&1)
t "ditanya lebih dulu"      "$(grep -c 'models.yml omp sudah ada' <<<"$out")" "1"
t "default mempertahankan"  "$(grep -c 'punya-saya' "$SB/keep/.omp/agent/models.yml")" "1"

# Opsi 2 hanya memindahkan gateway lama, bukan setiap baseUrl.
out=$(printf '2\n\nuji\nmesin\n2\n' | HOME="$SB/keep" bash setup.sh 2>&1)
t "gateway dipindahkan"     "$(grep -c "baseUrl: http://127.0.0.1:$GWPORT/v1" "$SB/keep/.omp/agent/models.yml")" "1"
t "provider dev tak tersentuh" "$(grep -c 'api.anthropic.com' "$SB/keep/.omp/agent/models.yml")" "1"

echo "═══ J: skill sampai ke KEDUA harness ═══"
# omp tidak membaca ~/.grok/skills; tanpa salinan kedua, /handoff hanya ada di
# Grok padahal seluruh gunanya bekerja di keduanya.
mkdir -p "$SB/skills/.grok"
printf '[model.internal-qwen]\nbase_url = "http://198.51.100.10:8987/api/v1"\napi_key = "dev-uji@mesin"\n' > "$SB/skills/.grok/config.toml"
HOME="$SB/skills" GROK_HOME="$SB/skills/.grok" $SETUP >/dev/null 2>&1
t "skill untuk Grok" "$([ -f "$SB/skills/.grok/skills/handoff/SKILL.md" ] && echo ya)" "ya"
t "skill untuk omp"  "$([ -f "$SB/skills/.cooper/skills/handoff/SKILL.md" ] && echo ya)" "ya"
t "keduanya identik" "$(cmp -s "$SB/skills/.grok/skills/handoff/SKILL.md" "$SB/skills/.cooper/skills/handoff/SKILL.md" && echo ya)" "ya"

echo
echo "LULUS: $pass   GAGAL: $fail"
[ "$fail" -eq 0 ]
