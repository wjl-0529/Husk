// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

/// The FAQ tab: common problems and what to do about them, so a user stuck on JIT or on an app
/// that will not open has an answer without leaving Husk.
struct FAQTab: View {
    @State private var query = ""

    private var sections: [FAQ.Section] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return FAQ.sections }
        return FAQ.sections.compactMap { s in
            let items = s.items.filter { $0.question.localizedCaseInsensitiveContains(q) || $0.answer.localizedCaseInsensitiveContains(q) }
            return items.isEmpty ? nil : FAQ.Section(title: s.title, symbol: s.symbol, items: items)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(sections) { s in
                    Section {
                        ForEach(s.items) { item in FAQRow(item: item, expanded: !query.isEmpty) }
                    } header: {
                        Label(LocalizedStringKey(s.title), systemImage: s.symbol)
                    }
                }
                if sections.isEmpty {
                    Text("没有匹配“\(query)”的内容。打开“设置 › 关于 › 打开控制台”查看 Husk 的运行状态。")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("常见问题")
            .searchable(text: $query, prompt: "搜索问题")
        }
    }
}

private struct FAQRow: View {
    let item: FAQ.Item
    var expanded: Bool
    @State private var open = false

    var body: some View {
        DisclosureGroup(isExpanded: Binding(get: { open || expanded }, set: { open = $0 })) {
            Text(.init(item.answer))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 4)
        } label: {
            Text(LocalizedStringKey(item.question)).font(.body.weight(.medium))
        }
    }
}

enum FAQ {
    struct Item: Identifiable {
        let question: String
        let answer: String
        var id: String { question }
        init(question: String, answer: String) {
            self.question = NSLocalizedString(question, comment: "FAQ question")
            self.answer = NSLocalizedString(answer, comment: "FAQ answer")
        }
    }
    struct Section: Identifiable { let title: String; let symbol: String; let items: [Item]; var id: String { title } }

