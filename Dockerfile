FROM python:3.10-bullseye

ENV AIL_HOME=/opt/ail
WORKDIR $AIL_HOME

RUN set -eux; \
    for i in 1 2 3; do \
      apt-get update && break; \
      sleep 5; \
    done; \
    apt-get install -y --no-install-recommends --fix-missing \
      build-essential \
      automake \
      cmake \
      g++ \
      gcc \
      git \
      graphviz \
      libadns1 \
      libadns1-dev \
      libev-dev \
      libffi-dev \
      libfreetype6-dev \
      libfuzzy-dev \
      libgmp-dev \
      libprotobuf-dev \
      libsnappy-dev \
      libssl-dev \
      libtool \
      libzbar0 \
      pkg-config \
      protobuf-compiler \
      p7zip-full \
      python3-opencv \
      rustc \
      cargo \
      unzip \
      wget; \
    rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN python -m pip install --no-cache-dir --upgrade pip \
    && grep -v '^pybgpranking' requirements.txt > /tmp/requirements.txt \
    && python -m pip install --no-cache-dir -r /tmp/requirements.txt \
    && python -m pip install --no-cache-dir 'git+https://github.com/D4-project/BGP-Ranking.git/@7e698f87366e6f99b4d0d11852737db28e3ddc62#egg=pybgpranking&subdirectory=client' \
    && python -m pip install --no-cache-dir tlsh

COPY . .

RUN chmod +x /opt/ail/docker/entrypoint.sh

ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["/opt/ail/docker/entrypoint.sh"]
