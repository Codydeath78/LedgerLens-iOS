import Foundation
import Network
internal import Combine

@MainActor
final class NetworkMonitor: ObservableObject {

    static let shared = NetworkMonitor()

    @Published private(set) var isConnected = true
    @Published private(set) var isExpensive = false
    @Published private(set) var interfaceName = "Network"

    private let monitor = NWPathMonitor()

    private let queue =
        DispatchQueue(
            label:
                "AI.Document.NetworkMonitor"
        )

    private init() {

        monitor.pathUpdateHandler = {
            [weak self] path in

            let connected =
                path.status == .satisfied

            let expensive =
                path.isExpensive

            let interfaceName: String

            if path.usesInterfaceType(.wifi) {

                interfaceName = "Wi-Fi"

            } else if path.usesInterfaceType(.cellular) {

                interfaceName = "Cellular"

            } else if path.usesInterfaceType(.wiredEthernet) {

                interfaceName = "Ethernet"

            } else {

                interfaceName = "Network"
            }

            Task { @MainActor in

                self?.isConnected =
                    connected

                self?.isExpensive =
                    expensive

                self?.interfaceName =
                    interfaceName
            }
        }

        monitor.start(queue: queue)
    }
}
