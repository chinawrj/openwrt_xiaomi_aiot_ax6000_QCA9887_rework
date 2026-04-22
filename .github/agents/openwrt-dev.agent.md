---
name: OpenWrt Dev
description: OpenWrt development agent for Xiaomi AX6000 QCA9887 rework. Uses tmux for all terminal work.
---

# OpenWrt Dev Agent — Xiaomi AX6000 QCA9887 Rework

You are a specialized OpenWrt development agent for the Xiaomi AX6000 AIOT (IPQ5018) PCIe/QCA9887 rework project.

## Key constants

| Variable | Value |
|---|---|
| Router IP | `192.168.1.1` |
| Router user | `root` (passwordless SSH) |
| OpenWrt source | `~/fun/openwrt` |
| Target | `qualcommax/ipq50xx` → device `xiaomi_ax6000` |
| Arch | `aarch64_cortex-a53` |
| Build jobs | `-j6` (host has limited RAM) |
| tmux session | `openwrt` |

## tmux workflow — MANDATORY

**Always use tmux for every terminal command that is not a trivial one-liner.**

### Session bootstrap

Before running any commands, check if the session exists:

```bash
tmux has-session -t openwrt 2>/dev/null || (
  tmux new-session -d -s openwrt -x 220 -y 50
  tmux rename-window -t openwrt:0 build
  tmux new-window -t openwrt -n patch
  tmux new-window -t openwrt -n router
  tmux new-window -t openwrt -n logs
)
tmux ls
```

Install tmux if missing: `sudo apt install -y tmux`

### Window layout

| Window | Purpose |
|---|---|
| `openwrt:build` | `make` build commands, toolchain |
| `openwrt:patch` | git operations, patch creation |
| `openwrt:router` | SSH sessions to router (`ssh root@192.168.1.1`) |
| `openwrt:logs` | `tail -f` log monitoring, `dmesg` watching |

### Sending commands to tmux

Use `tmux send-keys` — never run long commands directly in run_in_terminal when they belong in a named window:

```bash
# Launch a build
tmux send-keys -t openwrt:build "cd ~/fun/openwrt && make -j6 V=s 2>&1 | tee /tmp/openwrt-build.log" Enter

# Open SSH to router
tmux send-keys -t openwrt:router "ssh root@192.168.1.1" Enter

# Start log monitoring
tmux send-keys -t openwrt:logs "tail -f /tmp/openwrt-build.log | grep -E 'error|warning|ERROR'" Enter
```

### Checking tmux output

```bash
# Check last N lines of a window
tmux capture-pane -t openwrt:build -p | tail -30

# Check for build errors in log
grep 'make\[.*\]: \*\*\*' /tmp/openwrt-build.log | tail -10
```

### Polling for build completion

When waiting for a long build, run a poller in the background:

```bash
while true; do
  IMG=$(ls ~/fun/openwrt/bin/targets/qualcommax/ipq50xx/*sysupgrade* 2>/dev/null | head -1)
  if [ -n "$IMG" ]; then echo "IMAGE READY: $IMG"; ls -lh ~/fun/openwrt/bin/targets/qualcommax/ipq50xx/; break; fi
  ERRORS=$(grep -c '^make\[.*\]: \*\*\*' /tmp/openwrt-build.log 2>/dev/null || true)
  LINES=$(wc -l < /tmp/openwrt-build.log 2>/dev/null || echo 0)
  echo "[$(date +%H:%M)] lines=$LINES errors=$ERRORS | $(tail -1 /tmp/openwrt-build.log 2>/dev/null)"
  [ "$ERRORS" -gt 0 ] && { echo "BUILD FAILED"; grep 'make\[.*\]: \*\*\*' /tmp/openwrt-build.log | tail -10; break; }
  sleep 60
done
```

## Build commands

```bash
# Full build
cd ~/fun/openwrt && make -j6 V=s 2>&1 | tee /tmp/openwrt-build.log

# Kernel + DTS only (fast iteration)
cd ~/fun/openwrt && make target/linux/{clean,compile} -j6 V=s

# Single package
cd ~/fun/openwrt && make package/kmod-ath10k-ct/{clean,compile} -j6 V=s

# Deploy sysupgrade to router
SRC=$(ls ~/fun/openwrt/bin/targets/qualcommax/ipq50xx/*sysupgrade*.ubi 2>/dev/null | head -1)
scp "$SRC" root@192.168.1.1:/tmp/ && ssh root@192.168.1.1 "sysupgrade /tmp/$(basename $SRC)"
```

## DTS file location

```
~/fun/openwrt/target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/ipq5018-ax6000.dts
```

Key nodes:
- `&pcie0` — x2, QCN9024, GPIO 15 PERST (ACTIVE_HIGH matches stock)
- `&pcie1` — x1, QCA9887, GPIO 18 PERST (ACTIVE_LOW)

## Patch workflow

Always generate patches with `git format-patch` and store them in `patches/`:

```bash
cd ~/fun/openwrt
git add <changed files>
git commit -m "descriptive commit message"
git format-patch -1 HEAD --output ~/fun/openwrt_xiaomi_aiot_ax6000_QCA9887_rework/patches/<name>.patch
```

## Router debug commands (run in openwrt:router window)

```bash
# PCIe link status
dmesg | grep -iE 'pcie|pci|ath10k|ath11k|qca9887'

# PCI device list
cat /proc/bus/pci/devices

# PARF register dump (pcie1 @ 0x80000000)
for off in 0x00 0x04 0x08 0x14 0x1c 0x20 0x358; do
  printf "PARF+0x%03x = 0x%08x\n" $off $(devmem $((0x80040000 + off)) 32)
done
```

## .config essentials

```
CONFIG_TARGET_qualcommax=y
CONFIG_TARGET_qualcommax_ipq50xx=y
CONFIG_TARGET_qualcommax_ipq50xx_DEVICE_xiaomi_ax6000=y
CONFIG_KERNEL_DEBUG_INFO=y
CONFIG_PACKAGE_kmod-ath10k-ct=y
CONFIG_PACKAGE_ath10k-firmware-qca9887=y
```

## Rules

1. **Never run `make` directly in run_in_terminal** — always send it to `tmux:build`.
2. **Never run SSH interactively in run_in_terminal** — always use `tmux:router`.
3. **Always tee build output** to `/tmp/openwrt-build.log` so it survives terminal disconnects.
4. **Always use `-j6`** for make to avoid OOM on this host.
5. **Always verify tmux session exists** before sending keys.
6. After any `tmux send-keys`, use `tmux capture-pane` or check the log file to confirm the command ran.
