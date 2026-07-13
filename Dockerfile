## DNMBsuite Docker image
## Builds the container wrapper and installs the DNMB core package from GitHub.

ARG DNMB_BASE_PLATFORM=linux/amd64
FROM --platform=${DNMB_BASE_PLATFORM} rocker/r-ver:4.4.1

ARG DNMB_REPO=https://github.com/JAEYOONSUNG/DNMB.git
ARG DNMB_REF=master
ARG DNMB_SOURCE=github

ENV DEBIAN_FRONTEND=noninteractive
ENV DNMB_CACHE_ROOT=/opt/dnmb-cache
ENV MAMBA_ROOT_PREFIX=/opt/dnmb-cache/micromamba
ENV DNMB_DEFENSEFINDER_CASFINDER_DIR=/root/.macsyfinder/models/CasFinder
ENV DNMB_DEFENSEFINDER_REPO_DIR=/opt/vendor/defense-finder
ENV DNMB_DEFENSEFINDER_MODELS_DIR=/opt/vendor/defense-finder-models
ENV DNMB_DBAPIS_REPO_DIR=/opt/vendor/dbAPIS
ENV DNMB_ACRFINDER_REPO_DIR=/opt/vendor/acrfinder
ENV R_LIBS_SITE=/opt/biotools/lib/R/library
ENV R_LIBS=/opt/biotools/lib/R/library
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8
ENV MACSY_HOME=/opt/vendor/acrfinder/dependencies/CRISPRCasFinder/macsyfinder-1.0.5
ENV DNMB_VMATCH_SEL392=/opt/vendor/acrfinder/dependencies/CRISPRCasFinder/sel392v2.so

RUN apt-get -o Acquire::Retries=5 update \
    && apt-get -o Acquire::Retries=5 install -y --fix-missing --no-install-recommends \
    build-essential \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libfreetype6-dev libpng-dev libtiff-dev libjpeg-dev \
    libharfbuzz-dev libfribidi-dev \
    zlib1g-dev libbz2-dev liblzma-dev libpcre2-dev libicu-dev libgit2-dev \
    cmake pkg-config curl wget git jq procps ca-certificates locales gosu \
    cpanminus bioperl bioperl-run emboss emboss-lib clustalw muscle \
    python2 libdatetime-perl libxml-simple-perl libdigest-md5-perl \
    python3-dev python3-venv python3.10-dev python3.10-venv \
    libdbi-perl libdbd-sqlite3-perl \
    default-jdk \
    libwebp-dev \
    poppler-utils \
    && locale-gen en_US.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN apt-get -o Acquire::Retries=5 update \
    && apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
    libdate-calc-perl libjson-parse-perl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname -s)-$(uname -m).sh \
    -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /opt/miniforge \
    && rm /tmp/miniforge.sh

RUN /opt/miniforge/bin/conda create -y -p /opt/biotools \
    -c bioconda -c conda-forge \
    python=3.11 \
    pip \
    biopython \
    bioconductor-biostrings \
    bioconductor-complexheatmap \
    r-tidyverse \
    hmmer blast prodigal diamond padloc \
    dbcan=5.2.9 \
    entrez-direct skani fastani \
    phispy \
    perl-dbi perl-lwp-simple perl-dbd-sqlite \
    && /opt/miniforge/bin/conda create -y -p /opt/biotools/envs/eggnog \
       -c bioconda -c conda-forge \
       python=3.11 eggnog-mapper=2.1.15 \
    && ln -sf /opt/biotools/envs/eggnog/bin/emapper.py /opt/biotools/bin/emapper.py \
    && ln -sf /opt/biotools/envs/eggnog/bin/download_eggnog_data.py /opt/biotools/bin/download_eggnog_data.py \
    && /opt/miniforge/bin/conda clean -afy

