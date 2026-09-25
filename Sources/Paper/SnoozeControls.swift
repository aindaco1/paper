import SwiftUI
import PaperCore

extension SnoozeOption {
    var title: String {
        switch self {
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        case .oneHour: return "1 hour"
        case .twoHours: return "2 hours"
        case .tomorrow: return "Until tomorrow at 6 AM"
        }
    }
}

struct CustomSnoozeView: View {
    @ObservedObject var state: PaperState
    @Environment(\.dismiss) private var dismiss
    @State private var minutesText = "45"
    @FocusState private var minutesFocused: Bool

    private var minutes: Int? {
        guard let value = Int(minutesText.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...1440).contains(value) else { return nil }
        return value
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Snooze Paper").font(.headline)
            TextField("Minutes", text: $minutesText)
                .focused($minutesFocused).accessibilityIdentifier("paper.snoozeMinutes")
                .accessibilityLabel("Snooze duration in minutes")
            Text("Enter a whole number from 1 to 1,440 minutes.")
                .font(.caption).foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("Snooze") {
                    guard let minutes else { return }
                    state.snooze(minutes: Double(minutes))
                    dismiss()
                }.keyboardShortcut(.defaultAction)
                    .disabled(minutes == nil || !state.settings.enabled)
            }
        }.padding(24).frame(width: 320)
            .onAppear { minutesFocused = true }
    }
}
