import Foundation
import Compression

enum SwimImportExport {
    static let exportVersion = 10

    private static let crc32Table: [UInt32] = {
        (0..<256).map { n -> UInt32 in
            var c = UInt32(n)
            for _ in 0..<8 {
                c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1)
            }
            return c
        }
    }()

    static func generateExportString(from data: SwimData) async throws -> String {
        let payload: [String: Any] = [
            "v": exportVersion,
            "p": [
                "sex": data.profile.sex,
                "age": data.profile.age,
            ],
            "s": data.sessions.map(compressSession),
            "aa": data.profile.activeAmbient as Any,
        ]
        let jsonData = try JSONSerialization.data(withJSONObject: payload)
        guard let jsonStr = String(data: jsonData, encoding: .utf8) else {
            throw SwimImportExportError.invalidInput
        }
        let encoded = try await encodePayloadJson(jsonStr)
        let checksum = crc32(encoded)
        return "\(encoded):\(checksum)"
    }

    static func parseImportString(_ str: String) async throws -> SwimData {
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { throw SwimImportExportError.invalidFormat }

        let encoded = parts[0]
        let checksum = parts[1].lowercased()
        guard crc32(encoded) == checksum else { throw SwimImportExportError.checksumFailed }

        let decoded = try await decodePayloadJson(encoded)
        guard let compressed = try JSONSerialization.jsonObject(with: Data(decoded.utf8)) as? [String: Any] else {
            throw SwimImportExportError.invalidFormat
        }

        let version = compressed["v"] as? Int ?? 0
        guard [3, 4, 5, 6, 7, 8, 9, 10].contains(version) else {
            throw SwimImportExportError.unsupportedVersion
        }

        let profile = SwimProfile(
            name: "",
            sex: (compressed["p"] as? [String: Any])?["sex"] as? String ?? "male",
            age: (compressed["p"] as? [String: Any])?["age"] as? Int ?? 30,
            mascotId: nil,
            mascotSwitchMonthKey: nil,
            aiApiKey: "",
            activeAmbient: version >= 6 ? (compressed["aa"] as? String) : nil
        )

        let sessions = (compressed["s"] as? [[String: Any]] ?? []).map(decompressSession)

        return SwimData(
            profile: profile,
            sessions: sessions,
            monthlyChallengeRerolls: [:]
        )
    }

    enum SwimImportExportError: LocalizedError {
        case invalidInput
        case invalidFormat
        case checksumFailed
        case unsupportedVersion

        var errorDescription: String? {
            switch self {
            case .invalidInput: return "Invalid input"
            case .invalidFormat: return "Invalid format"
            case .checksumFailed: return "Checksum validation failed"
            case .unsupportedVersion: return "Unsupported export version"
            }
        }
    }

    private static func crc32(_ str: String) -> String {
        var crc: UInt32 = 0xFFFF_FFFF
        for byte in str.utf8 {
            crc = (crc >> 8) ^ crc32Table[Int((crc ^ UInt32(byte)) & 0xFF)]
        }
        return String(format: "%08x", (crc ^ 0xFFFF_FFFF))
    }

    private static func encodePayloadJson(_ jsonStr: String) async throws -> String {
        Data(jsonStr.utf8).base64EncodedString()
    }

    private static func decodePayloadJson(_ encoded: String) async throws -> String {
        guard let bytes = Data(base64Encoded: encoded) else {
            throw SwimImportExportError.invalidFormat
        }
        if bytes.count >= 2, bytes[0] == 0x1f, bytes[1] == 0x8b,
           let gunzipped = gzipDecompress(bytes),
           let text = String(data: gunzipped, encoding: .utf8) {
            return text
        }
        guard let text = String(data: bytes, encoding: .utf8) else {
            throw SwimImportExportError.invalidFormat
        }
        return text
    }

    private static func gzipDecompress(_ data: Data) -> Data? {
        decompress(data, algorithm: COMPRESSION_ZLIB)
    }

    private static func compress(_ data: Data, algorithm: compression_algorithm) -> Data? {
        data.withUnsafeBytes { buffer in
            let dstSize = max(64, data.count + 64)
            var dst = Data(count: dstSize)
            let written = dst.withUnsafeMutableBytes { dstBuffer -> Int in
                guard let srcPtr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                      let dstPtr = dstBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                    return 0
                }
                return compression_encode_buffer(
                    dstPtr, dstBuffer.count,
                    srcPtr, buffer.count,
                    nil, algorithm
                )
            }
            guard written > 0 else { return nil }
            dst.count = written
            return dst
        }
    }

    private static func decompress(_ data: Data, algorithm: compression_algorithm) -> Data? {
        data.withUnsafeBytes { buffer in
            var dst = Data(count: max(data.count * 4, 1024))
            var written = 0
            while written == 0 && dst.count <= data.count * 32 {
                written = dst.withUnsafeMutableBytes { dstBuffer -> Int in
                    guard let srcPtr = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self),
                          let dstPtr = dstBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                        return 0
                    }
                    return compression_decode_buffer(
                        dstPtr, dstBuffer.count,
                        srcPtr, buffer.count,
                        nil, algorithm
                    )
                }
                if written == 0 { dst.count *= 2 }
            }
            guard written > 0 else { return nil }
            dst.count = written
            return dst
        }
    }

    static func compressSessionForTesting(_ session: SwimSession) -> [String: Any] {
        compressSession(session)
    }

    static func decompressSessionForTesting(_ raw: [String: Any]) -> SwimSession {
        decompressSession(raw)
    }

    private static func compressSession(_ session: SwimSession) -> [String: Any] {
        var result: [String: Any] = [
            "i": session.id,
            "dt": session.date,
            "m": compressMetrics(session.metrics),
        ]
        if let createdAt = session.createdAt { result["ca"] = createdAt }
        if session.excludeFromStats { result["ex"] = true }
        if let uuid = session.healthKitWorkoutUUID { result["hk"] = uuid }
        return result
    }

    private static func decompressSession(_ raw: [String: Any]) -> SwimSession {
        SwimSession(
            id: raw["i"] as? String ?? UUID().uuidString,
            createdAt: raw["ca"] as? String,
            date: raw["dt"] as? String ?? "",
            metrics: decompressMetrics(raw["m"] as? [String: Any] ?? [:]),
            excludeFromStats: raw["ex"] as? Bool ?? false,
            healthKitWorkoutUUID: raw["hk"] as? String
        )
    }

    private static func compressMetrics(_ metrics: SwimMetrics) -> [String: Any] {
        var result: [String: Any] = [
            "pl": metrics.poolLengthM,
            "loc": metrics.location,
            "tr": metrics.timeRange,
        ]
        if let v = metrics.durationSec { result["ds"] = v }
        if let v = metrics.distanceM { result["dm"] = v }
        if let v = metrics.activeKcal { result["ak"] = v }
        if let v = metrics.totalKcal { result["tk"] = v }
        if let v = metrics.paceSecPer100m { result["ps"] = v }
        if let v = metrics.avgHeartRate { result["hr"] = v }
        if let v = metrics.laps { result["lp"] = v }
        if let v = metrics.goalM { result["gm"] = v }
        return result
    }

    private static func decompressMetrics(_ raw: [String: Any]) -> SwimMetrics {
        SwimMetrics(
            durationSec: raw["ds"] as? Int,
            distanceM: raw["dm"] as? Int,
            activeKcal: raw["ak"] as? Int,
            totalKcal: raw["tk"] as? Int,
            paceSecPer100m: raw["ps"] as? Int,
            avgHeartRate: raw["hr"] as? Int,
            laps: raw["lp"] as? Int,
            poolLengthM: raw["pl"] as? Int ?? 25,
            goalM: raw["gm"] as? Int,
            location: raw["loc"] as? String ?? "",
            timeRange: raw["tr"] as? String ?? "",
            strokes: .empty
        )
    }
}
