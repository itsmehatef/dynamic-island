import Foundation

private let _diLogFormatter = ISO8601DateFormatter()

func diLog(_ message: String) {
    let timestamp = _diLogFormatter.string(from: Date())
    let line = "\(timestamp) \(message)\n"
    guard let fp = fopen("/tmp/dynamic-island.log", "a") else { return }
    fputs(line, fp)
    fclose(fp)
}
