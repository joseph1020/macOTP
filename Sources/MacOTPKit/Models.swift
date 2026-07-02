// macOTP 엔진의 핵심 데이터 모델입니다.
import Foundation

public enum MacOTPDefaults {
    public static let defaultLimit = 200
    public static let maxLimit = 1_000
    public static let scanLimit = 50_000
}

public struct OTPKeywordConfig: Codable, Equatable {
    public let otpKeywords: [String]
    public let actionKeywords: [String]
    public let koreanKeywords: [String]

    enum CodingKeys: String, CodingKey {
        case otpKeywords = "otp_keywords"
        case actionKeywords = "action_keywords"
        case koreanKeywords = "korean_keywords"
    }

    public init(otpKeywords: [String], actionKeywords: [String], koreanKeywords: [String]) {
        self.otpKeywords = otpKeywords
        self.actionKeywords = actionKeywords
        self.koreanKeywords = koreanKeywords
    }

    public static func loadDefault() throws -> OTPKeywordConfig {
        guard let url = Bundle.module.url(forResource: "otp_keywords", withExtension: "json") else {
            throw MacOTPError.resourceMissing("otp_keywords.json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(OTPKeywordConfig.self, from: data)
    }
}

public struct DecodedAttributedBody: Equatable {
    public let plainText: String
    public let metadata: [String: String]

    public init(plainText: String, metadata: [String: String]) {
        self.plainText = plainText
        self.metadata = metadata
    }
}

public struct MessageRecord: Equatable {
    public let rowID: Int64
    public let date: Date
    public let service: String
    public let sender: String?
    public let text: String?
    public let attributedBody: Data?
    public let decodedBody: DecodedAttributedBody?

    public init(
        rowID: Int64,
        date: Date,
        service: String,
        sender: String?,
        text: String?,
        attributedBody: Data?,
        decodedBody: DecodedAttributedBody?
    ) {
        self.rowID = rowID
        self.date = date
        self.service = service
        self.sender = sender
        self.text = text
        self.attributedBody = attributedBody
        self.decodedBody = decodedBody
    }
}

public struct OTPResult: Codable, Equatable {
    public let rowID: Int64
    public let timestamp: Date
    public let sender: String?
    public let service: String
    public let code: String
    public let confidence: Int
    public let reason: String
    public let sanitizedPreview: String

    public init(
        rowID: Int64,
        timestamp: Date,
        sender: String?,
        service: String,
        code: String,
        confidence: Int,
        reason: String,
        sanitizedPreview: String
    ) {
        self.rowID = rowID
        self.timestamp = timestamp
        self.sender = sender
        self.service = service
        self.code = code
        self.confidence = confidence
        self.reason = reason
        self.sanitizedPreview = sanitizedPreview
    }
}

public enum MacOTPError: Error, CustomStringConvertible {
    case resourceMissing(String)
    case databaseUnavailable(String)
    case permissionDenied(String)
    case databaseLocked(String)
    case sqliteFailure(String)

    public var description: String {
        switch self {
        case .resourceMissing(let name):
            return "Required resource missing: \(name)"
        case .databaseUnavailable(let path):
            return "Messages database is unavailable at \(path)"
        case .permissionDenied(let detail):
            return "Permission denied. Grant Full Disk Access to the terminal app. \(detail)"
        case .databaseLocked(let detail):
            return "Messages database is locked. Close Messages or retry later. \(detail)"
        case .sqliteFailure(let detail):
            return "SQLite failure: \(detail)"
        }
    }
}
