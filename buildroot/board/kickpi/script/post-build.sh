#!/bin/sh
# K4B 专用 post-build：先跑通用 sun8i 流程，再用 K4B 的 env.cfg 重新生成 env.fex
# （通用 env.cfg 是 MQ-Dual 的 console=ttyS0，在 K4B 上串口看不到任何输出）
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
COMMON_SH="$SCRIPT_DIR/../../../allwinner-generic/sun8i-generic/scripts/post-build.sh"

"$COMMON_SH" "$@"

# 用 K4B 的 env.cfg 覆盖（console=ttyS3, earlyprintk=0x02500c00）
cp -f "$SCRIPT_DIR/env.cfg" "$BINARIES_DIR/env.cfg"
cd "$BINARIES_DIR"
./mkenvimage -r -p 0x00 -s 131072 -o env.fex env.cfg
echo "K4B: env.fex regenerated with console=ttyS3"
