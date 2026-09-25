import SwiftUI
import AppKit
import UniformTypeIdentifiers
import PaperCore

struct ShortcutControls: View {
    @ObservedObject var state: PaperState
    var body: some View {
        Toggle("Enable global shortcuts", isOn: $state.settings.shortcutEnabled)
        if state.settings.shortcutEnabled {
            ForEach(ShortcutAction.allCases) { action in
                HStack {
                    Text(action.title)
                    Spacer()
                    Button(state.settings.shortcuts[action]?.title ?? "Not set") { editing = action }
                        .accessibilityLabel("Edit shortcut for \(action.title)")
                }
            }
            if let error = state.shortcutError { Text(error).font(.caption).foregroundStyle(.red) }
        }
        Text("Shortcuts use physical A–Z keys and require Command or Control. Optional commands start unassigned.")
            .font(.caption).foregroundStyle(.secondary)
            .sheet(item: $editing) { action in ShortcutEditor(state: state, action: action) }
    }
    @State private var editing: ShortcutAction?
}

private struct ShortcutEditor: View {
    @ObservedObject var state: PaperState
    let action: ShortcutAction
    @Environment(\.dismiss) private var dismiss
    @State private var binding = ShortcutBinding()
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(action.title).font(.headline)
            Picker("Key", selection: $binding.key) {
                ForEach(ShortcutBinding.keys, id: \.self) { Text($0).tag($0) }
            }
            HStack {
                Toggle("⌘", isOn: $binding.command).accessibilityLabel("Command")
                Toggle("⌥", isOn: $binding.option).accessibilityLabel("Option")
                Toggle("⌃", isOn: $binding.control).accessibilityLabel("Control")
                Toggle("⇧", isOn: $binding.shift).accessibilityLabel("Shift")
            }
            Text(binding.isValid ? binding.title : "Include Command or Control.")
            HStack {
                if action != .toggle {
                    Button("Clear") { state.settings.shortcuts[action] = nil; dismiss() }
                } else {
                    Button("Use default") { binding = ShortcutBinding() }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") { state.settings.shortcuts[action] = binding; dismiss() }
                    .disabled(!binding.isValid).keyboardShortcut(.defaultAction)
            }
        }.padding(24).frame(width: 360)
            .onAppear { binding = state.settings.shortcuts[action] ?? ShortcutBinding() }
    }
}

struct AppLookControls: View {
    @ObservedObject var state: PaperState
    let choosingFile: Bool
    let chooseApp: (@escaping (URL) -> Void) -> Void
    var body: some View {
        Toggle("Use app-specific looks", isOn: $state.settings.appLooksEnabled)
        Text("Assigned looks take priority over day/night looks. App and display exclusions still pause Paper. Manual texture or look selection ends automatic switching.")
            .font(.caption).foregroundStyle(.secondary)
        ForEach(state.settings.appLooks.keys.sorted(), id: \.self) { app in
            HStack {
                Picker(appName(app), selection: Binding(get: { state.settings.appLooks[app] }, set: { state.settings.appLooks[app] = $0 })) {
                    ForEach(state.library.looks) { Text($0.name).tag(Optional($0.id)) }
                }
                Button { state.settings.appLooks.removeValue(forKey: app) } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless).accessibilityLabel("Remove look for \(appName(app))")
            }
        }
        Button("Assign a look to an app…", action: addApp).disabled(state.library.looks.isEmpty || choosingFile)
        if state.library.looks.isEmpty { Text("Save a look in Your paper first.").font(.caption).foregroundStyle(.secondary) }
    }
    private func appName(_ id: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) else { return id }
        return url.deletingPathExtension().lastPathComponent
    }
    private func addApp() {
        chooseApp { url in
            guard let id = Bundle(url: url)?.bundleIdentifier,
                  id != Bundle.main.bundleIdentifier, let look = state.library.looks.first else { return }
            if state.settings.appLooks[id] == nil { state.settings.appLooks[id] = look.id }
            state.settings.appLooksEnabled = true
        }
    }
}

struct DeskControls: View {
    @ObservedObject var state: PaperState
    @State private var name = ""
    var body: some View {
        Text("Save this display setup’s texture and rules. Paper recalls it when the same displays reconnect or Paper launches. Off, display exclusions, snooze and presentation pause always win.")
            .font(.caption).foregroundStyle(.secondary)
        if let name = state.activeDeskName { Text("Current desk: \(name)").font(.caption) }
        HStack {
            TextField("Desk name", text: $name)
            Button("Save this setup") {
                do { try state.saveDesk(name: name); name = "" }
                catch { state.showError("Could not save desk", error) }
            }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        Text("Saving the same display setup replaces its profile. Desk profiles stay on this Mac and are not part of library exports.")
            .font(.caption).foregroundStyle(.secondary)
        ForEach(state.deskProfiles) { desk in
            HStack {
                Text(desk.name)
                Spacer()
                Button { state.removeDesk(desk.id) } label: { Image(systemName: "minus.circle") }
                    .buttonStyle(.borderless).accessibilityLabel("Remove desk \(desk.name)")
            }
        }
    }
}

struct SurfaceControls: View {
    @ObservedObject var state: PaperState
    @State private var showingLamp = false
    @State private var showingStrip = false
    var body: some View {
        DisclosureGroup(isExpanded: $showingLamp) {
            Toggle("Warm ambient light", isOn: $state.settings.deskLamp.enabled)
            if state.settings.deskLamp.enabled {
                Slider(value: $state.settings.deskLamp.warmth, in: 0...1) { Text("Warmth") }
                Slider(value: $state.settings.deskLamp.strength, in: 0...1) { Text("Strength") }
                Text("A static warm wash, blended at your paper intensity. Pause Paper for accurate colors.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } label: {
            Text("Desk Lamp").contentShape(Rectangle()).onTapGesture { showingLamp.toggle() }
        }
        DisclosureGroup(isExpanded: $showingStrip) {
            Text("Turn the clear band on or off in the menu bar. Adjust it here or assign movement shortcuts below. It appears on each enabled display.")
                .font(.caption).foregroundStyle(.secondary)
            Slider(value: Binding(get: { state.settings.readingStrip.height }, set: {
                state.settings.readingStrip.height = $0; state.settings.readingStrip.normalize()
            }), in: 0.05...0.5) { Text("Strip height") }
            Slider(value: Binding(get: { state.settings.readingStrip.center }, set: {
                state.settings.readingStrip.center = $0; state.settings.readingStrip.normalize()
            }), in: 0...1) { Text("Strip position (bottom to top)") }
        } label: {
            Text("Reading strip").contentShape(Rectangle()).onTapGesture { showingStrip.toggle() }
        }
    }
}
