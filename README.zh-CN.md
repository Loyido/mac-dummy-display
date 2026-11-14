# macOS 虚拟显示器与 Sunshine 控制器中文说明

这个分支基于 `patrikviktor/mac-dummy-display` 官方版本，保留作者原来的虚拟显示器逻辑，并额外加入了适合远程串流的 Retina / HiDPI 设备预设。

当前目标是让 Mac 通过一个虚拟显示器输出更适合 iPad、MacBook、电视或 16:9 客户端的画面，再配合 Sunshine、Moonlight、Parsec 或 VoldLink 使用。

## 当前分支新增了什么

- 保留官方原始分辨率列表和虚拟显示器创建逻辑。
- 新增命名设备预设，不用再记具体分辨率数字。
- 新增菜单栏快速切换入口：
  - `Device Presets`：按设备名称切换分辨率。
  - `Refresh Rate`：切换当前模式支持的刷新率。
- 新增可重复执行的 `build_app.sh` 打包脚本。
- 新增 GitHub Actions 自动同步和自动打包流程，说明见 [自动同步和自动打包说明](docs/automation.zh-CN.md)。
- 在切换显示模式后自动重启帧同步，让 Sunshine 捕获时跟随新的显示模式。

## 已加入的设备预设

| 预设名称 | macOS 中显示的逻辑分辨率 | 实际 Retina backing 像素 | 刷新率 |
| --- | ---: | ---: | --- |
| MacBook Pro 14 Safe Area | 1512 x 945 | 3024 x 1890 | 60Hz, 120Hz |
| 1080p 16:9 | 1920 x 1080 | 3840 x 2160 | 60Hz, 120Hz |
| iPad mini 6 | 1133 x 744 | 2266 x 1488 | 60Hz |
| iPad Pro 11 | 1210 x 834 | 2420 x 1668 | 60Hz, 120Hz |
| iPhone Duo Inner Display | 1335 x 939 | 2670 x 1878 | 60Hz, 120Hz |

说明：

- `MacBook Pro 14 Safe Area` 是为 14 英寸 MacBook Pro 全屏显示准备的安全区域版本。它避开了摄像头刘海区域导致的可用高度变化，比完整的 `1512 x 982` 更适合你的实际串流画面。
- `1080p 16:9` 是标准 16:9 快速切换选项，适合电视、显示器、Parsec 窗口或普通 1080p 客户端。
- `iPad mini 6` 和 `iPad Pro 11` 使用的是 HiDPI 逻辑分辨率加 2x backing 像素的组合。macOS 设置里有时会显示 backing 数值，这是系统显示方式，不代表配置错误。
- `iPhone Duo Inner Display` 对应手机展开后的横屏内屏，宽高比为 445:313。规格见 [Apple 官网](https://www.apple.com.cn/iphone-duo/specs/)。

## 编译打包

在项目目录执行：

```bash
cd /Users/no1801-hometheater/Documents/mac-dummy-display
./build_app.sh
```

脚本会重新生成并签名：

```text
/Users/no1801-hometheater/Documents/mac-dummy-display/DummyDisplay.app
```

注意：如果 `/Applications/DummyDisplay.app` 里还有旧版本，请优先打开项目目录里的这个新版 app，或者之后手动替换到 `/Applications`。

## 使用方法

1. 打开 `DummyDisplay.app`。
2. 点击 macOS 菜单栏里的显示器图标。
3. 选择 `Enable Virtual Display` 开启虚拟显示器。
4. 进入 `Device Presets`，选择需要的设备预设，例如：
   - `MacBook Pro 14 Safe Area`
   - `1080p 16:9`
   - `iPad mini 6`
   - `iPad Pro 11`
   - `iPhone Duo Inner Display`
5. 如果当前预设支持多个刷新率，再进入 `Refresh Rate` 选择 `60Hz` 或 `120Hz`。
6. 打开 Sunshine、Parsec、Moonlight 或 VoldLink 进行连接测试。

## 关于刷新率

当前实现支持的是离散刷新率切换，例如 `60Hz`、`90Hz`、`120Hz`。

它不是 iPhone / MacBook Pro 那种连续动态 ProMotion 可变刷新率。也就是说，它可以切换到某个固定刷新率模式，但不会根据画面内容自动在 60Hz 到 120Hz 之间连续浮动。

## 关于自动切换分辨率

当前 app 已经支持手动快速切换。根据 Parsec、VoldLink 或 Moonlight 连接的客户端自动切换，还没有放进这个版本。

后续如果要做自动切换，比较稳妥的路线是：

- 在 Sunshine 的启动项或应用配置里调用一个切换脚本。
- 为不同客户端准备不同的启动入口，例如 iPad mini 6、iPad Pro 11、MacBook Pro 14。
- 启动串流前先切分辨率，结束后再恢复默认值。

这部分暂时没有写入 Sunshine 配置，所以更新 Sunshine 不会覆盖当前这个 app 的分辨率预设。

## 已验证情况

- macOS 系统设置可以识别 `Dummy Retina Display`。
- 自定义分辨率可以出现在显示器设置中。
- 菜单栏可以按设备名称快速切换预设。
- Sunshine 可以捕获虚拟显示器。
- Parsec / Moonlight / VoldLink 这条链路的自动分辨率切换还需要后续单独处理。

## 当前 Git 分支

这个修改分支是：

```text
retina-device-profiles
```

你的 GitHub fork 地址：

```text
https://github.com/Loyido/mac-dummy-display/tree/retina-device-profiles
```
