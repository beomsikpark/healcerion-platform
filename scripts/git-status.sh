#!/usr/bin/env bash
#
# Working repository status.
#
# Mirrors deliberately do NOT get a row here: a read-only mirror has no
# meaningful "status" — whatever it holds is discarded by a force sync. Every
# sub-repo in this workspace is such a mirror, so the working set is the root
# repo alone.
#
# Accidental mirror edits are still worth catching, so they are folded into a
# single summary line and only DIRTY ones are named. Full mirror detail:
#   make git-sync-legacy ARGS=--dry-run
#
# Usage: ./scripts/git-status.sh
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

# Repos we develop in. Add refactoring output here as it appears.
REPOS=(
    "."
)

clean=0; dirty=0; ahead_count=0; missing=0

printf '%-24s %-14s %-8s %-7s %s\n' "REPO" "BRANCH" "STATUS" "AHEAD" "DETAILS"
printf '%s\n' "--------------------------------------------------------------------------"

for repo in "${REPOS[@]}"; do
    [ "$repo" = "." ] && name="healcerion-platform" || name="$(basename "$repo")"

    if [ ! -e "$ROOT_DIR/$repo/.git" ]; then
        printf "${RED}%-24s %-14s %-8s${NC}\n" "$name" "-" "MISSING"
        missing=$((missing+1)); continue
    fi

    d="$ROOT_DIR/$repo"
    branch="$(git -C "$d" branch --show-current 2>/dev/null)"
    porcelain="$(git -C "$d" status --porcelain 2>/dev/null)"
    ahead="$(git -C "$d" rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo 0)"
    behind="$(git -C "$d" rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo 0)"

    if [ -n "$porcelain" ]; then
        staged=$(grep -c '^[MADRC]' <<<"$porcelain")
        unstaged=$(grep -c '^.[MDRC]' <<<"$porcelain")
        untracked=$(grep -c '^??' <<<"$porcelain")
        details=""
        [ "$staged"    -gt 0 ] && details+="staged:$staged "
        [ "$unstaged"  -gt 0 ] && details+="modified:$unstaged "
        [ "$untracked" -gt 0 ] && details+="untracked:$untracked "
        printf "${YELLOW}%-24s${NC} %-14s ${RED}%-8s${NC} " "$name" "$branch" "DIRTY"
        if   [ "$ahead"  -gt 0 ]; then printf "${CYAN}+%-6s${NC} " "$ahead"; ahead_count=$((ahead_count+1))
        elif [ "$behind" -gt 0 ]; then printf "${RED}-%-6s${NC} " "$behind"
        else printf '%-7s ' "-"; fi
        printf '%s\n' "$details"
        dirty=$((dirty+1))
    elif [ "$ahead" -gt 0 ]; then
        printf "${CYAN}%-24s${NC} %-14s ${GREEN}%-8s${NC} ${CYAN}+%-6s${NC}\n" "$name" "$branch" "CLEAN" "$ahead"
        ahead_count=$((ahead_count+1))
    else
        printf "${GREEN}%-24s${NC} %-14s ${GREEN}%-8s${NC} %-7s\n" "$name" "$branch" "CLEAN" "-"
        clean=$((clean+1))
    fi
done

echo
echo "--- Summary ---"
echo -e "Clean: ${GREEN}${clean}${NC}, Dirty: ${YELLOW}${dirty}${NC}, Ahead: ${CYAN}${ahead_count}${NC}, Missing: ${RED}${missing}${NC}"

# Mirrors: one line when healthy, named only when someone edited them.
mirror_total=0; mirror_dirty=()
while IFS= read -r gitdir; do
    r="${gitdir%/.git}"
    mirror_total=$((mirror_total+1))
    [ -n "$(git -C "$r" status --porcelain 2>/dev/null)" ] && mirror_dirty+=("${r#"$ROOT_DIR"/}")
done < <(find "$ROOT_DIR" -mindepth 2 -maxdepth 4 -name .git -type d -path "*/legacy/*")

if [ ${#mirror_dirty[@]} -eq 0 ]; then
    echo -e "Mirrors: ${GREEN}${mirror_total} clean${NC} (read-only — detail: make git-sync-legacy ARGS=--dry-run)"
else
    echo -e "Mirrors: ${mirror_total} total, ${RED}${#mirror_dirty[@]} EDITED${NC} — mirrors must never be edited:"
    printf "  ${RED}%s${NC}\n" "${mirror_dirty[@]}"
    # --clean is required: plain sync only resets tracked files, so a stray
    # untracked file would survive and keep showing up as EDITED here.
    echo "  discard with: make git-sync-legacy ARGS=--clean"
fi
