# syntax=docker/dockerfile:1

# Nothing is built from source but heimdall itself: `gyc` (which bundles midgard) and `gyllir` are
# downloaded as prebuilt release assets. The build-args have no default on purpose - YMIR_VERSION
# at the repo root is the single source of truth, and every CI workflow computes them from it.
# To build locally:
#   . ./YMIR_VERSION
#   GCC_MAJOR=$(echo "$GCC_VERSION" | cut -d. -f1)
#   docker build \
#     --build-arg GYC_RELEASE_TAG="$YMIR_BOOTSTRAP_VERSION" \
#     --build-arg GYC_ASSET="gyc-${GCC_MAJOR}_${YMIR_BOOTSTRAP_VERSION}_amd64.deb" \
#     --build-arg GYLLIR_RELEASE_TAG="$GYLLIR_VERSION" \
#     --build-arg GYLLIR_ASSET="gyllir_${GYLLIR_VERSION}_amd64.deb" \
#     --target test .
ARG GYC_RELEASE_TAG
ARG GYC_ASSET
ARG GYLLIR_RELEASE_TAG
ARG GYLLIR_ASSET

FROM ubuntu:26.04 AS toolchain
ARG GYC_RELEASE_TAG
ARG GYC_ASSET
ARG GYLLIR_RELEASE_TAG
ARG GYLLIR_ASSET
ENV DEBIAN_FRONTEND=noninteractive

RUN test -n "$GYC_RELEASE_TAG" && test -n "$GYC_ASSET" \
    && test -n "$GYLLIR_RELEASE_TAG" && test -n "$GYLLIR_ASSET" || \
    (echo "GYC_RELEASE_TAG, GYC_ASSET, GYLLIR_RELEASE_TAG and GYLLIR_ASSET build-args are required - see YMIR_VERSION" >&2 && exit 1)

RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates curl git build-essential \
    && rm -rf /var/lib/apt/lists/*

# The gyc .deb depends on g++-<N>/gcc-<N>/libgc-dev/libdwarf-dev; `apt-get install ./file.deb`
# resolves those from the archive.
RUN curl -fsSL -o /tmp/gyc.deb \
        "https://github.com/GNU-Ymir/gymir/releases/download/${GYC_RELEASE_TAG}/${GYC_ASSET}" \
    && curl -fsSL -o /tmp/gyllir.deb \
        "https://github.com/GNU-Ymir/Gyllir/releases/download/${GYLLIR_RELEASE_TAG}/${GYLLIR_ASSET}" \
    && apt-get update \
    && apt-get install -y --no-install-recommends /tmp/gyc.deb /tmp/gyllir.deb \
    && rm -f /tmp/gyc.deb /tmp/gyllir.deb \
    && rm -rf /var/lib/apt/lists/*

RUN gyc --version && gyllir --version

# Compiles libheimdall.a and, with `test --dry`, ./heimdall.test without running it - the `test`
# stage below (and the CI workflow) run it. The log is kept in the image so CI can read the
# warnings back even when this layer comes from the cache.
FROM toolchain AS build
WORKDIR /heimdall
COPY . .
RUN bash -o pipefail -c 'gyllir test --dry 2>&1 | tee build.log'

# Sequential on purpose: under -j the suite trips MID-143 (EINTR read as a closed socket).
FROM build AS test
RUN ./heimdall.test -sf
