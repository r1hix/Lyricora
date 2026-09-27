import Foundation
import SwiftUI

public enum PlaybackStatus: String, Codable, Sendable {
    case playing = "Playing"
    case paused = "Paused"
    case stopped = "Stopped"
    case unknown = "Unknown"
    
    public var isPlaying: Bool {
        self == .playing
    }
}

public struct Track: Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let artist: String
    public let album: String
    public let duration: TimeInterval
    public var artworkURL: URL?

    public init(
        id: String,
        title: String,
        artist: String,
        album: String,
        duration: TimeInterval,
        artworkURL: URL? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.artworkURL = artworkURL
    }
    
    public static let placeholder = Track(
        id: "placeholder",
        title: "Waiting for Spotify",
        artist: "Play a song in Spotify to begin",
        album: "Lyricora",
        duration: 210,
        artworkURL: nil
    )
}

public enum ViewMode: String, CaseIterable, Identifiable, Sendable {
    case miniHUD = "Mini HUD"
    case fullOverlay = "Full Lyrics"
    case ambientCanvas = "Ambient Canvas"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .miniHUD:
            return "capsule"
        case .fullOverlay:
            return "quote.bubble.fill"
        case .ambientCanvas:
            return "sparkles.rectangle.stack.fill"
        }
    }
    
    public var windowSize: CGSize {
        switch self {
        case .miniHUD:
            return CGSize(width: 480, height: 72)
        case .fullOverlay:
            return CGSize(width: 460, height: 680)
        case .ambientCanvas:
            return CGSize(width: 900, height: 650)
        }
    }
}

public enum TouchBarLyricsMode: String, CaseIterable, Identifiable, Sendable {
    case off = "Off"
    case lineByLine = "Line by Line"
    case wordFill = "Word Fill with Shaders"
    
    public var id: String { rawValue }
    
    public var iconName: String {
        switch self {
        case .off: return "slash.circle"
        case .lineByLine: return "text.alignleft"
        case .wordFill: return "sparkles"
        }
    }
}
