import Foundation

enum MediaStreamLine: Equatable {
    /// nil = nothing is playing
    case update(MediaState?)
    case ignored
}

/// Parses one line of `mediaremote-adapter stream --no-diff`.
enum MediaPayloadParser {
    private struct Envelope: Decodable {
        let type: String
        let payload: Payload?
    }

    private struct Payload: Decodable {
        let title: String?
        let artist: String?
        let playing: Bool?
        let bundleIdentifier: String?
    }

    static func parse(_ line: String) -> MediaStreamLine {
        guard let data = line.data(using: .utf8),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.type == "data" else { return .ignored }
        guard let payload = envelope.payload, let title = payload.title, !title.isEmpty else { return .update(nil) }
        let artist = payload.artist.flatMap { $0.isEmpty ? nil : $0 }
        return .update(MediaState(title: title, artist: artist,
                                  isPlaying: payload.playing ?? false,
                                  bundleIdentifier: payload.bundleIdentifier))
    }
}
