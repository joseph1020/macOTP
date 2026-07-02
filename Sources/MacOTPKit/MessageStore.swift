// macOTP Apple Messages DB 접근 계층입니다.
import CSQLite3
import Foundation

public struct MessageStore {
    private let databasePath: String
    private let decoder: AttributedBodyDecoder

    public init(
        databasePath: String = NSString(string: "~/Library/Messages/chat.db").expandingTildeInPath,
        decoder: AttributedBodyDecoder = AttributedBodyDecoder()
    ) {
        self.databasePath = databasePath
        self.decoder = decoder
    }

    public func recentMessages(since startDate: Date, limit: Int) throws -> [MessageRecord] {
        guard FileManager.default.fileExists(atPath: databasePath) else {
            throw MacOTPError.databaseUnavailable(databasePath)
        }

        var database: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        let openResult = sqlite3_open_v2(databasePath, &database, flags, nil)
        guard openResult == SQLITE_OK, let database else {
            let message = database.map { sqliteMessage($0) } ?? databasePath
            if let database {
                sqlite3_close(database)
            }
            if openResult == SQLITE_CANTOPEN || openResult == SQLITE_PERM {
                throw MacOTPError.permissionDenied(message)
            }
            throw MacOTPError.sqliteFailure(message)
        }
        defer {
            sqlite3_close(database)
        }

        let query = """
        SELECT message.rowid, message.date, message.service, message.text,
               message.attributedBody, handle.id
        FROM message
        LEFT JOIN handle ON message.handle_id = handle.rowid
        WHERE message.date >= ?
        ORDER BY message.date DESC
        LIMIT ?
        """

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, query, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw MacOTPError.sqliteFailure(sqliteMessage(database))
        }
        defer {
            sqlite3_finalize(statement)
        }

        sqlite3_bind_int64(statement, 1, appleMessageTimestamp(for: startDate))
        sqlite3_bind_int(statement, 2, Int32(limit))

        var records: [MessageRecord] = []
        while true {
            let step = sqlite3_step(statement)
            if step == SQLITE_DONE {
                break
            }
            guard step == SQLITE_ROW else {
                if step == SQLITE_BUSY || step == SQLITE_LOCKED {
                    throw MacOTPError.databaseLocked(sqliteMessage(database))
                }
                throw MacOTPError.sqliteFailure(sqliteMessage(database))
            }
            let record = record(from: statement)
            records.append(record)
        }

        return records
    }

    private func record(from statement: OpaquePointer) -> MessageRecord {
        let rowID = sqlite3_column_int64(statement, 0)
        let rawDate = sqlite3_column_int64(statement, 1)
        let service = stringColumn(statement, 2) ?? "unknown"
        let text = stringColumn(statement, 3)
        let data = dataColumn(statement, 4)
        let sender = stringColumn(statement, 5)
        let decoded = data.flatMap { decoder.decode($0) }

        return MessageRecord(
            rowID: rowID,
            date: dateFromAppleMessageTimestamp(rawDate),
            service: service,
            sender: sender,
            text: text,
            attributedBody: data,
            decodedBody: decoded
        )
    }

    private func stringColumn(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let pointer = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: pointer)
    }

    private func dataColumn(_ statement: OpaquePointer, _ index: Int32) -> Data? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let bytes = sqlite3_column_blob(statement, index) else {
            return nil
        }
        let count = Int(sqlite3_column_bytes(statement, index))
        return Data(bytes: bytes, count: count)
    }

    private func sqliteMessage(_ database: OpaquePointer) -> String {
        guard let message = sqlite3_errmsg(database) else {
            return "unknown error"
        }
        return String(cString: message)
    }

    private func appleMessageTimestamp(for date: Date) -> Int64 {
        let secondsSinceAppleEpoch = date.timeIntervalSinceReferenceDate
        return Int64(secondsSinceAppleEpoch * 1_000_000_000)
    }

    private func dateFromAppleMessageTimestamp(_ raw: Int64) -> Date {
        if abs(raw) > 10_000_000_000 {
            return Date(timeIntervalSinceReferenceDate: TimeInterval(raw) / 1_000_000_000)
        }
        return Date(timeIntervalSinceReferenceDate: TimeInterval(raw))
    }
}
