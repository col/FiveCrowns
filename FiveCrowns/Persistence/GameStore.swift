import Foundation

/// Reads and writes the game file. An actor so file I/O stays off the main
/// thread — the previous implementation wrapped I/O in `Task { }`, which
/// inherits the caller's executor and therefore did not.
actor GameStore {
    private let fileURL: URL
    private let debounce: Duration
    private var pendingSave: Task<Void, Never>?
    private var pendingSnapshot: GameSnapshot?
    /// Set when the file on disk was written by a newer build. Writing would
    /// destroy data this build cannot represent, so all saves become no-ops.
    private var isReadOnly = false

    init(fileURL: URL, debounce: Duration = .milliseconds(500)) {
        self.fileURL = fileURL
        self.debounce = debounce
    }

    /// The app's real store, in the documents directory.
    static func documents() throws -> GameStore {
        let directory = try FileManager.default.url(
            for: .documentDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true)
        return GameStore(fileURL: directory.appendingPathComponent("game.data"))
    }

    func load() -> GameSnapshot? {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            return nil
        }
        if let snapshot = try? JSONDecoder().decode(GameSnapshot.self, from: data) {
            guard !snapshot.isFromFutureVersion else {
                isReadOnly = true
                AppLog.persistence.error(
                    "Save file is schema v\(snapshot.schemaVersion) but this build reads v\(GameSnapshot.currentSchemaVersion); refusing to load or overwrite.")
                return nil
            }
            return snapshot
        }
        if let migrated = GameSnapshot(legacyData: data) {
            AppLog.persistence.info("Migrated a v1 save file to v2.")
            return migrated
        }
        quarantine(data)
        return nil
    }

    func save(_ snapshot: GameSnapshot) throws {
        guard !isReadOnly else { return }
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    /// Coalesces rapid mutations into one write.
    func scheduleSave(_ snapshot: GameSnapshot) {
        pendingSnapshot = snapshot
        pendingSave?.cancel()
        pendingSave = Task { [debounce] in
            try? await Task.sleep(for: debounce)
            guard !Task.isCancelled else { return }
            self.writePending()
        }
    }

    /// Writes any pending snapshot immediately rather than waiting out the
    /// debounce. Call before the app goes to the background.
    func flush() {
        pendingSave?.cancel()
        pendingSave = nil
        writePending()
    }

    private func writePending() {
        guard let snapshot = pendingSnapshot else { return }
        pendingSnapshot = nil
        do {
            try save(snapshot)
        } catch {
            AppLog.persistence.error(
                "Save failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Moves an undecodable file aside so the app can still launch. Previously
    /// a corrupt file crashed on every launch, bricking the install.
    private func quarantine(_ data: Data) {
        var candidate = fileURL.appendingPathExtension("corrupt")
        var suffix = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = fileURL.appendingPathExtension("corrupt-\(suffix)")
            suffix += 1
        }
        try? data.write(to: candidate, options: .atomic)
        try? FileManager.default.removeItem(at: fileURL)
        AppLog.persistence.error(
            "Save file was unreadable; quarantined to \(candidate.lastPathComponent, privacy: .public)")
    }
}
