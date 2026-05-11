import Foundation

@Observable
final class HostsXPCClient {
    static let shared = HostsXPCClient()

    private var connection: NSXPCConnection?
    private let queue = DispatchQueue(label: "com.colilab.hostflow.xpc-client")

    private init() {}

    func writeHosts(_ content: String) async throws {
        let conn = try connect()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let once = ResumeOnce()
            let proxy = conn.remoteObjectProxyWithErrorHandler { error in
                once.run { continuation.resume(throwing: error) }
            } as? HostFlowHelperProtocol
            guard let proxy else {
                once.run { continuation.resume(throwing: HostFlowClientError.connectionFailed) }
                return
            }
            proxy.writeHosts(content: content) { error in
                once.run {
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
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

    private func connect() throws -> NSXPCConnection {
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
            guard let conn = connection else {
                throw HostFlowClientError.connectionFailed
            }
            return conn
        }
    }
}

private final class ResumeOnce: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func run(_ block: () -> Void) {
        lock.lock()
        let go = !done
        done = true
        lock.unlock()
        if go { block() }
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
