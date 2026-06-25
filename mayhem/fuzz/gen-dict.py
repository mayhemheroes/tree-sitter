#!/usr/bin/env python3
"""Generate a libFuzzer/AFL dictionary from a tree-sitter grammar.json.

Python 3 port of the upstream test/fuzz/gen-dict.py (which was Python 2). Walks the
grammar definition, collects every STRING literal, and emits one escaped dictionary
entry per line. Usage: gen-dict.py <grammar.json>
"""
import json
import sys


def find_literals(literals, node):
    """Recursively find STRING literals in the grammar definition."""
    if isinstance(node, dict):
        if node.get('type') == 'STRING' and 'value' in node:
            literals.add(node['value'])
        for value in node.values():
            find_literals(literals, value)
    elif isinstance(node, list):
        for item in node:
            find_literals(literals, item)


def main():
    with open(sys.argv[1]) as f:
        grammar = json.load(f)

    literals = set()
    find_literals(literals, grammar)

    for lit in sorted(literals):
        if lit:
            print('"%s"' % ''.join('\\x%02x' % b for b in lit.encode('utf-8')))


if __name__ == '__main__':
    main()