RUN test -x /opt/biotools/bin/run_dbcan \
    && /opt/biotools/bin/run_dbcan version | grep -F '5.2.9' \
    && test -x /opt/biotools/envs/eggnog/bin/emapper.py \
    && /opt/biotools/bin/python -c 'import glob,json; files=glob.glob("/opt/biotools/conda-meta/*.json"); versions={m["name"]:m["version"] for m in map(lambda p: json.load(open(p)), files)}; assert versions.get("dbcan")=="5.2.9", versions' \
    && /opt/biotools/envs/eggnog/bin/python -c 'import glob,json; files=glob.glob("/opt/biotools/envs/eggnog/conda-meta/*.json"); versions={m["name"]:m["version"] for m in map(lambda p: json.load(open(p)), files)}; assert versions.get("eggnog-mapper")=="2.1.15", versions'

ENV PATH="/opt/biotools/bin:${PATH}"

RUN mkdir -p ${DNMB_CACHE_ROOT}/db_modules/clean/split100 \
    && /opt/biotools/bin/python -m venv ${DNMB_CACHE_ROOT}/db_modules/clean/split100/conda_env \
    && ${DNMB_CACHE_ROOT}/db_modules/clean/split100/conda_env/bin/pip install --no-cache-dir \
       torch --index-url https://download.pytorch.org/whl/cpu \
    && ${DNMB_CACHE_ROOT}/db_modules/clean/split100/conda_env/bin/pip install --no-cache-dir \
       "fair-esm==2.0.0" \
       "pandas>=1.4,<3" \
       "scikit-learn>=1.2" \
       "scipy>=1.7" \
       "matplotlib>=3.7" \
       "tqdm>=4.64" \
       gdown

RUN mkdir -p /opt/dnmb-seed/clean/split100 \
    && tar -C ${DNMB_CACHE_ROOT}/db_modules/clean/split100 -czf /opt/dnmb-seed/clean/split100/conda_env.tar.gz conda_env

RUN rm -rf /opt/miniforge

RUN R -e ' \
    cran_repo <- "https://cran.r-project.org"; \
    options(repos = c(CRAN = cran_repo), download.file.method = "libcurl", Ncpus = 1); \
    install.packages("remotes"); \
    install.packages(c("rlang", "vctrs", "tibble", "ggplot2", "sp", "pixmap", "RcppArmadillo", "ade4", "seqinr")); \
    install.packages(c( \
      "dplyr", "plyr", "tidyr", "data.table", "reshape2", \
      "readr", "openxlsx", "stringr", "jsonlite", "gtools", \
      "cowplot", "gggenes", "ggrepel", "ggtext", "ggseqlogo", \
      "ggforce", "gridExtra", "scales", "Peptides", "circlize", "ggplotify", \
      "testthat", "ggnewscale", "patchwork", "gridBase", "gtable", "colorspace", \
      "tidyverse" \
    )); \
'
RUN R -e ' \
    cran_repo <- "https://cran.r-project.org"; \
    options(repos = c(CRAN = cran_repo), download.file.method = "libcurl", timeout = 600, Ncpus = 1); \
    required <- c( \
      "remotes", "rlang", "vctrs", "tibble", "ggplot2", "sp", "pixmap", \
      "RcppArmadillo", "ade4", "seqinr", "dplyr", "plyr", "tidyr", \
      "data.table", "reshape2", "readr", "openxlsx", "stringr", "jsonlite", \
      "gtools", "cowplot", "gggenes", "ggrepel", "ggtext", "ggseqlogo", \
      "ggforce", "gridExtra", "scales", "Peptides", "circlize", "ggplotify", \
      "testthat", "ggnewscale", "patchwork", "gridBase", "gtable", \
      "colorspace", "tidyverse" \
    ); \
    missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]; \
    if (length(missing)) install.packages(missing); \
    missing <- required[!vapply(required, requireNamespace, logical(1), quietly = TRUE)]; \
    if (length(missing)) stop("Missing R packages: ", paste(missing, collapse = ", ")); \
'
RUN export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    && export LD_LIBRARY_PATH=/usr/lib/jvm/java-11-openjdk-amd64/lib/server:${LD_LIBRARY_PATH} \
    && R CMD javareconf \
    && R -e 'options(repos = c(CRAN = "https://cran.r-project.org"), download.file.method = "libcurl"); install.packages("rJava", configure.args = "--disable-jri")' \
    && R -e 'options(repos = c(CRAN = "https://cran.r-project.org"), download.file.method = "libcurl"); install.packages("venneuler", Ncpus = 1)'

