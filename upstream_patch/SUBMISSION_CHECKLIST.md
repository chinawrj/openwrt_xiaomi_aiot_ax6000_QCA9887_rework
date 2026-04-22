# OpenWrt upstream submission — Xiaomi AX6000 QCA9887 enable

This directory contains the final upstream patch and the checklist you must
complete before sending it to `openwrt-devel@lists.openwrt.org`.

---

## 1. The patch

[0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch](0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch)

* Generated from a branch based on `openwrt/main` (HEAD at fetch time:
  `a66e30631c qualcommax: move Device DTS to dedicated DTS directory`).
* Single commit, touches one file, +2 / -6 lines of actual DTS.
* Subject follows the observed `qualcommax: ipq50xx: <device>: <action>`
  convention used by recent ipq50xx commits (verified against `git log
  --format="%s" -30 FETCH_HEAD -- target/linux/qualcommax`).

### What the patch does

In `target/linux/qualcommax/dts/ipq5018-ax6000.dts`:

* removes the stale comment explaining why `&pcie1` was disabled
* flips `&pcie1 status` from `"disabled"` to `"okay"`
* changes `&pcie1 perst-gpios` flag from `GPIO_ACTIVE_LOW` to
  `GPIO_ACTIVE_HIGH`

Everything else needed for the QCA9887 (the `wifi@0,0` node with
`compatible = "qcom,ath10k"`, `qcom,ath10k-calibration-variant =
"Xiaomi-AX6000"`, the `caldata_qca9889` nvmem cell in the `0:art`
partition, the `&pcie1_phy status = "okay"`, and the image-side packages
`kmod-ath10k-ct-smallbuffers` + `ath10k-firmware-qca9887-ct` in
`target/linux/qualcommax/image/ipq50xx.mk`) is **already in mainline** —
OpenWrt merged the scaffolding long ago and only left the DTS bring-up
undone because the PERST polarity was wrong.

---

## 2. MUST-DO before sending

### 2.1 Replace the placeholder Signed-off-by

The patch currently contains:

```
From: YOUR NAME <your.email@example.com>
Signed-off-by: YOUR NAME <your.email@example.com>
```

