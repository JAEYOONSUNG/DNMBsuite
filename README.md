# DNMBsuite

Docker wrapper repository for the `DNMB` core package.

## What You Need To Provide

Only one thing is required from the user:

- one or more input GenBank files (`*.gb`, `*.gbk`, or `*.gbff`)

## What DNMBsuite Does Automatically

- installs the DNMB core package inside the container image
- uses a shared host cache at `~/.dnmb-cache`
- downloads module databases and tool assets on first use when needed
- reuses the shared cache on later runs

## Recommended Quick Start

The recommended way to use DNMBsuite is the bundled shell launcher.
It hides the Docker `run` and volume-mount details from the user.

Setup:

```bash
git clone https://github.com/JAEYOONSUNG/DNMBsuite.git
cd DNMBsuite
```

Run with default output location:

```bash
bash run-dnmb.sh /path/to/GCF_000143145.1.gbff
```

Run with a custom output directory:

```bash
bash run-dnmb.sh /path/to/GCF_000143145.1.gbff /path/to/output-dir
```

Run with selected modules only:

```bash
bash run-dnmb.sh /path/to/GCF_000143145.1.gbff --modules defensefinder,iselement,prophage
```

Run while disabling selected modules:

```bash
bash run-dnmb.sh /path/to/GCF_000143145.1.gbff --skip-modules interproscan,eggnog --cpu 8
```

What this launcher does:

- pulls `ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2` automatically when missing
- mounts the output directory to `/data`
- mounts `~/.dnmb-cache` to `/opt/dnmb/cache`
- copies the input GenBank file into the output directory when needed
- runs `DNMB::run_DNMB(clean_previous = TRUE)`

## Direct Docker Usage

If you want to use Docker directly without the shell launcher, the image also
contains its own built-in auto-run entrypoint.

Minimal folder-based usage:

```bash
docker run --rm \
  -v /path/to/workdir:/data \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2
```

Requirements:

- put one or more `*.gb`, `*.gbk`, or `*.gbff` files inside `/path/to/workdir`
- outputs are written back into that same folder

Run a single file explicitly:

```bash
docker run --rm \
  -v /path/to/parent-dir:/data \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2 \
  /data/GCF_000143145.1.gbff
```

In single-file mode, DNMBsuite stages only that file, runs the analysis, and
writes outputs back next to the original input file.

Supported module names for `--modules` and `--skip-modules`:

- `dbcan`
- `merops`
- `clean`
- `pazy`
- `gapmind`
- `defensefinder`
- `rebasefinder`
- `iselement`
- `prophage`
- `eggnog`
- `interproscan`

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
    └── GCF_000143145.1.gbff
```

### Option A. Pull the published image

```bash
docker pull ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2
```

### Option B. Build locally from this repository

```bash
docker build \
  --build-arg DNMB_REF=v1.0.2 \
  -t ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2 .
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
├── GCF_000143145.1.gbff
├── GCF_000143145_total.xlsx
├── dnmb_interproscan/
├── dnmb_module_clean/
├── dnmb_module_defensefinder/
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

## Build

Build from the pinned core release `v1.0.2`:

```bash
docker build \
  --build-arg DNMB_REF=v1.0.2 \
  -t ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2 .
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
docker pull ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2
```

If the package is private, authenticate first:

```bash
echo <GITHUB_TOKEN> | docker login ghcr.io -u <github-user> --password-stdin
```

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
  -v /path/to/workdir:/data \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2
```

### Notes for testers

- Put exactly the input GenBank files you want to analyze into `./data`.
- The first run can take a long time because module assets may need to be downloaded into `~/.dnmb-cache`.
- Later runs should be much faster because DNMB reuses the shared cache and matching previous outputs.
- If you want a clean rerun but still keep reusable outputs, keep `clean_previous = TRUE`. The current DNMB logic preserves matching cached module and external annotation outputs when the input genome has not changed.
- Advanced launcher environment variables:
  `DNMB_MODULES`, `DNMB_SKIP_MODULES`, `DNMB_MODULE_CPU`, `DNMB_PROPHAGE_BACKEND`, `DNMB_CLEAN_PREVIOUS`

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

Use a fixed core ref:

```bash
DNMB_REF=<dnmb-git-ref> docker compose build
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

## Core Version Selection

The Dockerfile installs the core package from:

```text
https://github.com/JAEYOONSUNG/DNMB.git
```

The git ref is controlled by:

```text
DNMB_REF
```

Examples:

```bash
docker build --build-arg DNMB_REF=v1.0.2 -t ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2 .
docker build --build-arg DNMB_REF=v1.0.2 -t ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2 .
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
3. Optionally change the default `DNMB_REF` in the workflow from `v1.0.2` to a later core release tag.

After that, pushes to `master` or tags matching `v*` will publish the image automatically.
