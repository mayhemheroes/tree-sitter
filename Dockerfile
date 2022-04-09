# Build Stage
FROM ubuntu:20.04

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

## setup result folders
RUN mkdir out/fuzz-results
WORKDIR /tree-sitter/out/fuzz-results
RUN mkdir bash && mkdir bash/corpus
RUN mkdir c && mkdir c/corpus
RUN mkdir cpp && mkdir cpp/corpus
RUN mkdir embedded-template && mkdir embedded-template/corpus
RUN mkdir go && mkdir go/corpus
RUN mkdir html && mkdir html/corpus
RUN mkdir java && mkdir java/corpus
RUN mkdir javascript && mkdir javascript/corpus
RUN mkdir jsdoc && mkdir jsdoc/corpus
RUN mkdir json && mkdir json/corpus
RUN mkdir php && mkdir php/corpus
RUN mkdir python && mkdir python/corpus
RUN mkdir ruby && mkdir ruby/corpus
RUN mkdir rust && mkdir rust/corpus
