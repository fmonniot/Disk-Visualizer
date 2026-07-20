//
//  DiskScanner.swift
//  Disk Visualizer
//
//  Walks a directory tree on a background task and builds a `FileNode` tree
//  with recursive sizes.
//
//  The walk is done with `getattrlistbulk(2)`: one syscall returns a batch of
//  directory entries *with* their attributes (name, object type, modification
//  time, allocated size), replacing the per-entry
//  `contentsOfDirectory` + `resourceValues` that Foundation forces to run
//  serially in-process. Directories are drained by a bounded pool of worker
//  threads pulling from a shared LIFO stack, which — unlike Foundation — scales
//  with the number of cores (measured: two independent processes scan at full
//  solo speed, so the bottleneck was Foundation, not the disk).
//
//  Everything here is `nonisolated` so it never runs on the main actor (the
//  project defaults to `@MainActor` isolation). The finished tree is built once
//  and never mutated, preserving `FileNode`'s `@unchecked Sendable` invariant.
//

import Foundation
import Darwin

nonisolated enum DiskScanner {
    struct Cancelled: Error {}

    /// Directory extensions we present as a single opaque item (their contents
    /// are summed for size but not exposed as navigable children).
    private static let opaqueExtensions: Set<String> = [
        "app", "photoslibrary", "xcassets", "framework", "bundle",
        "sketch", "dsym", "pkg", "mpkg", "rtfd", "scptd",
    ]

    // MARK: - Entry point

    /// Scans `url` recursively. Throws `Cancelled` if the surrounding task is
    /// cancelled; other filesystem errors (permissions, races) are skipped.
    ///
    /// - Parameters:
    ///   - isCancelled: polled once per directory (default: the current task's
    ///     cancellation).
    ///   - excluded: directory paths to leave out of the walk. Defaults to the
    ///     firmlink/system and nested-volume mount points below `url`; tests
    ///     inject an explicit set.
    static func scan(
        url: URL,
        isCancelled: @escaping @Sendable () -> Bool = { Task.isCancelled },
        excluded: Set<String>? = nil
    ) throws -> FileNode {
        let path = url.path
        let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent

        // Stat the root itself — it has no parent directory to have listed it.
        var st = stat()
        guard lstat(path, &st) == 0 else {
            // Unreadable root: mirror the old scanner's "skip" behaviour with an
            // empty leaf rather than failing the whole scan.
            return FileNode(
                name: name, rootURL: url, isDirectory: false, size: 0,
                modified: Date(), category: FileCategory.forFile(extension: url.pathExtension),
                fileCount: 1, children: []
            )
        }

        let format = st.st_mode & S_IFMT
        let isDirectory = format == S_IFDIR
        let isSymlink = format == S_IFLNK
        let ext = url.pathExtension.lowercased()
        let isOpaque = opaqueExtensions.contains(ext)
            || (isDirectory && !ext.isEmpty && isPackageDirectory(path))
        let modified = date(sec: st.st_mtimespec.tv_sec, nsec: st.st_mtimespec.tv_nsec)

        // Leaves: plain files, symlinks, and opaque package bundles.
        if !isDirectory || isSymlink || isOpaque {
            let size = (isDirectory && !isSymlink)
                ? directorySize(path)
                : Int64(st.st_blocks) * 512
            return FileNode(
                name: name, rootURL: url, isDirectory: isDirectory, size: size,
                modified: modified, category: FileCategory.forFile(extension: url.pathExtension),
                fileCount: 1, children: []
            )
        }

        // A regular directory: drive the parallel walk. When the root is a
        // whole volume, `excluded` holds the synthetic firmlink mounts (e.g.
        // `/System/Volumes/Data`) and any nested mounts (other volumes,
        // external drives) so their bytes aren't crossed into or double-counted.
        let coordinator = ScanCoordinator(
            isCancelled: isCancelled,
            excluded: excluded ?? excludedMountPoints(under: path)
        )
        let root = Builder(name: name, ownModified: modified, parent: nil, rootURL: url)
        coordinator.push(root, path)
        coordinator.run()

        if coordinator.wasCancelled { throw Cancelled() }
        return coordinator.rootResult ?? FileNode(
            name: name, rootURL: url, isDirectory: true, size: 0, modified: modified,
            category: .folder, fileCount: 0, children: []
        )
    }

    // MARK: - Reading one directory

    /// Reads `path`, partitioning its entries into finished leaf nodes and
    /// pending subdirectory builders. Called off the coordinator lock so the
    /// syscalls run in parallel across workers.
    fileprivate static func readDirectory(
        path: String, parent: Builder, excluding excluded: Set<String>
    ) -> (leaves: [FileNode], subdirs: [(Builder, String)]) {
        var leaves: [FileNode] = []
        var subdirs: [(Builder, String)] = []

        enumerateDirectory(path: path) { name, objType, modified, size in
            let childPath = join(path, name)
            if objType == objTypeDir {
                // A firmlink/system mount or a nested volume: not part of this
                // volume's tree (its content is reached elsewhere, or lives on
                // another device).
                if excluded.contains(childPath) { return }
                let ext = fileExtension(of: name).lowercased()
                let isOpaque = opaqueExtensions.contains(ext)
                    || (!ext.isEmpty && isPackageDirectory(childPath))
                if isOpaque {
                    // An opaque bundle: summed for size but not navigable.
                    leaves.append(FileNode(
                        name: name, rootURL: nil, isDirectory: true,
                        size: directorySize(childPath), modified: modified,
                        category: FileCategory.forFile(extension: ext),
                        fileCount: 1, children: []
                    ))
                } else {
                    let sub = Builder(name: name, ownModified: modified, parent: parent, rootURL: nil)
                    subdirs.append((sub, childPath))
                }
            } else {
                // A plain file, symlink, or special file — always a leaf.
                leaves.append(FileNode(
                    name: name, rootURL: nil, isDirectory: false, size: size,
                    modified: modified, category: FileCategory.forFile(extension: fileExtension(of: name)),
                    fileCount: 1, children: []
                ))
            }
        }
        return (leaves, subdirs)
    }

    /// Builds the finished `FileNode` for a directory whose children are all
    /// finalized. Aggregates size/count/modtime and sorts children by size
    /// (descending) so downstream layouts never re-sort.
    fileprivate static func buildDirectoryNode(_ builder: Builder) -> FileNode {
        var children = builder.children
        children.sort { $0.size > $1.size }

        let size = children.reduce(0) { $0 + $1.size }
        let fileCount = children.reduce(0) { $0 + $1.fileCount }
        let modified = children.map(\.modified).max() ?? builder.ownModified
        let category = dominantCategory(of: children) ?? .folder

        return FileNode(
            name: builder.name, rootURL: builder.rootURL, isDirectory: true,
            size: size, modified: modified, category: category,
            fileCount: fileCount, children: children
        )
    }

    // MARK: - Opaque-bundle size

    /// Sums allocated sizes of every file inside an opaque directory, walking
    /// it iteratively with the same `getattrlistbulk` primitive.
    private static func directorySize(_ path: String) -> Int64 {
        var total: Int64 = 0
        var stack: [String] = [path]
        while let dir = stack.popLast() {
            enumerateDirectory(path: dir) { name, objType, _, size in
                if objType == objTypeDir {
                    stack.append(join(dir, name))
                } else {
                    total += size
                }
            }
        }
        return total
    }

    // MARK: - getattrlistbulk

    /// `fsobj_type_t` values we care about; everything that isn't a directory is
    /// treated as a leaf (so symlinks are never followed).
    private static let objTypeDir: UInt32 = 2 // VDIR

    // Attribute-mask bits (from <sys/attr.h>), spelled out to avoid depending on
    // the imported macro types.
    private static let attrCmnReturnedAttrs: UInt32 = 0x8000_0000
    private static let attrCmnName: UInt32          = 0x0000_0001
    private static let attrCmnObjType: UInt32       = 0x0000_0008
    private static let attrCmnModtime: UInt32       = 0x0000_0400
    private static let attrFileAllocSize: UInt32    = 0x0000_0004
    private static let fsOptPackInvalAttrs: UInt64  = 0x0000_0008

    // Fixed byte offsets of each requested attribute within an entry. Valid
    // because FSOPT_PACK_INVAL_ATTRS makes the kernel emit every requested
    // attribute (zero-filled if unavailable), so the layout never shifts:
    //   [0]  u_int32_t        entry length
    //   [4]  attribute_set_t  returned attrs (5 × u_int32_t)
    //   [24] attrreference_t  name (offset + length), offset is from byte 24
    //   [32] fsobj_type_t     object type
    //   [36] struct timespec  modification time (tv_sec, tv_nsec)
    //   [52] off_t            allocated size
    private static let offName = 24
    private static let offObjType = 32
    private static let offModSec = 36
    private static let offModNsec = 44
    private static let offAllocSize = 52

    /// Opens `path` and invokes `body` once per entry. Unreadable directories
    /// (permissions, races) are silently skipped, matching the old scanner.
    private static func enumerateDirectory(
        path: String,
        _ body: (_ name: String, _ objType: UInt32, _ modified: Date, _ size: Int64) -> Void
    ) {
        let fd = open(path, O_RDONLY | O_DIRECTORY)
        guard fd >= 0 else { return }
        defer { close(fd) }

        var attrList = attrlist()
        attrList.bitmapcount = 5 // ATTR_BIT_MAP_COUNT
        attrList.commonattr = attrCmnReturnedAttrs | attrCmnName | attrCmnObjType | attrCmnModtime
        attrList.fileattr = attrFileAllocSize

        let bufSize = 64 * 1024
        let buf = UnsafeMutableRawBufferPointer.allocate(byteCount: bufSize, alignment: 8)
        defer { buf.deallocate() }
        guard let base = buf.baseAddress else { return }

        while true {
            let count = getattrlistbulk(fd, &attrList, base, bufSize, fsOptPackInvalAttrs)
            if count <= 0 { break }

            var offset = 0
            for _ in 0..<count {
                let entry = base + offset
                let length = entry.loadUnaligned(fromByteOffset: 0, as: UInt32.self)
                let nameRefOffset = entry.loadUnaligned(fromByteOffset: offName, as: Int32.self)
                let objType = entry.loadUnaligned(fromByteOffset: offObjType, as: UInt32.self)
                let sec = entry.loadUnaligned(fromByteOffset: offModSec, as: Int.self)
                let nsec = entry.loadUnaligned(fromByteOffset: offModNsec, as: Int.self)
                let allocSize = entry.loadUnaligned(fromByteOffset: offAllocSize, as: Int64.self)

                let namePtr = (entry + offName + Int(nameRefOffset))
                    .assumingMemoryBound(to: CChar.self)
                let name = String(cString: namePtr)

                body(name, objType, date(sec: sec, nsec: nsec), allocSize)
                offset += Int(length)
            }
        }
    }

    // MARK: - Helpers

    private static func date(sec: Int, nsec: Int) -> Date {
        Date(timeIntervalSince1970: Double(sec) + Double(nsec) / 1_000_000_000)
    }

    /// Joins a directory path and an entry name, avoiding a doubled separator
    /// when the directory is the volume root ("/").
    private static func join(_ path: String, _ name: String) -> String {
        path.hasSuffix("/") ? path + name : path + "/" + name
    }

    /// Extension of a bare file name, matching `URL.pathExtension` semantics
    /// (a leading dot is not an extension, e.g. `.gitignore`).
    private static func fileExtension(of name: String) -> String {
        guard let dot = name.lastIndex(of: "."), dot != name.startIndex else { return "" }
        return String(name[name.index(after: dot)...])
    }

    /// LaunchServices-backed package check. The `isPackage` flag isn't available
    /// at the `getattrlistbulk` layer, so this is used only as a targeted
    /// fallback for dotted directory names not already in `opaqueExtensions`.
    private static func isPackageDirectory(_ path: String) -> Bool {
        let values = try? URL(fileURLWithPath: path, isDirectory: true)
            .resourceValues(forKeys: [.isPackageKey])
        return values?.isPackage ?? false
    }

    // MARK: - Volume topology

    /// Mount points strictly below `rootPath` that the walk must not descend
    /// into. Two things live here:
    ///
    /// - **Firmlink / system mounts** (`/System/Volumes/Data`, `/System/Volumes/
    ///   Preboot`, `VM`, …). On the APFS boot volume group the writable Data
    ///   volume is firmlinked so its content already appears at `/Users`,
    ///   `/Applications`, etc.; its own mount point re-exposes the *same* bytes.
    ///   These are flagged `MNT_DONTBROWSE` (Finder hides them for the same
    ///   reason). Skipping them removes the double-counting.
    /// - **Nested volumes** (external drives under `/Volumes`, network mounts).
    ///   A whole-volume scan means the selected volume only, so any mount on a
    ///   different filesystem than the root is left out.
    ///
    /// Using the mount table (rather than a per-entry device-id guard) is
    /// necessary because the firmlinked Data volume deliberately reports the
    /// *same* `st_dev` as `/`, so a device-change check can't see it.
    private static func excludedMountPoints(under rootPath: String) -> Set<String> {
        var buffer: UnsafeMutablePointer<statfs>?
        let count = getmntinfo(&buffer, MNT_NOWAIT)
        guard count > 0, let buffer else { return [] }

        var excluded: Set<String> = []
        for i in 0..<Int(count) {
            let mountPoint = withUnsafeBytes(of: buffer[i].f_mntonname) { raw in
                String(cString: raw.baseAddress!.assumingMemoryBound(to: CChar.self))
            }
            if isStrictDescendant(mountPoint, of: rootPath) {
                excluded.insert(mountPoint)
            }
        }
        return excluded
    }

    /// Whether `path` sits strictly below `root` (never equal to it).
    private static func isStrictDescendant(_ path: String, of root: String) -> Bool {
        if root == "/" { return path != "/" }
        return path.hasPrefix(root.hasSuffix("/") ? root : root + "/")
    }

    /// The category holding the most bytes among `children` — matching the
    /// design's `_dom` aggregation.
    private static func dominantCategory(of children: [FileNode]) -> FileCategory? {
        var totals: [FileCategory: Int64] = [:]
        for child in children {
            totals[child.category, default: 0] += child.size
        }
        return totals.max { $0.value < $1.value }?.key
    }
}

