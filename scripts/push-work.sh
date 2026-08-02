#!/usr/bin/env bash
#
# Push one working repository to the remote it is allowed to be pushed to.
#
# Only repos listed in scripts/work-repos.sh can be pushed at all — mirrors are
# read-only Healcerion sources and have no push path anywhere in this tree.
#
# 왜 remote 를 인자로 받지 않고 목록에서 읽는가:
# 리팩토링 작업 사본의 `origin` 은 힐세리온 Phabricator 원본이다. 반영 방식
# (fork-and-PR·브랜치 위임 등)이 확정되기 전에 그쪽으로 push 하면 되돌릴 수
# 없다(docs/refactoring/r1/plan.md §위험). 대상 remote 를 목록에 고정하고
# phabricator URL 을 하드 거부해, 오타 하나로 원본에 브랜치가 올라가는 경로를
# 없앤다.
#
# Usage: ./scripts/push-work.sh <label> [-- <extra git push args>]
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; NC='\033[0m'

# shellcheck source=work-repos.sh
source "$SCRIPT_DIR/work-repos.sh"

UPSTREAM_HOST="phab.healcerion.com"

die() { printf "${RED}%s${NC}\n" "$*" >&2; exit 1; }

label="${1:-}"
if [ -z "$label" ]; then
    echo "usage: $0 <label> [-- <extra git push args>]" >&2
    echo "labels:" >&2
    for entry in "${WORK_REPOS[@]}"; do
        IFS='|' read -r p l r <<<"$entry"
        printf '  %-20s %-24s push -> %s\n' "$l" "$p" "$r" >&2
    done
    exit 1
fi
shift
[ "${1:-}" = "--" ] && shift

repo=""; push_remote=""
for entry in "${WORK_REPOS[@]}"; do
    IFS='|' read -r p l r <<<"$entry"
    if [ "$l" = "$label" ]; then repo="$p"; push_remote="$r"; break; fi
done
[ -n "$repo" ] || die "unknown working repo '$label' — see scripts/work-repos.sh"

d="$ROOT_DIR/$repo"
[ -e "$d/.git" ] || die "$label: $repo is not a git repo (work copy not created yet?)"

branch="$(git -C "$d" branch --show-current 2>/dev/null)"
[ -n "$branch" ] || die "$label: detached HEAD — check out a branch first"

url="$(git -C "$d" remote get-url "$push_remote" 2>/dev/null)"
if [ -z "$url" ]; then
    printf "${YELLOW}%s: remote '%s' is not configured — nothing was pushed.${NC}\n" "$label" "$push_remote"
    echo
    echo "  This repo's 'origin' is the Healcerion upstream; we never push there."
    echo "  Add our own remote first, then re-run:"
    echo
    echo "    git -C $repo remote add $push_remote <OUR-REMOTE-URL>"
    echo "    scripts/push-work.sh $label"
    echo
    exit 1
fi

case "$url" in
    *"$UPSTREAM_HOST"*)
        die "$label: remote '$push_remote' points at the Healcerion upstream ($url) — refused.
  Work copies are never pushed to Healcerion's repository. The reflection
  method (fork-and-PR / delegated branch) must be agreed first.
  Point '$push_remote' at our own remote instead."
        ;;
esac

printf "${GREEN}%s${NC}  %s -> %s (%s)  branch=%s\n" "$label" "$repo" "$push_remote" "$url" "$branch"
git -C "$d" push -u "$push_remote" "$branch" "$@"
