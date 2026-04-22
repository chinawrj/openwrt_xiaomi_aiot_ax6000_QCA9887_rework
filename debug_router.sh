#!/bin/bash
# Quick debug script: runs on the router directly to collect PCIe state
# Usage: ssh root@192.168.1.1 'sh -s' < debug_router.sh
#    or: ./build.sh dmesg | parf | clk

ROUTER_IP="${1:-192.168.1.1}"
SSH="ssh -o ConnectTimeout=10 root@$ROUTER_IP"

echo "===== Router: PCIe Debug Snapshot ====="
echo "Date: $(date -u)"
echo ""

echo "--- OpenWrt release ---"
$SSH "cat /etc/openwrt_release"
echo ""

echo "--- dmesg: pcie / ath ---"
$SSH "dmesg" | grep -iE 'pcie|qcom-pcie|ath10k|ath11k|168c:0050|17cb:1104|qca9887'
echo ""

echo "--- PCI devices ---"
$SSH "cat /proc/bus/pci/devices 2>/dev/null; ls /sys/bus/pci/devices/ 2>/dev/null"
echo ""

echo "--- Loaded modules ---"
$SSH "lsmod | grep -E 'ath|pcie|ipq'"
echo ""

echo "--- GPIO 18 state (PERST x1) ---"
$SSH "cat /sys/kernel/debug/gpio 2>/dev/null | grep -E 'gpio-18|gpio-15' || echo 'no debugfs'"
echo ""

echo "--- PHY@7e000 register dump (CDR/SSCG area) ---"
$SSH '
echo "Offset  Value"
for off in $(seq 0 4 0xbc); do
    addr=$(printf "0x%08x" $((0x7e000 + off)))
    val=$(devmem $addr 16 2>/dev/null) || { echo "devmem not available"; break; }
    printf "0x%03x   %s\n" $off "$val"
done
'
echo ""

echo "--- PARF0 (0x78000) register dump ---"
$SSH '
for off in $(seq 0 4 0x3ff); do
    addr=$(printf "0x%08x" $((0x78000 + off)))
    val=$(devmem $addr 2>/dev/null) || { echo "devmem not available"; break; }
    printf "PARF0[0x%03x] = %s\n" $off "$val"
done
'
