#!/bin/bash
#
# 하위 git repository 상태 확인 스크립트 (read-only 미러 — 변경이 있으면 안 된다)
#
# Usage: ./scripts/git-status.sh
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}=== healcerion-platform (root — 우리 문서) ===${NC}"
git -C "$ROOT_DIR" status --short --branch | head -20
echo

echo -e "${CYAN}=== Phabricator 미러 (변경 = 이상 신호) ===${NC}"
while IFS= read -r gitdir; do
    repo="$(dirname "$gitdir")"
    rel="${repo#$ROOT_DIR/}"
    [ "$rel" = "$ROOT_DIR" ] && continue
    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    dirty="$(git -C "$repo" status --porcelain 2>/dev/null | wc -l)"
    ahead="$(git -C "$repo" rev-list --count "@{u}..HEAD" 2>/dev/null || echo 0)"
    last="$(git -C "$repo" log -1 --format=%ci 2>/dev/null | cut -d' ' -f1)"
    if [ "$dirty" -eq 0 ] && [ "$ahead" -eq 0 ]; then
        printf "${GREEN}  clean${NC}  %-36s %-28s last=%s\n" "$rel" "$branch" "$last"
    else
        printf "${RED}  DIRTY${NC}  %-36s %-28s last=%s  (changed=%s ahead=%s)\n" \
            "$rel" "$branch" "$last" "$dirty" "$ahead"
    fi
# depth 3 = <container>/<repo>/.git   (e.g. mobile/sonex-app/.git)
# depth 4 = <container>/<group>/<repo>/.git (device/bsp/*, device/orig/*, mobile/orig/*)
# maxdepth 4 also keeps vendored checkouts nested deeper inside a mirror out of the list.
done < <(find "$ROOT_DIR" -mindepth 3 -maxdepth 4 -name .git -type d | sort)

echo
echo -e "${YELLOW}미러에 DIRTY 가 뜨면 편집한 것이다 — 되돌릴 것 (push 절대 금지).${NC}"
