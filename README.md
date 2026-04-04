# DNMBsuite

Docker wrapper repository for the `DNMB` core package.

## Design

- `DNMB` remains the core R package repository.
- `DNMBsuite` publishes the container image and compose wrapper.
- Large databases are not baked into the image.
- Runtime caches are stored in `~/.dnmb-cache` on the host and mounted into the container at `/opt/dnmb/cache`.

## Quick Start

1. Create a working directory and put your GenBank input into `data/`.
2. Mount `~/.dnmb-cache` so downloaded module databases are reused.
3. Run `DNMB::run_DNMB()` inside the container from `/data`.

Example directory layout:

```text
my-run/
├── data/
│   └── GCF_000143145.1.gbff
└── results/
```

Example one-shot run from that directory:

```bash
docker run --rm \
  -v "$(pwd)/data:/data" \
  -v "$(pwd)/results:/results" \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2 \
  Rscript -e 'library(DNMB); setwd("/data"); run_DNMB(clean_previous = TRUE)'
```

Expected behavior:

- DNMB looks for `*.gb`, `*.gbk`, or `*.gbff` inside `/data`.
- Results are written back into `/data` unless the core function writes a separate module-specific output folder.
- Shared module caches are reused from `~/.dnmb-cache`.

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
docker run --rm -it \
  -v "$(pwd)/data:/data" \
  -v "$(pwd)/results:/results" \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2 R
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
docker run --rm \
  -v "$(pwd)/data:/data" \
  -v "$(pwd)/results:/results" \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2 \
  Rscript -e 'library(DNMB); setwd("/data"); run_DNMB(clean_previous = TRUE)'
```

### One-shot run with explicit options

```bash
docker run --rm \
  -v "$(pwd)/data:/data" \
  -v "$(pwd)/results:/results" \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:v1.0.2 \
  Rscript -e 'library(DNMB); setwd("/data"); run_DNMB(module_dbCAN = TRUE, module_MEROPS = TRUE, module_CLEAN = TRUE, module_PAZy = TRUE, module_GapMind = TRUE, module_DefenseFinder = TRUE, module_REBASEfinder = TRUE, module_ISelement = TRUE, module_Prophage = TRUE, module_EggNOG = TRUE, module_InterProScan = TRUE, clean_previous = TRUE)'
```

### Notes for testers

- Put exactly the input GenBank files you want to analyze under `data/`.
- The first run can take a long time because module assets may need to be downloaded into `~/.dnmb-cache`.
- Later runs should be much faster because DNMB reuses the shared cache and matching previous outputs.
- If you want a clean rerun but still keep reusable outputs, keep `clean_previous = TRUE`. The current DNMB logic preserves matching cached module and external annotation outputs when the input genome has not changed.

## Compose

Create runtime directories first:

```bash
mkdir -p data results
```

Build and open interactive R:

```bash
docker compose build
docker compose run --rm dnmbsuite R
```

Run the pipeline directly:

```bash
docker compose run --rm dnmbsuite \
  Rscript -e 'library(DNMB); setwd("/data"); run_DNMB(clean_previous = TRUE)'
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
