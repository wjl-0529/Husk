# Husk 简体中文本地化

本版本新增 607 条中文本地化资源，涵盖主要导航、设置、应用详情、下载、JIT 引导和 24 项常见问题。中文系统自动选择简体中文，其他语言保留英文回退。游戏本身、Android 系统、网络返回的应用简介和底层诊断日志不由这些资源翻译；部分动态状态与长说明仍可能显示英文。

## GitHub Actions 打包

1. 将修改提交到你自己的 Husk Fork 的 main 分支；工作流会自动启动。也可以进入 Actions → Build Chinese Husk IPA → Run workflow 手动启动。
2. 工作流使用 macOS、最新稳定版 Xcode，并要求 iOS SDK 26 或更高版本，因为项目内置的 JIT 扩展需要它。
3. 首次构建需下载并编译 QEMU、ANGLE、MoltenVK 和 Rust 配对库，可能耗时数小时。
4. 构建成功后，进入该次运行的 Artifacts 下载 `Husk-zh-Hans`，解压后获得 IPA 和 TIPA。构建失败时可下载 `build-logs` 排查。
5. IPA 通过 SideStore、AltStore 等侧载工具重新签名安装；TIPA 用于 TrollStore 支持的设备。

## 验证状态

本地已检查中文资源语法、重复键、FAQ 对应关系及工作流配置。当前电脑为 Windows，无法执行 Xcode 编译或 iPhone 界面验证。云端工作流尚未运行，因此此源码包不包含已验证可安装的 IPA。

原项目没有 Actions 工作流。构建依赖脚本沿用上游；实际云端运行可能暴露上游依赖下载或新工具链兼容问题，需要根据日志修复。

许可证沿用 GPL-2.0-or-later，详见 LICENSE。上游：https://github.com/Leviidev/Husk
