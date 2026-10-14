// SPDX-License-Identifier: GPL-2.0-or-later
import SwiftUI

/// Why an app will not run, or why it stopped, in words: from what the APK is (before it starts) and from what its run logged.
///
/// Before a start it answers the questions the files can: is this an app at all, does it have code for this iPhone's CPU, is a
/// part of it missing, does it carry protection that refuses to run anywhere but a certified Android phone. After a run it reads
/// the log for the line that ended it: a crash in one of the app's libraries, the app closing itself, an exception from its Java
/// code, a feature of Android that Husk does not have yet, Google Play services it cannot do without.
struct AppDiagnosis: Identifiable, Equatable {
    enum Kind: String {
        case badAPK, unsupportedCPU, missingSplits, protected, needsGoogle, missingFeature, javaCrash, nativeCrash, closedItself,
             missingFunction, noProgress
    }
    let id = UUID()
    let kind: Kind
    let title: String
    let detail: String
    /// The log line or report field it came from, for the curious and for bug reports.
    let evidence: String?
    /// A warning before launch that still lets the app be tried.
    var blocksLaunch: Bool { kind == .badAPK || kind == .unsupportedCPU }

    static func == (a: AppDiagnosis, b: AppDiagnosis) -> Bool { a.kind == b.kind && a.title == b.title && a.detail == b.detail }

    var symbol: String {
        switch kind {
        case .badAPK: return "doc.badge.ellipsis"
        case .unsupportedCPU: return "cpu"
        case .missingSplits: return "square.stack.3d.up.slash"
        case .protected, .closedItself: return "lock.shield"
        case .needsGoogle: return "person.crop.circle.badge.exclamationmark"
        case .missingFeature, .missingFunction: return "puzzlepiece"
        case .javaCrash, .nativeCrash: return "exclamationmark.triangle.fill"
        case .noProgress: return "hourglass"
        }
    }

    // MARK: before a start

    /// Libraries of commercial app protectors: they check the device and the app's own files, and stop the app off a real phone.
    private static let protectorLibraries = ["libjiagu", "libDexHelper", "libsecexe", "libsecmain", "libprotectClass", "libdexprotector",
                                             "libapp_shield", "libNSaferOnly", "libshell-super", "libtup", "libAppGuard", "libxloader",
                                             "libarmour", "libnesec", "libSecShell", "libkwscmm", "libmobisec",
                                             // seen in Play apps: ByteDance's metasec (TikTok, CapCut), Netflix's, Akamai's bot manager
                                             // (eBay), and games whose own library refuses uncertified devices (Clash Royale, HCR2)
                                             "libmetasec", "libcf2a", "libakamaibap", "libakamaibmp", "libk30d", "libsupercell_", "libfingersoft_hcr2", "libfp"]

    static func preflight(_ app: TLApp) -> AppDiagnosis? {
        guard let r = app.report else { return nil }
        if !r.ok || r.verdict == "unreadable" {
            return AppDiagnosis(kind: .badAPK, title: "无效的 APK",
                                detail: "此文件不是 Husk 可读取的应用" + (r.error.map { ": \($0)." } ?? ".")
                                    + " 文件可能损坏、下载不完整，或不是 Android 应用。",
                                evidence: r.error ?? r.summary)
        }
        if r.verdict == "noArm64" {
            return AppDiagnosis(kind: .unsupportedCPU, title: "不支持：CPU 架构不匹配",
                                detail: r.summary + " iPhone 使用 64 位 ARM 代码，请寻找 arm64 或通用版本。",
                                evidence: "架构：" + r.abis.joined(separator: ", "))
        }
        if app.apks.count == 1, let base = app.apks.first, husk_apk_split_required(base) != 0 {
            return AppDiagnosis(kind: .missingSplits, title: "应用不完整",
                                detail: "此应用包含多个拆分 APK，但仅导入了基础包，因此缺少库或"
                                    + "资源。请导入完整的 .apks、.xapk 或 .apkm，或从 Husk 商店下载。",
                                evidence: "manifest: split APKs required")
        }
        if let lib = r.libraries.first(where: { l in protectorLibraries.contains(where: { l.name.hasPrefix($0) }) }) {
            return AppDiagnosis(kind: .protected, title: "受保护的应用",
                                detail: "此应用包含防篡改保护（\(lib.name)）。保护机制会检测认证的"
                                    + "应用会检测真实 Android 手机，不符合时关闭，因此可能无法在 Husk 中运行。",
                                evidence: lib.name)
        }
        return nil
    }

