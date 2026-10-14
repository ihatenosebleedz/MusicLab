import Foundation
import MusicLabCore

public enum MockData: Sendable {
    public static let sampleAlbums: [CatalogItem] = [
        CatalogItem(
            id: "1774438340",
            type: .album,
            title: "GNX",
            artistName: "Kendrick Lamar",
            albumName: "GNX",
            releaseDate: "2024-11-22",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music221/v4/31/5a/8f/315a8fb4-e503-455c-b172-e56c5e88e89f/24UM1IM41846.rgb.jpg/600x600bb.jpg",
            trackCount: 12,
            appleMusicUrl: "https://music.apple.com/us/album/gnx/1781290351",
            genre: "Hip-Hop/Rap",
            tracks: [
                TrackItem(trackNumber: 1, title: "wacced out murals", artistName: "Kendrick Lamar", durationSeconds: 331, isExplicit: true),
                TrackItem(trackNumber: 2, title: "squabble up", artistName: "Kendrick Lamar", durationSeconds: 158, isExplicit: true),
                TrackItem(trackNumber: 3, title: "luther (feat. SZA)", artistName: "Kendrick Lamar & SZA", durationSeconds: 178, isExplicit: true),
                TrackItem(trackNumber: 4, title: "man at the garden", artistName: "Kendrick Lamar", durationSeconds: 232, isExplicit: true),
                TrackItem(trackNumber: 5, title: "hey now (feat. Dody6)", artistName: "Kendrick Lamar", durationSeconds: 219, isExplicit: true),
                TrackItem(trackNumber: 6, title: "reincarnated", artistName: "Kendrick Lamar", durationSeconds: 275, isExplicit: true),
                TrackItem(trackNumber: 7, title: "tv off (feat. Lefty Gunplay)", artistName: "Kendrick Lamar", durationSeconds: 161, isExplicit: true),
                TrackItem(trackNumber: 8, title: "dodger blue", artistName: "Kendrick Lamar", durationSeconds: 131, isExplicit: true),
                TrackItem(trackNumber: 9, title: "peekaboo (feat. AzChike)", artistName: "Kendrick Lamar", durationSeconds: 154, isExplicit: true),
                TrackItem(trackNumber: 10, title: "heart pt. 6", artistName: "Kendrick Lamar", durationSeconds: 292, isExplicit: true),
                TrackItem(trackNumber: 11, title: "gnx (feat. Hitta J3, YoungThreat & Peysoh)", artistName: "Kendrick Lamar", durationSeconds: 202, isExplicit: true),
                TrackItem(trackNumber: 12, title: "gloria (feat. SZA)", artistName: "Kendrick Lamar & SZA", durationSeconds: 288, isExplicit: true)
            ]
        ),
        CatalogItem(
            id: "1732646278",
            type: .album,
            title: "BRAT",
            artistName: "Charli xcx",
            albumName: "BRAT",
            releaseDate: "2024-06-07",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/21/d9/6a/21d96ad8-12c8-8988-cb9d-d6ee65bebb4a/5054197949313.jpg/600x600bb.jpg",
            trackCount: 15,
            appleMusicUrl: "https://music.apple.com/us/album/brat/1732646278",
            genre: "Pop",
            tracks: [
                TrackItem(trackNumber: 1, title: "360", artistName: "Charli xcx", durationSeconds: 133, isExplicit: true),
                TrackItem(trackNumber: 2, title: "Club classics", artistName: "Charli xcx", durationSeconds: 153, isExplicit: false),
                TrackItem(trackNumber: 3, title: "Sympathy is a knife", artistName: "Charli xcx", durationSeconds: 151, isExplicit: true),
                TrackItem(trackNumber: 4, title: "I might say something stupid", artistName: "Charli xcx", durationSeconds: 109, isExplicit: false),
                TrackItem(trackNumber: 5, title: "Talk talk", artistName: "Charli xcx", durationSeconds: 161, isExplicit: false),
                TrackItem(trackNumber: 6, title: "Von dutch", artistName: "Charli xcx", durationSeconds: 164, isExplicit: true),
                TrackItem(trackNumber: 7, title: "Everything is romantic", artistName: "Charli xcx", durationSeconds: 203, isExplicit: false),
                TrackItem(trackNumber: 8, title: "Rewind", artistName: "Charli xcx", durationSeconds: 168, isExplicit: false),
                TrackItem(trackNumber: 9, title: "So I", artistName: "Charli xcx", durationSeconds: 211, isExplicit: false),
                TrackItem(trackNumber: 10, title: "Girl, so confusing", artistName: "Charli xcx", durationSeconds: 174, isExplicit: true),
                TrackItem(trackNumber: 11, title: "Apple", artistName: "Charli xcx", durationSeconds: 151, isExplicit: false),
                TrackItem(trackNumber: 12, title: "B2b", artistName: "Charli xcx", durationSeconds: 178, isExplicit: false),
                TrackItem(trackNumber: 13, title: "Mean girls", artistName: "Charli xcx", durationSeconds: 189, isExplicit: true),
                TrackItem(trackNumber: 14, title: "I think about it all the time", artistName: "Charli xcx", durationSeconds: 135, isExplicit: false),
                TrackItem(trackNumber: 15, title: "365", artistName: "Charli xcx", durationSeconds: 203, isExplicit: true)
            ]
        ),
        CatalogItem(
            id: "693452296",
            type: .album,
            title: "Discovery",
            artistName: "Daft Punk",
            albumName: "Discovery",
            releaseDate: "2001-03-12",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/43/d0/1e/43d01ee3-a3b0-51a7-0e62-c07a9b0c51cb/00724384960650.rgb.jpg/600x600bb.jpg",
            trackCount: 14,
            appleMusicUrl: "https://music.apple.com/us/album/discovery/693452296",
            genre: "Electronic",
            tracks: [
                TrackItem(trackNumber: 1, title: "One More Time", artistName: "Daft Punk", durationSeconds: 320, isExplicit: false),
                TrackItem(trackNumber: 2, title: "Aerodynamic", artistName: "Daft Punk", durationSeconds: 207, isExplicit: false),
                TrackItem(trackNumber: 3, title: "Digital Love", artistName: "Daft Punk", durationSeconds: 298, isExplicit: false),
                TrackItem(trackNumber: 4, title: "Harder, Better, Faster, Stronger", artistName: "Daft Punk", durationSeconds: 224, isExplicit: false),
                TrackItem(trackNumber: 5, title: "Crescendolls", artistName: "Daft Punk", durationSeconds: 211, isExplicit: false),
                TrackItem(trackNumber: 6, title: "Nightvision", artistName: "Daft Punk", durationSeconds: 104, isExplicit: false),
                TrackItem(trackNumber: 7, title: "Superheroes", artistName: "Daft Punk", durationSeconds: 237, isExplicit: false),
                TrackItem(trackNumber: 8, title: "High Life", artistName: "Daft Punk", durationSeconds: 202, isExplicit: false),
                TrackItem(trackNumber: 9, title: "Something About Us", artistName: "Daft Punk", durationSeconds: 231, isExplicit: false),
                TrackItem(trackNumber: 10, title: "Voyager", artistName: "Daft Punk", durationSeconds: 227, isExplicit: false),
                TrackItem(trackNumber: 11, title: "Veridis Quo", artistName: "Daft Punk", durationSeconds: 345, isExplicit: false),
                TrackItem(trackNumber: 12, title: "Short Circuit", artistName: "Daft Punk", durationSeconds: 206, isExplicit: false),
                TrackItem(trackNumber: 13, title: "Face to Face", artistName: "Daft Punk", durationSeconds: 240, isExplicit: false),
                TrackItem(trackNumber: 14, title: "Too Long", artistName: "Daft Punk", durationSeconds: 600, isExplicit: false)
            ]
        )
    ]
    
