# DNMBsuite

Docker wrapper repository for the `DNMB` core package.
<img alt="DNMB" src="https://github.com/user-attachments/assets/04288552-cd42-4d40-afb1-4bb0607f5bd6" />

## What You Need To Provide

Only one thing is required from the user:

- one or more input GenBank files (`*.gb`, `*.gbk`, or `*.gbff`)

## What DNMBsuite Does Automatically

- installs the DNMB core package inside the container image
- uses a shared host cache at `~/.dnmb-cache`
- downloads module databases and tool assets on first use when needed
- records module metadata in the shared cache so stale installs can be refreshed
- reuses the shared cache on later runs

## Recommended Quick Start

The simplest way to use DNMBsuite is the published Docker image.

Pull the image:

```bash
docker pull ghcr.io/jaeyoonsung/dnmbsuite:latest
```

On Linux, create the shared cache first so the container can reuse it without
leaving root-owned files behind:

```bash
mkdir -p "$HOME/.dnmb-cache"
```

Run from a folder that already contains one or more GenBank files:

```bash
cd [/path/to/folder/with/genbank]

docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v "$PWD:/data" \
  -v "$HOME/.dnmb-cache:/opt/dnmb-cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest
```

Run a single GenBank file explicitly:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -v /path/to/parent-dir:/data \
  -v "$HOME/.dnmb-cache:/opt/dnmb-cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest \
  /data/GCF_030369615.1.gbff
```

Run selected modules only with direct Docker:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e DNMB_MODULES=defensefinder,padloc,defensepredictor,iselement,prophage \
  -e DNMB_MODULE_CPU=8 \
  -v "$PWD:/data" \
  -v "$HOME/.dnmb-cache:/opt/dnmb-cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest
```

Run the anti-defense stack only with direct Docker:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e DNMB_MODULES=defensefinder,dbapis,acrfinder \
  -e DNMB_MODULE_CPU=8 \
  -v "$PWD:/data" \
  -v "$HOME/.dnmb-cache:/opt/dnmb-cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest
```

Run while disabling selected modules with direct Docker:

```bash
docker run --rm \
  --user "$(id -u):$(id -g)" \
  -e DNMB_SKIP_MODULES=interproscan,eggnog \
  -e DNMB_MODULE_CPU=8 \
  -v "$PWD:/data" \
  -v "$HOME/.dnmb-cache:/opt/dnmb-cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest
