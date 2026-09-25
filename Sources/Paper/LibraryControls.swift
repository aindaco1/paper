import SwiftUI
import PaperCore

struct LibraryControls: View {
    @ObservedObject var state: PaperState
    @State private var saving = false
    var body: some View {
        HStack {
            Button { state.toggleFavorite() } label: {
                Label(state.library.favorites.contains(state.texture.id) ? "Favorited" : "Favorite",
                      systemImage: state.library.favorites.contains(state.texture.id) ? "star.fill" : "star")
            }.accessibilityLabel("\(state.library.favorites.contains(state.texture.id) ? "Unfavorite" : "Favorite") \(state.texture.name)")
            Spacer()
            Menu("Saved looks") {
                ForEach(state.library.looks) { look in
                    Button(look.name) {
                        do { try state.applyLook(look.id) }
                        catch { state.showError("Could not apply look", error) }
                    }
                }
                if !state.library.looks.isEmpty { Divider() }
                Button("Save current look…") { saving = true }
                if !state.library.looks.isEmpty {
                    Menu("Remove look") {
                        ForEach(state.library.looks) { look in
                            Button(look.name) { state.removeLook(look.id) }
                        }
                    }
                }
            }.fixedSize()
        }
        .sheet(isPresented: $saving) { SaveLookView(state: state) }
    }
}

private struct SaveLookView: View {
    @ObservedObject var state: PaperState
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var error: String?
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Save this look").font(.headline)
            Text("Keep this texture, intensity and grain together. Reuse a name to replace an existing look.")
                .foregroundStyle(.secondary)
            TextField("Name", text: $name).accessibilityIdentifier("paper.lookName")
            if let error { Text(error).foregroundStyle(.red) }
            HStack {
                Text("\(state.library.looks.count) of 8 looks saved").font(.caption).foregroundStyle(.secondary)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Save") {
                    do { try state.saveLook(name: name); dismiss() }
                    catch { self.error = error.localizedDescription }
                }.keyboardShortcut(.defaultAction).disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(22).frame(width: 380)
    }
}
