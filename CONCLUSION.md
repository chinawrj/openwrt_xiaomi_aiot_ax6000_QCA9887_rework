# Conclusion — Xiaomi AX6000 QCA9887 rework

**Status: ✅ COMPLETED — upstream PR open, milestone can be closed.**

Date: 2026-04-22

## Outcome

**Upstream PR:** [openwrt/openwrt#23047 — `qualcommax: ipq50xx: ax6000: enable pcie1 for QCA9887`](https://github.com/openwrt/openwrt/pull/23047)

- Single commit, +2/-6 lines in `target/linux/qualcommax/dts/ipq5018-ax6000.dts`
- `&pcie1 status` → `"okay"`
- `&pcie1 perst-gpios` flag → `GPIO_ACTIVE_HIGH` (was `ACTIVE_LOW`)
- Author `chinawrj <chinawrj@gmail.com>`, DCO signed-off
- `checkpatch.pl` clean (0 errors, 0 warnings, 0 checks)
- All style + labeling rules match OpenWrt conventions

## What works on the device

All three radios enumerate, load firmware, and beacon simultaneously on a reworked Xiaomi AX6000 AIOT:

| PHY | Driver | Interface | Channel | Mode | SSID |
|---|---|---|---|---|---|
| phy0 (QCA9887 / PCIe1) | `ath10k_pci` | `phy0-ap0` | 36 (5180 MHz) | VHT80 | `OpenWrt-QCA9887` |
| phy1 (IPQ5018 AHB) | `ath11k` | `phy1-ap0` | 6 (2437 MHz) | HE20 | `OpenWrt-IPQ5018` |
| phy2 (QCN9024 / PCIe0) | `ath11k_pci` | `phy2-ap0` | 149 (5745 MHz) | HE80 | `OpenWrt-QCN9024` |

Full verbatim router logs (dmesg, `iw dev`, `ubus`, PCI enumeration, firmware versions, calibration via nvmem) are attached to the PR as [comment #4296313093](https://github.com/openwrt/openwrt/pull/23047#issuecomment-4296313093) and in [VALIDATION_REPORT.md](VALIDATION_REPORT.md).

## Scope

Strictly scoped to `xiaomi_ax6000`:
- No other DTS `#include`s `ipq5018-ax6000.dts`
- No other image recipe references it
- `&pcie1` override only resolves inside this single board's final DTB

No regression risk for any other OpenWrt device.

## Root cause (one sentence)

The upstream DTS kept `&pcie1` disabled because the original `perst-gpios` flag was `GPIO_ACTIVE_LOW` (inverted vs stock Xiaomi DTB), which held the QCA9887 card in reset so the link never trained. Matching the stock flag (`GPIO_ACTIVE_HIGH`) was sufficient.

## Key findings worth carrying forward

- On Qualcomm IPQ50xx, `perst-gpios` polarity flags in OpenWrt DTS **must** match the stock DTB flag byte exactly (`0x00 = GPIO_ACTIVE_HIGH`, `0x01 = GPIO_ACTIVE_LOW`). This is how this entire project's root cause was diagnosed.
- Upstream moved per-device DTS files from `.../files/arch/arm64/boot/dts/qcom/` to `target/linux/qualcommax/dts/<device>.dts` (commit `a66e30631c`); older rework patches under the old path no longer apply.
- QCA9887 calibration on this device lives in the `0:art` MTD partition at offset `0x4d000`, length `0x844`, exposed as nvmem cell `caldata_qca9889` (already wired up upstream).
- New OpenWrt GitHub PRs get `target/qualcommax` label auto-applied; maintainers add the `Link:` trailer on merge — contributors should **not** pre-add it.

## Key artifacts

| File | Purpose |
|---|---|
| [upstream_patch/0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch](upstream_patch/0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch) | The submitted patch |
| [upstream_patch/dtb_diff.txt](upstream_patch/dtb_diff.txt) | Whole-DTB diff (4 lines) proving minimal impact |
| [upstream_patch/dtb_pre.dts](upstream_patch/dtb_pre.dts) / [dtb_post.dts](upstream_patch/dtb_post.dts) | Decompiled compiled DTBs |
| [upstream_patch/SUBMISSION_CHECKLIST.md](upstream_patch/SUBMISSION_CHECKLIST.md) | OpenWrt submission rules reference |
| [VALIDATION_REPORT.md](VALIDATION_REPORT.md) | 3-radio on-hardware validation report |
| [pcie_analysis.md](pcie_analysis.md) / [TECHNICAL_ROADMAP.md](TECHNICAL_ROADMAP.md) | Investigation notes |

## Milestone

**Closed.** Nothing remains on the project side — the outcome is now in the upstream reviewer queue.
