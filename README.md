# OpenWrt Xiaomi AX6000 (AIOT) — QCA9887 PCIe Rework

## Project Goal

Enable the QCA9887 WiFi radio (connected via 1-lane PCIe) on OpenWrt for the Xiaomi AX6000 AIOT (RA72) router.

The upstream OpenWrt commit [d7f9e240c208](https://github.com/openwrt/openwrt/commit/d7f9e240c208891a7d26d7a1d308cabd70618cae) explicitly disables this PCIe controller with the comment:
> "although the pcie1 phy probes successfully, the controller is unable to bring it up"

This project collects stock firmware data and proposes fixes.

## Hardware

| Component | Details |
|---|---|
| Router | Xiaomi AX6000 AIOT (internal model RA72) |
| SoC | Qualcomm IPQ5018 v1.1 |
| Flash | NAND, UBI |
| WiFi 0 | IPQ5018 built-in (c000000.wifi), 802.11ax |
| WiFi 1 | QCN9024 (PCIe x2, 17cb:1104), 802.11ax 5GHz |
| WiFi 2 | QCA9887 (PCIe x1, 168c:0050), 802.11ac 2.4GHz mesh/AIoT |
| PCIe RC0 | 0x80000000, 1-lane, phy@7e000, PERST GPIO 18 |
| PCIe RC1 | 0xa0000000, 2-lane, phy@86000+86800, PERST GPIO 15 |

## Repository Contents

```
├── README.md                  # This file
├── pcie_analysis.md           # Detailed PCIe analysis (stock vs OpenWrt comparison)
├── TECHNICAL_ROADMAP.md       # Fix strategy and technical approaches
├── stock_data/
│   ├── stock_full_dump.txt    # Comprehensive register/config dump (9714 lines)
│   ├── stock_devicetree.dts   # Decompiled stock firmware device tree (2490 lines)
│   ├── stock_dtb.bin          # Raw stock firmware DTB binary
│   ├── art_full.bin           # WiFi calibration data (ART partition, 1MB)
│   ├── bdata.bin              # Board data partition (512KB)
│   ├── extra_info.txt         # dmesg, lsmod, clock tree, GPIO, regulator info
│   └── collect_all.sh         # Data collection script used on stock firmware
└── patches/                   # (future) OpenWrt patches
```

## Key Findings

1. **Both PCIe links work under stock firmware** — QCA9887 link is up and functional
2. **PERST GPIO polarity mismatch** — Stock uses GPIO 15 as active-HIGH for x2 controller, OpenWrt DTS uses active-LOW
3. **PHY register init matches** — Upstream driver programs same values as stock firmware
4. **CDR_CTRL_REG_7 (0x98) not programmed** — Different between x1 (0x1A8) and x2 (0x008), upstream driver skips it
5. **DTS typo** — OpenWrt has `status = "disbled"` (missing 'a')

## OpenWrt Version

- OpenWrt 25.12.2 stable (2026-03-26)
- Target: qualcommax/ipq50xx
- Kernel: 6.12

## Stock Firmware

- Version: 1.0.122
- Kernel: 4.4.60 (aarch64)
- DT compatible: "qcom,ipq5018-mp03.1", "qcom,ipq5018"
