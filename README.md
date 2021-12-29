# buaalogin

使用Nim语言编写的北航校园网客户端

## 编译

```shell
git clone https://github.com/Izumiko/buaalogin.git
cd buaalogin
nimble build
```

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
