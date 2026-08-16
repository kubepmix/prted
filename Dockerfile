ARG OPENPMIX_REPO=https://github.com/openpmix/openpmix
ARG OPENPMIX_REVISION=v5.0.11
ARG PRRTE_REPO=https://github.com/openpmix/prrte
ARG PRRTE_REVISION=v3.0.14

# Stage 1: build OpenPMIx
FROM ubuntu:24.04 AS pmix-build

RUN apt-get update 1>/dev/null && apt-get install -y --no-install-recommends \
    git autoconf libtool build-essential perl \
    flex libevent-dev libhwloc-dev zlib1g-dev \
    python3 python3-pip python3-dev 1>/dev/null \
    && rm -rf /var/lib/apt/lists/*

ARG OPENPMIX_REPO
ARG OPENPMIX_REVISION

RUN git clone ${OPENPMIX_REPO} /openpmix

WORKDIR /openpmix
RUN git checkout ${OPENPMIX_REVISION}
RUN git submodule update --init
RUN ./autogen.pl --quiet

RUN pip3 install --break-system-packages cython setuptools aiohttp 1>/dev/null
RUN ./configure --prefix=/opt/pmix 1>/dev/null
RUN make -j$(nproc) 1>/dev/null && make install 1>/dev/null

# Stage 2: build PRRTE
FROM ubuntu:24.04 AS prrte-build

RUN apt-get update 1>/dev/null && apt-get install -y --no-install-recommends \
    autoconf automake libtool build-essential perl pkg-config libevent-dev \
    flex libevent-dev libhwloc-dev zlib1g-dev python3 git ca-certificates 1>/dev/null \
    && rm -rf /var/lib/apt/lists/*

ARG PRRTE_REPO
ARG PRRTE_REVISION

RUN git clone ${PRRTE_REPO} /prrte

WORKDIR /prrte
RUN git checkout ${PRRTE_REVISION}
RUN git submodule update --init

RUN ./autogen.pl --quiet

COPY --from=pmix-build /opt/pmix /opt/pmix
RUN ./configure --with-pmix=/opt/pmix --prefix=/opt/prte 1>/dev/null
RUN make -j$(nproc) 1>/dev/null && make install 1>/dev/null

# Stage 4: Runtime
# ---------------------------------------------------------------------------
FROM ubuntu:24.04 AS runtime

RUN apt-get update 1>/dev/null && apt-get install -y --no-install-recommends \
    libevent-dev libhwloc-dev zlib1g ca-certificates curl 1>/dev/null \
    && rm -rf /var/lib/apt/lists/*

COPY --from=pmix-build /opt/pmix /opt/pmix
COPY --from=prrte-build /opt/prte /opt/prte

ENV PATH=/opt/prte/bin:/opt/pmix/bin:$PATH
ENV LD_LIBRARY_PATH=/opt/prte/lib:/opt/pmix/lib:$LD_LIBRARY_PATH
ENV HOME=/root

CMD ["prted"]