// MARK: - Parallel walk

/// A directory under construction. All mutable state is touched only under the
/// coordinator's lock; the finished `FileNode` is built once (outside the lock)
/// when `pending` reaches zero.
private nonisolated final class Builder {
    let name: String
    let ownModified: Date
    let parent: Builder?
    let rootURL: URL?

    /// Finished children: leaf nodes (appended when this directory is read) and
    /// finalized subdirectory nodes (appended as each subtree completes).
    var children: [FileNode] = []
    /// Number of subdirectory children not yet finalized.
    var pending: Int = 0

    init(name: String, ownModified: Date, parent: Builder?, rootURL: URL?) {
        self.name = name
        self.ownModified = ownModified
        self.parent = parent
        self.rootURL = rootURL
    }
}

/// Owns the shared work stack and drives a bounded pool of worker threads.
/// The heavy work (syscalls, node construction) happens off the lock; the lock
/// only guards the stack, the in-flight counter, and per-builder aggregation
/// bookkeeping.
private nonisolated final class ScanCoordinator: @unchecked Sendable {
    private let cond = NSCondition()
    private var stack: [(Builder, String)] = []
    private var inFlight = 0
    private var cancelled = false
    private(set) var rootResult: FileNode?

    private let isCancelled: @Sendable () -> Bool
    private let excluded: Set<String>

    init(isCancelled: @escaping @Sendable () -> Bool, excluded: Set<String>) {
        self.isCancelled = isCancelled
        self.excluded = excluded
    }

    var wasCancelled: Bool {
        cond.lock(); defer { cond.unlock() }
        return cancelled
    }

    func push(_ builder: Builder, _ path: String) {
        cond.lock()
        stack.append((builder, path))
        cond.signal()
        cond.unlock()
    }

    func run() {
        let workers = max(2, ProcessInfo.processInfo.activeProcessorCount)
        DispatchQueue.concurrentPerform(iterations: workers) { _ in
            self.workerLoop()
        }
    }

    private func workerLoop() {
        while let (builder, path) = nextWork() {
            let (leaves, subdirs) = DiskScanner.readDirectory(path: path, parent: builder, excluding: excluded)
            completeRead(builder, leaves: leaves, subdirs: subdirs)
        }
    }

    /// Pops the next directory to read, blocking while others are still in
    /// flight (they may yet push more work). Returns `nil` once the tree is
    /// fully drained or the scan is cancelled.
    private func nextWork() -> (Builder, String)? {
        cond.lock()
        defer { cond.unlock() }
        while true {
            if cancelled { cond.broadcast(); return nil }
            if isCancelled() {
                cancelled = true
                cond.broadcast()
                return nil
            }
            if let work = stack.popLast() {
                inFlight += 1
                return work
            }
            if inFlight == 0 {
                cond.broadcast()
                return nil
            }
            cond.wait()
        }
    }

    /// Records the result of reading one directory: attaches its leaves, queues
    /// its subdirectories, and — if it had none — begins finalizing it.
    private func completeRead(_ builder: Builder, leaves: [FileNode], subdirs: [(Builder, String)]) {
        cond.lock()
        builder.children.append(contentsOf: leaves)
        builder.pending = subdirs.count
        for work in subdirs { stack.append(work) }
        inFlight -= 1
        let readyToFinalize = builder.pending == 0
        cond.broadcast()
        cond.unlock()

        if readyToFinalize { finalizeCascade(builder) }
    }

    /// Finalizes `start`, then walks up finalizing every ancestor whose last
    /// child just completed. The `FileNode` construction runs off the lock;
    /// only attaching a finished node to its parent is guarded. Exactly one
    /// worker ever finalizes a given builder (the one that drives `pending` to
    /// zero), so reading `children` off the lock here is safe.
    private func finalizeCascade(_ start: Builder) {
        var builder = start
        while true {
            let finished = DiskScanner.buildDirectoryNode(builder)

            cond.lock()
            guard let parent = builder.parent else {
                rootResult = finished
                cond.broadcast()
                cond.unlock()
                return
            }
            parent.children.append(finished)
            parent.pending -= 1
            let parentReady = parent.pending == 0
            cond.unlock()

            if parentReady { builder = parent } else { return }
        }
    }
}