    // MARK: after a run

    /// The reason a run stopped, from its log; nil when nothing in it explains the end (the app closed the normal way).
    static func fromLog(_ text: String) -> AppDiagnosis? {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)

        // A native crash: the runtime's crash handler names the library the bad instruction was in
        if let i = lines.lastIndex(where: { $0.contains("=== CRASH:") || $0.contains("*** FATAL SIGNAL") }) {
            let head = lines[i]
            let lib = lines[(i + 1)..<min(lines.count, i + 4)].compactMap { l -> String? in
                guard l.contains("pc ") else { return nil }
                return l.split(separator: " ").map(String.init).first { $0.hasSuffix(".so") || $0.contains(".so") }
            }.first
            let signal = head.range(of: "signal \\d+", options: .regularExpression).map { String(head[$0]) } ?? "致命信号"
            if let lib, !lib.hasPrefix("libhusk"), !lib.contains("Husk") {
                return AppDiagnosis(kind: .nativeCrash, title: "在 \(lib) 中崩溃",
                                    detail: "应用的原生代码（\(lib)）因 \(signal) 停止，可能"
                                        + "需要 Husk 暂未提供的 Android 功能，或执行了 iOS 不允许的操作。",
                                    evidence: head)
            }
            return AppDiagnosis(kind: .nativeCrash, title: "应用崩溃",
                                detail: "因 \(signal) 停止，报告包含此次运行的完整日志。", evidence: head)
        }

        // The app ended itself from native code: protection that found it is not on a certified phone, most of the time
        if let l = lines.last(where: { $0.contains("bionic: exit(") && $0.contains("called from") }),
           let code = l.range(of: "exit\\((\\d+)\\)", options: .regularExpression).map({ String(l[$0]) }), code != "exit(0)" {
            let lib = l.components(separatedBy: "called from ").last?.split(separator: " ").first.map(String.init) ?? "应用代码"
            return AppDiagnosis(kind: .closedItself, title: "应用拒绝在此运行",
                                detail: "\(lib) 主动关闭了应用（\(code)）。反作弊或防篡改保护在"
                                    + "检测到不是认证的 Android 手机时会退出，Husk 无法模拟其认证。",
                                evidence: l)
        }

        // Java: the exception that ended the app's main thread
        if let l = lines.last(where: { $0.contains("main thread ended with ") }) {
            let what = l.components(separatedBy: "main thread ended with ").last ?? l
            let name = String(what.prefix { $0 != ":" && $0 != " " })
            let short = name.split(separator: ".").last.map(String.init) ?? name
            let message = what.dropFirst(name.count).drop { $0 == ":" || $0 == " " }
            let firstPart = message.components(separatedBy: " | caused by").first ?? String(message)
            if ["NoSuchMethodError", "NoClassDefFoundError", "UnsatisfiedLinkError", "AbstractMethodError", "NoSuchFieldError",
                "IncompatibleClassChangeError"].contains(short) {
                return AppDiagnosis(kind: .missingFeature, title: "使用了 Husk 尚不支持的功能",
                                    detail: "应用需要 Husk 运行时尚未提供的 Android 功能：\(apiName(firstPart))。",
                                    evidence: l)
            }
            if what.localizedCaseInsensitiveContains("google play services") || what.contains("GooglePlayServices") {
                return googleDiagnosis(l)
            }
            return AppDiagnosis(kind: .javaCrash, title: "应用崩溃",
                                detail: "代码因 \(short) 停止" + (firstPart.isEmpty ? "." : ": \(firstPart.prefix(220))"),
                                evidence: l)
        }

