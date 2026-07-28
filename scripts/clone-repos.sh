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
# All mirrors live under <container>/legacy/ — Healcerion-owned, read-only.
# Never edited or committed by us. The container top level is reserved for our
# own output. See CLAUDE.md.
REPOS=(
    # --- client: 장비·클라우드에 붙는 호스트 SW ---
    #     단일 코드베이스가 모바일·데스크톱을 함께 낸다(moana=Qt, sonex=Flutter).
    #     플랫폼별로 쪼갤 대상이 없어 mobile/desktop 축을 두지 않는다.
    #     그들 코드도 이 계층을 SononClient / TARGET_ID_CLIENT 로 부른다.
    "47:client/legacy/moana"              # rM    : Moana project (Qt, 앱 SOT)
    "76:client/legacy/sonex-app"          # rSAPP : flutter 로 구현된 sonex app (재작성 진행 중)
    "74:client/legacy/sonex-framework"    # rSFW  : sonex 앱의 SDK, ADK
    "45:client/legacy/cuattro-sdk"        # rCS   : Cuattro 용 window SDK C# 포팅 (300C/300L 전용)
    "42:client/legacy/ginny-string-table-converter"  # rGST : XLSX -> app string (Android/iOS)
    # --- web: 브라우저 관리자 콘솔 (장비 연결 없음) ---
    "73:web/legacy/sonex-admin-web"       # rSAW  : SoNex cloud admin web site
    # --- server ---
    "71:server/legacy/sonex-cloud-backend" # rSCBE : SoNex cloud web application server + database server
    "62:server/legacy/sonon-cloud"        # rCL   : sonon web admin site
    "65:server/legacy/russia-server"      # rRUS  : REST API test server (Russia ambulance)
    "26:server/legacy/dicomcontroller"    # rHDC  : DICOM SCU 라이브러리 + iOS 샘플
    # --- device: 장비 펌웨어·MCU·커널·부트로더·BSP ---
    #     belle = 500 시리즈(ZynqMP, 검토 범위) · ginny = 300 시리즈(단종, 범위 밖).
    "50:device/legacy/belle-fw"           # rBF   : Belle Firmware (현행 생산 라인)
    "53:device/legacy/belle-bsp"          # rBB   : Belle BSP (PetaLinux 프로젝트)
    "51:device/legacy/belle-kernel"       # rBK   : Belle Kernel (Linux 5.4.0)
    "52:device/legacy/belle-u-boot"       # rBU   : Belle U-Boot (v2020.01)
    "54:device/legacy/belle-fsbl"         # rBFS  : Belle FSBL  — 원격이 빈 저장소
    "55:device/legacy/belle-pmu"          # rBP   : Belle PMU   — 원격이 빈 저장소
    "70:device/legacy/belle-msp"          # r70   : MSP430 전원·감시 MCU
    "17:device/legacy/ginny-fw"           # rHFW  : 300 시리즈 펌웨어 (개발 이력의 본체)
    "60:device/legacy/elsa-fw"            # rFW   : ginny -> belle 과도기
    "75:device/legacy/500c-sn-fw"         # r75   : 500C Firmware ([LAB] CHARM, Socionext 베어메탈)
    "34:device/legacy/elsa-yocto-bsp"     # rEY   : repo 매니페스트 (BSP 아님)
    "36:device/legacy/meta-elsa"          # rME   : meta-elsa yocto recipes
    # --- fpga: cctv 에 대응 축 없음 (healcerion 고유) ---
    "56:fpga/legacy/elsa-fpga"            # rEF   : xczu3cg — belle 의 PL (검토 범위)
    "58:fpga/legacy/ginny-renewal"        # rFGR  : 300 series ginny FPGA renewal
    "40:fpga/legacy/ginny-table"          # rGT   : Ginny FPGA Table (배포 아티팩트, HDL 없음)
    "18:fpga/legacy/ginny-fpga"           # rGF   : ginny 계보의 출발점
    "48:fpga/legacy/elsa-dump-fpga"       # rEDF  : elsa-fpga 의 출발점
    "68:fpga/legacy/fuji-oem-us-fpga"     # rFF   : FUJI OEM 64Ch ultrasound equipment
    "72:fpga/legacy/charm-fpga"           # rCF   : 500C 용 FPGA (Efinix)
    "41:fpga/legacy/ash-fpga"             # rAF   : Ash FPGA (SMIC ASIC + FPGA 에뮬)
    "43:fpga/legacy/bf-delay-calculation" # rBDC  : Beamforming Delay Calculation (테이블 생성기)
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
