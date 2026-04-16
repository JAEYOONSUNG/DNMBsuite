## DNMBsuite Docker image
## Builds the container wrapper and installs the DNMB core package from GitHub.

FROM --platform=linux/amd64 rocker/r-ver:4.4.1

ARG DNMB_REPO=https://github.com/JAEYOONSUNG/DNMB.git
ARG DNMB_REF=master
ARG DNMB_SOURCE=github

ENV DEBIAN_FRONTEND=noninteractive
ENV DNMB_CACHE_ROOT=/opt/dnmb/cache
ENV R_LIBS_SITE=/opt/biotools/lib/R/library
ENV R_LIBS=/opt/biotools/lib/R/library
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

RUN sed -i 's|http://archive.ubuntu.com/ubuntu|http://azure.archive.ubuntu.com/ubuntu|g' /etc/apt/sources.list \
    && apt-get -o Acquire::Retries=5 update \
    && apt-get -o Acquire::Retries=5 install -y --fix-missing --no-install-recommends \
    build-essential \
    libcurl4-openssl-dev libssl-dev libxml2-dev \
    libfontconfig1-dev libfreetype6-dev libpng-dev libtiff-dev libjpeg-dev \
    libharfbuzz-dev libfribidi-dev \
    zlib1g-dev libbz2-dev liblzma-dev libpcre2-dev libicu-dev libgit2-dev \
    cmake pkg-config curl wget git procps ca-certificates locales gosu \
    default-jdk \
    libwebp-dev \
    poppler-utils \
    && locale-gen en_US.UTF-8 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-$(uname -s)-$(uname -m).sh \
    -o /tmp/miniforge.sh \
    && bash /tmp/miniforge.sh -b -p /opt/miniforge \
    && rm /tmp/miniforge.sh

RUN /opt/miniforge/bin/conda create -y -p /opt/biotools \
    -c bioconda -c conda-forge \
    python=3.12 \
    hmmer blast prodigal diamond padloc \
    dbcan \
    eggnog-mapper \
    entrez-direct skani fastani \
    phispy \
    perl-dbi perl-lwp-simple perl-dbd-sqlite \
    && /opt/miniforge/bin/conda clean -afy

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
    options(Ncpus = parallel::detectCores()); \
    install.packages("BiocManager", repos = "https://cloud.r-project.org"); \
    install.packages("remotes", repos = "https://cloud.r-project.org"); \
    BiocManager::install(c("Biostrings", "ComplexHeatmap"), ask = FALSE, update = FALSE); \
    install.packages(c( \
      "dplyr", "plyr", "tidyr", "data.table", "tibble", "reshape2", \
      "readr", "openxlsx", "seqinr", "stringr", "jsonlite", "gtools", \
      "ggplot2", "cowplot", "gggenes", "ggrepel", "ggtext", "ggseqlogo", \
      "ggforce", "gridExtra", "scales", "Peptides", "circlize", "ggplotify", \
      "testthat", "tidyverse", \
      "ggnewscale", "patchwork", "gridBase", "gtable", "colorspace" \
    ), repos = "https://cloud.r-project.org"); \
'
RUN export JAVA_HOME=/usr/lib/jvm/java-11-openjdk-amd64 \
    && export LD_LIBRARY_PATH=/usr/lib/jvm/java-11-openjdk-amd64/lib/server:${LD_LIBRARY_PATH} \
    && R CMD javareconf \
    && R -e 'install.packages("rJava", repos = "https://cloud.r-project.org", configure.args = "--disable-jri")' \
    && R -e 'install.packages("venneuler", repos = "https://cloud.r-project.org", Ncpus = 1)'

RUN R -e 'remotes::install_github("JAEYOONSUNG/DefenseViz", dependencies = FALSE, upgrade = "never")'

RUN /opt/biotools/bin/python -m pip install --no-cache-dir \
    git+https://github.com/mdmparis/defense-finder.git

COPY docker/local-dnmb-snapshot/ /tmp/DNMB-local/

RUN if [ "${DNMB_SOURCE}" = "local" ]; then \
      R -e 'remotes::install_local("/tmp/DNMB-local", dependencies = FALSE, upgrade = "never")'; \
    else \
      git clone "${DNMB_REPO}" /tmp/DNMB \
      && git -C /tmp/DNMB checkout "${DNMB_REF}" \
      && R -e 'remotes::install_local("/tmp/DNMB", dependencies = FALSE, upgrade = "never")'; \
    fi \
    && rm -rf /tmp/DNMB /tmp/DNMB-local

RUN mkdir -p /data /results ${DNMB_CACHE_ROOT} /opt/biotools/data /opt/biotools/test

WORKDIR /data

COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["run"]
