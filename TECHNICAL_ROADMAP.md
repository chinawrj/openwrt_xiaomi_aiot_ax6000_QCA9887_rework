# Technical Roadmap — QCA9887 PCIe Fix

## Problem Statement

On OpenWrt for Xiaomi AX6000 AIOT, the 1-lane PCIe controller (pcie1 @ 0x80000000) connected to QCA9887
fails to establish a link, despite the PHY probing successfully. The stock firmware has no such issue.

## Analysis Summary

### What Works in Stock Firmware
- PHY@7e000 (1-lane) initializes and reports link up
- PHY@86000 (2-lane) initializes and reports link up
- Both QCA9887 and QCN9024 are enumerated and functional
- dmesg shows: `qcom-pcie 80000000.pci: link up` within 0.47s of boot

### What OpenWrt DTS Currently Does
- pcie1 (0x80000000, x1, QCA9887): **disabled** (`status = "disbled"` — typo)
- pcie0 (0xa0000000, x2, QCN9024): enabled, working
- pcie1_phy: enabled, probes successfully
- Comment: "controller is unable to bring it up"

---

## Fix Approaches (Ordered by Likelihood)

### Approach 1: PERST GPIO Polarity Fix (HIGH PRIORITY)

**Finding**: Stock firmware DTS shows:
```
pci@a0000000: perst-gpio = <&tlmm 15 0x01>  ← GPIO_ACTIVE_HIGH
```

OpenWrt DTS has:
```
&pcie0: perst-gpios = <&tlmm 15 GPIO_ACTIVE_LOW>
```

This is a polarity mismatch for the x2 controller's PERST. While this affects pcie0 (not pcie1),
it may cause initialization timing issues that affect the shared clock/reset infrastructure.

**For pcie1 (x1):** Stock = `GPIO 18, 0x00 (active-low)`, OpenWrt = `GPIO 18, GPIO_ACTIVE_LOW` → **matches**.

**Action**: Fix pcie0 PERST polarity, then try enabling pcie1.

### Approach 2: Simply Enable pcie1 (Quick Test)

**Rationale**: The DTS has `status = "disbled"` (a typo for "disabled"). It's possible nobody
has tested it recently with the current kernel (6.12) and upstream pcie-qcom driver improvements.

**Action**:
```dts
&pcie1 {
    status = "okay";
    perst-gpios = <&tlmm 18 GPIO_ACTIVE_LOW>;
    
    wifi@0,0 {
        reg = <0x10000 0 0 0 0>;
        compatible = "pci168c,0050";
    };
};
```

### Approach 3: PCIe Controller Driver Investigation

**Key observations from stock DTS vs upstream:**

| Aspect | Stock | OpenWrt (upstream) |
|---|---|---|
| reg regions | 5 (dbi, elbi, dm_iatu, parf, config) | 6 (+mhi) |
| clock-names[0] | `sys_noc` | `iface` (renamed) |
| force_gen2 | `<1>` property | `max-link-speed = <2>` |
| pcie_x1_rp child | present | absent |
| qcom,msi-gicm-addr | `<0xb00a040>` | not present (uses standard MSI) |
| qcom,msi-gicm-base | `<0x1c0>` | not present |

The upstream `pcie-qcom.c` driver for IPQ5018 variant may have differences in:
- Link training sequence / timing
- PARF register initialization
- Clock gate control

**Action**: Compare PARF register values between stock running state and what upstream driver programs.
We have the full PARF dump in `stock_data/stock_full_dump.txt`.

### Approach 4: PHY Register Patching

**CDR_CTRL_REG_7 (offset 0x98)**:
- PHY@7e000 (x1): `0x01A8` — stock running value
- PHY@86000 (x2): `0x0008` — stock running value
- Upstream driver: **does not program this register**

This register may be critical for proper CDR (Clock Data Recovery) operation in 1-lane mode.
The significant difference (0x1A8 vs 0x008) between x1 and x2 PHYs suggests lane-count-specific tuning.

