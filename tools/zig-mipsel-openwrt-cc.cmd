@echo off
zig cc ^
  -target mipsel-linux-musleabi ^
  -mcpu=mips32r2 ^
  -msoft-float ^
  -ffunction-sections ^
  -fdata-sections ^
  %*