import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers
import DustWaveDiagnostics
import DustWaveUpdates

// Only these event categories are retained. Never put paths, names, raw errors or settings JSON in logs.
enum PaperLogEvent: String, Codable { case launch, loginLaunch, cleanQuit, toggled, importFailed, operationFailed, recovery, shortcutUnavailable, sleep, wake, displaysChanged, powerChanged }

struct PaperDiagnosticReport: Codable {
    var schema = "paper-diagnostic-v1"
    var id = UUID().uuidString.lowercased()
    var kind = "current_state"
    struct Application: Codable { var version: String; var build: String; var operatingSystem: String; var architecture = "arm64" }
    struct State: Codable {
        var enabled: Bool; var pause: String; var textureSource: String; var intensityBucket: Int
        var displays: Int; var excludedDisplays: Int; var floatingPanelsClear: Bool
        var battery: Bool; var lowPower: Bool; var schedule: String; var appRule: String
        var events: [PaperLogEvent]
    }
    var application: Application
    var state: State
    var crash: NativeCrashSummary?

    @MainActor static func snapshot(_ state: PaperState, bundle: Bundle = .main) -> Self {
        let os = ProcessInfo.processInfo.operatingSystemVersion
        let pause: String
        switch state.pauseReason {
        case .disabled: pause = "disabled"
        case .displayExcluded: pause = "display_excluded"
        case .comparing: pause = "comparing"
        case .snoozed, .presentation: pause = "snoozed" // Keep the deployed v1 relay contract.
        case .applicationExcluded: pause = "app_excluded"
        case .applicationNotIncluded: pause = "app_not_included"
        case .battery, .lowBattery: pause = "battery"
        case .lowPower: pause = "low_power"
        case .outsideSchedule: pause = "schedule"
        case nil: pause = "none"
        }
        return Self(application: .init(version: NativeCrashSummary.numericVersion(bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString")),
            build: NativeCrashSummary.numericVersion(bundle.object(forInfoDictionaryKey: "CFBundleVersion")),
            operatingSystem: "\(os.majorVersion).\(os.minorVersion).\(os.patchVersion)"),
            state: .init(enabled: state.settings.enabled, pause: pause,
                textureSource: state.customPapers.contains { $0.id == state.texture.id } ? "imported" : "bundled",
                intensityBucket: min(9, max(0, Int(state.appearance.intensity * 20))),
                displays: min(16, state.displayChoices.count),
                excludedDisplays: min(16, state.displayChoices.filter { state.settings.disabledDisplays.contains($0.id) }.count),
                floatingPanelsClear: !state.excludedPanelLevels.isEmpty,
                battery: state.onBattery, lowPower: state.lowPower,
                schedule: state.settings.schedule.enabled ? state.settings.schedule.mode.rawValue : "disabled",
                appRule: state.settings.appRuleMode.rawValue, events: state.diagnosticEvents))
    }
    mutating func includeCrash(_ data: Data) throws {
        let summary = try NativeCrashSummary.project(data, bundleID: "xyz.dustwave.paper", processNames: ["Paper"],
            images: ["Paper", "Sparkle", "SwiftUI", "SwiftUICore", "AppKit", "QuartzCore", "Metal", "libswiftCore.dylib", "libsystem_kernel.dylib"])
        crash = summary; kind = "native_crash"
        application.version = summary.version; application.build = summary.build; application.operatingSystem = summary.operatingSystem
    }
    func encoded() throws -> Data {
        let versionValues = [application.version, application.build, application.operatingSystem]
        guard schema == "paper-diagnostic-v1", UUID(uuidString: id)?.uuidString.lowercased() == id,
              ["current_state", "native_crash"].contains(kind), application.architecture == "arm64",
              versionValues.allSatisfy({ NativeCrashSummary.numericVersion($0) == $0 }),
              ["none", "disabled", "display_excluded", "comparing", "snoozed", "app_excluded", "app_not_included", "battery", "low_power", "schedule"].contains(state.pause),
              ["bundled", "imported"].contains(state.textureSource), (0...9).contains(state.intensityBucket),
              (0...16).contains(state.displays), (0...state.displays).contains(state.excludedDisplays),
              ["disabled", "fixed", "sunsetToSunrise", "sunriseToSunset"].contains(state.schedule),
              ["except", "only"].contains(state.appRule), state.events.count <= 20 else { throw ReportDeliveryError.invalidReport }
        if kind == "native_crash" {
            guard let crash, NativeCrashSummary.exceptions.contains(crash.exception),
                  crash.signal.map(NativeCrashSummary.signals.contains) ?? true,
                  crash.image.map({ ["Paper", "Sparkle", "SwiftUI", "SwiftUICore", "AppKit", "QuartzCore", "Metal", "libswiftCore.dylib", "libsystem_kernel.dylib"].contains($0) }) ?? true,
                  crash.imageOffset.map({ (0...1_000_000_000).contains($0) }) ?? true,
                  (crash.image == nil) == (crash.imageOffset == nil),
                  crash.version == application.version, crash.build == application.build,
                  crash.operatingSystem == application.operatingSystem else { throw ReportDeliveryError.invalidReport }
        } else if crash != nil { throw ReportDeliveryError.invalidReport }

        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(self)
        guard data.count <= 8192, UUID(uuidString: id) != nil else { throw ReportDeliveryError.invalidReport }
        return data
    }
}

@MainActor final class PaperDiagnostics: ObservableObject {
    static let endpoint = URL(string: "https://crash.dustwave.xyz/v1/paper/reports")!
    @Published private(set) var preview = ""
    @Published private(set) var sending = false
    @Published private(set) var status = "Review the report before sending."
    @Published private(set) var issueURL: URL?
    private let state: PaperState
    let updates: AppUpdateController
    private var report: PaperDiagnosticReport?
    private var bytes: Data?
    var canSend: Bool { bytes != nil && !sending && Bundle.main.bundleIdentifier == "xyz.dustwave.paper" && !PaperState.isTestRun }
    init(state: PaperState, updates: AppUpdateController) { self.state = state; self.updates = updates }
    func prepare() {
        guard !sending else { return }
        if let saved = state.pendingDiagnostic, let previous = try? JSONDecoder().decode(PaperDiagnosticReport.self, from: saved),
           previous.schema == "paper-diagnostic-v1", let bytes = try? previous.encoded() {
            report = previous; self.bytes = bytes; preview = String(decoding: bytes, as: UTF8.self)
        } else { refresh() }
    }
    func refresh() {
        guard !sending else { return }
        setReport(.snapshot(state)); issueURL = nil; status = "Review the report before sending."
    }
    private func setReport(_ report: PaperDiagnosticReport) {
        do {
            let data = try report.encoded()
            self.report = report; bytes = data; preview = String(decoding: data, as: UTF8.self)
            state.pendingDiagnostic = data
        } catch { status = "Could not prepare the report." }
    }
    func importCrash(window: NSWindow?) {
        guard !sending, let window else { return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [UTType(filenameExtension: "ips") ?? .json]
        panel.canChooseDirectories = false
        panel.message = "Choose a Paper .ips crash report up to 2 MB. Only the filtered summary below can be sent."
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let self, let url = panel.url else { return }
            do {
                guard url.pathExtension.lowercased() == "ips" else { throw ReportDeliveryError.invalidReport }
                var report = PaperDiagnosticReport.snapshot(self.state)
                try report.includeCrash(BoundedJSONFile.read(url, maximumBytes: 2_097_152))
                self.setReport(report); self.issueURL = nil; self.status = "Crash summary ready for review. The raw file stays on your Mac."
            } catch { self.status = "Choose a valid Paper .ips crash report no larger than 2 MB." }
        }
    }
    func export(window: NSWindow?) {
        guard !sending, let bytes, let window else { return }
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "Paper-diagnostic.json"
        panel.beginSheetModal(for: window) { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            do { try bytes.write(to: url, options: .atomic); self?.status = "Report saved locally." }
            catch { self?.status = "Could not save the report. Choose another location." }
        }
    }
    func send() {
        guard canSend, let bytes, let report, let id = UUID(uuidString: report.id) else { return }
        sending = true; updates.busy = true; status = "Sending the reviewed report…"
        Task {
            defer { sending = false; updates.busy = false }
            do {
                let receipt = try await ReviewedReportClient().send(bytes, reportID: id, endpoint: Self.endpoint)
                issueURL = URL(string: "https://github.com/aindaco1/paper/issues/\(receipt.issueNumber)")
                status = receipt.duplicate ? "This report was already received. Its count is unchanged." : "Report received. Matching reports share the same issue."
            } catch { status = "Delivery was not confirmed. Retry sends this same report without counting it twice." }
        }
    }
}

struct PaperDiagnosticsView: View {
    @ObservedObject var model: PaperDiagnostics
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Help & diagnostics").font(.title2)
            Text("Review a filtered report, save it locally, or send it to Paper’s public GitHub issues. Matching reports are grouped together.")
                .fixedSize(horizontal: false, vertical: true)
            Text("Includes app/system versions, broad overlay state, recent event categories and an optional crash summary. Excludes app names, display IDs, city, paths, recipe contents and raw logs.")
                .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            ScrollView { Text(model.preview).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading).padding(12) }
                .frame(height: 260).background(.quaternary, in: RoundedRectangle(cornerRadius: 8)).accessibilityLabel("Report preview")
            Text(model.status).font(.callout).fixedSize(horizontal: false, vertical: true).accessibilityIdentifier("paper.reportStatus")
            if let url = model.issueURL { Link("View GitHub issue", destination: url) }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Group {
                    Button("Refresh") { model.refresh() }
                    Button("Import crash log…") { model.importCrash(window: NSApp.keyWindow) }
                    Button("Save report…") { model.export(window: NSApp.keyWindow) }
                }.disabled(model.sending)
                Spacer(minLength: 16)
                Button("Send to public GitHub issues") { model.send() }
                    .disabled(!model.canSend).buttonStyle(.borderedProminent)
            }.controlSize(.regular)
        }.padding(24).frame(width: 640).onAppear { model.prepare() }
    }
}
