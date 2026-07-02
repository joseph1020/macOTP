// macOTP Messages attributedBody 디코더입니다.
import Foundation

public struct AttributedBodyDecoder {
    public init() {}

    public func decode(_ data: Data) -> DecodedAttributedBody? {
        guard !data.isEmpty else {
            return nil
        }

        if Self.isTypedStreamArchive(data) {
            return decodeTypedStream(data)
        }

        do {
            let unarchiver = try NSKeyedUnarchiver(forReadingFrom: data)
            unarchiver.requiresSecureCoding = true
            defer {
                unarchiver.finishDecoding()
            }
            let allowedClasses: [AnyClass] = [
                NSAttributedString.self,
                NSMutableAttributedString.self,
                NSString.self,
                NSMutableString.self,
                NSDictionary.self,
                NSMutableDictionary.self,
                NSArray.self,
                NSMutableArray.self,
                NSData.self,
                NSNumber.self,
                NSDate.self,
                NSValue.self
            ]
            guard let object = unarchiver.decodeObject(
                of: allowedClasses,
                forKey: NSKeyedArchiveRootObjectKey
            ) else {
                return nil
            }
            return decodeObject(object)
        } catch {
            return nil
        }
    }

    private func decodeTypedStream(_ data: Data) -> DecodedAttributedBody? {
        guard let unarchiver = NSUnarchiver(forReadingWith: data) else {
            return nil
        }
        guard let object = unarchiver.decodeObject() else {
            return nil
        }
        return decodeObject(object)
    }

    private func decodeObject(_ object: Any) -> DecodedAttributedBody? {
        if let attributed = object as? NSAttributedString {
            return decodeAttributedString(attributed)
        }
        if let string = object as? String {
            return DecodedAttributedBody(plainText: string, metadata: [:])
        }
        if let dictionary = object as? [AnyHashable: Any] {
            for value in dictionary.values {
                if let decoded = decodeObject(value) {
                    return decoded
                }
            }
        }
        if let array = object as? [Any] {
            for value in array {
                if let decoded = decodeObject(value) {
                    return decoded
                }
            }
        }
        return nil
    }

    private func decodeAttributedString(_ attributed: NSAttributedString) -> DecodedAttributedBody {
        var metadata: [String: String] = [:]
        let fullRange = NSRange(location: 0, length: attributed.length)
        attributed.enumerateAttributes(in: fullRange) { attributes, _, _ in
            for (key, value) in attributes {
                let name = key.rawValue
                if isOTPMetadataKey(name), metadata[name] == nil {
                    insertMetadata(name: name, value: value, into: &metadata)
                }
            }
        }
        return DecodedAttributedBody(plainText: attributed.string, metadata: metadata)
    }

    private func isOTPMetadataKey(_ name: String) -> Bool {
        let keys = ["__kIMOneTimeCodeAttributeName", "displayCode", "code", "AuthCode"]
        return keys.contains(name)
    }

    private func stringify(_ value: Any) -> String {
        if let string = value as? String {
            return string
        }
        if let number = value as? NSNumber {
            return number.stringValue
        }
        if let dictionary = value as? [AnyHashable: Any] {
            for key in ["displayCode", "code", "AuthCode", "__kIMOneTimeCodeAttributeName"] {
                if let nested = dictionary[key] {
                    return stringify(nested)
                }
            }
        }
        return String(describing: value)
    }

    private func insertMetadata(name: String, value: Any, into metadata: inout [String: String]) {
        if let dictionary = value as? [AnyHashable: Any] {
            for key in ["displayCode", "code", "AuthCode", "__kIMOneTimeCodeAttributeName"] {
                if let nested = dictionary[key], metadata[key] == nil {
                    metadata[key] = stringify(nested)
                }
            }
            if metadata[name] == nil {
                metadata[name] = stringify(value)
            }
            return
        }
        metadata[name] = stringify(value)
    }

    private static func isTypedStreamArchive(_ data: Data) -> Bool {
        let littleEndianSignature = Data([0x04, 0x0b]) + Data("streamtyped".utf8)
        let bigEndianSignature = Data([0x04, 0x0b]) + Data("typedstream".utf8)
        return data.starts(with: littleEndianSignature) || data.starts(with: bigEndianSignature)
    }
}
