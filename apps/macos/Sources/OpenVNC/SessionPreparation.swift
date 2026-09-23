import AppKit
import COpenVNCCore

struct PreparedSession {
    let host: String
    let width: UInt32
    let height: UInt32
    let scalePercent: UInt32
}

enum PreparationError: LocalizedError {
    case invalidHost, noScreen, unsupportedDisplay

    var errorDescription: String? {
        switch self {
        case .invalidHost:
            return "Informe um IP ou nome Tailscale válido, sem protocolo ou porta."
        case .noScreen:
            return "Não foi possível identificar a tela desta janela."
        case .unsupportedDisplay:
            return "As dimensões ou a escala desta tela estão fora dos limites do protótipo."
        }
    }
}

enum SessionPreparation {
    @MainActor
    static func prepare(host: String, screen: NSScreen?) throws -> PreparedSession {
        let host = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let bytes = Array(host.utf8)
        let valid = bytes.withUnsafeBufferPointer {
            openvnc_validate_host($0.baseAddress, $0.count) == 0
        }
        guard valid else { throw PreparationError.invalidHost }
        guard let screen else { throw PreparationError.noScreen }

        // Backing pixels can differ from panel pixels in macOS scaled modes.
        let pixels = screen.convertRectToBacking(screen.frame).size
        guard pixels.width.isFinite, pixels.height.isFinite,
              pixels.width >= 320, pixels.width <= 16384,
              pixels.height >= 200, pixels.height <= 16384 else {
            throw PreparationError.unsupportedDisplay
        }
        let request = openvnc_prepare_display(
            UInt32(pixels.width.rounded()), UInt32(pixels.height.rounded()),
            Double(screen.backingScaleFactor)
        )
        guard request.status == 0 else { throw PreparationError.unsupportedDisplay }
        return PreparedSession(
            host: host, width: request.width, height: request.height,
            scalePercent: request.scale_percent
        )
    }
}
