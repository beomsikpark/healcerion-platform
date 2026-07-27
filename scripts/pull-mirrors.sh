#!/usr/bin/env bash
#
# Force-sync every Phabricator mirror to its origin branch.
#
# Mirrors are read-only review copies, so local state is never preserved:
#   1) git fetch origin <branch>
#   2) git reset --hard origin/<branch>   <- local edits are discarded
#
# There are no submodules in any mirror (verified 2026-07-27), so unlike the
# cctv fw-orig-pull.sh this script has no submodule handling. Add it back if a
# mirror ever gains a .gitmodules.
#
# Repos are discovered from disk rather than a hardcoded list: clone-repos.sh
# already owns the repo->path mapping, and a second copy would drift.
#
# Usage: ./scripts/pull-mirrors.sh [--dry-run] [--clean] [path-substring...]
#
#   --dry-run   report what would change, touch nothing
#   --clean     also remove untracked files (git clean -fd)
#
# Examples:
#   ./scripts/pull-mirrors.sh --dry-run
#   ./scripts/pull-mirrors.sh mobile      # only paths containing "mobile"
#
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; CYAN='\033[0;36m'; NC='\033[0m'

DRY_RUN=false
CLEAN=false
FILTERS=()

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --clean)   CLEAN=true ;;
        -h|--help) sed -n '2,25p' "$0"; exit 0 ;;
        -*)        echo "Unknown option: $arg" >&2; exit 1 ;;
        *)         FILTERS+=("$arg") ;;
    esac
done

# <container>/legacy/<repo>/.git — depth 4 under ROOT_DIR
mapfile -t REPOS < <(find "$ROOT_DIR" -mindepth 4 -maxdepth 4 -name .git -type d \
                     | sed 's|/\.git$||' | sort)

if [ ${#FILTERS[@]} -gt 0 ]; then
    filtered=()
    for r in "${REPOS[@]}"; do
        for f in "${FILTERS[@]}"; do
            [[ "$r" == *"$f"* ]] && { filtered+=("$r"); break; }
        done
    done
    REPOS=("${filtered[@]}")
fi

if [ ${#REPOS[@]} -eq 0 ]; then
    echo "No mirrors matched. Run ./scripts/clone-repos.sh first."
    exit 1
fi

$DRY_RUN && echo -e "${CYAN}[DRY-RUN]${NC} nothing will be modified."
$CLEAN   && echo -e "${YELLOW}[CLEAN]${NC} untracked files will be removed."
echo

synced=0; uptodate=0; skipped=0; failed=0

printf '%-38s %-10s %-12s %s\n' "REPO" "BRANCH" "STATUS" "DETAILS"
printf '%s\n' "--------------------------------------------------------------------------------"

for repo in "${REPOS[@]}"; do
    rel="${repo#"$ROOT_DIR"/}"
    branch="$(git -C "$repo" branch --show-current 2>/dev/null)"

    if [ -z "$branch" ]; then
        printf "${YELLOW}%-38s${NC} %-10s ${YELLOW}%-12s${NC} %s\n" "$rel" "-" "DETACHED" "HEAD is not on a branch"
        skipped=$((skipped+1)); continue
    fi

    porcelain="$(git -C "$repo" status --porcelain 2>/dev/null)"
    modified=0; untracked=0
    if [ -n "$porcelain" ]; then
        modified=$(grep -cv '^??' <<<"$porcelain")
        untracked=$(grep -c '^??' <<<"$porcelain")
    fi
    details=""
    [ "$modified"  -gt 0 ] && details+="modified:$modified "
    [ "$untracked" -gt 0 ] && details+="untracked:$untracked "

    if ! git -C "$repo" fetch origin "$branch" --quiet 2>/dev/null; then
        printf "${RED}%-38s${NC} %-10s ${RED}%-12s${NC} %s\n" "$rel" "$branch" "FETCH-FAIL" "origin/$branch unreachable"
        failed=$((failed+1)); continue
    fi

    if ! git -C "$repo" rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
        printf "${YELLOW}%-38s${NC} %-10s ${YELLOW}%-12s${NC} %s\n" "$rel" "$branch" "NO-UPSTREAM" "origin/$branch missing"
        skipped=$((skipped+1)); continue
    fi

    local_sha="$(git -C "$repo" rev-parse HEAD)"
    remote_sha="$(git -C "$repo" rev-parse "origin/$branch")"

    if [ "$local_sha" = "$remote_sha" ] && [ "$modified" -eq 0 ] \
       && { [ "$untracked" -eq 0 ] || ! $CLEAN; }; then
        printf "${GREEN}%-38s${NC} %-10s ${GREEN}%-12s${NC} %s\n" "$rel" "$branch" "UP-TO-DATE" "${details:--}"
        uptodate=$((uptodate+1)); continue
    fi

    if $DRY_RUN; then
        plan="reset --hard origin/$branch"
        $CLEAN && plan+=" + clean -fd"
        printf "${CYAN}%-38s${NC} %-10s ${CYAN}%-12s${NC} %s [%s]\n" \
            "$rel" "$branch" "WOULD-SYNC" "${details:-no local changes}" "$plan"
        synced=$((synced+1)); continue
    fi

    if ! out="$(git -C "$repo" reset --hard "origin/$branch" 2>&1)"; then
        printf "${RED}%-38s${NC} %-10s ${RED}%-12s${NC} %s\n" "$rel" "$branch" "RESET-FAIL" "git reset --hard failed"
        sed 's/^/    /' <<<"$out"
        failed=$((failed+1)); continue
    fi

    if $CLEAN && ! out="$(git -C "$repo" clean -fd 2>&1)"; then
        printf "${RED}%-38s${NC} %-10s ${RED}%-12s${NC} %s\n" "$rel" "$branch" "CLEAN-FAIL" "git clean failed"
        sed 's/^/    /' <<<"$out"
        failed=$((failed+1)); continue
    fi

    short="$(git -C "$repo" rev-parse --short HEAD)"
    printf "${GREEN}%-38s${NC} %-10s ${GREEN}%-12s${NC} %s\n" \
        "$rel" "$branch" "SYNCED" "-> $short ${details:+(discarded: $details)}"
    synced=$((synced+1))
done

echo
echo "--- Summary ---"
echo -e "Synced: ${GREEN}${synced}${NC}, Up-to-date: ${GREEN}${uptodate}${NC}, Skipped: ${skipped}, Failed: ${RED}${failed}${NC}"
[ "$failed" -gt 0 ] && exit 1
exit 0
