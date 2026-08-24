# 自动同步和自动打包说明

这个仓库现在有两条 GitHub Actions 自动化流程：

- `Sync Upstream`：定时检查原作者仓库有没有更新。
- `Build macOS App`：在 GitHub 的 macOS 环境里编译并打包 `DummyDisplay.app`。

## 自动同步逻辑

同步流程文件是：

```text
.github/workflows/sync-upstream.yml
```

它每天会检查一次：

```text
patrikviktor/mac-dummy-display:main
```

如果原作者没有新提交，流程会直接结束。

如果原作者有新提交，流程不会直接改你的自定义分支，而是：

1. 从你的 `retina-device-profiles` 分支创建同步分支。
2. 把原作者的 `main` 合并进去。
3. 推送到 `sync/upstream-main`。
4. 自动向 `retina-device-profiles` 打开或更新一个 PR。

这样做的好处是：如果原作者改到了同一个 Swift 文件，你可以先看 PR 里的差异，确认我们的设备预设没有被破坏，再手动合并。

## 自动打包逻辑

打包流程文件是：

```text
.github/workflows/build-macos.yml
```

它会在这些情况运行：

- 推送到 `retina-device-profiles` 分支时。
- 有 PR 合并到 `retina-device-profiles` 前。
- 你在 GitHub Actions 页面手动点击运行时。

打包流程会执行：

```bash
./build_app.sh
```

然后上传：

```text
DummyDisplay.app.zip
```

## 从哪里下载打包结果

在 GitHub 页面里：

1. 打开你的 fork：`https://github.com/Loyido/mac-dummy-display`
2. 进入 `Actions`
3. 打开最近一次 `Build macOS App`
4. 在页面底部找到 `Artifacts`
5. 下载 `DummyDisplay-macos-<commit>.zip`

下载后解压，会得到：

```text
DummyDisplay.app
```

## 需要注意的地方

- 这个自动打包产物是临时签名，不是 Apple Developer ID 公证包。你自己使用没有问题，但第一次打开时 macOS 可能仍然会提示安全确认。
- 定时同步流程需要存在于 fork 的默认分支 `main`，GitHub 才会按计划自动运行。
- 如果同步时发生代码冲突，workflow 会失败并停在那里，需要人工处理冲突。
- 如果 GitHub 禁用了 Actions 创建 PR 的权限，同步流程可能只能推送分支，不能自动开 PR。遇到这种情况，在仓库设置里打开允许 Actions 创建 PR 的选项即可。
- 现在不会自动发布 Release。先用 Artifacts 更稳，等流程稳定后再加自动 Release。
