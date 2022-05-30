# Build Stage
FROM ubuntu:20.04 as builder

## Install build dependencies.
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y cmake clang git python

## build libFuzzer
RUN git clone https://github.com/llvm-mirror/compiler-rt && \
    cd compiler-rt/lib/fuzzer && \
    ./build.sh

## Add source code to the build stage.
ADD . /tree-sitter
WORKDIR /tree-sitter

## build fuzzers
RUN script/fetch-fixtures
RUN rm -rf test/fixtures/grammars/typescript/
RUN mkdir out && CC=clang CXX=clang++ LINK=clang++ LIB_FUZZER_PATH=/compiler-rt/lib/fuzzer/libFuzzer.a \
    script/build-fuzzers

FROM ubuntu:20.04
COPY --from=builder /tree-sitter/out /
