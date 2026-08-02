#!/usr/bin/env bash
#
# Working repository status.
#
# Mirrors deliberately do NOT get a row here: a read-only mirror has no
# meaningful "status" — whatever it holds is discarded by a force sync. The
# working set is the root repo plus the refactoring work copies created by each
# track's Phase 0-0 (scripts/work-repos.sh).
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

# Repos we develop in. Add refactoring work copies to scripts/work-repos.sh.
# shellcheck source=work-repos.sh
source "$SCRIPT_DIR/work-repos.sh"

clean=0; dirty=0; ahead_count=0; missing=0; absent=0

printf '%-22s %-16s %-8s %-7s %s\n' "REPO" "BRANCH" "STATUS" "AHEAD" "DETAILS"
printf '%s\n' "--------------------------------------------------------------------------"

for entry in "${WORK_REPOS[@]}"; do
    IFS='|' read -r repo name push_remote <<<"$entry"

    if [ ! -e "$ROOT_DIR/$repo/.git" ]; then
        # 루트가 없으면 실제 오류지만, 작업 사본은 해당 트랙의 Phase 0-0 이
        # 아직 안 돈 정상 상태일 수 있다. 둘을 다른 색으로 가른다.
        if [ "$repo" = "." ]; then
            printf "${RED}%-22s %-16s %-8s${NC} %-7s %s\n" "$name" "-" "MISSING" "-" "$repo"
            missing=$((missing+1))
        else
            printf "${YELLOW}%-22s${NC} %-16s ${YELLOW}%-8s${NC} %-7s %s\n" \
                "$name" "-" "ABSENT" "-" "work copy not created yet ($repo)"
            absent=$((absent+1))
        fi
        continue
    fi

    d="$ROOT_DIR/$repo"
    branch="$(git -C "$d" branch --show-current 2>/dev/null)"
    porcelain="$(git -C "$d" status --porcelain 2>/dev/null)"

    # 비교 기준: 설정된 upstream 이 있으면 그것, 없으면 이 저장소의 push 대상
    # remote 의 같은 이름 브랜치. 작업 사본은 upstream 이 아직 없는 것이 정상이라
    # 그때는 ahead/behind 를 계산하지 않고 그 사실을 DETAILS 에 적는다.
    upstream="$(git -C "$d" rev-parse --abbrev-ref '@{u}' 2>/dev/null)"
    if [ -z "$upstream" ] && git -C "$d" rev-parse --verify --quiet "$push_remote/$branch" >/dev/null 2>&1; then
        upstream="$push_remote/$branch"
    fi

    if [ -n "$upstream" ]; then
        ahead="$(git -C "$d" rev-list --count "$upstream..HEAD" 2>/dev/null || echo 0)"
        behind="$(git -C "$d" rev-list --count "HEAD..$upstream" 2>/dev/null || echo 0)"
        track=""
    else
        ahead=0; behind=0
        track="no-upstream(push -> $push_remote) "
    fi

    if [ -n "$porcelain" ]; then
        staged=$(grep -c '^[MADRC]' <<<"$porcelain")
        unstaged=$(grep -c '^.[MDRC]' <<<"$porcelain")
        untracked=$(grep -c '^??' <<<"$porcelain")
        details="$track"
        [ "$staged"    -gt 0 ] && details+="staged:$staged "
        [ "$unstaged"  -gt 0 ] && details+="modified:$unstaged "
        [ "$untracked" -gt 0 ] && details+="untracked:$untracked "
        printf "${YELLOW}%-22s${NC} %-16s ${RED}%-8s${NC} " "$name" "$branch" "DIRTY"
        if   [ "$ahead"  -gt 0 ]; then printf "${CYAN}+%-6s${NC} " "$ahead"; ahead_count=$((ahead_count+1))
        elif [ "$behind" -gt 0 ]; then printf "${RED}-%-6s${NC} " "$behind"
        else printf '%-7s ' "-"; fi
        printf '%s\n' "$details"
        dirty=$((dirty+1))
    elif [ "$ahead" -gt 0 ]; then
        printf "${CYAN}%-22s${NC} %-16s ${GREEN}%-8s${NC} ${CYAN}+%-6s${NC} %s\n" \
            "$name" "$branch" "CLEAN" "$ahead" "$track"
        ahead_count=$((ahead_count+1))
    else
        printf "${GREEN}%-22s${NC} %-16s ${GREEN}%-8s${NC} %-7s %s\n" \
            "$name" "$branch" "CLEAN" "-" "$track"
        clean=$((clean+1))
    fi
done

echo
echo "--- Summary ---"
echo -e "Clean: ${GREEN}${clean}${NC}, Dirty: ${YELLOW}${dirty}${NC}, Ahead: ${CYAN}${ahead_count}${NC}, Absent: ${YELLOW}${absent}${NC}, Missing: ${RED}${missing}${NC}"

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
