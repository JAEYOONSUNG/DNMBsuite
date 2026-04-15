# DNMBsuite

Docker wrapper repository for the `DNMB` core package.

![image](https://github.com/user-attachments/assets/9723c00f-447c-4987-bc25-f36068bf64ab)

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

Run from a folder that already contains one or more GenBank files:

```bash
cd [/path/to/folder/with/genbank]

docker run --rm \
  -v "$PWD:/data" \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest
```

Run a single GenBank file explicitly:

```bash
docker run --rm \
  -v /path/to/parent-dir:/data \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest \
  /data/GCF_030369615.1.gbff
```

Run selected modules only with direct Docker:

```bash
docker run --rm \
  -e DNMB_MODULES=defensefinder,padloc,defensepredictor,iselement,prophage \
  -e DNMB_MODULE_CPU=8 \
  -v "$PWD:/data" \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest
```

Run while disabling selected modules with direct Docker:

```bash
docker run --rm \
  -e DNMB_SKIP_MODULES=interproscan,eggnog \
  -e DNMB_MODULE_CPU=8 \
  -v "$PWD:/data" \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest
```

What this does:

- uses the working directory as `/data`
- mounts `~/.dnmb-cache` to `/opt/dnmb/cache`
- detects `*.gb`, `*.gbk`, or `*.gbff` automatically in folder mode
- writes outputs back into the same host folder
- keeps raw InterProScan TSV outputs inside `dnmb_interproscan/`
- lets you control module selection through `DNMB_MODULES`, `DNMB_SKIP_MODULES`, `DNMB_MODULE_CPU`, `DNMB_PROPHAGE_BACKEND`, and `DNMB_CLEAN_PREVIOUS`

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
- mounts `~/.dnmb-cache` to `/opt/dnmb/cache`
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
- `padloc`
- `defensepredictor`
- `merops`
- `pazy`
- `gapmind`
- `iselement`
- `prophage`


Special values for `--modules`:

- `all`
- `none`
- `core`

## Repository-Style Quick Start

If you prefer to run from inside the repository with Docker Compose, create a
`data/` directory in the repository root and put your GenBank file there.
DNMB writes outputs back into the same `data/` directory.

Example layout:

```text
DNMBsuite/
└── data/
    └── GCF_030369615.1.gbff
```

### Option A. Pull the published image

```bash
docker pull ghcr.io/jaeyoonsung/dnmbsuite:latest
```

### Option B. Build locally from this repository

```bash
docker build \
  --build-arg DNMB_REF=master \
  -t ghcr.io/jaeyoonsung/dnmbsuite:latest .
```

### Run

From the `DNMBsuite/` directory:

```bash
docker compose up
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
├── dnmb_module_clean/
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

### One-shot full run

Run DNMB directly without opening an interactive shell:

```bash
docker compose up
```

### One-shot run with explicit options

```bash
docker run --rm \
  -e DNMB_MODULES=defensefinder,iselement,prophage \
  -e DNMB_MODULE_CPU=8 \
  -e DNMB_AUTO_UPDATE=0 \
  -v /path/to/workdir:/data \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest
```

### Notes for testers

- Put exactly the input GenBank files you want to analyze into `./data`.
- The first run can take a long time because module assets may need to be downloaded into `~/.dnmb-cache`.
- Later runs should be much faster because DNMB reuses the shared cache and matching previous outputs.
- If you want a clean rerun but still keep reusable outputs, keep `clean_previous = TRUE`. The current DNMB logic preserves matching cached module and external annotation outputs when the input genome has not changed.
- DNMB auto-update is off by default. Leave it off for reproducible runs; enable it only when you explicitly want to refresh the bundled DNMB package from GitHub.
- Advanced launcher environment variables:
  `DNMB_MODULES`, `DNMB_SKIP_MODULES`, `DNMB_MODULE_CPU`, `DNMB_PROPHAGE_BACKEND`, `DNMB_CLEAN_PREVIOUS`, `DNMB_AUTO_UPDATE`, `DNMB_AUTO_UPDATE_BRANCH`

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
/opt/dnmb/cache
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

## Publish To GHCR

This repository includes a GitHub Actions workflow that builds and publishes to GitHub Container Registry.

Expected image name:

```text
ghcr.io/jaeyoonsung/dnmbsuite
```

Before first release:

1. Push this repository to `JAEYOONSUNG/DNMBsuite`.
2. Confirm Actions and Packages permissions are enabled.
3. Optionally change the default `DNMB_REF` in the workflow if you want to pin a specific core release later.

After that, pushes to `master` or tags matching `v*` will publish the image automatically.
