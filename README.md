# Launchpad2

在 Mac 上找回熟悉的 Launchpad：打开面板，输入应用名称，按下回车；也可以把常用应用排好位置、收进文件夹。

支持 **macOS 11 及以上**，提供 Apple Silicon 和 Intel 通用版。

## 下载与安装

1. 前往 [最新版本](https://github.com/xxxxxnus/launchpad2/releases/latest)。
2. Apple Silicon Mac（M1 及更新芯片）下载 `Launchpad2-1.0.0-arm64.zip`；Intel Mac 或需要兼容两种芯片时，下载 `Launchpad2-1.0.0-universal.zip`。
3. 解压，把 **Launchpad2.app** 拖进「应用程序」，然后双击打开。
4. 按 **Control + Option + Space**，随时打开或收起面板。也可以把 Launchpad2 拖进 Dock，通过点击打开。

目前安装包使用本地签名，尚未经过 Apple 公证。如果 macOS 阻止首次打开，请在尝试打开后进入「系统设置 → 隐私与安全性」选择「仍要打开」，按系统提示确认。

## 日常使用

| 想做什么 | 操作 |
| --- | --- |
| 查找应用 | 打开面板后直接输入名称，支持中文和模糊搜索，也能找到文件夹里的应用 |
| 打开应用 | 点击图标，或用方向键选择后按 Return |
| 翻页 | 双指水平滑动、鼠标滚轮、点击分页圆点，或 Command + 左 / 右方向键 |
| 收起面板 | 再按快捷键、点击空白，或按 Esc；Esc 会先退出文件夹、清空搜索或结束整理 |
| 调整图标位置 | 拖动图标；拖到屏幕左右边缘并停留可移到另一页 |
| 新建文件夹 | 把图标拖到另一个图标的中心 |
| 管理文件夹 | 点击打开，点击标题重命名；拖动内部图标排序，拖出面板移回主界面 |
| 撤销整理 | Command + Z；Shift + Command + Z 重做 |
| 隐藏应用 | 右键图标选择「隐藏应用」；菜单栏「恢复隐藏应用」可全部恢复 |
| 修改快捷键 | 点击面板右上角「设置」，或按 Command + 逗号 |
| 退出程序 | 菜单栏选择「退出 Launchpad2」 |

布局、文件夹名称和隐藏状态会自动保存。每次打开面板都会重新查找已安装的应用。隐藏图标不会卸载应用；把应用拖到 Dock 所在边缘可以固定到 Dock，也可以继续拖向废纸篓，此时会请求系统回收该应用。

## 触控板手势

面板内可双指滑动翻页、展开捏合收起。在「设置」中还可以开启**五指收拢打开、展开关闭**，并调整触发幅度；每次动作后先抬起手指。

五指功能默认关闭，属于实验功能，使用非公开的系统触控接口，可能因设备或系统版本而不可用。暂未完成 Apple Silicon 最新系统的真机手势验证，快捷键入口始终可用。

如果希望使用四指捏合，可在自己的手势工具中绑定「打开 Launchpad2.app」或 URL `launchpad2://open`。Launchpad2 本身不接管 macOS 的系统四指手势。

## 常见问题

**新安装的应用没有出现？**

重新打开面板，或在菜单栏选择「重新扫描应用」。支持系统与用户的 Applications 目录及其中的应用子目录。

**快捷键没有响应？**

从菜单栏打开「设置」，换一个组合键。被其他应用占用的组合可能无法注册。

**如何重置图标布局？**

先退出 Launchpad2，在 Finder 的「前往文件夹」中输入 `~/Library/Application Support/Launchpad2/`，备份或删除 `layout.v1`，再重新打开。

**这是系统 Launchpad 的替代品吗？**

它是独立的应用启动器，不会修改系统 Launchpad 数据库，也不导入系统已有布局。目前不提供 App Store 专属卸载和完整的 VoiceOver 图标导航。

## 从源码构建

需要 Rust 1.87+ 和 Xcode Command Line Tools，在 macOS 上执行：

```sh
cargo test --locked
cargo clippy --locked --all-targets -- -D warnings
./scripts/build-app.sh native
```

构建 Apple Silicon 与 Intel 通用安装包：

```sh
rustup target add aarch64-apple-darwin x86_64-apple-darwin
./scripts/build-app.sh universal
```

应用和带版本号的 ZIP 输出到 `dist/`。

遇到问题或有功能建议，欢迎提交 [Issue](https://github.com/xxxxxnus/launchpad2/issues)，请附上 macOS 版本、芯片型号和复现步骤。