        // Google Play services the app will not run without
        if let l = lines.last(where: { $0.contains("requires Google Play services") || $0.contains("Failed to fetch kids onboarding status")
                                        || $0.contains("GooglePlayServicesNotAvailableException") }),
           lines.contains(where: { $0.contains("the app finished") }) {
            return googleDiagnosis(l)
        }

        // An app whose work is done by Linux programs it starts as processes of their own (Winlator's and GameNative's Box64 and Wine,
        // a proot userland): its own screens run, the programs can not, as an iOS app may not start processes
        if let l = lines.first(where: { $0.contains("the app started a process:") }),
           ["box64", "box86", "wine", "proot", "/usr/bin/", "imagefs", "rootfs", "termux", "ld-linux"].contains(where: { l.localizedCaseInsensitiveContains($0) }) {
            let prog = l.components(separatedBy: "the app started a process: ").last?.components(separatedBy: " -- ").first ?? "程序"
            return AppDiagnosis(kind: .missingFeature, title: "将 Linux 程序作为独立进程运行",
                                detail: "此应用主要通过独立的 Linux 进程完成工作（此处为 \(prog.prefix(120))）。"
                                    + "应用界面可在 Husk 中运行，但 iOS 不允许应用启动其他进程，因此这些程序及其"
                                    + "运行的游戏或工具暂时无法启动。",
                                evidence: l)
        }

        // An app that only works signed in to a Google account: it asked Android's account picker, got none, and closed
        if let l = lines.last(where: { $0.contains("ChooseTypeAndAccountActivity") || $0.contains("AccountManager.newChooseAccountIntent") }),
           lines.contains(where: { $0.contains("the app finished") }) {
            return AppDiagnosis(kind: .needsGoogle, title: "需要 Google 账号",
                                detail: "此应用必须登录 Google 账号。它请求 Android 选择账号，但 Husk 没有可提供的 Google"
                                    + "账号，因此应用退出。",
                                evidence: l)
        }

        // A game whose data comes as an expansion file the store did not install
        if let l = lines.first(where: { $0.contains("expansion file (OBB) is missing") }) {
            return AppDiagnosis(kind: .missingSplits, title: "缺少游戏数据",
                                detail: "此游戏的大部分数据位于 Play 商店单独下载的 OBB 扩展文件中，"
                                    + "Husk 已安装应用，但未安装该文件，因此无法加载游戏。",
                                evidence: l)
        }

        // Video that only plays with DRM keys
        if let l = lines.first(where: { $0.contains("Husk 无法解密受保护的媒体") }) {
            return AppDiagnosis(kind: .protected, title: "不支持受保护的视频",
                                detail: "此应用的视频使用 Widevine DRM 保护，仅认证的 Android 设备能够解密。"
                                    + "未受保护的视频可以播放，受保护视频会保持黑屏。",
                                evidence: l)
        }

