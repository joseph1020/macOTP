import Foundation
@testable import MacOTPKit

struct OTPExtractorCompileTests {
    func metadataDisplayCodeWins() throws {
        let extractor = try OTPExtractor(
            keywords: OTPKeywordConfig(
                otpKeywords: ["verification code"],
                actionKeywords: ["verify"],
                koreanKeywords: ["인증번호"]
            )
        )
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

        _ = result?.code == "654321"
        _ = result?.confidence == 100
        _ = result?.reason == "Apple metadata displayCode"
    }

    func decodedBodyFallbackExtractsKeywordCode() throws {
        let extractor = try OTPExtractor(
            keywords: OTPKeywordConfig(
                otpKeywords: ["verification code"],
                actionKeywords: ["verify"],
                koreanKeywords: ["인증번호"]
            )
        )
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

        _ = result?.code == "839201"
        _ = result?.confidence == 90
        _ = result?.reason == "OTP keyword context"
    }

    func rejectsFalsePositives() throws {
        let extractor = try OTPExtractor(
            keywords: OTPKeywordConfig(
                otpKeywords: ["verification code"],
                actionKeywords: ["verify"],
                koreanKeywords: ["인증번호"]
            )
        )
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
            _ = extractor.extract(from: message) == nil
        }
    }

    func debugOutputIsSanitized() {
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

        _ = line.contains("rowid=42")
        _ = line.contains("textLength=59")
        _ = !line.contains("Your verification code")
        _ = !line.contains("123456")
    }

    func legitimateOTPWithSupportPhoneAndURLSurvives() throws {
        let extractor = try OTPExtractor(
            keywords: OTPKeywordConfig(
                otpKeywords: ["verification code"],
                actionKeywords: ["verify"],
                koreanKeywords: ["인증번호"]
            )
        )
        let message = MessageRecord(
            rowID: 50,
            date: Date(),
            service: "SMS",
            sender: "Service",
            text: "Your verification code is 123456. Call +1-555-0199 or visit https://example.com/help if this was not you.",
            attributedBody: nil,
            decodedBody: nil
        )

        _ = extractor.extract(from: message)?.code == "123456"
    }

    func sanitizedPreviewDoesNotExposeShortBodyWords() {
        let preview = OutputFormatter.sanitizedPreview("Alice login verification code is 123456")
        _ = !preview.contains("Alice")
        _ = !preview.contains("login verification code")
        _ = !preview.contains("123456")
    }
}
