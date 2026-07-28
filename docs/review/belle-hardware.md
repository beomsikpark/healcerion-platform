# belle 하드웨어 구성

> **근거**: `belle-bsp` **`origin/production-fw`** 의 `project-spec/configs/config`·`system-user.dtsi`, `belle-fw` `origin/production-fw-ver2.0` 의 드라이버·스크립트 직접 읽기(2026-07-28).
> **한계**: 회로도·BOM 은 없다. 아래는 **소프트웨어가 전제하는 하드웨어**를 역산한 것이다. 실장 부품 확정이 필요한 항목은 §7 에 모았다.
> **관련**: [device-firmware.md](device-firmware.md)(펌웨어 구조)

## 1. 보드 정체

| 항목 | 값 | 출처 |
|---|---|---|
| 보드명 | **`HIT REV1.0`** | `system-user.dtsi` 의 `model` |
| 제품명·호스트명 | `elsa-pp` (master 는 `elsa-es3`) | `config` 의 `SUBSYSTEM_PRODUCT`/`HOSTNAME` |
| SoC | **Xilinx Zynq UltraScale+ MPSoC** | `CONFIG_SYSTEM_ZYNQMP=y`, `compatible = "xlnx,zynqmp"` |
| APU | **Cortex-A53** (aarch64) | `SUBSYSTEM_PROCESSOR0_IP_NAME="psu_cortexa53_0"` |
| DDR | **512 MiB** (`0x20000000`), base `0x0` | `SUBSYSTEM_MEMORY_PSU_DDR_0_BANKLESS_SIZE` |
| 하드웨어 핸드오프 | `es3_v00.01.00.xsa` | `vivado-hw-xsa/` |

보드 코드명이 **셋 섞여 있다** — `HIT`(DT model) · `elsa-es3`/`elsa-pp`(PetaLinux product) · `belle`(저장소·설치 경로). ES3 → PP 는 시제품 단계 표기로 보인다(추정).

## 2. 저장장치 — QSPI NOR 단일 칩

**NAND 는 없다.** ZynqMP 내장 QSPI 컨트롤러(`psu_qspi_0`) 하나에 NOR 플래시 1개다.

```dts
&qspi {
    is-dual = <0>;  num-cs = <1>;
    flash0: flash@0 {
        compatible = "m25p80","jedec,spi-nor";
        /*compatible = "mt25ql02g";*/     ← 주석
        spi-tx-bus-width = <1>;  spi-rx-bus-width = <4>;   // Quad read
        spi-max-frequency = <150000000>;
    };
};
```

| 사실 | 값 |
|---|---|
| 인터페이스 | QSPI, Quad read, 최대 150 MHz |
| 구성 | 단일 칩(`num-cs=1`), dual-parallel 아님(`is-dual=0`) |
| 섹터 | **64 KB** — 커널이 `CONFIG_MTD_SPI_NOR_USE_4K_SECTORS` 를 끔 |
| 용량 | 파티션 합계 **118.25 MiB 이상 필요**. 주석의 `mt25ql02g` 는 Micron 2Gbit = **256 MiB** |

부품번호가 주석 처리돼 있고 활성 compatible 이 범용 `jedec,spi-nor` 라 **런타임 JEDEC ID 자동 인식**이다. 실장 부품은 저장소만으로 확정되지 않는다(§7).

### 2.1 파티션 — A/B 이중 뱅크

| # | 이름 | 크기 | 용도 |
|---|---|---:|---|
| 0 | `boot` | 2 MiB | `BOOT.BIN` (FSBL + PMU + ATF + u-boot) |
| 1 | `bootenv` | 256 KiB | u-boot 환경변수 |
| **2 / 3** | `kernel` / `kernel2` | **32 MiB × 2** | `image.ub` (커널 FIT + **initramfs rootfs**) |
| **4 / 5** | `hcproc` / `hcproc2` | **10 MiB × 2** | 애플리케이션 UBI 오버레이 |
| 6 | `userdata` | 30 MiB | 설정·캘리브레이션 (UBIFS) |
| 7 | `auth` | 2 MiB | ContextVision 키 저장소 |
| — | 합계 | **118.25 MiB** | |

커널과 애플리케이션이 각각 **A/B 뱅크**를 갖는다. `upgrade.sh` 가 `fw_printenv kernel_imagepart`·`hcproc_imagepart` 로 현재 뱅크를 읽어 **반대편에 기록**하므로 업그레이드 실패 시 롤백된다.

`auth`(mtd7)는 정의만 있고 `belle-fw/scripts/` 에서 접근 흔적이 없다 — 별도 경로로 쓰거나 미사용이다.

### 2.2 rootfs 는 RAM 에 있다

```
CONFIG_SUBSYSTEM_ROOTFS_INITRD=y
CONFIG_SUBSYSTEM_INITRAMFS_IMAGE_NAME="petalinux-image-minimal"
```

**rootfs 파티션이 없다.** rootfs 는 `image.ub` 안에 initramfs 로 들어가 RAM 에서 돈다. `rootfs.jffs2` 설정도 존재하나 선택돼 있지 않다.

