import SwiftUI
import AppKit
import UniformTypeIdentifiers

/// A user-created paper: a tiny recipe the procedural engine renders exactly
/// like a built-in preset. Values are clamped on conversion so imported
/// files can't produce anything outside the app's visual range.
struct CustomPaper: Codable, Equatable, Identifiable {
    var id: String = "custom-\(UUID().uuidString.lowercased())"
    var name: String = "My Paper"
    var tintRed: Double = 0.96
    var tintGreen: Double = 0.94
    var tintBlue: Double = 0.90
    /// Tint wash opacity at full design strength.
    var wash: Double = 0.38
    /// Woven crosshatch amount; 0 disables the weave.
    var weave: Double = 0 {
        didSet { enableGrainIfEditingTexture(from: oldValue, to: weave) }
    }
    /// Coarse mottling mixed into the grain.
    var blotch: Double = 0 {
        didSet { enableGrainIfEditingTexture(from: oldValue, to: blotch) }
    }
    /// Procedural engine used to render this paper. Freshly created papers
    /// use the v3 spectral+ engine; papers saved before this field existed
    /// decode as `.legacy` so they keep rendering with the original
    /// generator, unchanged.
    var engineVersion: TextureEngineVersion = .spectralPlus
    /// Stable per-paper RNG seed. Generated once when the paper is created
    /// and stored from then on (it round-trips through export/import)
    /// rather than being recomputed on every render.
    var seed: UInt64 = .random(in: .min ... .max)

    // MARK: - v3 (spectral+) parameters

    /// Dominant fiber orientation in radians (0 = horizontal, π/2 = vertical).
    var fiberAngle: Float = 0.3
    /// How strongly oriented fibers modulate the grain field, 0…1.
    var fiberStrength: Float = 0.30 {
        didSet { enableGrainIfEditingTexture(from: oldValue, to: fiberStrength) }
    }
    /// Perlin surface roughness mixed into the field, 0…1.
    var surfaceRoughness: Float = 0.15 {
        didSet { enableGrainIfEditingTexture(from: oldValue, to: surfaceRoughness) }
    }

    /// Optional strengths preserve quiet built-ins when copied into Paper Mill.
    /// Missing values retain the historical custom-paper rendering exactly.
    var darkGrainStrength: Float?
    var lightGrainStrength: Float?

    /// Grain-free built-ins carry explicit zero strengths when duplicated so
    /// their initial copy remains uniform. Once a texture-producing control
    /// changes, return to normal custom-paper strengths so the edit is visible.
    private mutating func enableGrainIfEditingTexture<T: Equatable>(from oldValue: T, to newValue: T) {
        guard oldValue != newValue, darkGrainStrength == 0, lightGrainStrength == 0 else { return }
        darkGrainStrength = nil
        lightGrainStrength = nil
    }

    var isDark: Bool {
        // Classification must use the same clamped tint as the renderer.
        0.299 * min(max(tintRed, 0), 1)
            + 0.587 * min(max(tintGreen, 0), 1)
            + 0.114 * min(max(tintBlue, 0), 1) < 0.5
    }

