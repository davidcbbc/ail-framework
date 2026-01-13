FROM python:3.11-bullseye

ENV AIL_HOME=/opt/ail
WORKDIR $AIL_HOME

RUN apt-get update && apt-get install -y --no-install-recommends \
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
    wget \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt ./
RUN python -m pip install --no-cache-dir --upgrade pip \
    && python -m pip install --no-cache-dir -r requirements.txt

COPY . .

RUN chmod +x /opt/ail/docker/entrypoint.sh

ENV PYTHONUNBUFFERED=1
ENTRYPOINT ["/opt/ail/docker/entrypoint.sh"]
