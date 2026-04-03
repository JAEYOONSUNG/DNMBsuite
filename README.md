# DNMBsuite

Docker wrapper repository for the `DNMB` core package.

## Design

- `DNMB` remains the core R package repository.
- `DNMBsuite` publishes the container image and compose wrapper.
- Large databases are not baked into the image.
- Runtime caches are stored in `~/.dnmb-cache` on the host and mounted into the container at `/opt/dnmb/cache`.

## Build

Build from the latest `master` of the core repository:

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

## Run

Interactive R:

```bash
docker run --rm -it \
  -v "$(pwd)/data:/data" \
  -v "$(pwd)/results:/results" \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest R
```

Example full DNMB run inside the container:

```bash
docker run --rm \
  -v "$(pwd)/data:/data" \
  -v "$(pwd)/results:/results" \
  -v "$HOME/.dnmb-cache:/opt/dnmb/cache" \
  ghcr.io/jaeyoonsung/dnmbsuite:latest \
  Rscript -e 'library(DNMB); setwd("/data"); run_DNMB(clean_previous = TRUE)'
```

## Compose

```bash
mkdir -p data results
docker compose build
docker compose run --rm dnmbsuite R
```

Use a fixed core ref:

```bash
DNMB_REF=<dnmb-git-ref> docker compose build
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
3. Optionally change the default `DNMB_REF` in the workflow from `master` to a tag or release branch policy.