You have to replace **both** occurrences with a real name + email that you
are willing to stand behind under the [Developer's Certificate of Origin
1.1](https://developercertificate.org/). This is mandatory — OpenWrt
rejects patches without a valid `Signed-off-by:`.

Easiest way:

```sh
cd ~/fun/openwrt
git checkout upstream-ax6000-pcie1
git config user.name  "Your Real Name"
git config user.email "you@example.org"
git commit --amend --reset-author --no-edit
# add a real Signed-off-by via a trailer
git commit --amend --no-edit -s   # '-s' appends Signed-off-by
# regenerate the patch:
git format-patch -1 --subject-prefix=PATCH \
   -o ~/fun/openwrt_xiaomi_aiot_ax6000_QCA9887_rework/upstream_patch/
```

### 2.2 Build test against current mainline

**DONE.** Both the unpatched upstream `main` (branch
`upstream-ax6000-prepatch` @ FETCH_HEAD) and the patched tree
(`upstream-ax6000-pcie1`) were built clean with

```sh
cd ~/fun/openwrt
git checkout <branch>
make -j6 target/linux/{clean,compile,install} V=s
```

against kernel 6.12.80. Zero errors in either log.

The only difference between the two **compiled** DTBs
(`build_dir/.../image-ipq5018-ax6000.dtb`) is:

```diff
--- dtb_pre.dts  (upstream, unpatched)
+++ dtb_post.dts (upstream + patch)
<  status = "disabled";
<  perst-gpios = <0x0b 0x12 0x01>;   /* tlmm, GPIO 18, ACTIVE_LOW */
---
>  status = "okay";
>  perst-gpios = <0x0b 0x12 0x00>;   /* tlmm, GPIO 18, ACTIVE_HIGH */
```

i.e. exactly the two lines the patch targets, nothing else changes.

Evidence saved in this directory:

* [dtb_pre.dts](dtb_pre.dts)  — decompiled DTB before the patch
* [dtb_post.dts](dtb_post.dts) — decompiled DTB after the patch
* [dtb_diff.txt](dtb_diff.txt) — the 4-line diff above

Build logs are at `/tmp/build_pre.log` and `/tmp/build_post.log`.

### 2.3 `checkpatch.pl` clean

Linux's `checkpatch.pl` is the canonical style checker for DT changes.

```sh
cd ~/fun/openwrt
./scripts/checkpatch.pl --no-tree --no-signoff \
   upstream_patch/0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch
```

(or run it from a Linux source tree — OpenWrt ships the same script under
`tools/`.) Must produce zero errors and zero warnings. Our patch only
changes two property values and removes a comment, so it should be clean.

### 2.4 Verify the patch applies on latest `main`

```sh
cd /tmp && rm -rf ow && git clone --depth=50 \
   https://git.openwrt.org/openwrt/openwrt.git ow
cd ow && git am ~/fun/openwrt_xiaomi_aiot_ax6000_QCA9887_rework/upstream_patch/0001-*.patch
```

`git am` must succeed without conflicts.

### 2.5 Runtime evidence

The mailing list reviewers will expect a short note about what was
tested. Point them at the triple-radio report already in this repo:

[../VALIDATION_REPORT.md](../VALIDATION_REPORT.md)

Key artefacts it contains:

* `dmesg` showing PCIe1 link-up, `ath10k_pci 0001:01:00.0: pci irq msi
  oper_irq_mode ...`, firmware `firmware-2.bin` loaded
* `iw phy phy0 info` showing QCA9887 channels 36..165
* 29-BSS scan result on phy0 proving RX works on real traffic
* Simultaneous `hostapd` `"status": "ENABLED"` on all three
  radios (phy0/phy1/phy2) on distinct channels (36 / 6 / 149)
* Calibration-variant / board-id strings loaded from the `0:art`
  partition via the `caldata_qca9889` nvmem cell

Paste a ~20-line distilled excerpt into the cover-letter or the commit
body if the maintainers ask.

---

## 3. OpenWrt submission rules — what must be true

These are the hard rules derived from the project's own
`CONTRIBUTING.md`, mailing-list etiquette and `git log` convention in the
mainline tree:

1. **One logical change per patch.** Our patch is a single self-contained
   bring-up change — good.
2. **Subject format**: `<target>: <subtarget>: <device>: <summary>` (lower
   case, short, imperative). Our subject follows this.
3. **Commit body**: wrap at ~72 chars, explain *why* (motivation) not
   *what* (the diff already says what). Must reference the hardware.
4. **`Signed-off-by:` trailer** with a real identity (DCO 1.1). See 2.1.
5. **No other trailers** unless they are real (`Tested-by:`,
   `Reviewed-by:`, `Fixes:` with a 12-char SHA + oneline). Don't invent
   them.
6. **Rebased on current `main`.** No merge commits, no "wip", no
   "refresh" noise.
7. **`git format-patch`**, not `git diff`. The file must carry `From:`,
   `Date:`, a Message-Id and a `-- \n2.x.y` footer. (This file already
   does.)
8. **Send with `git send-email`** to `openwrt-devel@lists.openwrt.org`.
   Do NOT attach the patch, do NOT use any HTML client. GitHub PRs are
   also accepted now but the mailing list is still the canonical path
   for core-target DTS changes.
9. **Subject prefix** `[PATCH]` (single patch) or `[PATCH v2]` on
   re-spin after review feedback.
10. **No trailing whitespace, no tabs-vs-spaces mix, no CRLF**, no
    reordering of unrelated lines. We only edited inside a single
    `&pcie1 { ... }` block — good.

---

## 4. Suggested send command

Once 2.1–2.4 are done:

```sh
cd ~/fun/openwrt
git send-email \
    --to="openwrt-devel@lists.openwrt.org" \
    --cc="robimarko@gmail.com" \
    --cc="ansuelsmth@gmail.com" \
    ~/fun/openwrt_xiaomi_aiot_ax6000_QCA9887_rework/upstream_patch/0001-qualcommax-ipq50xx-ax6000-enable-pcie1-for-QCA9887.patch
```

(`robimarko` and `ansuelsmth` are the two most active qualcommax
maintainers in recent `git log --format="%an" -30 -- target/linux/qualcommax`
— confirm against `git shortlog -s -n --since=6.months -- target/linux/qualcommax`
before sending so the Cc list is current.)

---

## 5. Responding to review

* Respin as `[PATCH v2]` (via `git format-patch -v2`) with a changelog
  **below the `---` line**, e.g.

  ```
  ---
  v2:
    - rewrap commit body per Robert's comment
    - drop unrelated whitespace
  ```

* Do **not** rewrite history between versions in a way that loses the
  `Signed-off-by:` — just amend and reformat.

---

## 6. Non-blocking follow-ups (out of scope for this PR)

Documented in `../VALIDATION_REPORT.md` §8:

* QCA9887 runs without a `Xiaomi-AX6000` entry in `board-2.bin` — falls
  back to the generic board data. Works fine; could be a separate
  firmware-data contribution later.
* ath10k in monitor mode returns `-95 dBm` fixed signal. ath10k driver
  quirk, not a hardware issue; station and AP scans read correct
  RSSI. Not relevant to this patch.
