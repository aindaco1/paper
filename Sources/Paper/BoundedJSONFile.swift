import Foundation
import Darwin

/// Bound the actual read, including files replaced or grown after selection.
/// Opening nonblocking before fstat also rejects FIFOs without hanging the UI.
enum BoundedJSONFile {
    static let maximumBytes = 1_048_576
    static func read(_ url: URL, maximumBytes: Int = Self.maximumBytes) throws -> Data {
        guard url.isFileURL, (1...2_097_152).contains(maximumBytes) else { throw PaperImportError.invalidRecipe }
        let descriptor = open(url.path, O_RDONLY | O_NONBLOCK | O_CLOEXEC)
        guard descriptor >= 0 else { throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO) }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_mode & mode_t(S_IFMT) == mode_t(S_IFREG),
              info.st_size <= maximumBytes else { throw PaperImportError.tooLarge }
        var data = Data()
        while data.count <= maximumBytes {
            let chunk = try handle.read(upToCount: min(65_536, maximumBytes + 1 - data.count)) ?? Data()
            if chunk.isEmpty { break }
            data.append(chunk)
        }
        guard data.count <= maximumBytes else { throw PaperImportError.tooLarge }
        return data
    }
}
