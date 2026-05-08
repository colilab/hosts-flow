import Foundation

@Observable
final class HostsXPCClient {
    static let shared = HostsXPCClient()

    private var connection: NSXPCConnection?
    private let queue = DispatchQueue(label: "com.colilab.hostflow.xpc-client")

    private init() {}

    func writeHosts(_ content: String) async throws {
        let proxy = try connect()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            proxy.writeHosts(content: content) { error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    func invalidate() {
        queue.sync {
            connection?.invalidate()
            connection = nil
        }
    }

    private func connect() throws -> HostFlowHelperProtocol {
        try queue.sync {
            if connection == nil {
                let conn = NSXPCConnection(machServiceName: HostFlowHelperConstants.machServiceName, options: .privileged)
                conn.remoteObjectInterface = NSXPCInterface(with: HostFlowHelperProtocol.self)
                conn.invalidationHandler = { [weak self] in
                    self?.queue.async { self?.connection = nil }
                }
                conn.interruptionHandler = { [weak self] in
                    self?.queue.async { self?.connection = nil }
                }
                conn.resume()
                connection = conn
            }
            guard let proxy = connection?.remoteObjectProxyWithErrorHandler({ _ in }) as? HostFlowHelperProtocol else {
                throw HostFlowClientError.connectionFailed
            }
            return proxy
        }
    }
}

enum HostFlowClientError: LocalizedError {
    case connectionFailed
    case helperNotInstalled

    var errorDescription: String? {
        switch self {
        case .connectionFailed: "Could not connect to the privileged helper."
        case .helperNotInstalled: "The privileged helper is not installed."
        }
    }
}