    public static let sampleSongs: [CatalogItem] = [
        CatalogItem(
            id: "1732646280",
            type: .song,
            title: "360",
            artistName: "Charli xcx",
            albumName: "BRAT",
            releaseDate: "2024-05-10",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music211/v4/21/d9/6a/21d96ad8-12c8-8988-cb9d-d6ee65bebb4a/5054197949313.jpg/600x600bb.jpg",
            trackCount: 1,
            appleMusicUrl: "https://music.apple.com/us/album/360/1732646278?i=1732646280",
            genre: "Pop"
        ),
        CatalogItem(
            id: "693452300",
            type: .song,
            title: "One More Time",
            artistName: "Daft Punk",
            albumName: "Discovery",
            releaseDate: "2000-11-13",
            artworkUrl: "https://is1-ssl.mzstatic.com/image/thumb/Music115/v4/43/d0/1e/43d01ee3-a3b0-51a7-0e62-c07a9b0c51cb/00724384960650.rgb.jpg/600x600bb.jpg",
            trackCount: 1,
            appleMusicUrl: "https://music.apple.com/us/album/one-more-time/693452296?i=693452300",
            genre: "Electronic"
        )
    ]
    
    public static let sampleJobs: [Job] = [
        Job(
            id: "job-101",
            type: "album",
            url: "https://music.apple.com/us/album/gnx/1781290351",
            name: "Kendrick Lamar — GNX",
            state: .verifying,
            stage: .verifying,
            progressHint: "Waiting for Navidrome auto-discovery (attempt 2/10)",
            createdAt: Date().addingTimeInterval(-180),
            updatedAt: Date().addingTimeInterval(-10),
            startedAt: Date().addingTimeInterval(-175),
            stdoutTail: "Parsed 12 tracks.\nFetched audio + lyrics sidecars.\nWritten to /mnt/media/Music/Kendrick Lamar/GNX (2024)/",
            addedTracks: [
                JobAddedTrack(title: "wacced out murals", artist: "Kendrick Lamar", album: "GNX", path: "/mnt/media/Music/Kendrick Lamar/GNX (2024)/01 - wacced out murals.m4a"),
                JobAddedTrack(title: "squabble up", artist: "Kendrick Lamar", album: "GNX", path: "/mnt/media/Music/Kendrick Lamar/GNX (2024)/02 - squabble up.m4a"),
                JobAddedTrack(title: "luther (feat. SZA)", artist: "Kendrick Lamar & SZA", album: "GNX", path: "/mnt/media/Music/Kendrick Lamar/GNX (2024)/03 - luther.m4a")
            ],
            navidrome: JobNavidromeStatus(verified: false, checkedAt: Date(), matches: 0)
        ),
        Job(
            id: "job-102",
            type: "album",
            url: "https://music.apple.com/us/album/brat/1732646278",
            name: "Charli xcx — BRAT",
            state: .downloading,
            stage: .fetching,
            progressHint: "amdl running (track 4 of 15)",
            createdAt: Date().addingTimeInterval(-60),
            updatedAt: Date().addingTimeInterval(-5),
            startedAt: Date().addingTimeInterval(-55),
            stdoutTail: "Fetching track 4/15: I might say something stupid...",
            addedTracks: []
        ),
        Job(
            id: "job-103",
            type: "album",
            url: "https://music.apple.com/us/album/discovery/693452296",
            name: "Daft Punk — Discovery",
            state: .completed,
            stage: .done,
            createdAt: Date().addingTimeInterval(-3600),
            updatedAt: Date().addingTimeInterval(-3400),
            startedAt: Date().addingTimeInterval(-3590),
            finishedAt: Date().addingTimeInterval(-3400),
            exitCode: 0,
            stdoutTail: "Success. 14 tracks downloaded.\nNavidrome auto-discovery verified 14/14 tracks.",
            addedTracks: [
                JobAddedTrack(title: "One More Time", artist: "Daft Punk", album: "Discovery", path: "/mnt/media/Music/Daft Punk/Discovery (2001)/01 - One More Time.m4a"),
                JobAddedTrack(title: "Aerodynamic", artist: "Daft Punk", album: "Discovery", path: "/mnt/media/Music/Daft Punk/Discovery (2001)/02 - Aerodynamic.m4a")
            ],
            navidrome: JobNavidromeStatus(verified: true, checkedAt: Date().addingTimeInterval(-3400), matches: 14)
        ),
        Job(
            id: "job-104",
            type: "song",
            url: "https://music.apple.com/us/album/unknown-track/111111",
            name: "Invalid Item — Demo Failure",
            state: .failed,
            stage: .error,
            createdAt: Date().addingTimeInterval(-7200),
            updatedAt: Date().addingTimeInterval(-7180),
            startedAt: Date().addingTimeInterval(-7195),
            finishedAt: Date().addingTimeInterval(-7180),
            exitCode: 1,
            stderrTail: "Error: 404 Not Found from amp-api.music.apple.com\namdl exited with code 1: item does not exist or regional restriction applies",
            error: JobErrorDetail(code: "AMDL_EXIT_1", message: "amdl process exited with code 1: regional restriction or 404")
        )
    ]
}