```

What this does:

- uses the working directory as `/data`
- mounts `~/.dnmb-cache` to `/opt/dnmb-cache`
- detects `*.gb`, `*.gbk`, or `*.gbff` automatically in folder mode
- writes outputs back into the same host folder
- keeps raw InterProScan TSV outputs inside `dnmb_interproscan/`
- on Linux, runs as your current host UID/GID in the direct `docker run` examples so output and cache files stay writable by you
- on arm64 hosts, add `--platform linux/amd64` to the direct `docker run` command because the published image is currently `amd64`
- lets you control module selection through `DNMB_MODULES`, `DNMB_SKIP_MODULES`, `DNMB_MODULE_CPU`, `DNMB_PROPHAGE_BACKEND`, `DNMB_CLEAN_PREVIOUS`, `DNMB_COMPARATIVE`, and `DNMB_COMPARATIVE_DATA_ROOT`

## Optional Shell Launcher

If you prefer not to type the Docker command manually, use the bundled shell
launcher.

Setup:

```bash
git clone https://github.com/JAEYOONSUNG/DNMBsuite.git
cd DNMBsuite
```

Run with default output location:

```bash
bash run-dnmb.sh /path/to/GCF_030369615.1.gbff
```

Run with a custom output directory:

```bash
bash run-dnmb.sh /path/to/GCF_030369615.1.gbff /path/to/output-dir
```

Run with selected modules only:

```bash
bash run-dnmb.sh /path/to/GCF_030369615.1.gbff --modules defensefinder,iselement,prophage
bash run-dnmb.sh /path/to/GCF_030369615.1.gbff --modules defensefinder,padloc,defensepredictor,iselement,prophage
```

Run the anti-defense stack only:

```bash
bash run-dnmb.sh /path/to/GCF_030369615.1.gbff --modules defensefinder,dbapis,acrfinder
```

Run while disabling selected modules:

```bash
bash run-dnmb.sh /path/to/GCF_030369615.1.gbff --skip-modules interproscan,eggnog --cpu 8
```

Opt in to a startup DNMB refresh from GitHub:

```bash
bash run-dnmb.sh /path/to/GCF_030369615.1.gbff --dnmb-auto-update --dnmb-auto-update-branch master
```

What this launcher does:

- pulls `ghcr.io/jaeyoonsung/dnmbsuite:latest` automatically when missing
- mounts the output directory to `/data`
- mounts `~/.dnmb-cache` to `/opt/dnmb-cache`
- copies the input GenBank file into the output directory when needed
- runs the same built-in container launcher
- keeps the bundled DNMB package fixed unless you explicitly opt in to `DNMB_AUTO_UPDATE=1`

In single-file mode, DNMBsuite stages only that file, runs the analysis, and
writes outputs back next to the original input file.

Supported module names for `--modules` and `--skip-modules`:


- `interproscan`
- `eggnog`
- `clean`
- `dbcan`
- `rebasefinder`
- `defensefinder`
- `dbapis`
- `acrfinder`
- `padloc`
- `defensepredictor`
- `merops`
- `pazy`
- `gapmind`
- `iselement`
- `phispy`
- `virsorter2`
- `pide`
- `prophage` (deprecated alias — maps to the backend chosen by `module_Prophage_backend`, default `phispy`)


Special values for `--modules`:

- `all`
- `none`
- `core`

### GPU-gated defaults (CLEAN and PIDE)

`CLEAN` and `PIDE` are both GPU-heavy: CLEAN runs LayerNormNet
embeddings, and PIDE runs an ESM-650M protein language model. Both run
~50–100× faster on a CUDA GPU than on CPU.

- The direct Docker entrypoint and `run-dnmb.sh` both probe `nvidia-smi -L`
  and turn `CLEAN`/`PIDE` on **only when a CUDA GPU is detected**; otherwise
  they are skipped so a typical laptop run completes in minutes rather than
  hours.
- When CUDA is detected, `run-dnmb.sh` also adds `--gpus all` to `docker run`
  so the container can reach the GPU, and exports `DNMB_CUDA=TRUE` for the R
  defaults to agree.
- Force CPU-based execution only when you explicitly want the slow CPU path by
  setting `DNMB_FORCE_CPU_HEAVY=1` or selecting the modules directly with
  `DNMB_MODULES=clean,pide` / `--modules clean,pide`.
- Force-disable them with `DNMB_CUDA=0`, `DNMB_SKIP_MODULES=clean,pide`, or
  `--skip-modules clean,pide`.

Direct Docker example for forcing the CPU path:

```bash
docker run --rm \
  --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -e DNMB_FORCE_CPU_HEAVY=1 \
  -v "$PWD:/data" \
  -v "$HOME/.dnmb-cache:/opt/dnmb-cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest
```

### Output location

Outputs are written into the same `data/` directory that contains the input
GenBank file.

Example output structure:

```text
data/
├── GCF_030369615.1.gbff
├── GCF_030369615_total.xlsx
├── dnmb_interproscan/
├── dnmb_module_acrfinder/
├── dnmb_module_clean/
├── dnmb_module_dbapis/
├── dnmb_module_defensefinder/
├── dnmb_module_padloc/
├── dnmb_module_defensepredictor/
├── dnmb_module_eggnog/
├── dnmb_module_gapmindaa/
├── dnmb_module_gapmindcarbon/
├── dnmb_module_iselement/
├── dnmb_module_merops/
├── dnmb_module_pazy/
├── dnmb_module_prophage/
├── dnmb_module_rebasefinder/
└── visualizations/
```

### Anti-defense outputs

When anti-defense hits are found, DNMBsuite aggregates:

- `DefenseFinder --antidefensefinder`
- `dbAPIS`
- `AcrFinder`

into the final workbook and the anti-defense visualization set.

Typical anti-defense output paths are:

```text
data/
├── dnmb_module_acrfinder/
├── dnmb_module_dbapis/
├── dnmb_module_defensefinder/
└── visualizations/
    ├── AntiDefense_overview.pdf
    └── AntiDefenseFinder_overview.pdf
