import XCTest
import Foundation
@testable import MusicLabCore

final class BackendDTOTests: XCTestCase {
    
    func testDecodeHealthResponse() throws {
        let json = """
        {
          "status": "ok",
          "version": "1.0.0",
          "timestamp": "2026-10-14T02:00:00.000Z",
          "services": {
            "amdl": {
              "available": true
            },
            "wrapperLite": {
              "healthy": true
            },
            "navidrome": {
              "openSubsonic": true
            }
          }
        }
        """.data(using: .utf8)!
        
        let health = try JSONDecoder().decode(BackendHealthResponse.self, from: json)
        XCTAssertEqual(health.status, "ok")
        XCTAssertEqual(health.version, "1.0.0")
        XCTAssertEqual(health.services?.amdl?.available, true)
        XCTAssertEqual(health.services?.wrapperLite?.healthy, true)
        XCTAssertEqual(health.services?.navidrome?.openSubsonic, true)
    }
    
    func testDecodeJobListResponse() throws {
        let json = """
        {
          "jobs": [
            {
              "id": "c1f77d8a-81a2-4a87-b9c2-509f6e14a1e9",
              "type": "album",
              "url": "https://music.apple.com/us/album/gnx/1781290351",
              "name": "Kendrick Lamar — GNX",
              "state": "verifying",
              "stage": "verifying",
              "progressHint": "Waiting for Navidrome auto-discovery (attempt 2/10)",
              "createdAt": "2026-10-13T21:35:00.000Z",
              "updatedAt": "2026-10-13T21:38:00.000Z",
              "addedTracksCount": 12,
              "navidrome": {
                "verified": false,
                "matches": 0
              }
            }
          ]
        }
        """.data(using: .utf8)!
        
        let list = try JSONDecoder().decode(JobsListResponse.self, from: json)
        XCTAssertEqual(list.jobs.count, 1)
        let job = list.jobs[0]
        XCTAssertEqual(job.id, "c1f77d8a-81a2-4a87-b9c2-509f6e14a1e9")
        XCTAssertEqual(job.type, "album")
        XCTAssertEqual(job.state, "verifying")
        XCTAssertEqual(job.addedTracksCount, 12)
        XCTAssertEqual(job.navidrome?.verified, false)
    }
    
    func testDecodeJobDetailResponse() throws {
        let json = """
        {
          "id": "c1f77d8a-81a2-4a87-b9c2-509f6e14a1e9",
          "type": "album",
          "url": "https://music.apple.com/us/album/gnx/1781290351",
          "name": "Kendrick Lamar — GNX",
          "state": "completed",
          "stage": "done",
          "progressHint": "12 tracks downloaded and verified in Navidrome",
          "createdAt": "2026-10-13T21:35:00.000Z",
          "updatedAt": "2026-10-13T21:39:00.000Z",
          "startedAt": "2026-10-13T21:35:02.000Z",
          "finishedAt": "2026-10-13T21:39:00.000Z",
          "exitCode": 0,
          "stdoutTail": "Completed: 12/12\\nSuccess",
          "stderrTail": "",
          "addedTracks": [
            {
              "title": "wacced out murals",
              "artist": "Kendrick Lamar",
              "album": "GNX",
              "path": "/mnt/media/Music/Kendrick Lamar/GNX (2024)/01 - wacced out murals.flac"
            }
          ],
          "navidrome": {
            "verified": true,
            "matches": 12
          }
        }
        """.data(using: .utf8)!
        
        let detail = try JSONDecoder().decode(BackendJobDetail.self, from: json)
        XCTAssertEqual(detail.id, "c1f77d8a-81a2-4a87-b9c2-509f6e14a1e9")
        XCTAssertEqual(detail.state, "completed")
        XCTAssertEqual(detail.exitCode, 0)
        XCTAssertEqual(detail.addedTracks.count, 1)
        XCTAssertEqual(detail.addedTracks[0].title, "wacced out murals")
        XCTAssertEqual(detail.navidrome?.verified, true)
    }
    
    func testDecodeJobSummaryWithLiveProgress() throws {
        let json = """
        {
          "jobs": [
            {
              "id": "abc",
              "type": "playlist",
              "url": "https://music.apple.com/us/playlist/sad/pl.u-76oNlDNIve4AoR2",
              "name": "Playlist: Sad",
              "state": "downloading",
              "stage": "downloading",
              "progressHint": "Downloading track 2 of 3 • 11 MB/s • ~20s left",
              "progressPercent": 33.3,
              "progressCompleted": 1,
              "progressTotal": 3,
              "etaSeconds": 20,
              "speedText": "11 MB/s",
              "createdAt": "2026-10-17T11:00:00.000Z",
              "updatedAt": "2026-10-17T11:00:10.000Z"
            }
          ]
        }
        """.data(using: .utf8)!

        let list = try JSONDecoder().decode(JobsListResponse.self, from: json)
        let s = list.jobs[0]
        XCTAssertEqual(s.progressPercent, 33.3)
        XCTAssertEqual(s.progressCompleted, 1)
        XCTAssertEqual(s.progressTotal, 3)
        XCTAssertEqual(s.etaSeconds, 20)
        XCTAssertEqual(s.speedText, "11 MB/s")
    }

