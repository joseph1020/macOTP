// macOTP 핵심 동작을 XCTest 없이 검증하는 로컬 테스트 실행기입니다.
import Foundation
import MacOTPKit

enum SelfTestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() {
        throw SelfTestFailure.failed(message)
    }
}

func makeExtractor() throws -> OTPExtractor {
    try OTPExtractor(
        keywords: OTPKeywordConfig(
            otpKeywords: ["verification code"],
            actionKeywords: ["verify"],
            koreanKeywords: ["인증번호"]
        )
    )
}

func testDefaultLimitSupportsBroadDateRanges() throws {
    try expect(MacOTPDefaults.defaultLimit == 200, "default limit should be 200")
    try expect(MacOTPDefaults.defaultLimit > 20, "default limit should not cap broad date ranges at 20")
    try expect(MacOTPDefaults.maxLimit == 1_000, "max limit should remain 1000")
    try expect(MacOTPDefaults.scanLimit > MacOTPDefaults.defaultLimit, "scan limit should exceed output limit")
}

func testResultLimitAppliesAfterExtraction() throws {
    let extractor = try makeExtractor()
    let oldNonOTPRows = (0..<200).map { index in
        MessageRecord(
            rowID: Int64(index),
            date: Date(timeIntervalSince1970: TimeInterval(index)),
            service: "SMS",
            sender: "Service",
            text: nil,
            attributedBody: nil,
            decodedBody: DecodedAttributedBody(plainText: "Reference message \(index)", metadata: [:])
        )
    }
    let olderOTPRow = MessageRecord(
        rowID: 201,
        date: Date(timeIntervalSince1970: 201),
        service: "SMS",
        sender: "Service",
        text: nil,
        attributedBody: nil,
        decodedBody: DecodedAttributedBody(plainText: "Your verification code is 246810.", metadata: [:])
    )
    let secondOTPRow = MessageRecord(
        rowID: 202,
        date: Date(timeIntervalSince1970: 202),
        service: "SMS",
        sender: "Service",
        text: nil,
        attributedBody: nil,
        decodedBody: DecodedAttributedBody(plainText: "Your verification code is 135791.", metadata: [:])
    )

    let scannedRows = oldNonOTPRows + [olderOTPRow, secondOTPRow]
    let extracted = scannedRows.compactMap { extractor.extract(from: $0) }
    let limited = Array(extracted.prefix(1))

    try expect(extracted.contains { $0.code == "246810" }, "broad scan missed OTP beyond first 200 raw rows")
    try expect(limited.count == 1, "result limit should cap returned OTP results")
    try expect(limited.first?.code == "246810", "result limit should apply after extraction")
}

func testMetadataDisplayCodeWins() throws {
    let extractor = try makeExtractor()
    let message = MessageRecord(
        rowID: 1,
        date: Date(timeIntervalSince1970: 100),
        service: "SMS",
        sender: "+15551234567",
        text: "ignore 111111",
        attributedBody: nil,
        decodedBody: DecodedAttributedBody(
            plainText: "ignore 111111",
            metadata: ["displayCode": "654321"]
        )
    )

    let result = extractor.extract(from: message)
    try expect(result?.code == "654321", "metadata displayCode was not selected")
    try expect(result?.confidence == 100, "metadata displayCode confidence mismatch")
    try expect(result?.reason == "Apple metadata displayCode", "metadata displayCode reason mismatch")
}

func testInvalidMetadataStopsBeforeTextFallback() throws {
    let extractor = try makeExtractor()
    let message = MessageRecord(
        rowID: 3,
        date: Date(timeIntervalSince1970: 300),
        service: "SMS",
        sender: "Service",
        text: nil,
        attributedBody: nil,
        decodedBody: DecodedAttributedBody(
            plainText: "Your verification code is 839201.",
            metadata: ["displayCode": "not a usable code"]
        )
    )

    try expect(extractor.extract(from: message) == nil, "invalid OTP metadata should stop text fallback")
}

func testDecodedBodyFallbackExtractsKeywordCode() throws {
    let extractor = try makeExtractor()
    let message = MessageRecord(
        rowID: 2,
        date: Date(timeIntervalSince1970: 200),
        service: "SMS",
        sender: "Bank",
        text: nil,
        attributedBody: nil,
        decodedBody: DecodedAttributedBody(
            plainText: "Your verification code is 839201. Do not share it.",
            metadata: [:]
        )
    )

    let result = extractor.extract(from: message)
    try expect(result?.code == "839201", "decoded body fallback did not extract expected code")
    try expect(result?.confidence == 90, "decoded body fallback confidence mismatch")
    try expect(result?.reason == "OTP keyword context", "decoded body fallback reason mismatch")
}

func testLocalOTPContextBeatsEarlierReferenceNumber() throws {
    let extractor = try makeExtractor()
    let message = MessageRecord(
        rowID: 4,
        date: Date(timeIntervalSince1970: 400),
        service: "SMS",
        sender: "Service",
        text: nil,
        attributedBody: nil,
        decodedBody: DecodedAttributedBody(
            plainText: "Reference 111111. Your verification code is 839201.",
            metadata: [:]
        )
    )

    let result = extractor.extract(from: message)
    try expect(result?.code == "839201", "local OTP context did not beat earlier reference number")
    try expect(result?.confidence == 90, "local OTP context confidence mismatch")
}

