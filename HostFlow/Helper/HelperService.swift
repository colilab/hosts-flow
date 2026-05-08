import Foundation

final class HelperService: NSObject, HostFlowHelperProtocol {
    func writeHosts(content: String, reply: @escaping (Error?) -> Void) {
        reply(nil)
    }
}
