import os

public enum AppLog {
    public static let subsystem = "com.chaseelder.nib"

    public static let app = Logger(subsystem: subsystem, category: "app")
    public static let document = Logger(subsystem: subsystem, category: "document")
    public static let core = Logger(subsystem: subsystem, category: "core")
    public static let lsp = Logger(subsystem: subsystem, category: "lsp")
    public static let ai = Logger(subsystem: subsystem, category: "ai")
}
