#!/usr/bin/env bash
# Clone Healcerion Phabricator repositories into their container folders.
#
# Access: ssh://git@phab.healcerion.com:2222/diffusion/<repo-id>/
#   - SSH user is `git` (NOT `vcs`), port 2222 (NOT 22).
#   - The /diffusion/<id>/ form works for every repo, including callsign-less ones.
#   - Repositories whose Phabricator status is `inactive` are refused over SSH
#     ("This repository is not available over SSH") — they need reactivation.
#
# Inventory source: tmp/repos-inventory.json (conduit diffusion.repository.search)
set -uo pipefail

BASE="ssh://git@phab.healcerion.com:2222/diffusion"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
JOBS="${JOBS:-3}"

# repo-id : local path
#
# Mirrors sit directly under their container, like cctv's device/ipc-app or
# desktop/cms-app. cctv reserves a *-orig subfolder (device/fw-orig) for legacy
# sources that a new in-house rewrite has replaced; we have produced no such
# rewrite yet, so nothing belongs there and the extra level would carry no
# information. Introduce <container>/orig/ at the moment our own output lands.
REPOS=(
    # --- mobile: Flutter client app + its SDK/ADK
    #     (app also builds windows/macos/linux — see CLAUDE.md) ---
    "76:mobile/sonex-app"            # sonex-APP        : flutter 로 구현된 sonex app
    "74:mobile/sonex-framework"      # sonex-framework  : sonex 앱의 SDK, ADK
    # --- web ---
    "73:web/sonex-admin-web"         # sonex-admin-web  : SoNex cloud admin web site
    # --- server ---
    "65:server/russia-server"        # russia-server    : REST API test server (Russia ambulance)
    "26:server/dicomcontroller"      # dicomcontroller  : (설명 없음)
    # --- device: 장비 펌웨어·MCU·yocto ---
    "70:device/belle-msp"            # belle-msp        : MSP430 MCU 펌웨어
    "60:device/elsa-fw"              # elsa-fw          : (설명 없음)
    "75:device/500c-sn-fw"           # 500C_SN_FW       : 500C Firmware ([LAB] CHARM)
    "34:device/elsa-yocto-bsp"       # elsa-yocto-bsp   : Elsa Project BSP
    "36:device/meta-elsa"            # meta-elsa        : meta-elsa yocto recipes
    "66:device/belle-fw"             # belle-fw         : elsa project firmware repo   [INACTIVE]
    "67:device/belle-bsp"            # belle-bsp        : elsa project firmware BSP    [INACTIVE]
    # --- fpga: cctv 에 대응 축 없음 (healcerion 고유) ---
    "68:fpga/fuji-oem-us-fpga"       # FUJI_OEM_US_FPGA : FUJI OEM 64Ch ultrasound equipment
    "58:fpga/ginny-renewal"          # fpga ginny renewal : 300 series ginny FPGA renewal
    "40:fpga/ginny-table"            # ginny-table      : Ginny FPGA Table
)

# 범위 제외 — upstream 포크 (힐세리온 자작 코드 아님. 우리는 빌드하지 않으므로 불필요):
#   37 elsa-linux  = git.freescale.com/imx/linux-2.6-imx @ rel_imx_4.1.15_1.1.0_ga
#   35 elsa-u-boot = github.com/Freescale/u-boot-fslc    @ imx_v2015.04_4.1.15_1.0.0_ga
#   커널·부트로더 버전은 위 설명만으로 확정되므로 수 GB 클론의 이득이 없다.
#
# 범위 제외 — 신호처리 R&D (알고리즘 트랙, 리팩토링 성격이 앱/FW 와 다름):
#   77 NextSRI · 78 NextDoppler · 39 cf-doppler-neon(rHFW 통합 예정)
#   49 US_Matlab_Simulator · 57 Frances-GUI-Simulator
#
# 범위 제외 — 사내 개발 인프라 (제품 SW 아님. docs/review/dev-environment.md §4 참조):
#   63 DevOps · 64 phabricator · 32 phabricator-to-slack
#
# 제외 — 중복(inactive 사본) 및 연습용:
#   69 belle-msp(inactive dup) · 61 elsa-fw(inactive dup) · 59 esla-fw(오타 dup)
#   38 test · 27 Sanbox · 11 Sandbox Test
#
# 미가시(계정 권한 필요) — PPT 스크린샷에는 있으나 conduit 조회 결과에 없음.
# 아래 3건이 확보되면 이 배열에 추가한다:
#   rM   Moana (5,705 commits, 배포중 Qt 앱)  -> mobile/moana
#   rCL  sonon-cloud (394 commits)            -> server/sonon-cloud
#   rHFW (cf-doppler-neon 설명이 통합 대상으로 언급 — 존재 추정) -> desktop/rhfw

clone_one() {
    local id="${1%%:*}" path="${1#*:}"
    local dir="$ROOT/$path"
    if [ -d "$dir/.git" ]; then
        printf 'SKIP  %-34s (already cloned)\n' "$path"
        return 0
    fi
    mkdir -p "$(dirname "$dir")"
    if git clone --quiet "$BASE/$id/" "$dir" 2>/dev/null; then
        printf 'OK    %-34s commits=%s size=%s\n' "$path" \
            "$(git -C "$dir" rev-list --count --all 2>/dev/null || echo '?')" \
            "$(du -sh "$dir" 2>/dev/null | cut -f1)"
    else
        rm -rf "$dir"
        printf 'FAIL  %-34s (id=%s — inactive 이거나 권한 없음)\n' "$path" "$id"
    fi
}
export -f clone_one
export BASE ROOT

printf '%s\n' "${REPOS[@]}" | xargs -P "$JOBS" -I{} bash -c 'clone_one "{}"'
