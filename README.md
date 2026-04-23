# OpenWrt Xiaomi AX6000 (AIOT) — QCA9887 PCIe Rework

**Status:** 🎉 **MERGED UPSTREAM — [openwrt/openwrt#23047](https://github.com/openwrt/openwrt/pull/23047) merged by @robimarko as commit [`6cbb072b57e9`](https://github.com/openwrt/openwrt/commit/6cbb072b57e9d72d07097902d975f8a13b768e72) on `main`. Project complete.**

> Backport to the `openwrt-25.12` release branch was requested by @georgemoussalem (the original AX6000 submitter) and is pending at @robimarko. Once merged there, users on stable OpenWrt 25.12.x will get 3-radio support for the Xiaomi AX6000 AIOT out of the box.

## Project Goal

Enable the QCA9887 WiFi radio (connected via 1-lane PCIe1) on OpenWrt for the Xiaomi AX6000 AIOT (RA72) router, turning it into a true tri-radio device.

The upstream OpenWrt commit [`d7f9e240c208`](https://github.com/openwrt/openwrt/commit/d7f9e240c208891a7d26d7a1d308cabd70618cae) (initial AX6000 support) explicitly disabled PCIe1 with the comment:

> "although the pcie1 phy probes successfully, the controller is unable to bring it up"

Root cause turned out to be a **single `perst-gpios` polarity flag mismatch** against the stock Xiaomi device-tree, not a hardware/controller issue.

## Result

| Radio | Bus | Driver | Band | Status |
|---|---|---|---|---|
| IPQ5018 built-in | AHB (`c000000.wifi`) | `ath11k` | 2.4 GHz | ✅ AP up, ch 6, HE20 |
| QCN9024 | PCIe0 (2-lane) | `ath11k_pci` | 5 GHz | ✅ AP up, ch 149, HE80 |
| **QCA9887** | **PCIe1 (1-lane)** | **`ath10k_pci`** | **5 GHz** | **✅ AP up, ch 36, VHT80 (this fix)** |

Full RF / dmesg / `iw dev` / `ubus` evidence: [VALIDATION_REPORT.md](VALIDATION_REPORT.md) and the [PR comment](https://github.com/openwrt/openwrt/pull/23047#issuecomment-4296313093).

## The Fix

A 2-line change in `target/linux/qualcommax/dts/ipq5018-ax6000.dts`:

```diff
 &pcie1 {
-    /*
-     * although the pcie1 phy probes successfully, the controller is unable
-     * to bring it up. So let's disable it until a solution is found.
-     */
-    status = "disabled";
+    status = "okay";
 
-    perst-gpios = <&tlmm 18 GPIO_ACTIVE_LOW>;
+    perst-gpios = <&tlmm 18 GPIO_ACTIVE_HIGH>;
```

Everything else needed (ath10k `wifi@0,0` node, `caldata_qca9889` nvmem cell, PCIe1 phy node, `kmod-ath10k-ct-smallbuffers` + `ath10k-firmware-qca9887-ct` in the image recipe) was **already upstream**. The DTS was the only missing piece.

### Scope

The change is strictly scoped to `xiaomi_ax6000`. No other OpenWrt device is affected:
- No other DTS `#include`s `ipq5018-ax6000.dts`
- No other image recipe references it
- `&pcie1 { ... }` override only applies inside this single board's final DTB

## Hardware

| Component | Details |
|---|---|
| Router | Xiaomi AX6000 AIOT (internal model RA72) |
| SoC | Qualcomm IPQ5018 v1.1 |
| Flash | NAND, UBI |
| WiFi 0 | IPQ5018 built-in (c000000.wifi), 802.11ax 2.4 GHz |
| WiFi 1 | QCN9024 on PCIe0 (17cb:1104), 802.11ax 5 GHz |
| WiFi 2 | QCA9887 on PCIe1 (168c:0050), 802.11ac 5 GHz |
| PCIe0 | 0xa0000000, 2-lane Gen2, PERST GPIO 15 (ACTIVE_HIGH) |
| PCIe1 | 0x80000000, 1-lane Gen1, PERST GPIO 18 (ACTIVE_HIGH ← was wrong) |

## Repository Contents

```
├── README.md                  # This file
├── CONCLUSION.md              # Final summary + upstream PR info
├── VALIDATION_REPORT.md       # 3-phy hardware validation report
├── pcie_analysis.md           # Detailed PCIe stock-vs-OpenWrt analysis
├── TECHNICAL_ROADMAP.md       # Fix strategy & investigation notes
├── build.sh                   # Local OpenWrt build helper
├── setup_dev.sh               # Dev environment bootstrap
├── debug_router.sh            # Router debug helpers (SSH/dmesg/PARF)
├── patches/                   # Early local patch history
├── upstream_patch/
│   ├── 0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch  # Final submitted patch
│   ├── SUBMISSION_CHECKLIST.md                                        # OpenWrt submission rules
│   ├── dtb_pre.dts / dtb_post.dts / dtb_diff.txt                      # DTB A/B proof
└── stock_data/
    ├── stock_full_dump.txt    # Comprehensive register/config dump
    ├── stock_devicetree.dts   # Decompiled stock firmware device tree
    ├── extra_info.txt         # dmesg, lsmod, clock tree, GPIO, regulators
    └── collect_all.sh         # Stock-firmware data-collection script
```

## Build & Test

```bash
# Build
cd ~/fun/openwrt
make -j6 V=s 2>&1 | tee /tmp/openwrt-build.log

# Flash
SRC=$(ls bin/targets/qualcommax/ipq50xx/*sysupgrade*.ubi | head -1)
scp -O "$SRC" root@192.168.1.1:/tmp/
ssh root@192.168.1.1 "setsid sh -c 'sysupgrade -n /tmp/$(basename $SRC) < /dev/null >/dev/null 2>&1 &'"
```

## Upstream PR

- **PR:** https://github.com/openwrt/openwrt/pull/23047 — **MERGED** (closed)
- **Title:** `qualcommax: ipq50xx: ax6000: enable pcie1 for QCA9887`
- **Author:** `chinawrj <chinawrj@gmail.com>` (DCO signed-off)
- **Branch:** [`chinawrj/openwrt-upstream:ax6000-pcie1-qca9887`](https://github.com/chinawrj/openwrt-upstream/tree/ax6000-pcie1-qca9887)
- **Merge commit on `main`:** [`6cbb072b57e9d72d07097902d975f8a13b768e72`](https://github.com/openwrt/openwrt/commit/6cbb072b57e9d72d07097902d975f8a13b768e72)
- **Merged by:** @robimarko (qualcommax maintainer)
- **Lint:** `scripts/checkpatch.pl --no-tree` → 0 errors, 0 warnings, 0 checks
- **Backport request (25.12):** open, acknowledged by maintainers

### Review feedback

- @georgemoussalem (original AX6000 PR author): *“Great find, I didn’t have the device when I submitted the initial PR, thanks! This should also be backported to 25.12.”*
- @sund00bie: *“Wow. Amazing work!”*
- @robimarko: merged after review, no change requests.

## Key Findings

1. **PERST GPIO polarity** in OpenWrt DTS must match the stock DTB flag byte exactly (`0x00 = GPIO_ACTIVE_HIGH`, `0x01 = GPIO_ACTIVE_LOW`). Stock used `ACTIVE_HIGH` on GPIO 18; OpenWrt had `ACTIVE_LOW`, holding the card in reset — this was the entire root cause.
2. The upstream OpenWrt tree moved per-device DTS files to `target/linux/qualcommax/dts/<device>.dts` (commit `a66e30631c`); any older patches under `.../files/arch/arm64/boot/dts/qcom/` no longer apply.
3. QCA9887 calibration lives in the `0:art` MTD partition at offset `0x4d000`, length `0x844`, exposed as nvmem cell `caldata_qca9889` (already wired up upstream).

## Stock Firmware Reference

- Version: 1.0.122
- Kernel: 4.4.60 (aarch64)
- DT compatible: `qcom,ipq5018-mp03.1`, `qcom,ipq5018`

## OpenWrt Target

- `qualcommax/ipq50xx`
- Device `xiaomi_ax6000`
- Tested on main @ `379c7fc3a0` (kernel 6.12.80)

## License

Patch and documentation in this repo follow the OpenWrt project license (GPL-2.0). Stock firmware data is included under fair-use for interoperability analysis only.
