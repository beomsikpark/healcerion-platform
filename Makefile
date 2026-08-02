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
        git-status git-clone git-pull git-push git-push-sonex git-sync-legacy \
        git-push-all git-commit \
        build test clean

ARGS ?=

## help: Show cross-repo orchestration targets
help:
	@printf '\nhealcerion-platform — root orchestration (NOT a build target)\n'
	@printf 'Everything under <container>/legacy/ is a READ-ONLY mirror of Healcerion source.\n'
	@printf 'Only the repos in scripts/work-repos.sh are ours to commit and push.\n\n'
	@printf 'Usage: make <target> [ARGS=...]\n\n'
	@printf 'Targets:\n'
	@grep -E '^## [a-zA-Z0-9_.-]+:' $(MAKEFILE_LIST) | sed 's/## /  /' | column -t -s ':'
	@printf '\nWorking repos: '
	@grep -c '^    "' scripts/work-repos.sh | tr -d '\n'
	@printf ' (scripts/work-repos.sh) · Mirrors: '
	@find . -mindepth 3 -maxdepth 4 -name .git -type d -path '*/legacy/*' 2>/dev/null | wc -l | tr -d '\n'
	@printf ' cloned\n'
	@printf 'Conventions: CLAUDE.md · Review docs: docs/review/\n\n'

# ─── git: 작업 저장소 (우리 산출물) ────────────────────────────
# 작업 저장소만 우리 것이고 나머지는 전부 미러다. 그래서 pull/push 의미가 정반대다.
#   작업  : ff-only pull + push  (작업물을 절대 잃으면 안 된다)
#   미러  : reset --hard 강제 동기화 (로컬 상태는 언제나 버린다)
# 한 타겟에 섞으면 작업물을 날릴 수 있어 타겟을 분리한다.
#
# 작업 저장소 목록의 SOT = scripts/work-repos.sh
#   healcerion-platform  = .                       (검토 산출물, push -> origin)
#   sonex-platform       = client/sonex-framework  (r1 작업 사본, push -> ours)
# 작업 사본의 origin 은 힐세리온 Phabricator 원본이라 push 대상이 아니다.

## git-status: Show git status across working repos + mirror summary (DIRTY mirror = accidental edit)
git-status:
	scripts/git-status.sh

## git-pull: Fast-forward the ROOT repo from origin (refuses if dirty)
git-pull:
	@[ -n "$$(git remote)" ] || { echo "no remote configured on root"; exit 1; }
	@[ -z "$$(git status --porcelain)" ] || { echo "root has uncommitted changes — commit or stash first"; exit 1; }
	@git rev-parse --abbrev-ref '@{u}' >/dev/null 2>&1 \
		|| { echo "no upstream for '$$(git branch --show-current)' — run 'make git-push' first"; exit 1; }
	git pull --ff-only

## git-push: Push the ROOT repo (healcerion-platform) to origin
git-push:
	scripts/push-work.sh healcerion-platform

## git-push-sonex: Push the sonex-platform work copy to OUR remote (never to Healcerion)
git-push-sonex:
	scripts/push-work.sh sonex-platform

# ─── git: 미러 (read-only) ─────────────────────────────────────

## git-clone: Clone missing mirrors (safe to re-run; existing repos are skipped)
git-clone:
	scripts/clone-repos.sh

## git-sync-legacy: Force-sync all mirrors to origin [ARGS=--dry-run|--clean|<path>]
git-sync-legacy:
	scripts/pull-mirrors.sh $(ARGS)

# ─── 거부 ──────────────────────────────────────────────────────
# cctv 의 git-push-all 을 손에 익은 대로 쳤을 때 미러까지 밀어버리지 않도록 막는다.

git-push-all git-commit:
	@echo ""
	@echo "$@: refused — this workspace is not cctv."
	@echo "  Sub-repos are READ-ONLY mirrors of Healcerion source; they are never pushed."
	@echo "  For the root repo use: make git-push"
	@echo "  Check for accidental mirror edits: make git-status"
	@echo "  Discard them with:                 make git-sync-legacy"
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
