#!/bin/bash
# Development helper: build and deploy to router at 192.168.1.1
# Usage:
#   ./build.sh full      - Full image build
#   ./build.sh kernel    - Rebuild kernel + modules only
#   ./build.sh dts       - Rebuild DTS / DTB only (fastest iteration)
#   ./build.sh deploy    - SCP latest image to router and reboot
#   ./build.sh dmesg     - Fetch dmesg from router (pcie/ath10k filtered)
#   ./build.sh parf      - Read PARF/PHY registers on router via devmem
set -e

OPENWRT_DIR="${OPENWRT_DIR:-$HOME/fun/openwrt}"
ROUTER_IP="${ROUTER_IP:-192.168.1.1}"
J="${J:-$(nproc)}"
SSH="ssh -o ConnectTimeout=10 root@$ROUTER_IP"
TARGET_DIR="$OPENWRT_DIR/bin/targets/qualcommax/ipq50xx"

cmd="${1:-full}"

case "$cmd" in
full)
    echo "==> Full build (j=$J)..."
    cd "$OPENWRT_DIR"
    make -j"$J" V=s 2>&1 | tee /tmp/openwrt_build.log | grep -E 'ERROR|error:|WARNING|warning:|^make|Building'
    echo ""
    echo "==> Images in: $TARGET_DIR"
    ls -lh "$TARGET_DIR"/*.bin 2>/dev/null || ls -lh "$TARGET_DIR"/*.img 2>/dev/null || true
    ;;

kernel)
    echo "==> Rebuilding kernel..."
    cd "$OPENWRT_DIR"
    make target/linux/{clean,compile} -j"$J" V=s 2>&1 | tee /tmp/openwrt_kernel.log | grep -E 'ERROR|error:|^make'
    ;;

dts)
    echo "==> Rebuilding DTS/DTB only..."
    cd "$OPENWRT_DIR"
    # Re-compile device tree and repack kernel image
    make target/linux/compile -j"$J" V=s \
        QUILT_PATCHES=target/linux/qualcommax/patches-6.12 2>&1 | \
        grep -E 'DTC|dtb|ERROR|error:|^make' | tail -30
    ;;

deploy)
    IMAGE=$(ls -t "$TARGET_DIR"/openwrt-qualcommax-ipq50xx-xiaomi_ax6000-aiot-squashfs-sysupgrade.bin 2>/dev/null | head -1)
    if [ -z "$IMAGE" ]; then
        echo "ERROR: No sysupgrade image found in $TARGET_DIR"
        echo "Available files:"
        ls "$TARGET_DIR"/ 2>/dev/null || true
        exit 1
    fi
    echo "==> Deploying: $(basename $IMAGE) ($(du -h $IMAGE | cut -f1))"
    echo "    to router $ROUTER_IP..."
    scp "$IMAGE" "root@$ROUTER_IP:/tmp/firmware.bin"
    echo "==> Flashing (router will reboot)..."
    $SSH "sysupgrade -n /tmp/firmware.bin" || true
    echo "==> Waiting for router to come back up..."
    sleep 30
    for i in $(seq 1 12); do
        if ssh -o ConnectTimeout=5 root@$ROUTER_IP "echo ok" 2>/dev/null; then
            echo "==> Router is back online!"
            break
        fi
        echo "    ...waiting ($i/12)"
        sleep 10
    done
    ;;

dmesg)
    echo "==> Router dmesg (pcie / ath10k / wifi):"
    $SSH "dmesg" | grep -iE 'pcie|qcom-pcie|qca9887|168c:0050|ath10k|ath11k|wifi|ipq5018' | head -80
    ;;

parf)
    echo "==> Reading PCIe PARF/PHY registers on router..."
    $SSH '
echo "--- PCIe1 (x1) PARF registers ---"
for off in 0x00 0x04 0x08 0x14 0x1c 0x20 0x28 0x35c 0x3a0; do
    addr=$(printf "0x%08x" $((0x78000 + $off)))
    val=$(devmem $addr 2>/dev/null || echo "FAIL")
    printf "  PARF0[%s] = %s\n" $off "$val"
done
echo ""
echo "--- PHY@7e000 (x1) CDR/SSCG registers ---"
for off in 0x90 0x94 0x98 0x9c 0xa0 0xa4 0xa8 0xac 0xb0; do
    addr=$(printf "0x%08x" $((0x7e000 + $off)))
    val=$(devmem $addr 16 2>/dev/null || echo "FAIL")
    printf "  PHY7e000[%s] = %s\n" $off "$val"
done
echo ""
echo "--- DBI0 Link Status (0x80000080) ---"
devmem 0x80000080 32 2>/dev/null || echo "FAIL (pcie1 disabled)"
'
    ;;

clk)
    echo "==> PCIe clock summary on router:"
    $SSH "cat /sys/kernel/debug/clk/clk_summary 2>/dev/null | grep -i pcie || echo 'debugfs not available'"
    ;;

*)
    echo "Usage: $0 [full|kernel|dts|deploy|dmesg|parf|clk]"
    exit 1
    ;;
esac
