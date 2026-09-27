import Foundation
import Combine
import AppKit
import QuartzCore
import Observation

@Observable
@MainActor
public final class SpotifyObserver {
    public static let shared = SpotifyObserver()
    
    // MARK: - Published State
    public private(set) var currentTrack: Track?
    public private(set) var playbackStatus: PlaybackStatus = .unknown
    public private(set) var anchorPosition: TimeInterval = 0.0
    public private(set) var anchorMediaTime: TimeInterval = 0.0
    public private(set) var trackDuration: TimeInterval = 0.0
    public private(set) var isSpotifyRunning: Bool = false
    public private(set) var artworkImage: NSImage?
    
    public var isPlaying: Bool {
        playbackStatus == .playing
    }
    
    // MARK: - Private Properties
    private var cancellables = Set<AnyCancellable>()
    private let spotifyBundleId = "com.spotify.client"
    private var lastArtworkFetchTrackId: String?
    
    // MARK: - Initialization
    public init() {
        setupNotificationObservers()
        checkInitialSpotifyState()
    }
    
    // MARK: - High-Precision Time Interpolation (Zero Polling)
    /// Calculates the current interpolated playback position based on monotonic media time.
    /// Returns the exact anchor position if paused, avoiding clock drift and zero battery consumption.
    public func interpolatedPosition(at mediaTime: TimeInterval = CACurrentMediaTime()) -> TimeInterval {
        guard isPlaying else {
            return anchorPosition
        }
        let elapsed = max(0, mediaTime - anchorMediaTime)
        let estimated = anchorPosition + elapsed
        if trackDuration > 0 {
            return min(estimated, trackDuration)
        }
        return estimated
    }
    
    // MARK: - Notification Setup
    private func setupNotificationObservers() {
        // Spotify distributed notification for playback state and track metadata
        DistributedNotificationCenter.default()
            .publisher(for: Notification.Name("com.spotify.client.PlaybackStateChanged"))
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                self?.handlePlaybackStateChanged(notification)
            }
            .store(in: &cancellables)
        
