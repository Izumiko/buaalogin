@echo off
zig cc ^
  -target mipsel-linux-musleabi ^
  -mcpu=mips32r2 ^
  -msoft-float ^
  -dynamic ^
  -Wl,--gc-sections ^
  -Wl,--strip-all ^
  -Wl,--build-id=none ^
  %*