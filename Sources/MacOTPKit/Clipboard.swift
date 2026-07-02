// macOTP 클립보드 연동입니다.
import AppKit

public enum Clipboard {
    public static func copy(_ value: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
    }
}
