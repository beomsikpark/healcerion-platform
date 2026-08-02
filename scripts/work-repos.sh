#!/usr/bin/env bash
#
# Working repositories — the SOT for every git target that is NOT a mirror.
#
# A "working repo" is one we develop in. Two kinds exist:
#   - the root repo (review output: docs/, scripts/, Makefile)
#   - refactoring work copies created by each track's Phase 0-0
#     (e.g. client/legacy/sonex-framework -> client/sonex-framework)
#
# Mirrors under <container>/legacy/ are NEVER listed here. They are read-only
# Healcerion sources, discarded by force sync; see scripts/pull-mirrors.sh.
#
# Format: <path>|<label>|<push-remote>
#   path        : relative to the repo root
#   label       : name shown in status output and accepted by push-work.sh
#   push-remote : the ONLY remote this repo may be pushed to
#
# 왜 push-remote 를 목록에 박아두는가:
# 작업 사본의 `origin` 은 힐세리온 Phabricator 원본이다. 반영 방식이 확정되기
# 전에 그쪽으로 push 하면 되돌릴 수 없다(docs/refactoring/r1/plan.md §위험).
# 그래서 push 대상 remote 를 코드에 고정하고, push-work.sh 가 origin 이
# phabricator 를 가리키는 한 절대 밀지 않도록 막는다.
#
WORK_REPOS=(
    ".|healcerion-platform|origin"
    "client/sonex-framework|sonex-platform|ours"
)
