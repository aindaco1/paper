import Foundation

/// A look changes only the paper's appearance. Visibility rules remain independent.
public struct PaperLook: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var textureID: String
    public var intensity: Double
    public var grainScale: Double
    public var grainStrength: Double

    public init(name: String, settings: PaperSettings) {
        id = UUID()
        self.name = name
        textureID = settings.textureID
        intensity = settings.intensity
        grainScale = settings.grainScale
        grainStrength = settings.grainStrength
    }
    public func apply(to settings: inout PaperSettings) {
        settings.textureID = textureID
        settings.intensity = intensity
        settings.grainScale = grainScale
        settings.grainStrength = grainStrength
        settings.normalize()
    }
}

public struct PaperLibrary: Codable, Equatable {
    public static let maximumLooks = 8
    public var favorites: Set<String> = []
    public var looks: [PaperLook] = []
    public init() {}

    public mutating func removeTexture(_ id: String) {
        favorites.remove(id)
        looks.removeAll { $0.textureID == id }
    }
}
