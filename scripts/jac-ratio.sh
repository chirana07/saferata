#!/usr/bin/env bash
# Measures how much of the hand-written code is Jac (target: >= 80%).
# Counts non-blank lines of source files; skips generated/vendored dirs,
# lockfiles, config and docs. Usage: scripts/jac-ratio.sh [dir]   (default: app)
DIR="${1:-app}"
find "$DIR" -type f \
  \( -name '*.jac' -o -name '*.py' -o -name '*.js' -o -name '*.jsx' -o -name '*.ts' \
     -o -name '*.tsx' -o -name '*.css' -o -name '*.html' -o -name '*.sql' -o -name '*.sh' \) \
  -not -path '*/.jac/*' -not -path '*/node_modules/*' -not -path '*/dist/*' \
  -not -path '*/build/*' -not -path '*/.git/*' -not -path '*/.claude/*' -print0 |
xargs -0 awk 'NF { ext=FILENAME; sub(/.*\./, "", ext); n[ext]++; t++ }
  END {
    if (t == 0) { print "no source files found"; exit 1 }
    for (e in n) printf "  %-6s %6d lines  %5.1f%%\n", e, n[e], 100*n[e]/t
    j = ("jac" in n) ? n["jac"] : 0
    printf "  JAC SHARE: %.1f%% of %d lines -> %s\n", 100*j/t, t, (j/t >= 0.8 ? "OK (>=80%)" : "BELOW 80% - FIX")
  }'
