# Xiaomi AX6000 (AIOT) PCIe Analysis — Stock vs OpenWrt

## Device Summary
- **Model**: Xiaomi AX6000 (AIOT), internal model RA72
- **SoC**: Qualcomm IPQ5018, SoC Version 1.1
- **DT compatible**: "qcom,ipq5018-mp03.1", "qcom,ipq5018"
- **Stock firmware**: 1.0.122, kernel 4.4.60 aarch64
- **OpenWrt**: 25.12.2 stable, target qualcommax/ipq50xx, kernel 6.12

## PCIe Hardware Topology

| Controller | Base Address | Lanes | PHY | PHY Address | PERST GPIO | WiFi Chip | PCI ID | Domain |
|---|---|---|---|---|---|---|---|---|
| RC0 (pci@80000000) | 0x80000000 | x1 | phy@7e000 | 0x7e000 | GPIO 18 (active low) | QCA9887 | 168c:0050 | 0 (stock) / 1 (OpenWrt) |
| RC1 (pci@a0000000) | 0xa0000000 | x2 | phy@86000 | 0x86000+0x86800 | GPIO 15 (active high) | QCN9024 | 17cb:1104 | 1 (stock) / 0 (OpenWrt) |

## Stock Firmware Status
**Both PCIe links come up successfully:**
```
[0.469906] qcom-pcie 80000000.pci: link up    ← QCA9887 (x1) WORKS
[0.719923] qcom-pcie a0000000.pci: link up    ← QCN9024 (x2) WORKS
```

**WiFi radios:**
- wifi0 → c000000.wifi (IPQ5018 built-in, 802.11abgn/ax)
- wifi1 → 0001:01:00.0 (QCN9024, 17CB:1104, 802.11an/ac/ax, 5GHz)
- wifi2 → 0000:01:00.0 (QCA9887, 168C:0050, 802.11abgn/ac, 2.4GHz mesh)

## OpenWrt DTS Status
**In `ipq5018-ax6000.dts`:**
- `&pcie0` (a0000000, x2, QCN9024): `status = "okay"` ✅
- `&pcie1` (80000000, x1, QCA9887): `status = "disbled"` ❌ (note: typo "disbled")
  - Comment: "although the pcie1 phy probes successfully, the controller is unable to bring it up"

## Detailed Comparison

### 1. PHY Nodes

#### phy@7e000 (1-lane, for QCA9887)
| Property | Stock DT | OpenWrt dtsi |
|---|---|---|
| compatible | `qca,uni-pcie-phy-gen2` | `qcom,ipq5018-uniphy-pcie-phy` |
| reg | 0x7e000, size 0x800 | 0x7e000, size 0x800 |
| clocks | GCC clock 0xc3 (pipe_clk) | `GCC_PCIE1_PIPE_CLK` |
| resets | GCC reset 0x2f, 0x30 | `GCC_PCIE1_PHY_BCR`, `GCC_PCIE1PHY_PHY_BCR` |
| clock-names | `pipe_clk` | (uses devm_clk_bulk_get_all) |
| reset-names | `phy`, `phy_phy` | (uses reset_control_array) |
| mode_fixed | 2 | N/A (not in upstream driver) |
| phy-type | `gen2` | N/A (hardcoded as PHY_TYPE_PCIE_GEN2) |
| num-lanes | N/A (implicit) | 1 |
| #clock-cells | N/A | 0 (acts as pipe_clk_src provider) |
| status | `ok` | `disabled` (enabled by board DTS) |

#### phy@86000 (2-lane, for QCN9024)
| Property | Stock DT | OpenWrt dtsi |
|---|---|---|
| compatible | `qca,uni-pcie-phy-gen2` | `qcom,ipq5018-uniphy-pcie-phy` |
| reg | 0x86000+0x86800, 2×0x800 | 0x86000, size 0x1000 |
| clocks | GCC clock 0xc2 (pipe_clk) | `GCC_PCIE0_PIPE_CLK` |
| resets | GCC reset 0x23, 0x24 | `GCC_PCIE0_PHY_BCR`, `GCC_PCIE0PHY_PHY_BCR` |
| x2 | 1 | N/A (num-lanes=2 instead) |
| num-lanes | N/A | 2 |
| status | `ok` | `disabled` (enabled by board DTS) |

