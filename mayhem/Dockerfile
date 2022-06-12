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

## fetch fuzzers for each language (typescript and tsx need extra preprocessing)
RUN script/fetch-fixtures
RUN mv test/fixtures/grammars/typescript test/fixtures/grammars/typescript_
RUN mv test/fixtures/grammars/typescript_/common test/fixtures/grammars
RUN mv test/fixtures/grammars/typescript_/tsx test/fixtures/grammars
RUN mv test/fixtures/grammars/typescript_/typescript test/fixtures/grammars


## build fuzzers
RUN mkdir out && CC=clang CXX=clang++ LINK=clang++ LIB_FUZZER_PATH=/compiler-rt/lib/fuzzer/libFuzzer.a \
    script/build-fuzzers bash c cpp embedded-template go html java javascript jsdoc json php python \
    ruby rust typescript tsx

FROM ubuntu:20.04
COPY --from=builder /tree-sitter/out /tree-sitter