func testRejectsFalsePositives() throws {
    let extractor = try makeExtractor()
    let samples = [
        "Your appointment is on 2026-07-02.",
        "Total amount is $123456 for invoice 889900.",
        "Call +1 555 123 4567 for support.",
        "Track order 123456 at https://example.com/123456"
    ]

    for (index, sample) in samples.enumerated() {
        let message = MessageRecord(
            rowID: Int64(index + 10),
            date: Date(),
            service: "SMS",
            sender: "Service",
            text: sample,
            attributedBody: nil,
            decodedBody: nil
        )
        try expect(extractor.extract(from: message) == nil, "false positive was extracted from: \(sample)")
    }
}

func testDebugOutputIsSanitized() throws {
    let message = MessageRecord(
        rowID: 42,
        date: Date(timeIntervalSince1970: 300),
        service: "SMS",
        sender: "Service",
        text: "Your verification code is 123456 and this is the full body.",
        attributedBody: Data([0, 1, 2]),
        decodedBody: nil
    )

    let line = OutputFormatter.debugLine(for: message, decodeSucceeded: false, metadataKeys: [])
    try expect(line.contains("rowid=42"), "debug line missing row id")
    try expect(line.contains("textLength=59"), "debug line missing text length")
    try expect(!line.contains("Your verification code"), "debug line leaked message body")
    try expect(!line.contains("123456"), "debug line leaked OTP")
}

func testLegitimateOTPWithSupportPhoneAndURLSurvives() throws {
    let extractor = try makeExtractor()
    let message = MessageRecord(
        rowID: 50,
        date: Date(),
        service: "SMS",
        sender: "Service",
        text: "Your verification code is 123456. Call +1-555-0199 or visit https://example.com/help if this was not you.",
        attributedBody: nil,
        decodedBody: nil
    )

    let result = extractor.extract(from: message)
    try expect(result?.code == "123456", "OTP near keyword was rejected because unrelated phone or URL existed")
}

func testSanitizedPreviewDoesNotExposeShortBodyWords() throws {
    let preview = OutputFormatter.sanitizedPreview("Alice login verification code is 123456")
    try expect(!preview.contains("Alice"), "preview leaked a name from the body")
    try expect(!preview.contains("login verification code"), "preview leaked body text")
    try expect(!preview.contains("123456"), "preview leaked OTP digits")
}

func testNestedMetadataIsFlattenedByConfidence() throws {
    let extractor = try makeExtractor()
    let message = MessageRecord(
        rowID: 60,
        date: Date(),
        service: "SMS",
        sender: "Service",
        text: nil,
        attributedBody: nil,
        decodedBody: DecodedAttributedBody(
            plainText: "",
            metadata: ["code": "772211"]
        )
    )

    let result = extractor.extract(from: message)
    try expect(result?.code == "772211", "nested code metadata was not extracted")
    try expect(result?.confidence == 95, "code metadata should have 95 confidence")
}

func testNativeAttributedArchiveDecodesMetadata() throws {
    let attributed = NSMutableAttributedString(string: "Use code 112233")
    attributed.addAttribute(
        NSAttributedString.Key("__kIMOneTimeCodeAttributeName"),
        value: ["displayCode": "112233", "code": "112233"],
        range: NSRange(location: 0, length: attributed.length)
    )
    let data = NSArchiver.archivedData(withRootObject: attributed)
    let decoded = AttributedBodyDecoder().decode(data)

    try expect(decoded?.plainText == "Use code 112233", "native attributed archive text was not decoded")
    try expect(decoded?.metadata["displayCode"] == "112233", "native attributed archive metadata was not decoded")
}

let tests: [(String, () throws -> Void)] = [
    ("default limit supports broad date ranges", testDefaultLimitSupportsBroadDateRanges),
    ("result limit applies after extraction", testResultLimitAppliesAfterExtraction),
    ("metadata displayCode wins", testMetadataDisplayCodeWins),
    ("invalid metadata stops before text fallback", testInvalidMetadataStopsBeforeTextFallback),
    ("decoded body fallback extracts keyword code", testDecodedBodyFallbackExtractsKeywordCode),
    ("local OTP context beats earlier reference number", testLocalOTPContextBeatsEarlierReferenceNumber),
    ("rejects false positives", testRejectsFalsePositives),
    ("debug output is sanitized", testDebugOutputIsSanitized),
    ("legitimate OTP with support phone and URL survives", testLegitimateOTPWithSupportPhoneAndURLSurvives),
    ("sanitized preview does not expose short body words", testSanitizedPreviewDoesNotExposeShortBodyWords),
    ("nested metadata confidence is preserved", testNestedMetadataIsFlattenedByConfidence),
    ("native attributed archive decodes metadata", testNativeAttributedArchiveDecodesMetadata)
]

do {
    for (name, test) in tests {
        try test()
        print("PASS: \(name)")
    }
} catch {
    fputs("FAIL: \(error)\n", stderr)
    exit(1)
}
