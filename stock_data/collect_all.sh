#!/bin/sh
# Comprehensive stock firmware data collection for Xiaomi AX6000 (AIOT)
# Run on router via telnet before rebooting to OpenWrt

OUT=/tmp/stock_full_dump.txt
echo "=== COLLECTION START ===" > $OUT
echo "Date: $(date)" >> $OUT
echo "Hostname: $(hostname)" >> $OUT

echo "=== 1. SYSTEM INFO ===" >> $OUT
cat /proc/version >> $OUT 2>&1
echo "" >> $OUT
cat /proc/cpuinfo >> $OUT 2>&1
echo "" >> $OUT
cat /proc/cmdline >> $OUT 2>&1
echo "" >> $OUT
uname -a >> $OUT 2>&1

echo "=== 2. FULL DMESG ===" >> $OUT
dmesg >> $OUT 2>&1

echo "=== 3. LSMOD ===" >> $OUT
lsmod >> $OUT 2>&1

echo "=== 4. FULL /proc/iomem ===" >> $OUT
cat /proc/iomem >> $OUT 2>&1

echo "=== 5. FULL /proc/ioports ===" >> $OUT
cat /proc/ioports >> $OUT 2>&1

echo "=== 6. PCI CONFIG SPACE ===" >> $OUT
# QCA9887 (domain 0, bus 1, dev 0, fn 0)
echo "--- 0000:01:00.0 (QCA9887) config ---" >> $OUT
if [ -f /sys/bus/pci/devices/0000:01:00.0/config ]; then
    hexdump -C /sys/bus/pci/devices/0000:01:00.0/config >> $OUT 2>&1
fi
echo "--- 0001:01:00.0 (QCN9024) config ---" >> $OUT
if [ -f /sys/bus/pci/devices/0001:01:00.0/config ]; then
    hexdump -C /sys/bus/pci/devices/0001:01:00.0/config >> $OUT 2>&1
fi
# Root ports
echo "--- 0000:00:00.0 (RC0 root port) config ---" >> $OUT
if [ -f /sys/bus/pci/devices/0000:00:00.0/config ]; then
    hexdump -C /sys/bus/pci/devices/0000:00:00.0/config >> $OUT 2>&1
fi
echo "--- 0001:00:00.0 (RC1 root port) config ---" >> $OUT
if [ -f /sys/bus/pci/devices/0001:00:00.0/config ]; then
    hexdump -C /sys/bus/pci/devices/0001:00:00.0/config >> $OUT 2>&1
fi

echo "=== 7. PCI TREE (lspci-like) ===" >> $OUT
for d in /sys/bus/pci/devices/*; do
    dev=$(basename $d)
    echo "--- $dev ---" >> $OUT
    echo "  vendor: $(cat $d/vendor 2>/dev/null)" >> $OUT
    echo "  device: $(cat $d/device 2>/dev/null)" >> $OUT
    echo "  class: $(cat $d/class 2>/dev/null)" >> $OUT
    echo "  subsystem_vendor: $(cat $d/subsystem_vendor 2>/dev/null)" >> $OUT
    echo "  subsystem_device: $(cat $d/subsystem_device 2>/dev/null)" >> $OUT
    echo "  driver: $(readlink $d/driver 2>/dev/null | sed 's:.*/::' )" >> $OUT
    echo "  resource:" >> $OUT
    cat $d/resource >> $OUT 2>&1
    echo "  irq: $(cat $d/irq 2>/dev/null)" >> $OUT
    echo "  enable: $(cat $d/enable 2>/dev/null)" >> $OUT
    echo "  max_link_speed: $(cat $d/max_link_speed 2>/dev/null)" >> $OUT
    echo "  current_link_speed: $(cat $d/current_link_speed 2>/dev/null)" >> $OUT
    echo "  max_link_width: $(cat $d/max_link_width 2>/dev/null)" >> $OUT
    echo "  current_link_width: $(cat $d/current_link_width 2>/dev/null)" >> $OUT
done