    init(
        id: String = "custom-\(UUID().uuidString.lowercased())",
        name: String = "My Paper",
        tintRed: Double = 0.96,
        tintGreen: Double = 0.94,
        tintBlue: Double = 0.90,
        wash: Double = 0.38,
        weave: Double = 0,
        blotch: Double = 0,
        engineVersion: TextureEngineVersion = .spectralPlus,
        seed: UInt64 = .random(in: .min ... .max),
        fiberAngle: Float = 0.3,
        fiberStrength: Float = 0.30,
        surfaceRoughness: Float = 0.15,
        darkGrainStrength: Float? = nil,
        lightGrainStrength: Float? = nil
    ) {
        self.id = id
        self.name = name
        self.tintRed = tintRed
        self.tintGreen = tintGreen
        self.tintBlue = tintBlue
        self.wash = wash
        self.weave = weave
        self.blotch = blotch
        self.engineVersion = engineVersion
        self.seed = seed
        self.fiberAngle = fiberAngle
        self.fiberStrength = fiberStrength
        self.surfaceRoughness = surfaceRoughness
        self.darkGrainStrength = darkGrainStrength
        self.lightGrainStrength = lightGrainStrength
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, tintRed, tintGreen, tintBlue, wash, weave, blotch, engineVersion, seed
        case fiberAngle, fiberStrength, surfaceRoughness
        case darkGrainStrength, lightGrainStrength
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tintRed = try container.decode(Double.self, forKey: .tintRed)
        tintGreen = try container.decode(Double.self, forKey: .tintGreen)
        tintBlue = try container.decode(Double.self, forKey: .tintBlue)
        wash = try container.decode(Double.self, forKey: .wash)
        weave = try container.decode(Double.self, forKey: .weave)
        blotch = try container.decode(Double.self, forKey: .blotch)
        // Version-less saves predate the v2 engine: keep them on the
        // original generator so previously exported papers render unchanged.
        engineVersion = try container.decodeIfPresent(TextureEngineVersion.self, forKey: .engineVersion) ?? .legacy
        // Seed-less saves predate stored seeds: derive one deterministically
        // from the paper's id so re-imports keep reproducing the same grain.
        seed = try container.decodeIfPresent(UInt64.self, forKey: .seed) ?? CustomPaper.legacySeed(from: id)
        // v3 parameters: default to zero (no fibers, no roughness) for
        // papers that predate v3.
        fiberAngle = try container.decodeIfPresent(Float.self, forKey: .fiberAngle) ?? 0
        fiberStrength = try container.decodeIfPresent(Float.self, forKey: .fiberStrength) ?? 0
        surfaceRoughness = try container.decodeIfPresent(Float.self, forKey: .surfaceRoughness) ?? 0
        darkGrainStrength = try container.decodeIfPresent(Float.self, forKey: .darkGrainStrength)
        lightGrainStrength = try container.decodeIfPresent(Float.self, forKey: .lightGrainStrength)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tintRed, forKey: .tintRed)
        try container.encode(tintGreen, forKey: .tintGreen)
        try container.encode(tintBlue, forKey: .tintBlue)
        try container.encode(wash, forKey: .wash)
        try container.encode(weave, forKey: .weave)
        try container.encode(blotch, forKey: .blotch)
        try container.encode(engineVersion, forKey: .engineVersion)
        try container.encode(seed, forKey: .seed)
        try container.encode(fiberAngle, forKey: .fiberAngle)
        try container.encode(fiberStrength, forKey: .fiberStrength)
        try container.encode(surfaceRoughness, forKey: .surfaceRoughness)
        try container.encodeIfPresent(darkGrainStrength, forKey: .darkGrainStrength)
        try container.encodeIfPresent(lightGrainStrength, forKey: .lightGrainStrength)
    }

    /// djb2 hash — deterministic across launches, so a legacy paper decoded
    /// without a stored seed always derives the same one from its id.
    private static func legacySeed(from id: String) -> UInt64 {
        var hash: UInt64 = 5381
        for byte in id.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return hash
    }
}

extension TexturePreset {
    /// Renders a custom paper through the same engine as built-ins: colors
    /// derive from the tint, blotch adds a coarse octave, weave adds the
    /// crosshatch. Every input is clamped — imports are untrusted.
    init(custom paper: CustomPaper) {
        func clamp(_ v: Double, _ range: ClosedRange<Double>) -> Double {
            min(max(v, range.lowerBound), range.upperBound)
        }
        let r = clamp(paper.tintRed, 0...1)
        let g = clamp(paper.tintGreen, 0...1)
        let b = clamp(paper.tintBlue, 0...1)
        let wash = clamp(paper.wash, 0.10...0.60)
        let weave = clamp(paper.weave, 0...0.35)
        let blotch = clamp(paper.blotch, 0...0.40)
        let dark = paper.isDark

        var octaves: [(cell: Int, weight: Float)] = [(1, 0.45), (2, 0.30), (4, 0.25)]
        if blotch > 0.01 {
            octaves.append((16, Float(blotch)))
        }

        self.init(
            id: paper.id,
            name: paper.name.isEmpty ? "My Paper" : paper.name,
            subtitle: "Custom paper",
            tint: NSColor(srgbRed: r, green: g, blue: b, alpha: 1),
            tintAlpha: wash,
            // Speckles: darkened tint for shadows, lightened for highlights —
            // keeps custom papers tonally coherent at any hue.
            darkColor: NSColor(srgbRed: r * 0.30, green: g * 0.28, blue: b * 0.25, alpha: 1),
            lightColor: NSColor(srgbRed: r + (1 - r) * 0.85, green: g + (1 - g) * 0.85, blue: b + (1 - b) * 0.85, alpha: 1),
            darkStrength: paper.darkGrainStrength.map { Float(clamp(Double($0), 0...1)) } ?? (dark ? 0.30 : 0.50),
            lightStrength: paper.lightGrainStrength.map { Float(clamp(Double($0), 0...1)) } ?? (dark ? 0.45 : 0.35),
            octaves: octaves,
            weave: weave > 0.01 ? (period: 8, amplitude: Float(weave)) : nil,
            isDark: dark,
            engineVersion: paper.engineVersion,
            seed: paper.seed,
            v3Config: paper.engineVersion == .spectralPlus
                ? TextureEngineConfig(
                    fiberAngle: Float(clamp(Double(paper.fiberAngle), 0...(Double.pi / 2))),
                    fiberStrength: Float(clamp(Double(paper.fiberStrength), 0...1)),
                    surfaceRoughness: Float(clamp(Double(paper.surfaceRoughness), 0...1))
                )
                : nil
        )
    }
}