### 2. PCIe Controller Nodes

#### pci@80000000 (1-lane, QCA9887)
| Property | Stock DT | OpenWrt dtsi (pcie1) |
|---|---|---|
| compatible | `qcom,pcie-ipq5018` | `qcom,pcie-ipq5018` |
| reg-names | dbi, elbi, dm_iatu, parf, config (5 regs) | dbi, elbi, atu, parf, config, mhi (6 regs) |
| parf | 0x78000, size 0x3000 | 0x78000, size 0x3000 |
| mhi | N/A | 0x7b000, size 0x1000 |
| num-lanes | 1 | 1 |
| force_gen2 | 1 | N/A (uses `max-link-speed = <2>`) |
| perst-gpio | GPIO 18, active low | `<&tlmm 18 GPIO_ACTIVE_LOW>` |
| clock-names | sys_noc, axi_m, axi_s, ahb, aux, axi_bridge | iface, axi_m, axi_s, ahb, aux, axi_bridge |
| linux,pci-domain | 0 | 1 |
| status | `ok` | `disabled` ("disbled") |

#### pci@a0000000 (2-lane, QCN9024)
| Property | Stock DT | OpenWrt dtsi (pcie0) |
|---|---|---|
| num-lanes | 2 | 2 |
| parf | 0x80000, size 0x3000 | 0x80000, size 0x3000 |
| mhi | N/A | 0x83000, size 0x1000 |
| perst-gpio | GPIO 15, active high | `<&tlmm 15 GPIO_ACTIVE_LOW>` ← **POLARITY DIFFERENCE!** |
| linux,pci-domain | 1 | 0 |
| status | `ok` | `okay` |

### 3. PHY Register Values (captured from running stock firmware via devmem)

| Register | Offset | PHY@7e000 (x1) | PHY@86000 (x2 lane0) | Upstream driver writes |
|---|---|---|---|---|
| CDR_CTRL_REG_1 | 0x80 | 0x0200 | 0x0200 | 0x200 ✅ |
| CDR_CTRL_REG_2 | 0x84 | 0x0419 | 0x0419 | 0x419 ✅ |
| CDR_CTRL_REG_3 | 0x88 | 0xFDBF | 0xFDBF | not programmed |
| CDR_CTRL_REG_4 | 0x8c | 0x03F9 | 0x03F9 | 0x3f9 ✅ |
| CDR_CTRL_REG_5 | 0x90 | 0x01C9 | 0x01C9 | 0x1c9 ✅ |
| CDR_CTRL_REG_6 | 0x94 | 0x0000 | 0x0000 | not programmed |
| CDR_CTRL_REG_7 | 0x98 | **0x01A8** | **0x0008** | not programmed ⚠️ |
| SSCG_CTRL_REG_1 | 0x9c | 0x0001 | 0x0001 | 0x1 ✅ |
| SSCG_CTRL_REG_2 | 0xa0 | 0x00EB | 0x00EB | 0xeb ✅ |
| SSCG_CTRL_REG_3 | 0xa4 | 0xD360 | 0xD360 | 0xd360 ✅ |
| SSCG_CTRL_REG_4 | 0xa8 | 0x9CB9 | 0x9CB9 | 0x1cb9 (bit15=PLL lock) |
| SSCG_CTRL_REG_5 | 0xac | 0x023A | 0x023A | 0x23a ✅ |
| SSCG_CTRL_REG_6 | 0xb0 | **0xFEE7** | **0xFA60** | not programmed ⚠️ |
| PHY_CFG_PLLCFG | 0x220 | 0x0000 | 0x0000 | not programmed |
| PCS_INTERNAL_CONTROL_2 | 0x2d8 | 0xF101 | 0xF101 | 0xf101 ✅ |
| PHY_CFG_EIOS_DTCT | 0x3e4 | 0x0000 | 0x00C4 | not programmed |
| PHY_CFG_GEN3_ALIGN | 0x3e8 | 0x0000 | 0x0022 | not programmed |

### 4. Clock Tree (Stock Firmware)