echo "=== 8. PCIe PARF REGISTERS (controller config) ===" >> $OUT
echo "--- PARF @0x78000 (RC0, x1) ---" >> $OUT
for off in 0x00 0x04 0x08 0x0c 0x10 0x14 0x18 0x1c 0x20 0x24 0x28 0x2c 0x30 0x34 0x38 0x3c \
           0x40 0x44 0x48 0x4c 0x50 0x54 0x58 0x5c 0x60 0x64 0x68 0x6c 0x70 0x74 0x78 0x7c \
           0x80 0x84 0x88 0x8c 0x90 0x94 0x98 0x9c 0xa0 0xa4 0xa8 0xac 0xb0 0xb4 0xb8 0xbc \
           0xc0 0xc4 0xc8 0xcc 0xd0 0xd4 0xd8 0xdc 0xe0 0xe4 0xe8 0xec 0xf0 0xf4 0xf8 0xfc \
           0x100 0x104 0x108 0x10c 0x110 0x114 0x118 0x11c 0x120 0x124 0x128 0x12c 0x130 0x134 0x138 0x13c \
           0x140 0x144 0x148 0x14c 0x150 0x154 0x158 0x15c 0x160 0x164 0x168 0x16c 0x170 0x174 0x178 0x17c \
           0x180 0x184 0x188 0x18c 0x190 0x194 0x198 0x19c 0x1a0 0x1a4 0x1a8 0x1ac 0x1b0 0x1b4 0x1b8 0x1bc \
           0x1c0 0x1c4 0x1c8 0x1cc 0x1d0 0x1d4 0x1d8 0x1dc 0x1e0 0x1e4 0x1e8 0x1ec 0x1f0 0x1f4 0x1f8 0x1fc \
           0x200 0x204 0x208 0x20c 0x210 0x214 0x218 0x21c 0x220 0x224 0x228 0x22c; do
    addr=$((0x78000 + off))
    printf "PARF0[0x%03x]: " $((off)) >> $OUT
    devmem $addr >> $OUT 2>&1
done

echo "--- PARF @0x80000 (RC1, x2) ---" >> $OUT
for off in 0x00 0x04 0x08 0x0c 0x10 0x14 0x18 0x1c 0x20 0x24 0x28 0x2c 0x30 0x34 0x38 0x3c \
           0x40 0x44 0x48 0x4c 0x50 0x54 0x58 0x5c 0x60 0x64 0x68 0x6c 0x70 0x74 0x78 0x7c \
           0x80 0x84 0x88 0x8c 0x90 0x94 0x98 0x9c 0xa0 0xa4 0xa8 0xac 0xb0 0xb4 0xb8 0xbc \
           0xc0 0xc4 0xc8 0xcc 0xd0 0xd4 0xd8 0xdc 0xe0 0xe4 0xe8 0xec 0xf0 0xf4 0xf8 0xfc \
           0x100 0x104 0x108 0x10c 0x110 0x114 0x118 0x11c 0x120 0x124 0x128 0x12c 0x130 0x134 0x138 0x13c \
           0x140 0x144 0x148 0x14c 0x150 0x154 0x158 0x15c 0x160 0x164 0x168 0x16c 0x170 0x174 0x178 0x17c \
           0x180 0x184 0x188 0x18c 0x190 0x194 0x198 0x19c 0x1a0 0x1a4 0x1a8 0x1ac 0x1b0 0x1b4 0x1b8 0x1bc \
           0x1c0 0x1c4 0x1c8 0x1cc 0x1d0 0x1d4 0x1d8 0x1dc 0x1e0 0x1e4 0x1e8 0x1ec 0x1f0 0x1f4 0x1f8 0x1fc \
           0x200 0x204 0x208 0x20c 0x210 0x214 0x218 0x21c 0x220 0x224 0x228 0x22c; do
    addr=$((0x80000 + off))
    printf "PARF1[0x%03x]: " $((off)) >> $OUT
    devmem $addr >> $OUT 2>&1
done

echo "=== 9. PCIe PHY FULL REGISTER DUMP ===" >> $OUT
echo "--- PHY@7e000 (x1, QCA9887) full 0x000-0x7FF ---" >> $OUT
off=0
while [ $off -lt 2048 ]; do
    addr=$((0x7e000 + off))
    printf "PHY0[0x%03x]: " $off >> $OUT
    devmem $addr >> $OUT 2>&1
    off=$((off + 4))
done

echo "--- PHY@86000 (x2 lane0) full 0x000-0x7FF ---" >> $OUT
off=0
while [ $off -lt 2048 ]; do
    addr=$((0x86000 + off))
    printf "PHY1L0[0x%03x]: " $off >> $OUT
    devmem $addr >> $OUT 2>&1
    off=$((off + 4))
done

echo "--- PHY@86800 (x2 lane1) full 0x000-0x7FF ---" >> $OUT
off=0
while [ $off -lt 2048 ]; do
    addr=$((0x86800 + off))
    printf "PHY1L1[0x%03x]: " $off >> $OUT
    devmem $addr >> $OUT 2>&1
    off=$((off + 4))
done

