# Conclusion — Xiaomi AX6000 QCA9887 rework, upstream-ready

Date: 2026-04-22

## Status

**DONE (ready for upstream PR):**

1. Hardware rework verified end-to-end on the target unit:
   - 3 radios enumerate: phy0 = QCA9887 (ath10k / PCIe1), phy1 = IPQ5018
     (ath11k AHB), phy2 = QCN9024 (ath11k_pci / PCIe0)
   - All three carry live open-encryption APs on distinct channels
     (36 / 6 / 149). Full RF evidence in [VALIDATION_REPORT.md](VALIDATION_REPORT.md).

2. Upstream-ready patch prepared and build-verified against current
   `openwrt.git main` (kernel 6.12.80):
   - Single commit, +2/-6 lines in
     `target/linux/qualcommax/dts/ipq5018-ax6000.dts`
   - `&pcie1 status = "disabled"` → `"okay"`
   - `&pcie1 perst-gpios` flag `GPIO_ACTIVE_LOW` → `GPIO_ACTIVE_HIGH`
   - All QCA9887 scaffolding (`wifi@0,0` ath10k node, `caldata_qca9889`
     nvmem cell, `&pcie1_phy` okay, image-side
     `kmod-ath10k-ct-smallbuffers` + `ath10k-firmware-qca9887-ct`) is
     **already in mainline** — the DTS was the only missing piece.

3. Build-level A/B proof that the patch does only what it claims:
   - Both branches (`upstream-ax6000-prepatch` and
     `upstream-ax6000-pcie1`) compiled cleanly with
     `make -j6 target/linux/{clean,compile,install} V=s`
   - Decompiled DTBs differ by exactly 4 lines (the two property
     changes) and nothing else.
   - Artifacts preserved in [upstream_patch/](upstream_patch/):
     [dtb_pre.dts](upstream_patch/dtb_pre.dts),
     [dtb_post.dts](upstream_patch/dtb_post.dts),
     [dtb_diff.txt](upstream_patch/dtb_diff.txt).

## What was NOT done (deferred, with reason)

* **On-hardware A/B sysupgrade of the two freshly built images.**
  Authorized by the user, but execution was interrupted by the
  workspace transfer. The router is currently running stock OpenWrt
  25.12.2 with only 2 phys — which happens to match the "pre-patch"
  expectation already. The hardware-level validation in
  [VALIDATION_REPORT.md](VALIDATION_REPORT.md) (3 phys, ath10k firmware
  loaded, PCIe1 link up, QCA9887 enumerated at PCI 168c:0050) was
  produced on an earlier custom build with the same DTS fix, so the
  patched-side behaviour is already empirically known.

* **Replacing placeholder `Signed-off-by` in the patch with a real
  identity.** See [upstream_patch/SUBMISSION_CHECKLIST.md](upstream_patch/SUBMISSION_CHECKLIST.md)
  §2.1 for the exact `git commit --amend --reset-author -s` recipe.

## Next steps after PC transfer

1. Set real `git config user.name/email` in `~/fun/openwrt`, re-author
   the commit on branch `upstream-ax6000-pcie1`, regenerate
   [upstream_patch/0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch](upstream_patch/0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch).
2. Optionally redo the hardware A/B sysupgrade test with the two
   squashfs-sysupgrade images (script it, two flashes, one reboot each,
   capture `iw dev` + relevant dmesg).
3. Run `checkpatch.pl`, `git am` dry-run on a fresh clone of
   `openwrt.git`, then `git send-email` to
   `openwrt-devel@lists.openwrt.org` (Cc the recent qualcommax
   maintainers listed in the checklist).

## Key files for the new PC

| File | Purpose |
|---|---|
| [upstream_patch/0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch](upstream_patch/0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch) | The upstream PR patch (single commit) |
| [upstream_patch/SUBMISSION_CHECKLIST.md](upstream_patch/SUBMISSION_CHECKLIST.md) | OpenWrt submission rules + must-do items |
| [upstream_patch/dtb_diff.txt](upstream_patch/dtb_diff.txt) | 4-line whole-DTB diff proving minimal impact |
| [upstream_patch/dtb_pre.dts](upstream_patch/dtb_pre.dts) / [dtb_post.dts](upstream_patch/dtb_post.dts) | Decompiled compiled DTBs |
| [VALIDATION_REPORT.md](VALIDATION_REPORT.md) | 699-line triple-radio RF evidence |
| [patches/](patches/) | Local (rework-repo) patch history |
| [pcie_analysis.md](pcie_analysis.md) / [TECHNICAL_ROADMAP.md](TECHNICAL_ROADMAP.md) | Background investigation notes |

## Key findings worth carrying forward

* On Qualcomm IPQ50xx, `perst-gpios` polarity flags in OpenWrt DTS
  **must match the stock DTB flag byte exactly** (0x00 = `GPIO_ACTIVE_HIGH`,
  0x01 = `GPIO_ACTIVE_LOW`). This was the entire root cause for PCIe1
  being marked "unbringable" upstream.
* The upstream OpenWrt tree has already moved per-device DTS files to
  `target/linux/qualcommax/dts/<device>.dts` (commit `a66e30631c`);
  old rework patches under `.../files/arch/arm64/boot/dts/qcom/` no
  longer apply to main.
* Stock Xiaomi firmware stores ath10k QCA9887 calibration in the
  `0:art` partition at offset `0x4d000`, length `0x844`, exposed as
  nvmem cell `caldata_qca9889` — already wired up upstream.