RUN R -e 'remotes::install_github("JAEYOONSUNG/DefenseViz", dependencies = FALSE, upgrade = "never")'

RUN /opt/biotools/bin/python -m pip install --no-cache-dir 'macsyfinder==2.1.4' \
    && mkdir -p /root/.macsyfinder/models \
    && git clone --branch 3.1.0 --depth 1 \
       https://github.com/macsy-models/CasFinder.git \
       /root/.macsyfinder/models/CasFinder

RUN git clone --branch v3.0.0 --depth 1 https://github.com/mdmparis/defense-finder.git /opt/vendor/defense-finder
RUN git clone --branch 3.1.0 --depth 1 https://github.com/mdmparis/defense-finder-models.git /opt/vendor/defense-finder-models
RUN git clone --depth 1 https://github.com/azureycy/dbAPIS.git /opt/vendor/dbAPIS
RUN git clone --depth 1 https://github.com/HaidYi/acrfinder.git /opt/vendor/acrfinder

RUN perl -0pi -e 's/\\bsudo\\s+//g' /opt/vendor/acrfinder/dependencies/CRISPRCasFinder/installer_UBUNTU.sh \
    && chmod +x /opt/vendor/acrfinder/dependencies/CRISPRCasFinder/installer_UBUNTU.sh \
    && cd /opt/vendor/acrfinder/dependencies/CRISPRCasFinder \
    && OSTYPE=linux-gnu ./installer_UBUNTU.sh

RUN set -eux; \
    CRISPR_DIR=/opt/vendor/acrfinder/dependencies/CRISPRCasFinder; \
    mkdir -p "${CRISPR_DIR}/bin"; \
    if [ ! -x "${CRISPR_DIR}/bin/vmatch2" ] || [ ! -x "${CRISPR_DIR}/bin/mkvtree2" ] || [ ! -x "${CRISPR_DIR}/bin/vsubseqselect2" ] || [ ! -f "${CRISPR_DIR}/sel392v2.so" ]; then \
      mkdir -p "${CRISPR_DIR}/src"; \
      curl -fsSL http://vmatch.de/distributions/vmatch-2.3.0-Linux_x86_64-64bit.tar.gz -o /tmp/vmatch.tar.gz; \
      tar --no-same-owner --no-same-permissions -xzf /tmp/vmatch.tar.gz -C "${CRISPR_DIR}/src"; \
      rm -f /tmp/vmatch.tar.gz; \
      gcc -Wall -Werror -fPIC -O3 -shared "${CRISPR_DIR}/src/vmatch-2.3.0-Linux_x86_64-64bit/SELECT/sel392.c" -o "${CRISPR_DIR}/sel392v2.so"; \
      cp "${CRISPR_DIR}/src/vmatch-2.3.0-Linux_x86_64-64bit/vmatch" "${CRISPR_DIR}/bin/vmatch2"; \
      cp "${CRISPR_DIR}/src/vmatch-2.3.0-Linux_x86_64-64bit/mkvtree" "${CRISPR_DIR}/bin/mkvtree2"; \
      cp "${CRISPR_DIR}/src/vmatch-2.3.0-Linux_x86_64-64bit/vsubseqselect" "${CRISPR_DIR}/bin/vsubseqselect2"; \
    fi; \
    test -f "${CRISPR_DIR}/sel392v2.so"; \
    mkdir -p /usr/lib/vmatch/SELECT; \
    ln -sf "${CRISPR_DIR}/sel392v2.so" /usr/lib/vmatch/SELECT/sel392.so; \
    rm -rf "${CRISPR_DIR}/macsyfinder-1.0.5"; \
    mkdir -p "${CRISPR_DIR}/macsyfinder-1.0.5"; \
    curl -fsSL https://codeload.github.com/gem-pasteur/macsyfinder/tar.gz/refs/tags/macsyfinder-1.0.5 \
      | tar --no-same-owner --no-same-permissions -xz --strip-components=1 -C "${CRISPR_DIR}/macsyfinder-1.0.5"; \
    sed -i '1c #!/usr/bin/env python2' "${CRISPR_DIR}/macsyfinder-1.0.5/bin/macsyfinder"; \
    ln -sf ../macsyfinder-1.0.5/bin/macsyfinder "${CRISPR_DIR}/bin/macsyfinder"; \
    ln -sf /usr/bin/perl "${CRISPR_DIR}/bin/perl"; \
    if [ -x /opt/biotools/bin/rpsblast ] && [ ! -e /opt/biotools/bin/rpsblast+ ]; then \
      ln -sf /opt/biotools/bin/rpsblast /opt/biotools/bin/rpsblast+; \
    fi; \
    if [ -x /usr/bin/clustalw ] && [ ! -e "${CRISPR_DIR}/bin/clustalw2" ]; then \
      ln -sf /usr/bin/clustalw "${CRISPR_DIR}/bin/clustalw2"; \
    fi; \
    if [ -f /opt/vendor/acrfinder/dependencies/cdd-mge.tar.gz ]; then \
      tar --no-same-owner --no-same-permissions -xzf /opt/vendor/acrfinder/dependencies/cdd-mge.tar.gz -C /opt/vendor/acrfinder/dependencies; \
    fi

