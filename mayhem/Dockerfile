# syntax=docker/dockerfile:1.7
#
# Commit-image Dockerfile (SMALL form) — builds the tree-sitter multi-grammar fuzz harnesses ON TOP
# of the org C/C++ base image (debian + clang/llvm + libFuzzer + the build-contract ENV).
#
# Build (from the repo root):
#   DOCKER_BUILDKIT=1 docker build -f mayhem/Dockerfile \
#       --build-arg COMMIT=$(git rev-parse HEAD) -t tree-sitter-commit .

FROM ghcr.io/mayhemheroes/base:20260621

ARG COMMIT
ARG REPO_URL
# SOURCE_DATE_EPOCH stays an ARG (available to build.sh); never bake it as an ENV — an empty value
# breaks clang. build.sh unsets it when empty.
ARG SOURCE_DATE_EPOCH

# Sanitizer override: the base exports SANITIZER_FLAGS (ASan+UBSan, halting) as the default. Declared
# WITHOUT a default so the base ENV flows through unless --build-arg SANITIZER_FLAGS="..." overrides it.
ARG SANITIZER_FLAGS
# Build parallelism (optional; build.sh falls back to nproc).
ARG MAYHEM_JOBS=

# Source enters from the build CONTEXT (the CI checkout): the full repo is copied to /mayhem and
# build.sh builds in place.
USER mayhem
WORKDIR /mayhem
COPY --chown=2000:2000 . /mayhem

RUN bash mayhem/build.sh

# Run the functional oracle at build time — a failing suite fails the image build.
RUN if [ -f mayhem/test.sh ]; then bash mayhem/test.sh; else echo "no mayhem/test.sh"; fi

LABEL org.opencontainers.image.source="${REPO_URL}" \
      org.opencontainers.image.revision="${COMMIT}" \
      rlenv.tier="commit" \
      rlenv.source_date_epoch="${SOURCE_DATE_EPOCH}" \
      rlenv.user="mayhem"

USER mayhem
WORKDIR /mayhem
