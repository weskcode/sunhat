import Foundation

private final class TestResourceBundle: NSObject {}

enum TestResources {
    // Links retain one authoritative fixture while Cloud runs on a separate test worker.
    static func url(named name: String) throws -> URL {
        guard let url = Bundle(for: TestResourceBundle.self).url(forResource: name, withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }
}