echo "=== 10. GCC CLOCK/RESET REGISTERS (PCIe related) ===" >> $OUT
echo "--- GCC base @0x1800000 ---" >> $OUT
# PCIe0 clocks (x2)
for name_off in \
    "GCC_PCIE0_AXI_M_CBCR:0x28004" \
    "GCC_PCIE0_AXI_S_CBCR:0x28008" \
    "GCC_PCIE0_AXI_S_BRIDGE_CBCR:0x2800c" \
    "GCC_PCIE0_AHB_CBCR:0x28010" \
    "GCC_PCIE0_AUX_CBCR:0x28014" \
    "GCC_PCIE0_PIPE_CBCR:0x28018" \
    "GCC_SYS_NOC_PCIE0_AXI_CBCR:0x2601c" \
    "GCC_PCIE0_AXI_CMD_RCGR:0x28018" \
    "GCC_PCIE0_BCR:0x28000" \
    "GCC_PCIE0_LINK_DOWN_BCR:0x28054" \
    "GCC_PCIE0_PHY_BCR:0x28060" \
    "GCC_PCIE0PHY_PHY_BCR:0x28064" \
    "GCC_PCIE1_AXI_M_CBCR:0x29004" \
    "GCC_PCIE1_AXI_S_CBCR:0x29008" \
    "GCC_PCIE1_AXI_S_BRIDGE_CBCR:0x2900c" \
    "GCC_PCIE1_AHB_CBCR:0x29010" \
    "GCC_PCIE1_AUX_CBCR:0x29014" \
    "GCC_PCIE1_PIPE_CBCR:0x29018" \
    "GCC_SYS_NOC_PCIE1_AXI_CBCR:0x26020" \
    "GCC_PCIE1_BCR:0x29000" \
    "GCC_PCIE1_LINK_DOWN_BCR:0x29054" \
    "GCC_PCIE1_PHY_BCR:0x29060" \
    "GCC_PCIE1PHY_PHY_BCR:0x29064" \
    "GCC_CMN_BLK_AHB_CBCR:0x3a004" \
    "GCC_CMN_BLK_SYS_CBCR:0x3a008"; do
    name=$(echo $name_off | cut -d: -f1)
    off=$(echo $name_off | cut -d: -f2)
    addr=$((0x1800000 + off))
    printf "%s [0x%x]: " "$name" $addr >> $OUT
    devmem $addr >> $OUT 2>&1
done

echo "=== 11. PCIe DBI REGISTERS (link status) ===" >> $OUT
echo "--- DBI @0x80000000 (RC0, x1) ---" >> $OUT
for name_off in \
    "VENDOR_ID:0x00" \
    "DEVICE_ID:0x02" \
    "COMMAND:0x04" \
    "STATUS:0x06" \
    "CLASS_REV:0x08" \
    "BIST:0x0c" \
    "BAR0:0x10" \
    "LINK_CAPABILITIES:0x7c" \
    "LINK_CONTROL_STATUS:0x80" \
    "LINK_CAPABILITIES2:0x9c" \
    "LINK_CONTROL_STATUS2:0xa0" \
    "PORT_LINK_CTRL:0x710" \
    "GEN2_CTRL:0x80c" \
    "LINK_WIDTH_SPEED_CTRL:0x80c" \
    "MISC_CONTROL_1:0x8bc"; do
    name=$(echo $name_off | cut -d: -f1)
    off=$(echo $name_off | cut -d: -f2)
    addr=$((0x80000000 + off))
    printf "DBI0.%s[0x%03x]: " "$name" $((off)) >> $OUT
    devmem $addr >> $OUT 2>&1
done

echo "--- DBI @0xa0000000 (RC1, x2) ---" >> $OUT
for name_off in \
    "VENDOR_ID:0x00" \
    "DEVICE_ID:0x02" \
    "COMMAND:0x04" \
    "STATUS:0x06" \
    "CLASS_REV:0x08" \
    "BIST:0x0c" \
    "BAR0:0x10" \
    "LINK_CAPABILITIES:0x7c" \
    "LINK_CONTROL_STATUS:0x80" \
    "LINK_CAPABILITIES2:0x9c" \
    "LINK_CONTROL_STATUS2:0xa0" \
    "PORT_LINK_CTRL:0x710" \
    "GEN2_CTRL:0x80c" \
    "LINK_WIDTH_SPEED_CTRL:0x80c" \
    "MISC_CONTROL_1:0x8bc"; do
    name=$(echo $name_off | cut -d: -f1)
    off=$(echo $name_off | cut -d: -f2)
    addr=$((0xa0000000 + off))
    printf "DBI1.%s[0x%03x]: " "$name" $((off)) >> $OUT
    devmem $addr >> $OUT 2>&1
done

echo "=== 12. ELBI REGISTERS ===" >> $OUT
echo "--- ELBI @0x80000f20 (RC0, x1) ---" >> $OUT
for off in 0x00 0x04 0x08 0x0c 0x10 0x14 0x18 0x1c 0x20 0x24 0x28; do
    addr=$((0x80000f20 + off))
    printf "ELBI0[0x%02x]: " $((off)) >> $OUT
    devmem $addr >> $OUT 2>&1
