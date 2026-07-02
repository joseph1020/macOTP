// macOTP CLI 엔트리포인트입니다.
import Foundation
import MacOTPKit

struct CLIOptions {
    var hours: Int?
    var days: Int?
    var limit = MacOTPDefaults.defaultLimit
    var copy = false
    var json = false
    var debug = false
}

let maxHours = 24 * 365
let maxDays = 365
let maxLimit = MacOTPDefaults.maxLimit

func parseOptions(_ arguments: [String]) throws -> CLIOptions {
    var options = CLIOptions()
    var index = 0
    while index < arguments.count {
        let argument = arguments[index]
        switch argument {
        case "--hours":
            index += 1
            guard index < arguments.count,
                  let value = Int(arguments[index]),
                  (1...maxHours).contains(value) else {
                throw MacOTPError.sqliteFailure("--hours requires an integer from 1 to \(maxHours)")
            }
            options.hours = value
        case "--days":
            index += 1
            guard index < arguments.count,
                  let value = Int(arguments[index]),
                  (1...maxDays).contains(value) else {
                throw MacOTPError.sqliteFailure("--days requires an integer from 1 to \(maxDays)")
            }
            options.days = value
        case "--limit":
            index += 1
            guard index < arguments.count,
                  let value = Int(arguments[index]),
                  (1...maxLimit).contains(value) else {
                throw MacOTPError.sqliteFailure("--limit requires an integer from 1 to \(maxLimit)")
            }
            options.limit = value
        case "--copy":
            options.copy = true
        case "--json":
            options.json = true
        case "--debug":
            options.debug = true
        case "--help", "-h":
            print("Usage: macotp [--hours N] [--days N] [--limit N] [--copy] [--json] [--debug]")
            print("Defaults: --limit \(MacOTPDefaults.defaultLimit). Max: --limit \(MacOTPDefaults.maxLimit).")
            print("--limit caps returned OTP results; scan window is based on --hours/--days.")
            exit(0)
        default:
            throw MacOTPError.sqliteFailure("Unknown argument: \(argument)")
        }
        index += 1
    }
    return options
}

func printErr(_ line: String) {
    fputs(line + "\n", stderr)
}

do {
    let options = try parseOptions(Array(CommandLine.arguments.dropFirst()))
    let interval: TimeInterval
    if let hours = options.hours {
        interval = TimeInterval(hours * 60 * 60)
    } else if let days = options.days {
        interval = TimeInterval(days * 24 * 60 * 60)
    } else {
        interval = TimeInterval(24 * 60 * 60)
    }

    let startDate = Date().addingTimeInterval(-interval)
    let records = try MessageStore().recentMessages(since: startDate, limit: MacOTPDefaults.scanLimit)

    let extractor = try OTPExtractor()
    let extractedResults = records.compactMap { record -> OTPResult? in
        if options.debug {
            let metadataKeys = record.decodedBody.map { Array($0.metadata.keys) } ?? []
            printErr(OutputFormatter.debugLine(
                for: record,
                decodeSucceeded: record.decodedBody != nil,
                metadataKeys: metadataKeys
            ))
        }
        return extractor.extract(from: record)
    }
    let results = Array(extractedResults.prefix(options.limit))

    if options.copy, let first = results.first {
        Clipboard.copy(first.code)
    }

    if options.json {
        print(try OutputFormatter.json(for: results))
    } else {
        for result in results {
            print(OutputFormatter.defaultLine(for: result))
        }
    }
} catch {
    fputs("macotp: \(error)\n", stderr)
    exit(1)
}