        // A function of Android's C library or system libraries that was never written for Husk
        if let l = lines.first(where: { $0.contains("CALLED an unresolved import: ") }), lines.contains(where: { $0.contains("the app finished") || $0.contains("CRASH") }) {
            let fn = l.components(separatedBy: "unresolved import: ").last?.split(separator: " ").first.map(String.init) ?? "?"
            return AppDiagnosis(kind: .missingFunction, title: "使用了 Husk 尚不支持的功能",
                                detail: "应用调用了 Husk 尚未提供的系统函数 \(fn)。", evidence: l)
        }
        return nil
    }

    private static func googleDiagnosis(_ line: String) -> AppDiagnosis {
        AppDiagnosis(kind: .needsGoogle, title: "需要 Google Play 服务",
                     detail: "此应用对 Google Play 服务（登录、账号与设备检查）的需求超出了 Husk"
                        + "能够提供的范围。仅调用 Google 库的应用可以运行，但此应用需要真实服务。",
                     evidence: line)
    }

    /// "android/os/StrictMode$ThreadPolicy$Builder.penaltyListener(...)" as "StrictMode.ThreadPolicy.Builder.penaltyListener".
    private static func apiName(_ s: String) -> String {
        var t = s.components(separatedBy: "(").first ?? s
        t = t.replacingOccurrences(of: "No implementation found for ", with: "")
        t = t.replacingOccurrences(of: "$", with: ".")
        let parts = t.split(separator: "/").map(String.init)
        return (parts.count > 1 ? parts.suffix(2).joined(separator: ".") : t).trimmingCharacters(in: .whitespaces)
    }
}

/// A diagnosis, as a card: on an app's page before it starts, and over an app's screen when it stops.
struct AppDiagnosisCard: View {
    let diagnosis: AppDiagnosis
    var showsEvidence = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: diagnosis.symbol)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(diagnosis.blocksLaunch ? .red : .orange)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStringKey(diagnosis.title)).font(.subheadline.weight(.semibold))
                Text(LocalizedStringKey(diagnosis.detail)).font(.footnote).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                if showsEvidence, let e = diagnosis.evidence {
                    Text(e).font(.system(size: 10.5, design: .monospaced)).foregroundStyle(.secondary)
                        .lineLimit(4).textSelection(.enabled).padding(.top, 2)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Over an app's screen when its run ends with a reason: what happened, and the way out.
struct AppStoppedOverlay: View {
    let app: TLApp
    let diagnosis: AppDiagnosis
    let close: () -> Void
    @State private var report: URL?

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 14) {
                Text(app.label).font(.footnote.weight(.semibold)).foregroundStyle(.secondary)
                AppDiagnosisCard(diagnosis: diagnosis, showsEvidence: true)
                HStack(spacing: 10) {
                    if let report {
                        ShareLink(item: report) { Label("分享报告", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity) }
                            .buttonStyle(.bordered)
                    }
                    Button(action: close) { Text("关闭").frame(maxWidth: .infinity) }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(18)
            .frame(maxWidth: 440)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(24)
        }
        .task { report = AppDiagnosis.writeReport(app: app, diagnosis: diagnosis) }
    }
}

extension AppDiagnosis {
    /// The run that just ended, in one text file to share: the reason, the app, this device, and the runtime's log of the run.
    @MainActor static func writeReport(app: TLApp, diagnosis d: AppDiagnosis) -> URL? {
        let info = Bundle.main.infoDictionary ?? [:]
        var text = """
        Husk app report
        ===============
        App      : \(app.label) (\(app.packageName ?? "?"))
        What     : \(d.title)
        Why      : \(d.detail)
        Evidence : \(d.evidence ?? "-")
        Husk     : \(info["CFBundleShortVersionString"] as? String ?? "?") (\(info["CFBundleVersion"] as? String ?? "?"))
        Device   : \(HuskLog.deviceModel), \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
        APKs     : \(app.apks.map { ($0 as NSString).lastPathComponent }.joined(separator: ", "))
        Engine   : \(app.report?.runnerName ?? "?")

        ---- log of the run ----

        """
        if let c = husk_tl_attempt_log() { text += String(cString: c); free(c) }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Husk 应用报告 - \(app.label.replacingOccurrences(of: "/", with: "-")).txt")
        do { try text.write(to: url, atomically: true, encoding: .utf8) } catch { return nil }
        return url
    }

    /// When a run has ended: why, from its log (nil when it closed the normal way).
    static func ofCurrentRun() -> AppDiagnosis? {
        guard let c = husk_tl_attempt_log() else { return nil }
        defer { free(c) }
        return fromLog(String(cString: c))
    }
}