done
echo "--- ELBI @0xa0000f20 (RC1, x2) ---" >> $OUT
for off in 0x00 0x04 0x08 0x0c 0x10 0x14 0x18 0x1c 0x20 0x24 0x28; do
    addr=$((0xa0000f20 + off))
    printf "ELBI1[0x%02x]: " $((off)) >> $OUT
    devmem $addr >> $OUT 2>&1
done

echo "=== 13. GPIO REGISTERS ===" >> $OUT
echo "--- TLMM GPIO 15 (PCIe x2 PERST) ---" >> $OUT
devmem $((0x100F000)) >> $OUT 2>&1
devmem $((0x100F004)) >> $OUT 2>&1
echo "--- TLMM GPIO 18 (PCIe x1 PERST) ---" >> $OUT
devmem $((0x1012000)) >> $OUT 2>&1
devmem $((0x1012004)) >> $OUT 2>&1

echo "=== 14. FULL DEVICE TREE BINARY ===" >> $OUT
echo "(saving to /tmp/stock_dtb.bin)" >> $OUT
if [ -f /sys/firmware/fdt ]; then
    cp /sys/firmware/fdt /tmp/stock_dtb.bin
    ls -la /tmp/stock_dtb.bin >> $OUT 2>&1
    echo "DTB saved" >> $OUT
else
    echo "No /sys/firmware/fdt" >> $OUT
fi

echo "=== 15. NVRAM/ENV ===" >> $OUT
nvram show 2>&1 | head -200 >> $OUT
echo "" >> $OUT
cat /proc/mtd >> $OUT 2>&1

echo "=== 16. WIFI MODULE INFO ===" >> $OUT
for mod in ath_ol_pci_2_0 cnss_pci qca_ol wifi_3_0 wifi_2_0; do
    echo "--- modinfo $mod ---" >> $OUT
    if [ -f /sys/module/$mod/parameters ]; then
        echo "  params:" >> $OUT
        ls /sys/module/$mod/parameters/ >> $OUT 2>&1
    fi
    if [ -d /sys/module/$mod ]; then
        echo "  exists: yes" >> $OUT
    fi
done

echo "=== 17. WIFI CALDATA INFO ===" >> $OUT
echo "--- ART partition (mtd13) content header ---" >> $OUT
hexdump -C /dev/mtd13 -n 256 >> $OUT 2>&1
echo "--- caldata_qca9889 offset 0x4d000 ---" >> $OUT
dd if=/dev/mtd13 bs=1 skip=$((0x4d000)) count=64 2>/dev/null | hexdump -C >> $OUT 2>&1

echo "=== 18. /proc/device-tree PCIe nodes (text) ===" >> $OUT
for node in pci@80000000 pci@a0000000 phy@7e000 phy@86000; do
    echo "--- /proc/device-tree/soc/$node ---" >> $OUT
    find /proc/device-tree/soc/$node -type f | sort | while read f; do
        echo "  $f:" >> $OUT
        hexdump -C "$f" >> $OUT 2>&1
    done
done

echo "=== 19. NETWORK INTERFACES ===" >> $OUT
ifconfig -a >> $OUT 2>&1

echo "=== 20. BOOT ENV / PARTITIONS ===" >> $OUT
nvram get flag_boot_rootfs >> $OUT 2>&1
nvram get flag_last_success >> $OUT 2>&1
nvram get flag_boot_success >> $OUT 2>&1
echo "--- fw_printenv ---" >> $OUT
fw_printenv 2>&1 | head -50 >> $OUT

echo "=== 21. KERNEL CONFIG FRAGMENTS ===" >> $OUT
zcat /proc/config.gz 2>/dev/null | grep -i "pci\|ath\|qca\|wifi\|phy" >> $OUT 2>&1
if [ $? -ne 0 ]; then
    echo "No /proc/config.gz" >> $OUT
fi

echo "=== 22. TCSR REGISTER (PCIe PHY mode select) ===" >> $OUT
# TCSR registers that control PCIe mode
for off in 0x0 0x4 0x8 0xc 0x10 0x14 0x100 0x104 0x108 0x10c 0x110 0x1000 0x1004 0x6100; do
    addr=$((0x1937000 + off))
    printf "TCSR[0x%04x]: " $((off)) >> $OUT
    devmem $addr >> $OUT 2>&1
done

echo "=== 23. CMN_BLK (Common Block) REGISTERS ===" >> $OUT
for off in 0x0 0x4 0x8 0xc 0x10 0x14 0x18 0x1c 0x20 0x24 0x28 0x2c 0x30; do
    addr=$((0x9b000 + off))
    printf "CMN_BLK[0x%02x]: " $((off)) >> $OUT
    devmem $addr >> $OUT 2>&1
done

echo "=== COLLECTION COMPLETE ===" >> $OUT
wc -l $OUT
ls -lh $OUT
echo "Done! File: $OUT"
