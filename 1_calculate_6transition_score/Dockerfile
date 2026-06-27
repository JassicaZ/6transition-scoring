FROM rocker/r-ver:4.4.1

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    git \
    cmake \
    && rm -rf /var/lib/apt/lists/*

COPY env env

RUN pip3 install --no-cache-dir -r env/requirements.txt
RUN Rscript env/install_packages.R


COPY model model
COPY scripts scripts
COPY run.sh .