→ 램디스크라 변경이 남지 않으므로, 애플리케이션 오버레이(`hcproc`)를 **매 부팅마다 다시 덮어써야 한다**. 이것이 `hcproc.sh` 가 `cp -rf /hcproc/bin/* /usr/bin/` 하는 이유다.

SD 슬롯 2개(`sdhci0`·`sdhci1`)가 활성화돼 있으나 부팅 미디어는 전부 flash 로 지정돼 있다.

## 3. PL(FPGA) 인터페이스

```dts
plif: plif@b0000000 {
    compatible = "vendor,plinterface";
    reg = <0x0 0xb0000000 0x0 0x100000>;      // 1 MiB 윈도우
    interrupt-parent = <&gpio>;  interrupts = <40 2>;
};
```

- **주소 `0xB000_0000`, 1 MiB 레지스터 윈도우** — `belle-fw/lib/hw/pl_ctrl.cpp` 의 `PL_CTRL_REG_BASE_ADDR 0xb0000000` 과 일치
- **인터럽트가 GIC 가 아니라 GPIO 40 번을 통해 온다** — GIC 경로(`interrupts = <0 89 1>`)는 주석 처리돼 있다. 우회 배선으로 보인다(추정)
- 전용 드라이버 `modules/plif/`(`plif.c`·`plif_dma.c`) + `modules/zynqdma/` 가 DMA 를 담당

### 3.1 FPGA 는 ZynqMP PL 하나다 — 초판 판정 철회

> **정정 (2026-07-28 적대적 검증)**: 초판은 "`configs/500l/fpga.bin` 의 IDCODE 가 **`0x03631093` = Artix-7 XC7A100T** 이므로 **ZynqMP PL + 외부 Artix-7 2개 구성인지 미확정**" 이라 적었다. **틀렸다** — `fpga.bin` 은 파일이 아니라 **심볼릭 링크**(mode `120000`)이고, 링크를 따라가지 않고 다른 파일의 IDCODE 를 귀속시킨 것이다.

| 경로 | 링크 대상 | 비트스트림 IDCODE | 소자 계열 |
|---|---|---|---|
| `configs/500l/fpga.bin` | `PP_1119_ext_trig.bin` | **`0x04a42093`** | **Artix-7 아님** (7-series 계열코드 `0x03…` 과 다름) |
| `configs/300l/fpga.bin` | `top_steer_1211.bin` | `0x03631093` | Artix-7 XC7A100T |

**Artix-7 비트스트림은 `configs/300l/` 아래에만 있다.** 그 디렉토리는 현재 컴파일 플래그 조합에서 도달 불가능한 300 시리즈 잔존물이다([device-firmware.md §5](device-firmware.md)). 교차 확인 — `elsa-fpga`(belle 의 PL 저장소)는 전 브랜치에서 **`xczu3cg`** 만 타깃한다(브랜치당 24~29건, `xc7a100tcsg324-1` 은 3건 잔존).

→ **belle 은 ZynqMP 내장 PL 단독**이고 외부 FPGA 는 없다. `scripts/fpga_dnw.sh`(`/sys/class/fpga_manager/fpga0/firmware`)·`belle-post.sh`(`fpgautil -b /userdata/fpga.bin`) 경로 하나로 일관된다.

> **다만 정확한 ZU 부품번호는 여전히 미확인이다.** 이 `.bin` 에는 part 문자열 헤더가 없어 IDCODE 만 남고, 우리는 Xilinx IDCODE 표로 대조하지 않았다. `0x04a42093` 을 "ZU3" 으로 읽은 [device-firmware.md §1](device-firmware.md) 의 서술은 **그쪽 주장이지 우리가 검증한 것이 아니다.** 확정 근거는 `elsa-fpga` 의 `xczu3cg` 쪽이다.

## 4. 주변장치

| 버스·장치 | 내용 |
|---|---|
| **I2C1** (400 kHz) | **TI INA231 전력 모니터 2개** — `@0x40`, `@0x41` |
| **I2C0** (100 kHz) | `belle-msp` MSP430 과의 링크(MCU 가 슬레이브 `0x48`) |
| **SPI1** | `spidev` 2채널(CS0·CS1). `compatible = "rohm,dh2228fv"` 는 spidev 노출용 관용 표기 |
| **QSPI** | §2 |
| **SDHCI 0·1** | SD 슬롯 2개 |
| **GPIO** | 전원 버튼 `sw19`(GPIO 23, keycode 108, **wakeup 소스**). PL·MSP430 인터럽트도 GPIO 40 경유 |
| **UART1** | **disabled** — 콘솔로 쓰지 않는다 |
| WiFi | Marvell SDIO (`modules/wifi/mrvl` 의 `.ko`·펌웨어 바이너리) |
| BLE | `modules/ble/` (BlueZ 도구 프리빌트) |

