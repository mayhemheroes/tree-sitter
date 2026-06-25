#!/usr/bin/env bash
#
# mayhem/build.sh — build the tree-sitter multi-grammar fuzz harnesses.
#
# tree-sitter is a parser library; each fuzz target links the core library against ONE generated
# grammar (parser.c [+ scanner.{c,cc}]) and feeds the fuzzed bytes to ts_parser_parse_string via the
# upstream harness (mayhem/fuzzer.cc). Upstream removed the in-tree libFuzzer harness + the network
# `script/fetch-fixtures` flow, so the grammar sources are VENDORED under mayhem/grammars/ (pinned
# content) and this build is fully AIR-GAPPED — no grammar is fetched at build time.
#
# Runs inside the commit image (mayhem/Dockerfile) as `mayhem` in /mayhem. The base image exports the
# build contract (CC, CXX, SANITIZER_FLAGS, LIB_FUZZING_ENGINE, DEBUG_FLAGS, SRC). We build:
#   1. a CLEAN libtree-sitter.a + /mayhem/ts_selftest (normal flags) for the functional oracle (test.sh)
#   2. an INSTRUMENTED libtree-sitter.a (ASan+UBSan+SanCov+DWARF<4) + one /mayhem/<lang>_fuzzer per grammar
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

# Build knobs from the ENV (overridable), with parameter-expansion fallbacks. SANITIZER_FLAGS uses '='
# (no colon) so an explicit empty value (--build-arg SANITIZER_FLAGS=) is honored (no sanitizers).
: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
# DEBUG_FLAGS carries DWARF debug info independently of the sanitizer switch. DWARF MUST be < 4
# (Mayhem triage can't read >=4); clang-19's plain -g emits DWARF-5, so -gdwarf-3 is explicit and is
# placed AFTER $SANITIZER_FLAGS (which the base ends with a plain -g) so the DWARF-3 setting wins.
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS

cd "$SRC"

GRAMMARS="$SRC/mayhem/grammars"
OUT=/mayhem
# SanCov-only instrumentation for the fuzzed library/grammar objects (the libFuzzer runtime + main
# come from $LIB_FUZZING_ENGINE on the final harness link).
INSTR="-fsanitize=fuzzer-no-link"

# All Mayhem targets. typescript/tsx come from the same upstream grammar repo (separate parsers).
LANGS="bash c cpp embedded-template go html java javascript jsdoc json php python ruby rust typescript tsx"

# lang -> vendored src dir (relative to $GRAMMARS). php/typescript/tsx are nested + share a common/.
gdir() {
  case "$1" in
    php)        echo "php/php/src" ;;
    typescript) echo "typescript/typescript/src" ;;
    tsx)        echo "typescript/tsx/src" ;;
    *)          echo "$1/src" ;;
  esac
}

# ---------------------------------------------------------------------------------------------------
# 1) CLEAN build (normal flags, no sanitizers) for the functional oracle: libtree-sitter.a + selftest.
#    Done FIRST and stashed so the sanitized rebuild below can reuse the same source tree.
# ---------------------------------------------------------------------------------------------------
echo ">> [1/2] clean oracle build (libtree-sitter.a + ts_selftest)"
make clean >/dev/null 2>&1 || true
make -j"$MAYHEM_JOBS" libtree-sitter.a CC="$CC" CFLAGS="-O2 $DEBUG_FLAGS"
json_src="$GRAMMARS/json/src"
"$CC" -O2 $DEBUG_FLAGS -I"$json_src" -c "$json_src/parser.c" -o "$json_src/parser_oracle.o"
"$CC" -O2 $DEBUG_FLAGS -I lib/include "$SRC/mayhem/ts_selftest.c" \
    "$json_src/parser_oracle.o" libtree-sitter.a -o "$OUT/ts_selftest"
echo ">> ts_selftest -> $OUT/ts_selftest"

# ---------------------------------------------------------------------------------------------------
# 2) INSTRUMENTED build: rebuild libtree-sitter.a with sanitizers + SanCov + DWARF<4, then one
#    libFuzzer harness per grammar.
# ---------------------------------------------------------------------------------------------------
echo ">> [2/2] instrumented fuzz build (libtree-sitter.a + ${LANGS})"
make clean >/dev/null 2>&1 || true
make -j"$MAYHEM_JOBS" libtree-sitter.a CC="$CC" CFLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS $INSTR -O1"

for lang in $LANGS; do
  d="$GRAMMARS/$(gdir "$lang")"
  echo ">> building ${lang}_fuzzer (from $d)"
  objs=()

  if [ -e "$d/scanner.cc" ]; then
    "$CXX" $SANITIZER_FLAGS $DEBUG_FLAGS $INSTR -O1 -I"$d" -c "$d/scanner.cc" -o "$d/scanner.o"
    objs+=("$d/scanner.o")
  elif [ -e "$d/scanner.c" ]; then
    "$CC" $SANITIZER_FLAGS $DEBUG_FLAGS $INSTR -std=c11 -O1 -I"$d" -c "$d/scanner.c" -o "$d/scanner.o"
    objs+=("$d/scanner.o")
  fi

  # parser.c at -O0 — these files are huge; -O0 keeps the build tractable.
  "$CC" $SANITIZER_FLAGS $DEBUG_FLAGS $INSTR -O0 -I"$d" -c "$d/parser.c" -o "$d/parser.o"
  objs+=("$d/parser.o")

  ts_lang="tree_sitter_$(echo "$lang" | tr -- - _)"
  "$CXX" $SANITIZER_FLAGS $DEBUG_FLAGS -std=c++11 -I lib/include \
      -DTS_LANG="$ts_lang" -DTS_LANG_QUERY_FILENAME='""' \
      "$SRC/mayhem/fuzz/fuzzer.cc" "${objs[@]}" libtree-sitter.a $LIB_FUZZING_ENGINE \
      -o "$OUT/${lang}_fuzzer"

  # libFuzzer/AFL dictionary from the grammar's string literals (best-effort).
  python3 "$SRC/mayhem/fuzz/gen-dict.py" "$d/grammar.json" > "$OUT/${lang}.dict" 2>/dev/null || \
    : > "$OUT/${lang}.dict"
done

echo ">> build complete:"
ls -1 "$OUT"/*_fuzzer
