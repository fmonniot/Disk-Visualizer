//
//  FileCategory.swift
//  Disk Visualizer
//
//  Classifies a file (or, for a folder, its dominant content) into a broad
//  type used for coloring the visualization. Mirrors the `TYPES` table from
//  the design.
//

import Foundation

nonisolated enum FileCategory: String, CaseIterable, Sendable {
    case folder
    case video
    case image
    case document
    case archive
    case app
    case audio
    case code
    case system

    /// Human-readable label shown in the legend.
    var label: String {
        switch self {
        case .folder:   return "Folder"
        case .video:    return "Video"
        case .image:    return "Images"
        case .document: return "Documents"
        case .archive:  return "Archives"
        case .app:      return "Apps"
        case .audio:    return "Audio"
        case .code:     return "Code"
        case .system:   return "System"
        }
    }

    /// Singular label used for a selected item's "kind" line.
    var singularLabel: String {
        switch self {
        case .folder:   return "Folder"
        case .video:    return "Video"
        case .image:    return "Image"
        case .document: return "Document"
        case .archive:  return "Archive"
        case .app:      return "App"
        case .audio:    return "Audio"
        case .code:     return "Code"
        case .system:   return "System"
        }
    }

    /// Gradient start color (`c0`) as a hex string.
    var startHex: String {
        switch self {
        case .folder:   return "5b6270"
        case .video:    return "6a4bff"
        case .image:    return "22c55e"
        case .document: return "f59e0b"
        case .archive:  return "ef4444"
        case .app:      return "14b8c6"
        case .audio:    return "ec4899"
        case .code:     return "eab308"
        case .system:   return "6b7280"
        }
    }

    /// Gradient end color (`c1`) as a hex string.
    var endHex: String {
        switch self {
        case .folder:   return "828a99"
        case .video:    return "a86bff"
        case .image:    return "5ee089"
        case .document: return "ffca57"
        case .archive:  return "ff7a72"
        case .app:      return "54e0ea"
        case .audio:    return "ff77b4"
        case .code:     return "ffe15a"
        case .system:   return "9aa2b1"
        }
    }

    /// Order used by the legend at the bottom of the window.
    static let legendOrder: [FileCategory] =
        [.video, .image, .document, .archive, .app, .audio, .code, .system]

    /// Classifies a file by its path extension.
    static func forFile(extension ext: String) -> FileCategory {
        switch ext.lowercased() {
        case "mov", "mp4", "m4v", "avi", "mkv", "webm", "wmv", "flv", "mpg", "mpeg":
            return .video
        case "jpg", "jpeg", "png", "gif", "heic", "heif", "tiff", "tif", "bmp",
             "webp", "svg", "raw", "cr2", "nef", "arw", "dng", "psd", "sketch",
             "xcassets", "photoslibrary", "icns":
            return .image
        case "pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "key", "pages",
             "numbers", "txt", "md", "rtf", "epub", "csv":
            return .document
        case "zip", "tar", "gz", "tgz", "bz2", "xz", "rar", "7z", "iso", "dmg":
            return .archive
        case "app", "pkg", "mpkg":
            return .app
        case "mp3", "flac", "wav", "aac", "m4a", "ogg", "aiff", "aif", "alac":
            return .audio
        case "swift", "js", "ts", "jsx", "tsx", "html", "css", "scss", "py",
             "rb", "go", "rs", "c", "cpp", "cc", "h", "hpp", "m", "mm", "java",
             "kt", "json", "yaml", "yml", "toml", "sh", "resolved", "lock":
            return .code
        default:
            return .system
        }
    }
}
