#!/usr/bin/env bash
# Deploy the web build to GitHub Pages (https://hieubqdsm.github.io/crime-in-clock-tower/)
# - rebuilds the nothreads web export, then force-pushes it as a SINGLE-COMMIT
#   orphan branch "gh-pages" (keeps the 40 MB binaries out of main's history).
# Requires git >= 2.42 (worktree --orphan). The main working tree is untouched.
set -euo pipefail
cd "$(dirname "$0")/.."

GODOT="$(sed -n 's/^- godot_exe: "\(.*\)"$/\1/p' docs/LOCAL.md)"
if [ -z "$GODOT" ]; then echo "godot_exe missing in docs/LOCAL.md" >&2; exit 1; fi

echo "→ exporting web build (nothreads)"
mkdir -p build/web   # --export-release fails if the target folder is missing
"$GODOT" --headless --path . --export-release "Web Smoke Test"

echo "→ staging gh-pages orphan worktree"
WT="$(mktemp -d)"
git worktree add --orphan -b gh-pages-deploy "$WT" >/dev/null
trap 'git worktree remove --force "$WT" >/dev/null 2>&1; git branch -D gh-pages-deploy >/dev/null 2>&1 || true' EXIT

cp build/web/index* "$WT/"
rm -f "$WT"/*.import
# keep only the runtime files Pages needs
(cd "$WT" && git add -A && \
 git commit -q -m "Web deploy: $(git -C .. rev-parse --short=8 main 2>/dev/null || echo snapshot) $(date +%F)")

echo "→ pushing gh-pages"
git -C "$WT" push --force origin HEAD:gh-pages
echo "✓ live at https://hieubqdsm.github.io/crime-in-clock-tower/"
