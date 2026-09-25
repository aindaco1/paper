import SwiftUI
import CoreLocation
import PaperCore

extension ScheduleMode {
    var title: String {
        switch self {
        case .fixed: return "Fixed times"
        case .sunsetToSunrise: return "Sunset to sunrise"
        case .sunriseToSunset: return "Sunrise to sunset"
        }
    }
}

struct SolarScheduleControls: View {
    @ObservedObject var state: PaperState
    @State private var choosingCity = false
    var body: some View {
        HStack {
            Text(state.settings.schedule.location?.name ?? "Choose a city")
            Spacer()
            Button("Choose city…") { choosingCity = true }
        }
        if let location = state.settings.schedule.location,
           let day = SolarDay.calculate(on: state.now, at: location) {
            Text(description(day, location: location)).font(.caption).foregroundStyle(.secondary)
        } else {
            Text("Choose a city to calculate sunrise and sunset.").font(.caption).foregroundStyle(.secondary)
        }
        Text("Calculated on your Mac. City lookup uses Apple’s service; no location permission is needed.")
            .font(.caption).foregroundStyle(.secondary)
            .sheet(isPresented: $choosingCity) { CityPicker(state: state) }
    }
    private func description(_ day: SolarDay, location: SolarLocation) -> String {
        guard let sunrise = day.sunrise, let sunset = day.sunset else {
            return day.continuousDaylight ? "Continuous daylight today." : "Continuous night today."
        }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.timeZone = TimeZone(identifier: location.timeZoneIdentifier)
        return "Sunrise ≈ \(formatter.string(from: sunrise)) · Sunset ≈ \(formatter.string(from: sunset)) (city’s local time)"
    }
}

private struct CityPicker: View {
    @ObservedObject var state: PaperState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [SolarLocation] = []
    @State private var searching = false
    @State private var error: String?
    @State private var geocoder = CLGeocoder()
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Schedule city").font(.headline)
            Text("Enter a city and country. This city stays selected when you travel.").foregroundStyle(.secondary)
            HStack {
                TextField("City and country", text: $query).onSubmit(search)
                Button("Find", action: search).disabled(searching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            if searching { ProgressView().controlSize(.small) }
            if let error { Text(error).foregroundStyle(.red) }
            ForEach(Array(results.enumerated()), id: \.offset) { _, location in
                Button(location.name) { state.settings.schedule.location = location; dismiss() }
            }
            HStack {
                if state.settings.schedule.location != nil {
                    Button("Clear city", role: .destructive) { state.settings.schedule.location = nil; dismiss() }
                }
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction)
            }
        }.padding(22).frame(width: 420)
            .onDisappear { searchTask?.cancel(); geocoder.cancelGeocode() }
    }
    private func search() {
        guard !searching, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        searching = true; error = nil; results = []
        searchTask = Task { @MainActor in
            defer { searching = false }
            do {
                let places = try await geocoder.geocodeAddressString(query)
                guard !Task.isCancelled else { return }
                results = places.compactMap { place in
                    guard let coordinate = place.location?.coordinate, let timeZone = place.timeZone else { return nil }
                    let name = [place.locality ?? place.name, place.administrativeArea, place.country]
                        .compactMap { $0 }.reduce(into: [String]()) { if !$0.contains($1) { $0.append($1) } }.joined(separator: ", ")
                    return SolarLocation(name: name, latitude: coordinate.latitude, longitude: coordinate.longitude,
                                         timeZoneIdentifier: timeZone.identifier)
                }
                if results.isEmpty { error = "No city found. Try including the state or country." }
            } catch {
                if !Task.isCancelled { self.error = "City lookup failed. Check your connection and try again." }
            }
        }
    }
}

struct AutomaticLooksControls: View {
    @ObservedObject var state: PaperState
    var body: some View {
        Toggle("Automatic day/night looks", isOn: $state.settings.automaticLooks.enabled)
        if state.settings.automaticLooks.enabled {
            Picker("Switch with", selection: $state.settings.automaticLooks.trigger) {
                Text("Sunrise and sunset").tag(AutomaticLooks.Trigger.solar)
                Text("macOS appearance").tag(AutomaticLooks.Trigger.systemAppearance)
            }
            Picker(state.settings.automaticLooks.trigger == .solar ? "Day look" : "Light look", selection: $state.settings.automaticLooks.dayLookID) {
                Text("Choose a saved look").tag(UUID?.none)
                ForEach(state.library.looks) { Text($0.name).tag(Optional($0.id)) }
            }
            Picker(state.settings.automaticLooks.trigger == .solar ? "Night look" : "Dark look", selection: $state.settings.automaticLooks.nightLookID) {
                Text("Choose a saved look").tag(UUID?.none)
                ForEach(state.library.looks) { Text($0.name).tag(Optional($0.id)) }
            }
            if state.settings.automaticLooks.trigger == .solar && (!state.settings.schedule.enabled || state.settings.schedule.mode == .fixed) {
                SolarScheduleControls(state: state)
            }
            Text("Save looks in Your paper first. Manual selection or applying a look ends automatic switching. Visibility rules still apply.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}