```

Notes:

- `AntiDefense_overview.pdf` is the integrated anti-defense summary across the available anti-defense modules.
- `AntiDefenseFinder_overview.pdf` is the DefenseFinder-specific anti-defense plot.
- If all anti-defense modules complete with `0` hits for a genome, the anti-defense PDFs can be skipped because there is nothing to draw.

### First-run behavior

- the first run can take a long time because module assets may need to be downloaded into `~/.dnmb-cache`
- later runs are much faster because DNMB reuses the shared cache and matching previous outputs
- `clean_previous = TRUE` removes stale run artifacts but preserves matching reusable outputs when the input genome has not changed
- DNMB core auto-update is disabled by default so a published image stays reproducible; opt in only when you intentionally want the container to track the latest GitHub branch

## Build

Build from the latest core on `master`:

```bash
docker build \
  --build-arg DNMB_REF=master \
  -t ghcr.io/jaeyoonsung/dnmbsuite:latest .
```

Build from a fixed core commit or tag:

```bash
docker build \
  --build-arg DNMB_REF=<dnmb-git-ref> \
  -t ghcr.io/jaeyoonsung/dnmbsuite:<tag> .
```

## Pull Published Image

Once the image is published to GHCR:

```bash
docker pull ghcr.io/jaeyoonsung/dnmbsuite:latest
```

If the package is private, authenticate first:

```bash
echo <GITHUB_TOKEN> | docker login ghcr.io -u <github-user> --password-stdin
```

For release or manuscript runs, prefer a fixed image tag or digest and keep `DNMB_AUTO_UPDATE=0`.

## Usage

### Interactive R

Open an interactive R session inside the container:

```bash
docker compose run --rm dnmbshell
```

Inside R:

```r
library(DNMB)
setwd("/data")
run_DNMB(clean_previous = TRUE)
```

To also emit the full comparative suite across sibling genome folders at
the end of the per-genome run, pass `comparative = TRUE`:

```r
library(DNMB)
setwd("/data/<focal-genome>")
run_DNMB(clean_previous = TRUE, comparative = TRUE)
# or point elsewhere:
# run_DNMB(clean_previous = TRUE, comparative = TRUE, comparative_data_root = "/data")
```

### Comparative per-module heatmaps across genomes

`run_DNMB(comparative = TRUE)` renders the full suite end-to-end after
the per-genome pipeline finishes (it calls each plotter below against
`dirname(getwd())`, or `comparative_data_root` when supplied). The
individual plotters stay useful when you want a subset or custom colors.

Run the comparative suite directly with Docker, without opening R, after
per-genome DNMB runs have already produced one genome folder per GenBank file:

```text
data/
├── genome_1/
│   └── input_1.gbff
├── genome_2/
│   └── input_2.gbff
└── genome_3/
    └── input_3.gbff
```

From the parent directory that contains `data/`:

```bash
docker run --rm \
  --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -e DNMB_MODULE_CPU=8 \
  -v "$PWD/data:/data" \
  -v "$HOME/.dnmb-cache:/opt/dnmb-cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest \
  comparative /data
```

This writes comparative PDFs and count matrices under:

```text
data/comparative/
```

To run a per-genome DNMB analysis and render the comparative suite at the end
from a focal genome folder, use:

```bash
cd /path/to/data/genome_1

docker run --rm \
  --platform linux/amd64 \
  --user "$(id -u):$(id -g)" \
  -e DNMB_COMPARATIVE=1 \
  -e DNMB_COMPARATIVE_DATA_ROOT=/data \
  -e DNMB_MODULE_CPU=8 \
  -v "$(dirname "$PWD"):/data" \
  -v "$HOME/.dnmb-cache:/opt/dnmb-cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest \
  /data/$(basename "$PWD")
