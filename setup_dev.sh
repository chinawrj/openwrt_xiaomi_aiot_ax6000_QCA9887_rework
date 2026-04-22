#!/bin/bash
# Setup script for QCA9887 PCIe rework development environment
# Clones OpenWrt 25.12.2, configures for qualcommax/ipq50xx, applies patches.
set -e

OPENWRT_TAG="v25.12.2"
OPENWRT_DIR="$HOME/fun/openwrt"
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
ROUTER_IP="${ROUTER_IP:-192.168.1.1}"

echo "==> OpenWrt source dir: $OPENWRT_DIR"
echo "==> Target tag: $OPENWRT_TAG"
echo "==> Router IP: $ROUTER_IP"
echo ""

# 1. Clone OpenWrt
if [ ! -d "$OPENWRT_DIR" ]; then
    echo "==> Cloning OpenWrt $OPENWRT_TAG..."
    git clone --depth 1 --branch "$OPENWRT_TAG" \
        https://git.openwrt.org/openwrt/openwrt.git "$OPENWRT_DIR"
else
    echo "==> OpenWrt dir already exists: $OPENWRT_DIR"
    echo "    To re-clone, remove it first: rm -rf $OPENWRT_DIR"
fi

cd "$OPENWRT_DIR"

# 2. Feeds
echo ""
echo "==> Updating feeds..."
./scripts/feeds update -a
./scripts/feeds install -a

# 3. Apply patches from repo
PATCH_DIR="$REPO_DIR/patches"
if ls "$PATCH_DIR"/*.patch &>/dev/null; then
    echo ""
    echo "==> Applying patches from $PATCH_DIR..."
    for p in "$PATCH_DIR"/*.patch; do
        echo "    Applying: $(basename $p)"
        git am --whitespace=fix "$p"
    done
else
    echo ""
    echo "==> No patches to apply yet (patches/ is empty)"
fi

# 4. Configure for qualcommax/ipq50xx - Xiaomi AX6000 AIOT
echo ""
echo "==> Writing .config for qualcommax/ipq50xx (Xiaomi AX6000 AIOT)..."
cat > "$OPENWRT_DIR/.config" << 'EOF'
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq50xx=y
CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_xiaomi_ax6000=y
# Reduce build time: only build target packages
CONFIG_ALL_NONSHARED=n
CONFIG_ALL_KMODS=n
# Keep kernel debug symbols for development
CONFIG_KERNEL_DEBUG_INFO=y
# ath10k for QCA9887
CONFIG_PACKAGE_kmod-ath10k-ct=y
CONFIG_PACKAGE_ath10k-firmware-qca9887=y
EOF

make defconfig

echo ""
echo "==> Setup complete!"
echo ""
echo "Next steps:"
echo "  cd $OPENWRT_DIR"
echo "  make -j\$(nproc) V=s         # Full build"
echo "  make target/linux/{clean,compile} -j\$(nproc)  # Kernel only"
echo ""
echo "  Or use: ./build.sh [full|kernel|dts|deploy]"