        // Monitor when Spotify application launches or terminates
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == self.spotifyBundleId else { return }
                self.isSpotifyRunning = true
                self.fetchCurrentSpotifyStateOneShot()
            }
            .store(in: &cancellables)
        
        NSWorkspace.shared.notificationCenter
            .publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                      app.bundleIdentifier == self.spotifyBundleId else { return }
                self.isSpotifyRunning = false
                self.playbackStatus = .stopped
                self.currentTrack = nil
                self.artworkImage = nil
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Handling
    private func handlePlaybackStateChanged(_ notification: Notification) {
        guard let userInfo = notification.userInfo else { return }
        
        self.isSpotifyRunning = true
        
        // Parse Player State
        if let rawState = userInfo["Player State"] as? String {
            switch rawState.lowercased() {
            case "playing":
                self.playbackStatus = .playing
            case "paused":
                self.playbackStatus = .paused
            default:
                self.playbackStatus = .stopped
            }
        }
        
        // Parse Position
        var position: TimeInterval = 0.0
        if let pos = userInfo["Playback Position"] as? Double {
            position = pos
        } else if let pos = userInfo["Playback Position"] as? Int {
            position = Double(pos)
        }
        
        // Parse Duration
        var duration: TimeInterval = 0.0
        if let dur = userInfo["Duration"] as? Double {
            duration = dur > 10_000 ? dur / 1000.0 : dur
        } else if let dur = userInfo["Duration"] as? Int {
            let durDouble = Double(dur)
            duration = durDouble > 10_000 ? durDouble / 1000.0 : durDouble
        }
        
        // Calibrate local high-precision clock
        self.anchorPosition = position
        self.anchorMediaTime = CACurrentMediaTime()
        self.trackDuration = duration
        
        // Parse Track Metadata
        let trackId = userInfo["Track ID"] as? String ?? ""
        let name = userInfo["Name"] as? String ?? "Unknown Track"
        let artist = userInfo["Artist"] as? String ?? "Unknown Artist"
        let album = userInfo["Album"] as? String ?? "Unknown Album"
        
        // Check if track changed (by ID or Title/Artist)
        let isDifferentTrack = (self.currentTrack?.id != trackId && !trackId.isEmpty) ||
                               (self.currentTrack?.title != name) ||
                               (self.currentTrack?.artist != artist)
        
        let newTrack = Track(
            id: trackId,
            title: name,
            artist: artist,
            album: album,
            duration: duration,
            artworkURL: isDifferentTrack ? nil : self.currentTrack?.artworkURL
        )
        self.currentTrack = newTrack
        
        if isDifferentTrack {
            self.lastArtworkFetchTrackId = nil
            self.artworkImage = nil // Reset old artwork so views re-render cleanly
            fetchArtworkForCurrentTrack(track: newTrack)
        }
    }
    
    // MARK: - Initial State Query (One-Shot Only, Zero Polling)
    private func checkInitialSpotifyState() {
        let runningApps = NSWorkspace.shared.runningApplications
        self.isSpotifyRunning = runningApps.contains { $0.bundleIdentifier == spotifyBundleId }
        
        if self.isSpotifyRunning {
            fetchCurrentSpotifyStateOneShot()
        }
    }
    
    private func fetchCurrentSpotifyStateOneShot() {
        Task.detached(priority: .userInitiated) {
            let script = """
            tell application "Spotify"
                if it is running then
                    set pState to player state as string
                    set pPosition to player position as real
                    set tDuration to duration of current track as real
                    set tName to name of current track as string
                    set tArtist to artist of current track as string
                    set tAlbum to album of current track as string
                    set tId to id of current track as string
                    set tArt to artwork url of current track as string
                    return pState & "|||" & pPosition & "|||" & (tDuration / 1000.0) & "|||" & tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tId & "|||" & tArt
                else
                    return ""
                end if
            end tell
            """
            
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            let result = appleScript?.executeAndReturnError(&error)
            
            guard error == nil, let stringValue = result?.stringValue, !stringValue.isEmpty else { return }
            
            let components = stringValue.components(separatedBy: "|||")
            guard components.count >= 8 else { return }
            
            let stateStr = components[0].lowercased()
            let position = Double(components[1]) ?? 0.0
            let duration = Double(components[2]) ?? 0.0
            let name = components[3]
            let artist = components[4]
            let album = components[5]
            let trackId = components[6]
            let artworkUrlStr = components[7]
            
            await MainActor.run { [weak self] in
                guard let self = self else { return }
                self.playbackStatus = (stateStr == "playing") ? .playing : .paused
                self.anchorPosition = position
                self.anchorMediaTime = CACurrentMediaTime()
                self.trackDuration = duration
                
                let artworkURL = URL(string: artworkUrlStr)
                let track = Track(
                    id: trackId,
                    title: name,
                    artist: artist,
                    album: album,
                    duration: duration,
                    artworkURL: artworkURL
                )
                self.currentTrack = track
                self.fetchArtworkForCurrentTrack(track: track)
            }
        }
    }
    
    // MARK: - Artwork Fetching & Fallback
    private func fetchArtworkForCurrentTrack(track: Track) {
        let fetchId = !track.id.isEmpty ? track.id : "\(track.artist)-\(track.title)"
        guard fetchId != lastArtworkFetchTrackId || artworkImage == nil else { return }
        lastArtworkFetchTrackId = fetchId
        
        Task.detached(priority: .utility) { [weak self] in
            // Try fetching from Spotify AppleScript artwork url
            var artURL: URL? = nil
            let script = "tell application \"Spotify\" to if it is running then return artwork url of current track"
            var err: NSDictionary?
            if let res = NSAppleScript(source: script)?.executeAndReturnError(&err).stringValue,
               let parsedURL = URL(string: res), !res.isEmpty {
                artURL = parsedURL
            }
            
            // Fallback: iTunes Search API for high-resolution artwork
            if artURL == nil {
                artURL = await self?.fetchiTunesArtwork(track: track)
            }
            
            guard let validURL = artURL else { return }
            
            // Download image
            do {
                let (data, _) = try await URLSession.shared.data(from: validURL)
                if let image = NSImage(data: data) {
                    await MainActor.run { [weak self] in
                        guard let self = self, self.currentTrack?.title == track.title else { return }
                        self.artworkImage = image
                        self.currentTrack?.artworkURL = validURL
                    }
                }
            } catch {
                // Ignore transient network errors
            }
        }
    }
    
    private nonisolated func fetchiTunesArtwork(track: Track) async -> URL? {
        let query = "\(track.artist) \(track.title)"
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let url = URL(string: "https://itunes.apple.com/search?term=\(query)&entity=song&limit=1") else {
            return nil
        }
        
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            struct iTunesResponse: Decodable {
                struct Item: Decodable {
                    let artworkUrl100: String?
                }
                let results: [Item]
            }
            let decoded = try JSONDecoder().decode(iTunesResponse.self, from: data)
            if let artworkUrl100 = decoded.results.first?.artworkUrl100 {
                // Upscale to high quality 600x600 artwork
                let hiRes = artworkUrl100.replacingOccurrences(of: "100x100bb.jpg", with: "600x600bb.jpg")
                return URL(string: hiRes)
            }
        } catch {
            return nil
        }
        return nil
    }
    
    // MARK: - Transport Commands (Non-blocking Asynchronous AppleScript)
    public func togglePlayPause() {
        executeAppleScriptAsync("tell application \"Spotify\" to playpause")
        // Immediate optimistic state toggle for snappy UI feedback
        if playbackStatus == .playing {
            anchorPosition = interpolatedPosition()
            anchorMediaTime = CACurrentMediaTime()
            playbackStatus = .paused
        } else {
            anchorMediaTime = CACurrentMediaTime()
            playbackStatus = .playing
        }
    }
    
    public func play() {
        executeAppleScriptAsync("tell application \"Spotify\" to play")
        anchorMediaTime = CACurrentMediaTime()
        playbackStatus = .playing
    }
    
    public func pause() {
        executeAppleScriptAsync("tell application \"Spotify\" to pause")
        anchorPosition = interpolatedPosition()
        anchorMediaTime = CACurrentMediaTime()
        playbackStatus = .paused
    }
    
    public func nextTrack() {
        executeAppleScriptAsync("tell application \"Spotify\" to next track")
    }
    
    public func previousTrack() {
        executeAppleScriptAsync("tell application \"Spotify\" to previous track")
    }
    
    public func seek(to position: TimeInterval) {
        let clamped = min(max(0, position), max(trackDuration, 0))
        self.anchorPosition = clamped
        self.anchorMediaTime = CACurrentMediaTime()
        executeAppleScriptAsync("tell application \"Spotify\" to set player position to \(clamped)")
    }
    
    private func executeAppleScriptAsync(_ script: String) {
        Task.detached(priority: .userInitiated) {
            var error: NSDictionary?
            let appleScript = NSAppleScript(source: script)
            appleScript?.executeAndReturnError(&error)
        }
    }
}
