import Foundation

final class HelperListenerDelegate: NSObject, NSXPCListenerDelegate {
    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        do {
            try CallerVerification(connection: newConnection).verify()
        } catch {
            NSLog("[HostFlowHelper] rejecting connection: \(error)")
            return false
        }
        newConnection.exportedInterface = NSXPCInterface(with: HostFlowHelperProtocol.self)
        newConnection.exportedObject = HelperService()
        newConnection.resume()
        return true
    }
}
