import Foundation
import PaperCore

struct PaperCollection: Codable {
    var papers: [CustomPaper] = []
    var library = PaperLibrary()
}

struct PaperArchive: Codable {
    var format = "xyz.dustwave.paper.library"
    var version = 1
    var collection: PaperCollection

    static func decode(_ data: Data) throws -> PaperArchive {
        guard data.count <= BoundedJSONFile.maximumBytes else { throw PaperImportError.tooLarge }
        let archive: PaperArchive
        do { archive = try JSONDecoder().decode(Self.self, from: data) }
        catch { throw ArchiveError.invalid }
        guard archive.format == "xyz.dustwave.paper.library", archive.version == 1 else { throw ArchiveError.version }
        try validate(archive.collection)
        return archive
    }
    static func validate(_ collection: PaperCollection) throws {
        guard collection.papers.count <= 50, collection.library.looks.count <= PaperLibrary.maximumLooks else { throw ArchiveError.capacity }
        var ids = Set(TexturePreset.all.map(\.id))
        for paper in collection.papers {
            guard paper.id.hasPrefix("custom-"), UUID(uuidString: String(paper.id.dropFirst(7))) != nil,
                  ids.insert(paper.id).inserted else { throw ArchiveError.invalid }
            _ = try RecipeImport.validated(paper)
        }
        guard collection.library.favorites.isSubset(of: ids) else { throw ArchiveError.missingTexture }
        var lookIDs = Set<UUID>()
        for look in collection.library.looks {
            guard ids.contains(look.textureID) else { throw ArchiveError.missingTexture }
            guard lookIDs.insert(look.id).inserted, !look.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  look.name.count <= 60, look.name.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) }),
                  look.intensity.isFinite, (0.05...0.45).contains(look.intensity),
                  [0.5, 1, 2].contains(look.grainScale), look.grainStrength.isFinite,
                  (0.25...2).contains(look.grainStrength) else { throw ArchiveError.invalid }
        }
    }
    func encoded() throws -> Data {
        try Self.validate(collection)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(self)
        guard data.count <= BoundedJSONFile.maximumBytes else { throw PaperImportError.tooLarge }
        return data
    }

    /// One bounded, atomic merge: preserve existing entries, remap collisions and
    /// their references, and make reimporting an unchanged backup idempotent.
    func merging(into existing: PaperCollection) throws -> PaperCollection {
        try Self.validate(collection)
        var result = existing
        var remap: [String: String] = [:]
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        for original in collection.papers {
            var paper = try RecipeImport.validated(original)
            if let match = result.papers.first(where: { $0.id == paper.id }) {
                if try encoder.encode(match) == encoder.encode(paper) { continue }
                var comparable = paper
                comparable.id = ""
                let content = try encoder.encode(comparable)
                if let prior = try result.papers.first(where: { other in
                    var candidate = other; candidate.id = ""
                    return try encoder.encode(candidate) == content
                }) { remap[original.id] = prior.id; continue }
                paper.id = "custom-\(UUID().uuidString.lowercased())"
                remap[original.id] = paper.id
            }
            result.papers.append(paper)
        }
        for original in collection.library.looks {
            var look = original
            look.textureID = remap[look.textureID] ?? look.textureID
            if let match = result.library.looks.first(where: { $0.id == look.id }) {
                if match == look { continue }
                if result.library.looks.contains(where: { other in
                    var comparable = look; comparable.id = other.id; comparable.name = other.name
                    let base = String(look.name.prefix(45))
                    return comparable == other && (other.name == look.name || other.name.hasPrefix(base + " (imported "))
                }) { continue }
                look.id = UUID()
            }
            let base = String(look.name.prefix(45))
            var suffix = 1
            while result.library.looks.contains(where: { $0.name.localizedCaseInsensitiveCompare(look.name) == .orderedSame }) {
                look.name = "\(base) (imported \(suffix))"; suffix += 1
            }
            result.library.looks.append(look)
        }
        result.library.favorites.formUnion(collection.library.favorites.map { remap[$0] ?? $0 })
        try Self.validate(result)
        return result
    }
}

enum ArchiveError: LocalizedError {
    case invalid, version, capacity, missingTexture
    var errorDescription: String? {
        switch self {
        case .invalid: return "Choose a valid Paper library backup. Nothing was imported."
        case .version: return "This library format is not supported by this version of Paper."
        case .capacity: return "The merged library would exceed 50 imported papers or eight saved looks. Remove some items and try again."
        case .missingTexture: return "This backup refers to a missing texture. Export it again with its custom papers included."
        }
    }
}