**SSCG_CTRL_REG_6 (offset 0xb0)**:
- PHY@7e000 (x1): `0xFEE7`
- PHY@86000 (x2): `0xFA60`
- Upstream driver: **does not program this register**

**Action**: If other approaches fail, try adding these register writes to the PHY driver:
```c
/* In phy-qcom-uniphy-pcie-28lp.c, after existing init_seq */
if (phy->lanes == 1) {
    writel(0x01a8, phy->base + 0x98);  /* CDR_CTRL_REG_7 for x1 */
}
```

### Approach 5: Clock/Reset Sequencing

Stock firmware clock tree shows both PCIe subsystems fully clocked:
```
gcc_pcie1_pipe_clk: enable_cnt=2, 125MHz
gcc_pcie1_aux_clk: enable_cnt=1, 2MHz
```

However, the stock dump didn't show pcie1 AXI clocks explicitly in the clock summary,
which could indicate they're managed differently.

**Action**: After booting OpenWrt, check if pcie1 clocks are enabled:
```sh
cat /sys/kernel/debug/clk/clk_summary | grep pcie1
```

### Approach 6: Power Sequencing / Regulator

Stock firmware uses dummy regulators for all PCIe power supplies:
```
vdda → regulator-dummy
vdda_phy → regulator-dummy  
vdda_refclk → regulator-dummy
```

This means power is hardwired/always-on. The upstream driver expects regulator properties.
If the regulators are absent from the DTS, the driver might fail silently.

**Action**: Add dummy fixed regulators to the board DTS if not already present.

---

## Execution Plan

### Phase 1: Minimal DTS Fix
1. Fix `status = "disbled"` → `status = "okay"` for pcie1
2. Fix PERST GPIO polarity for pcie0 (GPIO 15: active-low → active-high)  
3. Build custom OpenWrt image or apply DTS overlay
4. Boot and check dmesg

### Phase 2: Debug Link Training
If Phase 1 doesn't work:
1. Read PARF registers via devmem after OpenWrt boot
2. Compare with stock PARF dump
3. Check PCIe link status register (DBI + 0x80)
4. Enable verbose PCIe debug: `echo 8 > /proc/sys/kernel/printk`

### Phase 3: Driver Patches
If link still fails:
1. Add CDR_CTRL_REG_7 write to PHY driver
2. Investigate PARF init differences
3. Check if `pcie_x1_rp` child node is needed
4. Consider MSI-GICM configuration

### Phase 4: Upstream Submission
Once working:
1. Clean up patches
2. Test stability
3. Submit to OpenWrt mailing list / GitHub

---

## Key Register Addresses (for debugging)

| Register | Address | Purpose |
|---|---|---|
| PHY@7e000 CDR_CTRL_REG_7 | 0x7e098 | CDR tuning (x1 specific?) |
| PHY@7e000 SSCG_CTRL_REG_4 | 0x7e0a8 | PLL lock status (bit15) |
| PARF0 base | 0x78000 | PCIe x1 controller config |
| DBI0 base | 0x80000000 | PCIe x1 DBI space |
| DBI0 LINK_STATUS | 0x80000080 | Link control/status |
| GCC_PCIE1_PIPE_CBCR | 0x1829018 | Pipe clock enable |
| GCC_PCIE1_AXI_M_CBCR | 0x1829004 | AXI master clock |
| GCC_PCIE1_BCR | 0x1829000 | PCIe1 block reset |
| TLMM GPIO 18 CFG | 0x1012000 | PERST GPIO config |
| TLMM GPIO 15 CFG | 0x100F000 | PERST GPIO config |

## References

- OpenWrt commit: [d7f9e240c208](https://github.com/openwrt/openwrt/commit/d7f9e240c208891a7d26d7a1d308cabd70618cae)
- DTS: `target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ax6000.dts`
- dtsi: `arch/arm64/boot/dts/qcom/ipq5018.dtsi`
- PHY driver: `drivers/phy/qualcomm/phy-qcom-uniphy-pcie-28lp.c`
- PCIe driver: `drivers/pci/controller/dwc/pcie-qcom.c`