```

After per-genome DNMB runs finish, render across-genome heatmaps for
defense-module families as well as enzyme/CAZyme modules. Each plotter
treats every GenBank-bearing subfolder of `data_root` as one genome,
auto-runs only the relevant module (`db = "<Module>"`, not the full
pipeline) for genomes missing that output, and writes a PDF + count
matrix under `<data_root>/comparative/`.

```r
library(DNMB)

data_root <- "/data"   # parent directory with one subfolder per genome

# Defense-system heatmaps (purple palette)
dnmb_plot_comparative_defensefinder(data_root)    # DefenseFinder
dnmb_plot_comparative_padloc(data_root)           # PADLOC
dnmb_plot_comparative_defensepredictor(data_root) # DefensePredictor
dnmb_plot_comparative_rebasefinder(data_root)     # REBASEfinder

# Enzyme / CAZyme heatmaps (module-specific palettes)
dnmb_plot_comparative_merops(data_root)             # MEROPS family (C26, S8, …)
dnmb_plot_comparative_merops_catalytic(data_root)   # MEROPS catalytic type (Cysteine, Serine, …)
dnmb_plot_comparative_dbcan(data_root)              # dbCAN class (GH, GT, PL, …)
dnmb_plot_comparative_dbcan_family(data_root)       # dbCAN family (GH13, GT2, …)
dnmb_plot_comparative_cgc(data_root)                # CGC signature mix (CAZyme+TC+TF, …)
dnmb_plot_comparative_cgc_substrate(data_root)      # CGC substrate (starch, melibiose, …)
dnmb_plot_comparative_pazy(data_root)               # PAZy families

# Prophage heatmaps (purple palette)
dnmb_plot_comparative_phispy(data_root)     # PhiSpy regions bucketed by size
dnmb_plot_comparative_virsorter2(data_root) # VirSorter2 max_score_group
dnmb_plot_comparative_pide(data_root)       # PIDE regions bucketed by size
```

Pass `auto_run_missing = FALSE` to render only what already exists.

### Notes for testers

- Put exactly the input GenBank files you want to analyze into `./data`.
- The first run can take a long time because module assets may need to be downloaded into `~/.dnmb-cache`.
- Later runs should be much faster because DNMB reuses the shared cache and matching previous outputs.
- If you want a clean rerun but still keep reusable outputs, keep `clean_previous = TRUE`. The current DNMB logic preserves matching cached module and external annotation outputs when the input genome has not changed.
- DNMB auto-update is off by default. Leave it off for reproducible runs; enable it only when you explicitly want to refresh the bundled DNMB package from GitHub.
- If older Linux runs left root-owned files in `~/.dnmb-cache`, fix them before rerunning with:
  `sudo chown -R "$(id -u):$(id -g)" "$HOME/.dnmb-cache"`
- If an older image fails only in PADLOC with `mkdir: cannot create directory '/opt/biotools/bin/../data': Permission denied`, either pull a rebuilt image from this repo or add:
  `-v "$HOME/.dnmb-cache/padloc-bootstrap:/opt/biotools/data"`
  to the direct `docker run` command after creating that host folder once with:
  `mkdir -p "$HOME/.dnmb-cache/padloc-bootstrap"`
- Advanced launcher environment variables:
  `DNMB_MODULES`, `DNMB_SKIP_MODULES`, `DNMB_MODULE_CPU`, `DNMB_PROPHAGE_BACKEND`, `DNMB_CLEAN_PREVIOUS`, `DNMB_FORCE_CPU_HEAVY`, `DNMB_COMPARATIVE`, `DNMB_COMPARATIVE_DATA_ROOT`, `DNMB_AUTO_UPDATE`, `DNMB_AUTO_UPDATE_BRANCH`

## Compose

Create the input directory first:

```bash
mkdir -p data
```

Build and run the pipeline:

```bash
docker compose build
docker compose up
```

Open an interactive R shell instead:

```bash
docker compose run --rm dnmbshell
```

Use a different core ref only if you explicitly want to override the default:

```bash
DNMB_REF=<dnmb-git-ref> docker compose build
```

Opt in to DNMB startup refresh only when desired:

```bash
DNMB_AUTO_UPDATE=1 DNMB_AUTO_UPDATE_BRANCH=master docker compose up
```

Use a different output tag locally:

```bash
IMAGE_TAG=test docker compose build
```

## Cache

DNMBsuite expects a shared host cache at:

```text
~/.dnmb-cache
```

This directory is mounted to:

```text
/opt/dnmb-cache
```

inside the container, and `DNMB_CACHE_ROOT` is set automatically.

This means:

- module databases are downloaded once and reused
- Docker and local DNMB runs can share the same cache
- users normally do not need to set `module_cache_root` manually inside the container
- the DNMBsuite container seeds the CLEAN Python environment into the mounted host cache when it is missing

## Core Source

```text
https://github.com/JAEYOONSUNG/DNMB.git
```

By default DNMBsuite installs the DNMB core from this repository at image build time using:

```text
master
```

Container startup does not mutate that installed core unless you explicitly set `DNMB_AUTO_UPDATE=1`.

If you need to override the build-time core ref, use `DNMB_REF`:

```bash
docker build --build-arg DNMB_REF=master -t ghcr.io/jaeyoonsung/dnmbsuite:latest .
docker build --build-arg DNMB_REF=<commit-sha> -t ghcr.io/jaeyoonsung/dnmbsuite:dev .
```


## License
This project is released under MIT licence, which allows for both personal and commercial use, modification, and distribution of our work, provided that proper credit is given.

We hope our resources will prove invaluable to your research in systems biology. For any questions or feedback, please don't hesitate to reach out through our GitHub issues or contact section.

## Citation
If you use this piepline, please cite:
```
[DNMB] DNMB: Programmable domestication of thermophilic bacteria through removal of non-canonical defense systems.
			 Sung, J.Y., Lee, M.H., Park, J.S., Kim, H.B., Ganbat, D., Kim, D.G., Cho, H.W., Suh, M.K., Lee, J.S., Lee, S.J., Kim, S.B.*, and Lee, D.W.*.
			 *bioRxiv* 2026.03.21.173436. (2026)  