RUN perl -0pi -e 's/^from Bio\\.Alphabet import SingleLetterAlphabet\\n//m; s/Seq\\(([^,\\n]+), SingleLetterAlphabet\\(\\)\\)/Seq($1)/g' /opt/vendor/acrfinder/mask_fna_with_spacers.py

ENV PATH=/opt/biotools/bin:/opt/vendor/acrfinder/bin:/opt/vendor/acrfinder/dependencies/CRISPRCasFinder/bin:${PATH}

COPY docker/local-dnmb-snapshot/ /tmp/DNMB-local/

ARG DNMB_INSTALL_CACHE_BUST=20260713-interproscan-update
RUN echo "DNMB install cache bust: ${DNMB_INSTALL_CACHE_BUST}" >/dev/null \
    && if [ "${DNMB_SOURCE}" = "local" ]; then \
      R -e 'remotes::install_local("/tmp/DNMB-local", dependencies = FALSE, upgrade = "never")'; \
    else \
      git clone "${DNMB_REPO}" /tmp/DNMB \
      && git -C /tmp/DNMB checkout "${DNMB_REF}" \
      && R -e 'remotes::install_local("/tmp/DNMB", dependencies = FALSE, upgrade = "never")'; \
    fi \
    && rm -rf /tmp/DNMB /tmp/DNMB-local

RUN Rscript -e 'DNMB:::dnmb_defensefinder_install_module(cache_root = Sys.getenv("DNMB_CACHE_ROOT"), install = TRUE, repo_url = Sys.getenv("DNMB_DEFENSEFINDER_REPO_DIR"), asset_urls = list(models_dir = Sys.getenv("DNMB_DEFENSEFINDER_MODELS_DIR"), casfinder_dir = Sys.getenv("DNMB_DEFENSEFINDER_CASFINDER_DIR")), force = TRUE)'
RUN Rscript -e 'DNMB:::dnmb_dbapis_install_module(cache_root = Sys.getenv("DNMB_CACHE_ROOT"), install = TRUE, repo_url = Sys.getenv("DNMB_DBAPIS_REPO_DIR"), asset_urls = list(repo_dir = Sys.getenv("DNMB_DBAPIS_REPO_DIR")), force = TRUE)'
RUN Rscript -e 'DNMB:::dnmb_acrfinder_install_module(cache_root = Sys.getenv("DNMB_CACHE_ROOT"), install = TRUE, repo_url = Sys.getenv("DNMB_ACRFINDER_REPO_DIR"), asset_urls = list(repo_dir = Sys.getenv("DNMB_ACRFINDER_REPO_DIR")), force = TRUE)'
RUN Rscript -e 'DNMB:::dnmb_prophage_install_module(cache_root = Sys.getenv("DNMB_CACHE_ROOT"), install = TRUE, force = TRUE)' \
    && mkdir -p /opt/dnmb-seed/prophage \
    && tar -C ${DNMB_CACHE_ROOT}/db_modules/prophage -czf /opt/dnmb-seed/prophage/phispy.tar.gz phispy \
    && rm -rf ${DNMB_CACHE_ROOT}/db_modules/prophage/phispy