    func testJobProgressHelpers() {
        let active = Job(
            id: "abc",
            type: "playlist",
            url: "u",
            name: "n",
            state: .downloading,
            progressPercent: 33.3,
            progressCompleted: 1,
            progressTotal: 3,
            etaSeconds: 20,
            speedText: "11 MB/s",
            createdAt: Date(),
            updatedAt: Date()
        )
        XCTAssertTrue(active.showsDownloadProgress)
        XCTAssertEqual(active.etaText, "20s left")

        let stalled = Job(
            id: "def",
            type: "song",
            url: "u",
            name: "n",
            state: .downloading,
            createdAt: Date(),
            updatedAt: Date()
        )
        XCTAssertFalse(stalled.showsDownloadProgress)
        XCTAssertNil(stalled.etaText)

        let long = Job(
            id: "ghi",
            type: "playlist",
            url: "u",
            name: "n",
            state: .downloading,
            progressPercent: 10,
            etaSeconds: 3725,
            createdAt: Date(),
            updatedAt: Date()
        )
        XCTAssertEqual(long.etaText, "1h 2m left")
    }

    func testEncodeJobSubmissionRequest() throws {
        let request = JobSubmissionRequest(
            url: "https://music.apple.com/us/album/gnx/1781290351",
            name: "Kendrick Lamar — GNX"
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["url"] as? String, "https://music.apple.com/us/album/gnx/1781290351")
        XCTAssertEqual(json?["name"] as? String, "Kendrick Lamar — GNX")
    }
    
    func testEncodeJobSubmissionRequestWithDestination() throws {
        let request = JobSubmissionRequest(
            url: "https://music.apple.com/us/album/gnx/1781290351",
            name: "Kendrick Lamar — GNX",
            destinationId: "elijah"
        )
        let data = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["destinationId"] as? String, "elijah")
    }
    
    func testDecodeDestinationsResponse() throws {
        let json = """
        {
          "destinations": [
            { "id": "bryon", "isDefault": true },
            { "id": "elijah", "isDefault": false }
          ],
          "defaultId": "bryon"
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(DestinationsResponse.self, from: json)
        XCTAssertEqual(response.destinations.count, 2)
        XCTAssertEqual(response.defaultId, "bryon")
        XCTAssertTrue(response.destinations[0].isDefault)
        XCTAssertEqual(response.destinations[1].id, "elijah")
        XCTAssertFalse(response.destinations[1].isDefault)
    }
    
    func testDecodeLogsResponse() throws {
        let json = """
        {
          "logs": [
            {
              "source": "job",
              "jobId": "c1f77d8a-81a2-4a87-b9c2-509f6e14a1e9",
              "stream": "stdout",
              "at": "2026-10-16T10:00:00.000Z",
              "line": "Downloading track: wacced out murals"
            },
            {
              "source": "backend",
              "stream": "service",
              "at": "2026-10-16T10:00:00.000Z",
              "line": "server started"
            }
          ],
          "page": { "limit": 100, "offset": 0, "total": 2, "hasMore": false },
          "available": { "backend": true, "job": true, "wrapper": false }
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LogsResponse.self, from: json)
        XCTAssertEqual(response.logs.count, 2)
        XCTAssertEqual(response.logs[0].source, "job")
        XCTAssertEqual(response.logs[0].jobId, "c1f77d8a-81a2-4a87-b9c2-509f6e14a1e9")
        XCTAssertEqual(response.logs[1].source, "backend")
        XCTAssertEqual(response.page.total, 2)
        XCTAssertFalse(response.page.hasMore)
        XCTAssertEqual(response.available.backend, true)
        XCTAssertEqual(response.available.wrapper, false)
    }
    
    func testDecodeLogsResponseWithPartialAvailability() throws {
        // The server may only report availability for the requested source.
        let json = """
        {
          "logs": [],
          "page": { "limit": 100, "offset": 0, "total": 0, "hasMore": false },
          "available": { "backend": true }
        }
        """.data(using: .utf8)!
        
        let response = try JSONDecoder().decode(LogsResponse.self, from: json)
        XCTAssertTrue(response.logs.isEmpty)
        XCTAssertEqual(response.available.backend, true)
        XCTAssertNil(response.available.job)
        XCTAssertNil(response.available.wrapper)
    }
}
