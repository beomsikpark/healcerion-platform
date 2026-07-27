# healcerion-platform — root orchestration Makefile
#
# 루트는 빌드 대상이 아니라 cross-repo 오케스트레이션 레이어다.
# 게다가 이 워크스페이스는 힐세리온(외부사) 소스의 read-only 미러이므로
# 빌드·커밋·push 계열 타겟은 존재하지 않거나 명시적으로 거부한다.
#
# 규약: CLAUDE.md
# 현 단계에서는 git 계열 타겟만 제공한다.

.DEFAULT_GOAL := help
.PHONY: help \
        git-status git-clone git-pull \
        git-push git-push-all git-commit \
        build test clean

ARGS ?=

## help: Show cross-repo orchestration targets
help:
	@printf '\nhealcerion-platform — root orchestration (NOT a build target)\n'
	@printf 'All sub-repos are READ-ONLY mirrors of Healcerion sources.\n\n'
	@printf 'Usage: make <target> [ARGS=...]\n\n'
	@printf 'Targets:\n'
	@grep -E '^## [a-zA-Z0-9_.-]+:' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
	@printf '\nMirrors: '
	@find . -mindepth 3 -maxdepth 4 -name .git -type d 2>/dev/null | wc -l | tr -d '\n'
	@printf ' cloned\n'
	@printf 'Conventions: CLAUDE.md · Review docs: docs/review/\n\n'

# ─── git (cross-repo) ──────────────────────────────────────────

## git-status: Show git status across root + all mirrors (DIRTY = accidental edit)
git-status:
	scripts/git-status.sh

## git-clone: Clone missing mirrors (safe to re-run; existing repos are skipped)
git-clone:
	scripts/clone-repos.sh

## git-pull: Force-sync mirrors to origin [ARGS=--dry-run|--clean|<path-substring>]
git-pull:
	scripts/pull-mirrors.sh $(ARGS)

# ─── 거부: 미러는 read-only ────────────────────────────────────
# cctv 에는 git-push-all 이 있으나 여기서는 금지다. 손에 익은 명령을
# 무심코 쳤을 때 조용히 성공하는 대신 여기서 멈추게 한다.

git-push git-push-all git-commit:
	@echo ""
	@echo "$@: refused — every sub-repo here is a READ-ONLY mirror of Healcerion source."
	@echo "  Editing, committing or pushing to a mirror is forbidden (see CLAUDE.md)."
	@echo "  Check for accidental edits with: make git-status"
	@echo "  Discard them with:               make git-pull"
	@echo ""
	@exit 1

# ─── 거부: 루트는 빌드 대상 아님 ───────────────────────────────

build test clean:
	@echo ""
	@echo "$@: root is an orchestrator, not a build target."
	@echo "  We review these sources; we do not build them."
	@echo "  See 'make help' for available targets."
	@echo ""
	@exit 1
