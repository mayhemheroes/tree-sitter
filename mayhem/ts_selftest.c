/*
 * ts_selftest.c — functional known-answer test for the tree-sitter core library.
 *
 * Parses a fixed JSON document with the vendored tree-sitter-json grammar and prints
 * the s-expression of the resulting syntax tree to stdout. mayhem/test.sh compares this
 * against a golden string, so the oracle asserts real parsing BEHAVIOR (a neutered /
 * exit(0) build produces no tree → the golden comparison fails).
 *
 * Built by mayhem/build.sh with the project's NORMAL flags (no sanitizers), linked
 * against a clean libtree-sitter.a + the json parser.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "tree_sitter/api.h"

extern const TSLanguage *tree_sitter_json(void);

int main(void) {
  const char *source = "[1, true, \"x\", null]";

  TSParser *parser = ts_parser_new();
  if (!ts_parser_set_language(parser, tree_sitter_json())) {
    fprintf(stderr, "ts_selftest: ts_parser_set_language failed (ABI mismatch)\n");
    return 2;
  }

  TSTree *tree = ts_parser_parse_string(parser, NULL, source, (uint32_t)strlen(source));
  if (!tree) {
    fprintf(stderr, "ts_selftest: parse returned NULL\n");
    return 3;
  }

  TSNode root = ts_tree_root_node(tree);
  char *sexp = ts_node_string(root);
  printf("%s\n", sexp);

  free(sexp);
  ts_tree_delete(tree);
  ts_parser_delete(parser);
  return 0;
}
