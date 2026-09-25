import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PaperCore
import DustWaveUpdates

struct PaperView: View {
    @ObservedObject var state: PaperState
    @ObservedObject var updates: AppUpdateController
    let showDiagnostics: () -> Void
    @State private var choosingFile = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 14) {
                Image(systemName: "doc.text")
                    .font(.system(size: 29, weight: .light))
                    .frame(width: 50, height: 54)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Paper").font(.system(size: 26, weight: .semibold, design: .serif))
                    Text(state.status).font(.callout).foregroundStyle(.secondary)
                        .accessibilityIdentifier("paper.status")
                }
                Spacer()
                Toggle("Enable Paper", isOn: Binding(get: { state.settings.enabled }, set: { _ in state.toggle() }))
                    .toggleStyle(.switch).labelsHidden()
                    .accessibilityIdentifier("paper.enabled")
            }.padding(22)

            Form {
                Section("Your paper") {
                    Picker("Texture", selection: Binding(get: { state.texture.id }, set: { try? state.selectTexture($0) })) {
                        if !state.favoriteTextures.isEmpty {
                            Section("Favorites") {
                                ForEach(state.favoriteTextures) { texture in Text(texture.name).tag(texture.id) }
                            }
                        }
                        Section("All papers") {
                            ForEach(state.otherTextures) { texture in Text(texture.name).tag(texture.id) }
                        }
                    }.accessibilityIdentifier("paper.texture")
                    LibraryControls(state: state)
                    if state.settings.automaticLooks.enabled {
                        Text(state.automaticLook.map { "Automatic look: \($0.name)" } ?? "Choose a city and two saved looks to finish setup.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    TextureSample(preset: state.texture, adjustments: state.adjustments, intensity: state.appearance.intensity)
                        .frame(height: 92)
                    HStack {
                        Slider(value: Binding(get: { state.appearance.intensity }, set: { state.settings.intensity = $0 }), in: 0.05...0.45, step: 0.01) {
                            Text("Intensity")
                        }.accessibilityValue(state.intensityDescription)
                            .accessibilityIdentifier("paper.intensity")
                        Text(state.intensityDescription)
                            .monospacedDigit().frame(width: 38).accessibilityHidden(true)
                    }
                    .disabled(state.settings.automaticLooks.enabled)
                    Picker("Grain", selection: Binding(get: { state.appearance.grainScale }, set: { state.settings.grainScale = $0 })) {
                        Text("Fine").tag(0.5)
                        Text("Natural").tag(1.0)
                        Text("Coarse").tag(2.0)
                    }.pickerStyle(.segmented).disabled(state.settings.automaticLooks.enabled)
                    HStack {
                        Button("Import paper…", action: importPaper).disabled(choosingFile)
                        Spacer()
                        if state.customPapers.contains(where: { $0.id == state.settings.textureID }) {
                            Button("Remove imported paper", role: .destructive) { state.removeSelectedImport() }
                                .disabled(state.settings.automaticLooks.enabled)
                        }
                    }
                }
                Section("When to show it") {
                    Toggle("Use a daily schedule", isOn: $state.settings.schedule.enabled)
                    if state.settings.schedule.enabled {
                        Picker("Schedule", selection: $state.settings.schedule.mode) {
                            ForEach(ScheduleMode.allCases) { Text($0.title).tag($0) }
                        }
                        if state.settings.schedule.mode == .fixed {
                            HStack {
                                DatePicker("From", selection: timeBinding(start: true), displayedComponents: .hourAndMinute)
                                DatePicker("To", selection: timeBinding(start: false), displayedComponents: .hourAndMinute)
                            }
                            Text(state.settings.schedule.startMinute == state.settings.schedule.endMinute
                                 ? "Matching times keep Paper available all day."
                                 : "Uses your Mac’s local time. Turning Paper off always takes priority.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else { SolarScheduleControls(state: state) }
                    }
                    AutomaticLooksControls(state: state)
                    Toggle("Pause on battery", isOn: $state.settings.pauseOnBattery)
                    Toggle("Pause in Low Power Mode", isOn: $state.settings.pauseOnLowPower)
                }
                Section("Displays") {
                    ForEach(state.displayChoices) { display in
                        Toggle(display.name, isOn: Binding(
                            get: { !state.settings.disabledDisplays.contains(display.id) },
                            set: { included in
                                if included { state.settings.disabledDisplays.remove(display.id) }
                                else { state.settings.disabledDisplays.insert(display.id) }
                            }))
                        Toggle("Custom intensity for \(display.name)", isOn: Binding(
                            get: { state.settings.displayIntensities[display.id] != nil },
                            set: { enabled in state.settings.displayIntensities[display.id] = enabled ? state.appearance.intensity : nil }))
                            .font(.caption)
                        if state.settings.displayIntensities[display.id] != nil {
                            HStack {
                                Slider(value: Binding(get: { state.settings.intensity(for: display.id) },
                                    set: { state.settings.displayIntensities[display.id] = $0 }), in: 0.05...0.45, step: 0.01) {
                                        Text("\(display.name) intensity")
                                    }
                                Text(state.settings.intensity(for: display.id).formatted(.percent.precision(.fractionLength(0))))
                                    .monospacedDigit().frame(width: 38)
                            }
                        }
                    }
                }
                Section("App rules") {
                    Toggle("Only show in selected apps", isOn: Binding(
                        get: { state.settings.appRuleMode == .only },
                        set: { state.settings.appRuleMode = $0 ? .only : .except }))
                    if state.settings.appRuleMode == .only {
                        Text("Paper waits until a selected app is active. Excluded apps still take priority.")
                            .font(.caption).foregroundStyle(.secondary)
                        ForEach(state.settings.includedApps) { app in
                            HStack {
                                Text(app.name)
                                Spacer()
                                Button { state.settings.includedApps.removeAll { $0.id == app.id } } label: {
                                    Image(systemName: "minus.circle")
                                }.buttonStyle(.borderless).accessibilityLabel("Remove \(app.name) from selected apps")
                            }
                        }
                        Button("Add selected app…") { addApp(included: true) }.disabled(choosingFile)
                    }
                }
                Section("Pause in these apps") {
                    Text("Pauses when an app is active. Floating panels from excluded apps stay above the texture.")
                        .font(.caption).foregroundStyle(.secondary)
                    if state.settings.excludedApps.isEmpty {
                        Text("Keep an unmodified view in photo, video, or other apps you choose.")
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    ForEach(state.settings.excludedApps) { app in
                        HStack {
                            Text(app.name)
                            Spacer()
                            Button {
                                state.settings.excludedApps.removeAll { $0.id == app.id }
                            } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Remove \(app.name) from excluded apps")
                                .help("Remove \(app.name)")
                        }
                    }
                    Button("Add app…") { addApp() }.disabled(choosingFile)
                }
                Section("Library backup") {
                    HStack {
                        Button("Export library…", action: exportLibrary).disabled(choosingFile)
                        Spacer()
                        Button("Import library…", action: importLibrary).disabled(choosingFile)
                    }
                    Text("Includes favorites, saved looks and custom papers. Import merges them without replacing your existing items.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Updates & support") {
                    Toggle("Check for updates automatically", isOn: Binding(get: { updates.automaticallyChecksForUpdates }, set: updates.setAutomaticChecks))
                    HStack {
                        Button("Check for Updates…") { updates.checkForUpdates() }.disabled(!updates.canCheckForUpdates || updates.busy)
                        Spacer()
                        Button("Help & diagnostics…", action: showDiagnostics)
                    }
                    Text("Update checks use GitHub. Reports are sent only after you review them and choose Send.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Preferences") {
                    Toggle("Toggle with ⇧⌥⌘P", isOn: $state.settings.shortcutEnabled)
                    if let error = state.shortcutError { Text(error).font(.caption).foregroundStyle(.red) }
                    Toggle("Launch at login", isOn: Binding(get: { state.loginState == .enabled }, set: { _ in state.toggleLogin() }))
                        .disabled(state.loginState == .unavailable)
                    if state.loginState == .requiresApproval {
                        Button("Approve in Login Items…") { state.login.openSystemSettings() }
                    } else if state.loginState == .unavailable {
                        Text("Launch at login is unavailable on this Mac.").font(.caption).foregroundStyle(.secondary)
                    }
                    Text("Pause Paper before screenshots, screen sharing, or color-sensitive work.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }.formStyle(.grouped)
            HStack {
                Text("A softer surface for your screen.").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("About Paper") { NSApp.orderFrontStandardAboutPanel(nil) }.buttonStyle(.link)
                Button("Quit") { NSApp.terminate(nil) }.buttonStyle(.link)
            }.padding(.horizontal, 22).padding(.vertical, 12)
        }
        .frame(minWidth: 480, minHeight: 550)
        .sheet(isPresented: $state.showingCustomSnooze) { CustomSnoozeView(state: state) }
        .alert(item: $state.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }

    private func timeBinding(start: Bool) -> Binding<Date> {
        Binding(get: {
            let minute = start ? state.settings.schedule.startMinute : state.settings.schedule.endMinute
            return Calendar.current.date(bySettingHour: minute / 60, minute: minute % 60, second: 0, of: Date()) ?? Date()
        }, set: { date in
            let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
            let minute = (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
            if start { state.settings.schedule.startMinute = minute }
            else { state.settings.schedule.endMinute = minute }
        })
    }
    private func importPaper() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose a Deckle-compatible JSON paper recipe."
        panel.prompt = "Import"
        chooseFile(panel) { response in
            guard response == .OK else { return }
            state.importRecipes(urls: panel.urls)
        }
    }
    private func addApp(included: Bool = false) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.prompt = "Add app"
        chooseFile(panel) { response in
            guard response == .OK, let url = panel.url else { return }
            state.addExcludedApp(url: url, included: included)
        }
    }

    private func exportLibrary() {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "Paper-library.json"
        chooseFile(panel) { response in
            guard response == .OK, let url = panel.url else { return }
            do { try state.exportLibrary().write(to: url, options: .atomic) }
            catch { state.showError("Could not export library", error) }
        }
    }
    private func importLibrary() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.message = "Merge a Paper library backup. Existing items and visibility settings are preserved."
        chooseFile(panel) { response in
            guard response == .OK, let url = panel.url else { return }
            do { try state.importLibrary(BoundedJSONFile.read(url)) }
            catch { state.showError("Could not import library", error) }
        }
    }
    private func chooseFile(_ panel: NSSavePanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
        guard !choosingFile,
              let window = NSApp.windows.first(where: { $0.contentViewController is NSHostingController<PaperView> })
        else { return }
        choosingFile = true
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        panel.beginSheetModal(for: window) { response in
            choosingFile = false
            completion(response)
        }
    }
}

/// Rendering is keyed and kept out of body evaluation, as highlighted by Deckle PR #49.
struct TextureSample: View {
    let preset: TexturePreset
    let adjustments: TextureRenderer.GrainAdjustments
    let intensity: Double
    @State private var tile: NSImage?
    var body: some View {
        ZStack(alignment: .leading) {
            Color.white
            VStack(alignment: .leading, spacing: 7) {
                Text("A little room to think.").font(.system(size: 20, design: .serif))
                Text("Keep the words clear and the background quiet.").font(.system(size: 12))
            }.foregroundStyle(Color(white: 0.18)).padding(16)
            if let tile {
                Image(nsImage: tile).resizable(resizingMode: .tile).opacity(intensity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.08)))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(preset.name) texture preview")
        .task(id: preset.cacheSignature + adjustments.cacheKey) {
            tile = TextureRenderer.compositeTile(for: preset, adjustments: adjustments, backingScale: 2)
        }
    }
}
