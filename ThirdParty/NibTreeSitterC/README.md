# Vendored Tree-sitter

MIT-licensed sources used by **NIB-008**:

| Path | Upstream | Version |
| --- | --- | --- |
| `src/runtime` | [tree-sitter/tree-sitter](https://github.com/tree-sitter/tree-sitter) | 0.24.7 |
| `src/json` | [tree-sitter/tree-sitter-json](https://github.com/tree-sitter/tree-sitter-json) | 0.24.8 |
| `src/python` | [tree-sitter/tree-sitter-python](https://github.com/tree-sitter/tree-sitter-python) | 0.23.6 |
| `src/markdown` | [tree-sitter-grammars/tree-sitter-markdown](https://github.com/tree-sitter-grammars/tree-sitter-markdown) | 0.3.2 |

Highlight queries live in `Services/Syntax/Queries` and are intentionally simplified (no `#match?` predicates) so the highlighter can run without a predicate host.
