# Setup Developer — harness CooperAgent

Tanggal: 2026-08-27

## Masalah yang dipecahkan

Tiap developer memasang Grok sendiri-sendiri, dan `~/.grok/config.toml` di tiap
mesin berbeda. Akibatnya pada 27 Agustus 2026 terukur langsung:

- Satu dev tidak punya `auto_compact_threshold_percent`. Sesinya tumbuh sampai
  **130.914 token** dari plafon 131.072, menabrak dinding, dan mulai dari nol —
  seluruh percakapan hilang.
- `/cooper-handoff` menulis checkpoint ke `.cooper/context/` proyek — tidak bergantung pada `[memory]` harness mana pun.
- Skill CooperAgent tidak terlihat di luar repo ini karena tersimpan di
  `<repo>/.grok/skills/`, bukan `~/.grok/skills/`.

Ketiganya satu sebab: **config drift antar mesin**.

## Cara pasang

```bash
git clone <repo>            # atau: git pull, bila sudah ada
cd CooperAgent-cli
./scripts/setup-dev.sh --dry-run    # lihat apa yang akan berubah
./scripts/setup-dev.sh              # pasang
```

Windows tanpa WSL:

```powershell
.\scripts\setup-dev.ps1 -DryRun
.\scripts\setup-dev.ps1
```

Berlaku pada sesi `grok` **berikutnya**; sesi yang sedang berjalan tidak
terpengaruh, jadi aman dijalankan kapan saja.

## Yang dipasang

| Tujuan | Isi |
| :--- | :--- |
| `~/.grok/AGENTS.md` | Aturan kerja agent. Dibaca otomatis di folder mana pun, termasuk folder kosong yang belum jadi repo |
| `~/.grok/config.toml` | Di-**merge**: hanya kunci terkelola yang diubah |
| `~/.grok/skills/` | `cooper-handoff`, `cooper-structure`. Skill lain di mesin dev tidak disentuh |
| `~/.omp/agent/AGENTS.md` | Aturan yang sama untuk Oh My Pi |
| `~/.omp/agent/models.yml` | Dibuat bila belum ada; bila sudah ada **tidak ditimpa**, hanya diperiksa terhadap config Grok |
| omp `compaction.thresholdPercent` | Disetel 80%, sama dengan Grok |

`api_key` **tidak** ada di template, jadi identitas tiap dev tetap miliknya dan
tidak ada kredensial yang masuk git. Bila `api_key` belum ada di mesin, skrip
memberi tahu cara menambahkannya.

## Kunci yang dikelola dan alasannya

```toml
[session]
auto_compact_threshold_percent = 80

[model.internal-qwen]
context_window = 131072
max_tokens = 12288
```

> **Jangan salin angka ini ke kode Anda.** Sejak 1 September 2026 ketiganya
> tidak lagi dipatok di skrip mana pun: skrip setup MENGAMBILNYA dari
> `GET /v1/models` gateway saat dipasang, dan menulis apa pun yang dijawab
> server. Angka di atas adalah nilai per 1 September 2026, dicantumkan supaya
> perhitungan di bawah bisa diikuti — bukan sebagai konstanta.
>
> Nilai yang berlaku sekarang selalu ada di `curl <gateway>/v1/models`, di
> bawah kunci `cooperagent`. Ia berubah setiap kali `--parallel` server
> dinaikkan, dan itu yang dulu tidak pernah sampai ke satu pun mesin dev.

Plafon satu slot server adalah **131.072 token untuk prompt DAN jawaban
sekaligus**. Yang menentukan aman atau tidak bukan penyebutnya, melainkan
hasil kalinya:

```
picu = context_window x ambang
sisa = 131.072 - (picu + max_tokens)
```

| | compaction dipicu di | prompt + jawaban | sisa untuk hasil tool |
| :-- | --: | --: | --: |
| 131.072 / 85% | 111.411 | 123.699 | 7.373 |
| 118.784 / 90% | 106.905 | 119.193 | 11.879 |
| **131.072 / 80%** | **104.858** | 117.146 | **13.926** |

Bentuk kedua menyisihkan jatah keluaran di dalam `context_window` sendiri.
Bentuk ketiga — yang dipakai sekarang — membiarkan `context_window` menyebut
ukuran slot yang sebenarnya dan menaruh seluruh bantalan pada ambangnya. Sisanya
paling lega, dan aritmetikanya ada di satu tempat, bukan dua.

Yang berbahaya adalah `131.072` dengan ambang **tinggi**: pada 85% sisanya
tinggal 7.373 token, dan itu harus menanggung jawaban penuh sekaligus hasil tool
besar. Ambang 80% yang membuat bentuk ini aman, bukan penyebutnya.

## Memperbarui

Jangan menyunting `~/.grok/` langsung — suntingannya hilang pada pembaruan
berikutnya. Sunting sumbernya di `templates/`, commit, lalu tiap dev
`git pull` dan menjalankan ulang skrip setup. Skrip bersifat idempoten: bila
sudah sesuai, ia tidak menulis apa pun dan tidak membuat cadangan baru.

## Pi Agent (opsi tambahan)

`setup-dev.*` tetap updater jalur Grok/omp. Pi dipasang hanya dari pilihan **5**
pada `setup.sh`/`setup.ps1`, atau dari adapter terisolasi:

```bash
./scripts/setup-pi.sh --endpoint <gateway> --token ca_... --rules
```

Adapter pi menulis `~/.pi/agent/models.json`, `settings.json`, dan aturan penuh
ke `~/.pi/agent/AGENTS.md`. JSON di-merge sehingga provider/model tambahan,
provider berbayar, kunci, tema, dan setting dev lain tetap utuh. Skill dibaca
dari `~/.cooper/skills/` bersama.

Model id, context window, max output, dan ambang compaction dibaca dari
`/v1/models`; `reserveTokens = context_window - threshold_tokens`. Token `ca_...`
diperiksa sebelum penulisan dan identitas berasal dari `/api/auth/whoami`.
`verify()` juga menguji chat lewat pi, AGENTS global, dan checkpoint sementara.
Pi hanya untuk mesin dev, bukan s1/s2.
