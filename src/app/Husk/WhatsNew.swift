// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

// MARK: - what's new

/// What this version brought, shown once after updating to it (not on a first install: onboarding is the welcome then).
enum WhatsNew {
    struct Item: Identifiable {
        let symbol: String
        let title: String
        let detail: String
        var id: String { title }
    }

    /// The version whose notes these are. A build of the same version shows nothing again.
    static let version = "1.0.1"
    static let items: [Item] = [
        Item(symbol: "bag.fill", title: "Google Play",
             detail: "从商店页获取游戏。Play 商店下载的拆分 APK 和资源包可通过翻译层运行。"),
        Item(symbol: "checkmark.seal.fill", title: "Google Play 服务",
             detail: "游戏会认为 Play 服务已安装但尚未登录，从而继续运行。"),
        Item(symbol: "arrow.up.doc.fill", title: "存档备份",
             detail: "在游戏详情页将存档备份为 .zip，以后可在本机或其他设备恢复。"),
        Item(symbol: "exclamationmark.bubble.fill", title: "崩溃报告",
             detail: "游戏导致 Husk 崩溃后，下次启动会显示原因并提供可分享的报告。"),
        Item(symbol: "checkmark.circle.fill", title: "了解兼容情况",
             detail: "库会标记游戏上次的运行情况：可游玩、崩溃或未能启动。"),
        Item(symbol: "gamecontroller.fill", title: "Godot 游戏",
             detail: "使用 Godot 3 和 4 制作的游戏现已支持翻译层运行。"),
        Item(symbol: "slider.horizontal.below.square.and.square.filled", title: "自定义控制布局",
             detail: "为每个游戏单独移动、调整大小或隐藏屏幕虚拟手柄按钮。"),
        Item(symbol: "keyboard.fill", title: "在 Minecraft 中输入文字",
             detail: "聊天、告示牌和世界名称输入框会呼出键盘。"),
        Item(symbol: "arrow.left.arrow.right", title: "切换游戏",
             detail: "关闭 Husk 后即可切换游戏；重新打开时会自动启动所选游戏。"),
        Item(symbol: "puzzlepiece.extension.fill", title: "Geode",
             detail: "在游戏设置中开启 Geometry Dash 模组，支持 Geode 5。"),
    ]

    private static let seenKey = "husk.whatsNew.seen"

    /// Whether to show the notes now: an update to this version, not a new install.
    static var due: Bool {
        let seen = UserDefaults.standard.string(forKey: seenKey)
        if seen == version { return false }
        if Onboarding.needed { markSeen(); return false }       // a first install: onboarding welcomes them
        return true
    }

    static func markSeen() { UserDefaults.standard.set(version, forKey: seenKey) }
}

struct WhatsNewSheet: View {
    var done: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Husk \(WhatsNew.version) 更新内容").font(.largeTitle.weight(.bold))
                        Text("首个完整版本。").foregroundStyle(.secondary)
                    }
                    .padding(.top, 36)
                    ForEach(WhatsNew.items) { item in
                        HStack(alignment: .top, spacing: 16) {
                            Image(systemName: item.symbol)
                                .font(.system(size: 26))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(LocalizedStringKey(item.title)).font(.headline)
                                Text(LocalizedStringKey(item.detail)).font(.subheadline).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 20)
            }
            Button(action: done) {
                Text("继续").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 28)
            .padding(.vertical, 18)
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - a newer Husk

/// A newer Husk on GitHub: the releases page is asked at launch (at most twice a day) and the person is told once per release.
@MainActor
final class AppUpdates: ObservableObject {
    static let shared = AppUpdates()

    struct Release: Equatable {
        let version: String
        let page: URL
    }

    @Published var available: Release?

    private static let api = URL(string: "https://api.github.com/repos/Leviidev/Husk/releases/latest")!
    private static let checkedKey = "husk.updates.checked", dismissedKey = "husk.updates.dismissed"

    static var current: String { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0" }

    func check() async {
        let d = UserDefaults.standard
        if Date().timeIntervalSince1970 - d.double(forKey: Self.checkedKey) < 12 * 3600 { return }
        var req = URLRequest(url: Self.api)
        req.timeoutInterval = 20
        req.setValue("Husk", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String,
              let page = (obj["html_url"] as? String).flatMap(URL.init(string:)) else { return }
        d.set(Date().timeIntervalSince1970, forKey: Self.checkedKey)
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard Self.newer(version, than: Self.current), d.string(forKey: Self.dismissedKey) != version else { return }
        HuskLog.log("update", "Husk \(version) is out (this is \(Self.current))")
        available = Release(version: version, page: page)
    }

    func dismiss() {
        if let v = available?.version { UserDefaults.standard.set(v, forKey: Self.dismissedKey) }
        available = nil
    }

    /// "1.0.10" is newer than "1.0.9": compared number by number.
    static func newer(_ a: String, than b: String) -> Bool {
        let x = a.split(separator: ".").map { Int($0) ?? 0 }, y = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}
