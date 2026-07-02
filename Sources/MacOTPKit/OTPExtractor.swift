// macOTP OTP 추출 파이프라인입니다.
import Foundation

public struct OTPExtractor {
    private let keywords: OTPKeywordConfig

    public init(keywords: OTPKeywordConfig? = nil) throws {
        if let keywords {
            self.keywords = keywords
        } else {
            self.keywords = try OTPKeywordConfig.loadDefault()
        }
    }

    public func extract(from message: MessageRecord) -> OTPResult? {
        if let decodedBody = message.decodedBody {
            if let metadataResult = extractFromMetadata(decodedBody.metadata, message: message) {
                return metadataResult
            }
            if containsOTPMetadata(decodedBody.metadata) {
                return nil
            }
        }

        if let decodedBody = message.decodedBody,
           let textResult = extractFromText(decodedBody.plainText, message: message) {
            return textResult
        }

        if message.decodedBody == nil,
           let text = message.text,
           let textResult = extractFromText(text, message: message) {
            return textResult
        }

        return nil
    }

    private func containsOTPMetadata(_ metadata: [String: String]) -> Bool {
        metadata.keys.contains { isOTPMetadataKey($0) }
    }

    private func isOTPMetadataKey(_ key: String) -> Bool {
        ["displayCode", "__kIMOneTimeCodeAttributeName", "code", "AuthCode"].contains(key)
    }

    private func extractFromMetadata(_ metadata: [String: String], message: MessageRecord) -> OTPResult? {
        let orderedKeys = [
            ("displayCode", 100),
            ("__kIMOneTimeCodeAttributeName", 100),
            ("code", 95),
            ("AuthCode", 95)
        ]

        for (key, confidence) in orderedKeys {
            guard let raw = metadata[key], let code = normalizedCode(raw) else {
                continue
            }
            return makeResult(
                code: code,
                confidence: confidence,
                reason: "Apple metadata \(key)",
                sourceText: nil,
                message: message
            )
        }
        return nil
    }

    private func extractFromText(_ text: String, message: MessageRecord) -> OTPResult? {
        guard hasStrongContext(text) else {
            return nil
        }

        let candidates = numericCandidates(in: text)
        var bestCandidate: (code: String, confidence: Int, reason: String)?
        for candidate in candidates {
            guard !isRejected(candidate.code, in: text, range: candidate.range) else {
                continue
            }

            let scored = score(candidate: candidate, in: text)
            if bestCandidate == nil || scored.confidence > bestCandidate!.confidence {
                bestCandidate = (candidate.code, scored.confidence, scored.reason)
            }
        }

        guard let bestCandidate else {
            return nil
        }

        return makeResult(
            code: bestCandidate.code,
            confidence: bestCandidate.confidence,
            reason: bestCandidate.reason,
            sourceText: text,
            message: message
        )
    }

    private func score(
        candidate: (code: String, range: Range<String.Index>),
        in text: String
    ) -> (confidence: Int, reason: String) {
        let local = localCandidateContext(around: candidate.range, in: text)
        if containsAnyKeyword(local, keywords.otpKeywords + keywords.koreanKeywords) {
            return (90, "OTP keyword context")
        }
        if containsAnyKeyword(local, keywords.actionKeywords) {
            return (80, "Authentication keyword context")
        }
        if containsAnyKeyword(text, keywords.otpKeywords + keywords.koreanKeywords) {
            return (70, "Strong numeric context")
        }
        return (70, "Strong numeric context")
    }

    private func makeResult(
        code: String,
        confidence: Int,
        reason: String,
        sourceText: String?,
        message: MessageRecord
    ) -> OTPResult {
        OTPResult(
            rowID: message.rowID,
            timestamp: message.date,
            sender: message.sender,
            service: message.service,
            code: code,
            confidence: confidence,
            reason: reason,
            sanitizedPreview: OutputFormatter.sanitizedPreview(sourceText ?? "")
        )
    }

    private func hasStrongContext(_ text: String) -> Bool {
        containsAnyKeyword(text, keywords.otpKeywords + keywords.actionKeywords + keywords.koreanKeywords)
    }

    private func containsAnyKeyword(_ text: String, _ candidates: [String]) -> Bool {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return candidates.contains { keyword in
            folded.contains(keyword.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current))
        }
    }

    private func normalizedCode(_ raw: String) -> String? {
        let digits = raw.filter(\.isNumber)
        guard (4...8).contains(digits.count) else {
            return nil
        }
        return digits
    }

    private func numericCandidates(in text: String) -> [(code: String, range: Range<String.Index>)] {
        let pattern = #"(?<![\d+])\d{4,8}(?!\d)"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        return expression.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else {
                return nil
            }
            return (String(text[range]), range)
        }
    }

    private func isRejected(_ code: String, in text: String, range: Range<String.Index>) -> Bool {
        if code.count == 4, let number = Int(code), (1900...2099).contains(number) {
            return true
        }
        if hasNearbySymbol("$€£¥₩", around: range, in: text) {
            return true
        }
        let candidateWindow = window(around: range, in: text, radius: 16).lowercased()
        if candidateWindow.contains("http://") || candidateWindow.contains("https://") {
            return true
        }
        if containsContext(["invoice", "order", "tracking", "track", "appointment"], in: candidateWindow) {
            return true
        }
        if looksLikePhoneNumber(around: range, in: text) {
            return true
        }
        return false
    }

    private func hasNearbySymbol(_ symbols: String, around range: Range<String.Index>, in text: String) -> Bool {
        let lower = text.index(range.lowerBound, offsetBy: -2, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex
        return text[lower..<upper].contains { symbols.contains($0) }
    }

    private func window(around range: Range<String.Index>, in text: String, radius: Int) -> String {
        let lower = text.index(range.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[lower..<upper])
    }

    private func localCandidateContext(around range: Range<String.Index>, in text: String) -> String {
        let lower = text.index(range.lowerBound, offsetBy: -32, limitedBy: text.startIndex) ?? text.startIndex
        let upper = text.index(range.upperBound, offsetBy: 16, limitedBy: text.endIndex) ?? text.endIndex
        return String(text[lower..<upper])
    }

    private func containsContext(_ words: [String], in text: String) -> Bool {
        let lower = text.lowercased()
        return words.contains { lower.contains($0) }
    }

    private func looksLikePhoneNumber(around range: Range<String.Index>, in text: String) -> Bool {
        let local = window(around: range, in: text, radius: 4)
        let digitCount = local.filter(\.isNumber).count
        return digitCount >= 10 && (local.contains("+") || local.contains("-") || local.contains(" "))
    }
}