```
Please, cite also the underlying algorithm/database if it was used for the search step of DNMB:
```
  [EggNOG-mapper v2]    eggNOG-mapper v2: Functional annotation, orthology assignments, and domain prediction at
                        the metagenomic scale. Carlos P. Cantalapiedra, Ana Hernandez-Plaza,
                        Ivica Letunic, Peer Bork, Jaime Huerta-Cepas. 2021. Molecular Biology and Evolution
                        38(12):5825-5829. https://doi.org/10.1093/molbev/msab293

  [CLEAN]               Enzyme function prediction using contrastive learning. Tianhao Yu, Haiyang Cui, Jianan Canal Li,
                        Yunan Luo, Guangde Jiang, Huimin Zhao. 2023. Science 379(6639):1358-1363. 
                        https://doi.org/10.1126/science.adf2465

  [InterProScan]        InterProScan 5: genome-scale protein function classification.
                        Philip Jones, David Binns, Hsin-Yu Chang, Matthew Fraser, Weizhong Li, Craig McAnulla,
                        Hamish McWilliam, John Maslen, Alex Mitchell, Gift Nuka, Sebastien Pesseat, Antony F. Quinn,
                        Amaia Sangrador-Vegas, Maxim Scheremetjew, Siew-Yit Yong, Rodrigo Lopez, Sarah Hunter.
                        2014. Bioinformatics 30(9):1236-1240. https://doi.org/10.1093/bioinformatics/btu031

  [DefenseFinder]       DefenseFinder: Systematic and quantitative view of the antiviral arsenal of prokaryotes.
                        Florian Tesson, Alexandre Herve, Ernest Mordret, Marie Touchon, Camille d'Humieres, Jean Cury,
                        Aude Bernheim. 2022. Nature Communications 13:2561. https://doi.org/10.1038/s41467-022-30269-9

  [REBASE]              REBASE-a database for DNA restriction and modification: enzymes, genes and genomes.
                        Richard J. Roberts, Tamas Vincze, Janos Posfai, Dana Macelis. 2010. Nucleic Acids Research
                        38(Database issue):D234-D236. https://doi.org/10.1093/nar/gkp874

  [GapMindAA]           GapMind: Automated annotation of amino acid biosynthesis.
                        Morgan N. Price, Adam M. Deutschbauer, Adam P. Arkin. 2020. mSystems 5(3):e00291-20.
                        https://doi.org/10.1128/mSystems.00291-20

  [GapMindCarbon]       Filling gaps in bacterial catabolic pathways with computation and high-throughput genetics.
                        Morgan N. Price, Adam M. Deutschbauer, Adam P. Arkin. 2022. PLoS Genetics 18(4):e1010156.
                        https://doi.org/10.1371/journal.pgen.1010156

  [MEROPS]              The MEROPS database of proteolytic enzymes, their substrates and inhibitors in 2017 and a
                        comparison with peptidases in the PANTHER database. Neil D. Rawlings, Alan J. Barrett,
                        Paul D. Thomas, Xiaosong Huang, Alex Bateman, Robert D. Finn. 2018. Nucleic Acids Research
                        46(D1):D624-D632. https://doi.org/10.1093/nar/gkx1134

  [dbCAN]               dbCAN3: automated carbohydrate-active enzyme and substrate annotation.
                        Jinfang Zheng, Qiwei Ge, Yuchen Yan, Xinpeng Zhang, Le Huang, Yanbin Yin. 2023.
                        Nucleic Acids Research 51(W1):W115-W121. https://doi.org/10.1093/nar/gkad328

  [PAZy]                Plastics degradation by hydrolytic enzymes: The plastics-active enzymes database-PAZy.
                        Patrick C. F. Buchholz, Golo Feuerriegel, Hongli Zhang, Pablo Perez-Garcia,
                        Lena-Luisa Nover, Jennifer Chow, Wolfgang R. Streit, Jurgen Pleiss. 2022.
                        Proteins 90(7):1443-1456. https://doi.org/10.1002/prot.26325

  [ISelement]           ISEScan: automated identification of insertion sequence elements in prokaryotic genomes.
                        Zhiqun Xie, Haixu Tang. 2017. Bioinformatics 33(21):3340-3347.
                        https://doi.org/10.1093/bioinformatics/btx433

						ISfinder: the reference centre for bacterial insertion sequences. 
                        Philippe Siguier, Jerome Perochon, Lucie Lestrade, Jacques Mahillon,
                        Michael Chandler. 2006. Nucleic Acids Research 34(Database issue):D32-D36.
                        https://doi.org/10.1093/nar/gkj014

  [PhiSpy]              PhiSpy: a novel algorithm for finding prophages in bacterial genomes that combines similarity-
                        and composition-based strategies. Sajia Akhter, Rashedul Aziz,
                        Robert A. Edwards. 2012. Nucleic Acids Research 40(16):e126. https://doi.org/10.1093/nar/gks406

  [VirSorter2]          VirSorter2: a multi-classifier, expert-guided approach to detect diverse DNA and RNA viruses.
                        Jiarong Guo, Ben Bolduc, Ahmed A Zayed, Arvind Varsani, Guillermo Dominguez-Huerta, Tom O Delmont,
                        Akbar Adjie Pratama, M Consuelo Gazitúa, Dean Vik, Matthew B Sullivan, Simon Roux. 2021. Microbiome 9:37.
                        https://doi.org/10.1186/s40168-020-00990-y

  [PIDE]                PIDE: a deep learning-based tool for prophage identification using genome-wide features.
                        https://github.com/BackofenLab/PIDE

  [dbAPIS]				dbAPIS: dbAPIS: a database of anti-prokaryotic immune system genes. Yuchen Yan , Jinfang Zheng ,
						Xinpeng Zhang , Yanbin Yin. 2025. Nucleic Acids Research 52(D1):D419–D425, https://doi.org/10.1093/nar/gkad932
```
