import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PaperCore

struct PaperView: View {
    @ObservedObject var state: PaperState
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
                    Picker("Texture", selection: $state.settings.textureID) {
                        ForEach(state.allTextures) { texture in Text(texture.name).tag(texture.id) }
                    }.accessibilityIdentifier("paper.texture")
                    TextureSample(preset: state.texture, adjustments: state.adjustments, intensity: state.settings.intensity)
                        .frame(height: 92)
                    HStack {
                        Slider(value: $state.settings.intensity, in: 0.05...0.45, step: 0.01) {
                            Text("Intensity")
                        }.accessibilityValue(state.intensityDescription)
                            .accessibilityIdentifier("paper.intensity")
                        Text(state.intensityDescription)
                            .monospacedDigit().frame(width: 38).accessibilityHidden(true)
                    }
                    Picker("Grain", selection: $state.settings.grainScale) {
                        Text("Fine").tag(0.5)
                        Text("Natural").tag(1.0)
                        Text("Coarse").tag(2.0)
                    }.pickerStyle(.segmented)
                    HStack {
                        Button(state.comparing ? "Back to paper" : "Compare original") { state.comparing.toggle() }
                            .disabled(!state.settings.enabled)
                        Spacer()
                        Menu("Snooze") {
                            ForEach(SnoozeOption.allCases) { option in
                                Button(option.title) { state.snooze(option) }
                            }
                            Divider()
                            Button("Custom duration…") { state.showingCustomSnooze = true }
                        }.fixedSize().disabled(!state.settings.enabled)
                        if let until = state.settings.snoozeUntil, until > state.now {
                            Button("End snooze") { state.settings.snoozeUntil = nil }
                        }
                    }
                    HStack {
                        Button("Import paper…", action: importPaper).disabled(choosingFile)
                        Spacer()
                        if state.customPapers.contains(where: { $0.id == state.settings.textureID }) {
                            Button("Remove imported paper", role: .destructive) { state.removeSelectedImport() }
                        }
                    }
                }
                Section("When to show it") {
                    Toggle("Use a daily schedule", isOn: $state.settings.schedule.enabled)
                    if state.settings.schedule.enabled {
                        HStack {
                            DatePicker("From", selection: timeBinding(start: true), displayedComponents: .hourAndMinute)
                            DatePicker("To", selection: timeBinding(start: false), displayedComponents: .hourAndMinute)
                        }
                        Text(state.settings.schedule.startMinute == state.settings.schedule.endMinute
                             ? "Matching times keep Paper available all day."
                             : "Uses your Mac’s local time. Turning Paper off always takes priority.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
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
                    }
                }
                Section("Pause in these apps") {
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
                    Button("Add app…", action: addApp).disabled(choosingFile)
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
    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.canChooseDirectories = false
        panel.prompt = "Add app"
        chooseFile(panel) { response in
            guard response == .OK, let url = panel.url else { return }
            state.addExcludedApp(url: url)
        }
    }

    private func chooseFile(_ panel: NSOpenPanel, completion: @escaping (NSApplication.ModalResponse) -> Void) {
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
