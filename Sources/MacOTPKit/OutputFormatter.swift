// macOTP 출력 포맷터입니다.
import Foundation

public enum OutputFormatter {
    public static func sanitizedPreview(_ text: String, maxLength: Int = 80) -> String {
        guard !text.isEmpty else {
            return ""
        }
        let digitCount = text.filter(\.isNumber).count
        return "sanitized body: chars=\(text.count) digits=\(digitCount)"
    }

    public static func defaultLine(for result: OTPResult) -> String {
        let sender = result.sender ?? "unknown"
        return "\(result.timestamp) \(sender) \(result.service) \(result.code) confidence=\(result.confidence) \(result.reason) \(result.sanitizedPreview)"
    }

    public static func debugLine(
        for message: MessageRecord,
        decodeSucceeded: Bool,
        metadataKeys: [String]
    ) -> String {
        let textLength = message.text?.count ?? 0
        let bodyLength = message.attributedBody?.count ?? 0
        let keys = metadataKeys.sorted().joined(separator: ",")
        return "rowid=\(message.rowID) timestamp=\(message.date) decodeSucceeded=\(decodeSucceeded) metadataKeys=[\(keys)] textLength=\(textLength) attributedBodyLength=\(bodyLength)"
    }

    public static func json(for results: [OTPResult]) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(results)
        return String(decoding: data, as: UTF8.self)
    }
}
