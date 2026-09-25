import AppKit
import Darwin

/// Advisory lock, retained for the process lifetime and released by the kernel on
/// exit/crash. A stable inode avoids races between copies, including simultaneous launches.
final class InstanceLease {
    private var descriptor: Int32 = -1
    init(directory: URL, name: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        let parent = open(directory.path, O_RDONLY | O_DIRECTORY | O_NOFOLLOW | O_CLOEXEC)
        guard parent >= 0 else { throw POSIXError(.EACCES) }
        defer { close(parent) }
        var directoryInfo = stat()
        guard fstat(parent, &directoryInfo) == 0, directoryInfo.st_uid == getuid(),
              directoryInfo.st_mode & 0o022 == 0 else { throw POSIXError(.EACCES) }
        descriptor = openat(parent, name, O_CREAT | O_RDWR | O_NOFOLLOW | O_CLOEXEC, 0o600)
        guard descriptor >= 0 else { throw POSIXError(.EACCES) }
        var info = stat()
        guard fstat(descriptor, &info) == 0, info.st_uid == getuid(), info.st_nlink == 1,
              info.st_mode & S_IFMT == S_IFREG, info.st_mode & 0o077 == 0 else {
            close(descriptor); descriptor = -1; throw POSIXError(.EACCES)
        }
    }
    func acquire() throws -> Bool {
        if flock(descriptor, LOCK_EX | LOCK_NB) == 0 { return true }
        if errno == EWOULDBLOCK { return false }
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
    deinit { if descriptor >= 0 { close(descriptor) } }
}

@MainActor
final class SingleInstance {
    private let lease: InstanceLease
    private var observer: NSObjectProtocol?
    private let notification: Notification.Name
    init() throws {
        let suite = ProcessInfo.processInfo.environment["PAPER_TEST_SUITE"].flatMap(UUID.init(uuidString:))?.uuidString ?? "main"
        let directory = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                                    appropriateFor: nil, create: true).appendingPathComponent("Paper/Instances")
        lease = try InstanceLease(directory: directory, name: "\(suite).lock")
        notification = Notification.Name("xyz.dustwave.paper.reopen.\(getuid()).\(suite)")
    }
    func acquire(onReopen: @escaping () -> Void) throws -> Bool {
        guard try lease.acquire() else {
            // Retries also cover another copy still initializing its delegate.
            for _ in 0..<5 {
                DistributedNotificationCenter.default().postNotificationName(notification, object: nil, userInfo: nil, deliverImmediately: true)
                RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            }
            return false
        }
        observer = DistributedNotificationCenter.default().addObserver(forName: notification, object: nil, queue: .main) { _ in
            Task { @MainActor in onReopen() }
        }
        return true
    }
    deinit { if let observer { DistributedNotificationCenter.default().removeObserver(observer) } }
}
