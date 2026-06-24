# buaalogin

使用Nim语言编写的北航校园网客户端，支持登录、注销、状态查询和断线检测后自动登录。

## 支持的平台

当前统一构建脚本可在 Windows 主机上生成以下目标：

| 构建目标 | 输出文件 |
|---|---|
| Windows AMD64 | `buaalogin-windows-amd64.exe` |
| Linux AMD64 | `buaalogin-linux-amd64` |
| Linux ARM64 | `buaalogin-linux-arm64` |
| OpenWrt MIPSLE | `buaalogin-openwrt-mipsel` |

所有构建结果均输出到 `dist/`。

## 构建环境

推荐在 Windows PowerShell 中构建，并使用 Scoop 安装 Nim 和 Zig：

```powershell
scoop install nim zig
```

确认工具可以运行：

```powershell
nim --version
nimble --version
zig version
```

### 关于 Scoop shim

Scoop 通常会在 `PATH` 中注册：

```text
<SCOOP>\shims\nim.exe
```

该文件是 shim，并不是真正的 Nim 编译器。`build.ps1` 会优先执行：

```powershell
scoop prefix nim
```

以定位真实的：

```text
<SCOOP>\apps\nim\current\bin\nim.exe
```

随后将真实的 Nim `bin` 目录临时放到当前构建进程的 `PATH` 最前面，避免 Nimble 无法识别 Nim。

如果自动定位失败，也可以显式指定：

```powershell
.\build.ps1 `
  -NimExe "D:\Scoop\apps\nim\current\bin\nim.exe"
```

## 统一构建

克隆项目：

```powershell
git clone https://github.com/Izumiko/buaalogin.git
cd buaalogin
```

构建全部平台：

```powershell
.\build.ps1
```

只构建指定目标：

```powershell
.\build.ps1 -Targets openwrt-mipsel
```

同时构建多个目标：

```powershell
.\build.ps1 `
  -Targets linux-amd64,linux-arm64,openwrt-mipsel
```

清理后重新构建：

```powershell
.\build.ps1 -Clean
```

输出详细的 Nimble、Nim 和外部编译器命令：

```powershell
.\build.ps1 -VerboseBuild
```

依赖已经安装完成时，可跳过 `nimble install --depsOnly`：

```powershell
.\build.ps1 -SkipDeps
```

组合使用：

```powershell
.\build.ps1 `
  -Targets openwrt-mipsel `
  -Clean `
  -VerboseBuild
```

## 缓存目录

构建脚本将 Nimble 包目录和 Nim 编译缓存固定在项目的 `build/` 下，避免缓存写入 Scoop 安装目录，也避免不同目标之间相互污染。

```text
build/
├─ nimble/
│  ├─ pkgcache/
│  ├─ pkgs2/
│  ├─ bin/
│  └─ nimbledata2.json
└─ nimcache/
   ├─ windows-amd64/
   ├─ linux-amd64/
   ├─ linux-arm64/
   └─ openwrt-mipsel/
```

其中：

- `build/nimble` 是 Nimble 根目录；
- `build/nimble/pkgcache` 保存下载缓存；
- `build/nimble/pkgs2` 保存已安装的依赖包；
- `build/nimcache/<target>` 保存 Nim 为对应目标生成的 C 文件和目标文件；
- 每个平台使用独立的 `nimcache`。

也可以将 Nimble 目录放到其他位置：

```powershell
.\build.ps1 `
  -NimbleDir "D:\Caches\buaalogin-nimble"
```

## 交叉编译方式

项目统一使用 Nim 的 C 后端，并通过：

```text
--cc:clang
```

调用 `tools/` 中对应目标的 Zig C 编译器包装器。各平台的编译器和链接器映射在 `src/nim.cfg` 中配置。

典型结构如下：

```text
buaalogin/
├─ build.ps1
├─ buaalogin.nimble
├─ src/
│  ├─ main.nim
│  ├─ xEncode.nim
│  └─ nim.cfg
└─ tools/
   ├─ zig-aarch64-linux.cmd
   ├─ zig-mipsel-openwrt-cc.cmd
   ├─ zig-mipsel-openwrt-link.cmd
   ├─ zig-x86_64-linux.cmd
   └─ zig-x86_64-windows.cmd
```

这样无需分别安装 Windows、Linux AMD64、Linux ARM64 和 MIPSLE 的编译工具链。

### OpenWrt MIPSLE

OpenWrt 版本应与目标设备的 ABI 保持一致，包括：

- MIPS little-endian；
- MIPS32/MIPS32r2 指令集；
- soft-float 或 hard-float；
- musl 动态加载器路径；
- OpenWrt 上实际提供的共享库版本。

当前构建目标使用 Zig 的 MIPSLE Linux musl 目标，并通过系统 musl 动态链接，以减小最终程序体积。


### TLS 运行时依赖

项目通过 Nim 的 SSL/OpenSSL 接口访问 HTTPS。Linux 和 OpenWrt 目标系统需要提供兼容的：

```text
libssl
libcrypto
```

编译成功只代表 ELF 已生成；发布前还应在目标系统上实际测试 HTTPS 登录、状态查询和注销。

## 用法

```text
Usage: buaalogin [-u:username] [-p:password] login/logout/status/detect
```

### 登录

```shell
buaalogin -u:username -p:password login
```

### 注销

```shell
buaalogin logout
```

### 查询状态

```shell
buaalogin status
```

### 检测并自动登录

```shell
buaalogin -u:username -p:password detect
```

可以结合 Windows 任务计划程序、Linux `cron` 或 OpenWrt `cron` 定时执行 `detect`。

## 致谢

[goomadao/beihangLogin](https://github.com/goomadao/beihangLogin)
