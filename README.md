# buaalogin

使用Nim语言编写的北航校园网客户端

## 编译

```shell
git clone https://github.com/Izumiko/buaalogin.git
cd buaalogin
nimble build
```

使用`nim --app:gui c src/main.nim`来生成Windows下无cmd窗口的程序。

交叉编译说明：
假设Host是Linux x64，编译mipsel架构路由上使用的版本，则在`src/nim.cfg`中增加如下配置（具体路径根据openwrt编译路径填写）

```shell
mipsel.linux.gcc.path = "/home/user/lede/staging_dir/toolchain-mipsel_24kc_gcc-8.4.0_musl/bin"
mipsel.linux.gcc.exe = "mipsel-openwrt-linux-gcc"
mipsel.linux.gcc.linkerexe = "mipsel-openwrt-linux-gcc"
```

之后执行 `nim c --cpu:mipsel --os:linux src/main.nim` 来生成程序。

## 用法

```
Usage: buaalogin [-u:username] [-p:password] login/logout/status/detect
```

- 登录

```shell
buaalogin -u:username -p:password login
```

- 注销

```shell
buaalogin logout
```

- 查询状态

```shell
buaalogin status
```

- 检测并自动登录

```shell
buaalogin -u:username -p:password detect
```

结合系统的计划任务，定时执行上述命令

## 致谢

[goomadao/beihangLogin](https://github.com/goomadao/beihangLogin)