`msp430@FF0A0000` 노드의 주소 `0xFF0A_0000` 은 ZynqMP **PS GPIO 컨트롤러 베이스**다 — MSP430 자체의 주소가 아니라 드라이버가 GPIO 를 통해 통신하는 구조로 보인다(추정).

## 5. 보조 MCU — MSP430FR2433

`belle-msp` 저장소가 담당한다. 초음파가 아니라 **전원·부팅 감독**이 역할이다.

| 기능 | 내용 |
|---|---|
| 전원 시퀀싱 | `IO_ENABLE`·`FPD_ENABLE`·`LPD_ENABLE`·`PS_POR_B` 제어 |
| 부팅 감독 | `CUR_BRINGUP_1_OK`(u-boot) · `CUR_BRINGUP_2_OK`(커널) 핸드셰이크. 타임아웃 시 `power_reset()` |
| 소프트웨어 워치독 | HW WDT 를 끄고, 호스트가 I2C 레지스터 `DEVICE_WATCHDOG_REG` 를 4 ms 주기로 갱신하는지 감시 |
| 배터리 | **MAX1720x 퓨얼게이지**(I2C `0x36`) 판독 → 호스트에 레지스터로 보고 |
| 표시 | RGB LED 드라이버(I2C `0x14`) |
| 버튼 | 짧게 = on/off, 길게(≈5초) = 팩토리 리셋 |

인터페이스가 **I2C 이중 역할**이다 — 하드웨어 I2C 슬레이브(주소 `0x48`)로 호스트에 레지스터 파일을 노출하고, 별도 **비트뱅잉 I2C 마스터**로 퓨얼게이지·LED 를 제어한다.

## 6. 초음파 프론트엔드

펌웨어 코드에서 역산한 것이다.

| 블록 | 근거 |
|---|---|
| **MAX2082** 아날로그 빔포머·AFE | `belle-fw/lib/fpga_ebi_max2082.cpp`, `configs/500l/max2082_reg.dat` |
| TX 펄서 | `lib/pulser.cpp`, `configs/500l/pulser_init_conf.dat` |
| TGC | `configs/500l/atgc*.dat`, `atgc_wait_time.dat` |
| 빔포밍 지연·개구 | `SA_Rx_dly_dlt_*.dat` · `SA_Tx_apo_dlt.dat` · `mux_table.dat` — **SA(합성개구) 방식** |
| 프로브 | **500L**(리니어). 컴파일 플래그 `_USING_500L_DEV_`·`_LINEAR_ARRAY` |
| 도플러 | CF 샘플링 40 MHz (`_CF_SAMPLE_40M_`) |

신호처리는 **소프트웨어에 있다** — 컬러 도플러(`lib/cf-doppler.c`, ARM NEON)·PW·M-mode 가 A53 에서 돈다. `image_proc/` 가 belle 세대에 추가되면서 영상 형성 일부도 장비로 넘어왔다.

## 7. 확인이 필요한 항목

| 항목 | 현재 상태 |
|---|---|
| **QSPI 플래시 실장 부품** | 주석의 `mt25ql02g`(256 MiB)가 유일한 단서. 부팅 로그의 `spi-nor: found ...` 로 확정 가능 |
| ~~**FPGA 개수·구성**~~ | **해소** — ZynqMP PL 단독(§3.1). 외부 Artix-7 은 300 시리즈 잔존물이었다 |
| **ZynqMP 정확한 부품번호** | `config` 에 없다. `es3_v00.01.00.xsa`(Vivado 핸드오프) 안에 있으나 원본 프로젝트가 없다. `elsa-fpga` 의 `xczu3cg` 가 가장 강한 단서이나 비트스트림 IDCODE(`0x04a42093`)를 Xilinx 표와 대조하지 않았다 |
| **보드 리비전 관계** | `HIT REV1.0`(DT) · `elsa-es3` · `elsa-pp` 세 표기의 대응 |
| **`auth` 파티션 사용처** | 정의만 있고 펌웨어 스크립트에서 접근 흔적 없음 |
| **회로도·BOM** | 없음. 위 내용은 전부 소프트웨어에서 역산한 것 |

## 8. HLAB-2487 함의

| 관측 | 함의 |
|---|---|
| rootfs 가 initramfs(RAM) | 앱을 별도 오버레이로 매 부팅 복사해야 하는 구조가 여기서 나온다. 리팩토링 시 이 전제를 유지할지가 갈림길 |
| 커널·앱 A/B 이중 뱅크 | **롤백 가능한 업그레이드 구조가 이미 있다.** 300 시리즈의 통짜 재플래시보다 개선된 자산 |
| 플래시 118 MiB 에 앱 뱅크는 10 MiB | 앱 크기 상한이 낮다. 기능 추가 여력이 제한적이다 |
| `.xsa` 원본 Vivado 프로젝트 부재 | **하드웨어 변경 대응 불가.** PL 설계를 못 바꾼다 |
| 회로도·BOM 부재 | HW 관련 판단은 전부 코드 역산에 의존한다. 반입 시 요청 목록에 포함해야 한다 |
