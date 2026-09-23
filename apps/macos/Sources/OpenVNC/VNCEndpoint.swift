import COpenVNCCore
import Foundation

struct VNCEndpoint {
    let url: URL
    var credentialAccount: String { url.absoluteString }

    init(host: String, port: String, tls: Bool) throws {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = Array(host.utf8)
        let status = bytes.withUnsafeBufferPointer {
            openvnc_validate_endpoint($0.baseAddress, $0.count, UInt32(port) ?? 0, tls ? 1 : 0)
        }
        switch status {
        case 0: break
        case 2: throw EndpointError.invalidPort
        case 3: throw EndpointError.tailnetIPRequired
        default: throw PreparationError.invalidHost
        }
        let authority = host.contains(":") ? "[\(host)]" : host
        guard let url = URL(string: "\(tls ? "wss" : "ws")://\(authority):\(UInt32(port)!)/") else {
            throw PreparationError.invalidHost
        }
        self.url = url
    }
}

enum EndpointError: LocalizedError {
    case invalidPort, tailnetIPRequired
    var errorDescription: String? {
        switch self {
        case .invalidPort: return "A porta deve estar entre 1 e 65535."
        case .tailnetIPRequired:
            return "Para conectar sem TLS, use o IP Tailscale do Windows e mantenha o Tailscale conectado. Nomes de host exigem WSS nesta versão."
        }
    }
}