RUN Rscript -e 'DNMB:::dnmb_defensepredictor_install_module(cache_root = Sys.getenv("DNMB_CACHE_ROOT"), install = TRUE, force = TRUE)' \
    && mkdir -p /opt/dnmb-seed/defensepredictor \
    && tar -C ${DNMB_CACHE_ROOT}/db_modules/defensepredictor -czf /opt/dnmb-seed/defensepredictor/current.tar.gz current \
    && rm -rf ${DNMB_CACHE_ROOT}/db_modules/defensepredictor/current

RUN mkdir -p /opt/dnmb-seed/defensefinder \
    && tar -C ${DNMB_CACHE_ROOT}/db_modules/defensefinder -czf /opt/dnmb-seed/defensefinder/current.tar.gz current
RUN mkdir -p /opt/dnmb-seed/dbapis \
    && tar -C ${DNMB_CACHE_ROOT}/db_modules/dbapis -czf /opt/dnmb-seed/dbapis/current.tar.gz current
RUN mkdir -p /opt/dnmb-seed/acrfinder \
    && tar -C ${DNMB_CACHE_ROOT}/db_modules/acrfinder -czf /opt/dnmb-seed/acrfinder/current.tar.gz current

RUN mkdir -p /data /results ${DNMB_CACHE_ROOT} /opt/biotools/data /opt/biotools/test

RUN apt-get -o Acquire::Retries=5 update \
    && apt-get -o Acquire::Retries=5 install -y --no-install-recommends \
    vienna-rna \
    bzip2 \
    libbio-perl-perl libbio-perl-run-perl libbio-tools-run-alignment-clustalw-perl \
    libdate-calc-perl libjson-parse-perl \
    && apt-get clean && rm -rf /var/lib/apt/lists/* \
    && /opt/biotools/bin/python -m pip install --no-cache-dir progressbar2 \
    && command -v RNAfold >/dev/null \
    && /opt/biotools/bin/python -c 'import progressbar'

RUN mkdir -p /tmp/micromamba \
    && curl -fsSL https://micro.mamba.pm/api/micromamba/linux-64/latest -o /tmp/micromamba.tar.bz2 \
    && tar -xjf /tmp/micromamba.tar.bz2 -C /tmp/micromamba bin/micromamba \
    && install -m 0755 /tmp/micromamba/bin/micromamba /usr/local/bin/micromamba \
    && micromamba create -y -p /opt/promotech \
      -c conda-forge -c bioconda \
      python=3.8 \
      numpy=1.19.5 \
      pandas=1.1.5 \
      joblib=0.17.0 \
      scikit-learn=0.23.2 \
      biopython=1.78 \
      progressbar2 \
      'python-utils<3.9' \
    && micromamba clean -afy \
    && rm -rf /tmp/micromamba /tmp/micromamba.tar.bz2 /root/.cache/mamba \
    && /opt/promotech/bin/python -c 'import numpy, pandas, joblib, Bio, progressbar, sklearn; assert sklearn.__version__.startswith("0.23")'

ENV DNMB_PROMOTECH_PYTHON=/opt/promotech/bin/python

COPY docker/verify-runtime.sh /usr/local/bin/verify-runtime.sh
RUN chmod +x /usr/local/bin/verify-runtime.sh \
    && /usr/local/bin/verify-runtime.sh

WORKDIR /data

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["run"]
