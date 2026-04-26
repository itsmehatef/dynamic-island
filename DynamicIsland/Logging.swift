import Foundation

func diLog(_ message: String) {
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "\(timestamp) \(message)\n"
    guard let fp = fopen("/tmp/dynamic-island.log", "a") else { return }
    fputs(line, fp)
    fclose(fp)
}