    static let sections: [Section] = [
        Section(title: "JIT", symbol: "bolt.fill", items: [
            Item(question: "JIT 是什么？Husk 为什么需要它？",
                 answer: "Android 应用和游戏在运行时会编译代码，因此需要可写且可执行的内存。iOS 仅在调试器连接到应用时允许这样做；开启 JIT 就是临时连接调试器。不启用 JIT 时，可以浏览应用库，但无法启动 Android 或游戏。"),
            Item(question: "应该使用哪种 JIT 开启方式？",
                 answer: "• **iOS 27 或更高版本：**设置 › JIT › 在此 iPhone 上配对，无需电脑。\n• **iOS 26：**使用内置 StikJIT、在电脑上生成的配对文件以及 LocalDevVPN。\n• **更早的 iOS 或 LiveContainer 内的 Husk：**使用 StikDebug。\n• **通过 TrollStore 安装：**使用 TrollStore，并开启 URL Scheme。\n• **Dopamine 越狱：**在越狱设置中允许应用使用 JIT。"),
            Item(question: "StikJIT 无法连接或开启 JIT 失败",
                 answer: "1. 确认已安装并连接 **LocalDevVPN**，状态栏应显示 VPN 图标。\n2. 开启 Wi-Fi，即使通信仅发生在本机。\n3. 开启 **开发者模式**（设置 › 隐私与安全性 › 开发者模式）。\n4. 首次使用会下载 Apple 的开发者磁盘映像，请等待完成。\n5. 仍然失败？重新连接 LocalDevVPN，然后重新配对。"),
            Item(question: "开发者模式中没有“与 Husk 配对”",
                 answer: "先在 Husk 中点击 **开始配对**，并允许 **本地网络** 访问。如果之前拒绝，请到设置 › 隐私与安全性 › 本地网络 › Husk 开启。Wi-Fi 必须开启；首次启用开发者模式需要重启 iPhone。"),
            Item(question: "配对文件失效了",
                 answer: "重置 iPhone 的信任设置后，配对文件会失效；部分 iOS 更新也可能导致失效。请重新生成文件，或在 iOS 27 上直接在 iPhone 配对，然后在设置 › JIT 中重新导入。"),
            Item(question: "StikDebug 打开了，但 JIT 仍未开启",
                 answer: "单独打开 StikDebug，确认已导入配对文件，并且 LocalDevVPN 已连接。将 StikDebug 更新到最新版本。Husk 会自动发送 JIT 脚本，无需在 StikDebug 中为 Husk 单独配置。"),
            Item(question: "为什么需要再次开启 JIT？",
                 answer: "JIT 仅在 Husk 运行期间有效。iOS 在后台关闭 Husk 或你从应用切换器划掉它后，下次启动需要重新开启 JIT。完成本机配对或导入配对文件后，只需点击一次。"),
            Item(question: "不启用 JIT 可以使用 Husk 吗？",
                 answer: "可以浏览和导入应用，但无法运行 Android 内容。所有游戏和应用都需要 JIT。"),
        ]),
        Section(title: "Husk 本身", symbol: "app.badge", items: [
            Item(question: "Husk 完全无法打开",
                 answer: "• **打开后立即退出：**签名证书可能已过期，免费 Apple 账号的签名有效期为 7 天。用侧载工具重新签名或安装，应用和存档会保留。\n• **不受信任的开发者：**到设置 › 通用 › VPN 与设备管理中信任证书。\n• **要求开发者模式：**在设置 › 隐私与安全性中开启。"),
            Item(question: "游玩时 Husk 退出了",
                 answer: "再次打开 Husk 会显示原因，并提供可分享的报告。通常是内存不足或遇到尚不支持的功能。关闭其他应用；若反复发生，请分享报告。"),
            Item(question: "如何获取日志来反馈问题？",
                 answer: "打开库中的应用详情，点击 **分享报告**。Husk 自身的日志位于设置 › 关于 › **打开控制台**。开启 **开发者信息** 可以获得更多细节。"),
            Item(question: "如何更新 Husk？",
                 answer: "新版本发布时 Husk 会提醒你。使用同一侧载工具安装新 IPA 并覆盖旧版本，应用库、应用和存档会保留。"),
        ]),
        Section(title: "应用与游戏", symbol: "gamecontroller.fill", items: [
            Item(question: "应用无法打开",
                 answer: "打开库中的应用详情，查看停止原因：\n• **受保护的应用：**检查真实 Android 设备，或使用反作弊、DRM；Husk 不会绕过这些机制。\n• **CPU 架构不匹配：**APK 只有 32 位代码，请寻找 arm64-v8a 版本。\n• **应用不完整或缺少数据：**需要拆分 APK 或 OBB，请导入完整的 .apks、.xapk 或 .apkm。\n• **需要 Google：**应用需要 Husk 无法提供的 Google 账号或 Play 服务。\n• **缺少功能：**请分享报告，以便后续支持。"),
            Item(question: "屏幕一直黑屏",
                 answer: "大型游戏首次启动需要准备代码和数据，可能耗时一分钟。如果仍然黑屏，请关闭后再打开；问题不变时请分享报告。"),
            Item(question: "修改版或重新打包的 APK 崩溃",
                 answer: "APKVISION 等网站的重新打包版本可能改写代码或增加防篡改检查，因此更容易出问题。请尝试开发者或 APKMirror 提供的原版 APK。"),
            Item(question: "可以导入哪些文件？",
                 answer: "支持 .apk 以及 .apks、.xapk、.apkm 拆分包。可以分享到 Husk、从“文件”打开，或点击库中的 + 按钮导入。"),
            Item(question: "游戏运行缓慢或手机发热",
                 answer: "关闭其他应用，并让手机降温。游戏以原生方式运行，但部分 Android 硬件承担的工作会由 CPU 执行。低电量模式也会降低 Husk 的速度。"),
            Item(question: "可以使用手柄吗？",
                 answer: "可以。在 iPhone 的蓝牙设置中连接手柄，支持手柄的游戏即可识别。"),
            Item(question: "游戏运行时可以继续使用 Husk 吗？",
                 answer: "在设置中开启 **在窗口中打开应用**。应用会在可移动、调整大小和最小化的窗口中运行。"),
            Item(question: "无法使用 Google 登录",
                 answer: "Husk 不包含 Google Play 服务，因此“使用 Google 登录”可能失败。如果应用支持，请改用邮箱或其他登录方式。"),
        ]),
        Section(title: "存档与存储", symbol: "externaldrive.fill", items: [
            Item(question: "我的存档在哪里？",
                 answer: "各应用的数据保存在 Husk 内。在应用详情中使用 **备份存档** 导出，使用 **恢复存档** 导入，也可以恢复到另一部 iPhone。"),
            Item(question: "Husk 占用了大量存储空间",
                 answer: "导入的应用及数据都在 Husk 文件夹中。可在详情页移除不再游玩的游戏。完整 Android 系统额外占用约 2 GB，仅运行 Android 本身时需要。"),
        ]),
        Section(title: "Android", symbol: "cpu", items: [
            Item(question: "应用运行与 Android 系统有什么区别？",
                 answer: "大多数应用和游戏直接在 iPhone 上运行，如同原生应用。完整 Android 系统是独立且较慢的选项，用于必须在真实 Android 环境中运行的内容。"),
            Item(question: "Android 启动很慢",
                 answer: "首次启动需要下载 Android 映像并从头开机，可能耗时数分钟。之后 Husk 会恢复已保存的机器状态，速度更快。"),
        ]),
    ]
}