Both PCIe controllers have all clocks enabled:
```
pcie20_phy0_pipe_clk (enable=1) → pcie0_pipe_clk_src (enable=1) → gcc_pcie0_pipe_clk (enable=2)  [x2]
pcie20_phy1_pipe_clk (enable=1) → pcie1_pipe_clk_src (enable=1) → gcc_pcie1_pipe_clk (enable=2)  [x1]
pcie0_aux_clk_src (enable=1) → gcc_pcie0_aux_clk (enable=1)  [x2]
pcie1_aux_clk_src (enable=1) → gcc_pcie1_aux_clk (enable=1)  [x1]
pcie0_axi_clk_src (enable=4) → gcc_pcie0_axi_m_clk, gcc_pcie0_axi_s_clk, etc  [x2]
```

### 5. GPIO State (Stock Firmware)
```
gpio15 : out 0 2mA pull down    ← PCIe RC1 (x2) PERST for QCN9024
gpio18 : out 0 2mA pull down    ← PCIe RC0 (x1) PERST for QCA9887
```
Both PERST GPIOs are output low (deasserted for active-low PERST).

### 6. Regulators
Stock uses dummy regulators for all three supplies per controller:
- `vdda` → regulator-dummy
- `vdda_phy` → regulator-dummy
- `vdda_refclk` → regulator-dummy

This means the power is always-on / hardwired. No external regulator GPIOs needed.

## Potential Root Causes for PCIe1 (x1, QCA9887) Failure

### Hypothesis 1: PERST GPIO polarity for pcie0 (x2)
Stock DT shows `perst-gpio` for pci@a0000000: `GPIO 15, active HIGH (0x01)`.
OpenWrt DTS has `perst-gpios = <&tlmm 15 GPIO_ACTIVE_LOW>`.
**This polarity difference is for pcie0 (x2), not pcie1 (x1).** But it's worth noting.

For pcie1 (x1, QCA9887): both stock and OpenWrt agree on GPIO 18, active low.

### Hypothesis 2: PCIe controller cannot establish link
The PHY probes OK, but the PCIe controller can't bring up the link.
This could be caused by:
- Incorrect link training timeout
- Missing or wrong clock configuration
- PCIe PARF register misconfiguration for 1-lane mode

### Hypothesis 3: Missing PHY registers
The upstream driver doesn't program CDR_CTRL_REG_7 (0x98) and SSCG_CTRL_REG_6 (0xb0).
Stock has **0x1A8** at 0x98 for the x1 PHY vs **0x008** for x2.
These may be critical for proper SERDES operation in 1-lane mode.

### Hypothesis 4: PCI domain swap
Stock: pci@80000000 = domain 0, pci@a0000000 = domain 1
OpenWrt: pcie1 (80000000) = domain 1, pcie0 (a0000000) = domain 0
This shouldn't affect link training, but worth noting.

### Hypothesis 5: qcom-pcie driver ipq5018 variant
The upstream `qcom-pcie.c` driver may have an issue specific to the 1-lane controller.
Need to check if there's any lane-count-specific logic in the controller init.

## Recommended Fix Strategy

### Step 1: Try enabling pcie1 with typo fix
Change `status = "disbled"` to `status = "okay"` and test if it actually works
(the "disbled" typo means it was never properly tested).

### Step 2: Fix PERST GPIO polarity for pcie0
Stock: GPIO 15 active HIGH for QCN9024
OpenWrt: GPIO 15 active LOW
Consider changing to `GPIO_ACTIVE_HIGH` if link issues appear.

### Step 3: After booting OpenWrt, check dmesg
```
dmesg | grep -i pcie
```
Look for PHY probe messages and link training errors.

### Step 4: If link still fails, check the PCIe PHY driver
May need to add the missing register writes:
- CDR_CTRL_REG_7 (0x98): 0x1A8 for 1-lane PHY
- SSCG_CTRL_REG_6 (0xb0): varies per PHY

### Step 5: Read GCC PCIe clock/reset registers
Verify that GCC_PCIE1_* clocks and resets are properly configured.

## Files Reference
- OpenWrt DTS: `target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ax6000.dts`
- OpenWrt SoC dtsi: `arch/arm64/boot/dts/qcom/ipq5018.dtsi` (upstream kernel)
- PHY driver: `drivers/phy/qualcomm/phy-qcom-uniphy-pcie-28lp.c`
- PCIe controller driver: `drivers/pci/controller/dwc/pcie-qcom.c`
- Stock PCIe data: `/tmp/pcie_info.txt` on router (3055 lines, 197.6KB)
