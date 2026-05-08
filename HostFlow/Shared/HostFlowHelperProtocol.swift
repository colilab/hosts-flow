import Foundation

@objc public protocol HostFlowHelperProtocol {
    func writeHosts(content: String, reply: @escaping (Error?) -> Void)
}

public enum HostFlowHelperConstants {
    public static let machServiceName = "com.colilab.hostflow.helper"
}
