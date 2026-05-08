import Foundation

let delegate = HelperListenerDelegate()
let listener = NSXPCListener(machServiceName: HostFlowHelperConstants.machServiceName)
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
