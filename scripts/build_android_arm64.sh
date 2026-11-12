#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NDK_ROOT="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
if [[ -z "$NDK_ROOT" ]]; then
  echo "ERROR: Set ANDROID_NDK_HOME or ANDROID_NDK_ROOT to Android NDK r27c." >&2
  exit 2
fi

HOST_TAG="linux-x86_64"
TOOLCHAIN="$NDK_ROOT/toolchains/llvm/prebuilt/$HOST_TAG/bin"
CXX="$TOOLCHAIN/aarch64-linux-android24-clang++"
READELF="$TOOLCHAIN/llvm-readelf"
OBJDUMP="$TOOLCHAIN/llvm-objdump"
for tool in "$CXX" "$READELF" "$OBJDUMP"; do
  [[ -x "$tool" ]] || { echo "ERROR: Missing NDK tool: $tool" >&2; exit 2; }
done

OUT_DIR="$ROOT/dist"
OUT="$OUT_DIR/onyx-android-arm64"
mkdir -p "$OUT_DIR"
rm -f "$OUT"

echo "Onyx Android ARM64 build"
echo "NDK: $NDK_ROOT"
echo "Compiler: $CXX"
"$CXX" --version | head -n 1
echo "Target: AArch64, API 24, ARMv8-A + NEON baseline; optional runtime SDOT"

"$CXX" \
  -std=c++17 -O3 -DNDEBUG -DNN_MAX_HIDDEN=1024 \
  -march=armv8-a+simd -mtune=cortex-a76 -pthread \
  -static-libstdc++ -Wl,--build-id=none \
  "$ROOT/onyx.cpp" -o "$OUT"
chmod 755 "$OUT"

"$READELF" -h "$OUT" | grep -q 'AArch64' || {
  echo "ERROR: output is not an AArch64 ELF." >&2; exit 1;
}
"$READELF" -d "$OUT" > "$OUT_DIR/onyx-android-arm64-dynamic.txt"
if grep -q 'libc++_shared.so' "$OUT_DIR/onyx-android-arm64-dynamic.txt"; then
  echo "ERROR: output unexpectedly depends on libc++_shared.so." >&2
  exit 1
fi
"$OBJDUMP" -d "$OUT" > "$OUT_DIR/onyx-android-arm64.disasm"
if ! grep -Eq '\b(smull|smlal|saddlp)\s+v[0-9]+' "$OUT_DIR/onyx-android-arm64.disasm"; then
  echo "ERROR: expected AArch64 NEON multiply/accumulate instructions were not found." >&2
  exit 1
fi
if ! grep -Eq '\bsdot\s+v[0-9]+\.4s' "$OUT_DIR/onyx-android-arm64.disasm"; then
  echo "ERROR: SDOT kernel was not emitted; check the NDK compiler's target-attribute support." >&2
  exit 1
fi

file "$OUT"
echo "PASS: AArch64 ELF confirmed."
echo "PASS: NEON arithmetic found in disassembly."
echo "PASS: optional SDOT instruction found in disassembly."
echo "PASS: no libc++_shared.so dependency."
echo "Engine artifact: $OUT"
echo "Keep onyx.nnue beside the executable when installing it."
