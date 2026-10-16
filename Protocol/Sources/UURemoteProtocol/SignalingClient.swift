import Foundation

public enum UUSignalingEvent: Sendable {
    case connected
    case roomInfoAck(Data)
    case soac(UUSoacMessage)
    case beControlled(Data)
    case released
    case left
    case disconnected(String)
    case rawEvent(name: String, payload: Data)
}

/// Engine.IO v4 + Socket.IO client for UU room signaling (`X-NRD-AUTH` = room token).
public final class UUSignalingClient: @unchecked Sendable {
    private var task: URLSessionWebSocketTask?
    private let session: URLSession
    private var ackCounter: Int = 10
    public var onEvent: (@Sendable (UUSignalingEvent) -> Void)?

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func connect(signalingServer: String, roomToken: String) async throws {
        let base = signalingServer.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/socket.io/?transport=websocket&EIO=4") else {
            throw UUHTTPError.badURL
        }
        var req = URLRequest(url: url)
        req.setValue(roomToken, forHTTPHeaderField: "X-NRD-AUTH")
        let task = session.webSocketTask(with: req)
        self.task = task
        task.resume()
        receiveLoop()
    }

    public func disconnect() {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        onEvent?(.disconnected("local"))
    }

    public func emit(event: String, payload: [String: Any]) async throws {
        let data = try JSONSerialization.data(withJSONObject: [event, payload], options: [])
        guard let json = String(data: data, encoding: .utf8) else { return }
        try await sendText("42\(json)")
    }

    /// Socket.IO binary event: `451-[name, header, {_placeholder,num:0}]` + 1 binary frame.
    public func emitBinaryEvent(name: String, header: [String: Any], attachment: Data) async throws {
        let placeholder: [String: Any] = ["_placeholder": true, "num": 0]
        let arr: [Any] = [name, header, placeholder]
        let data = try JSONSerialization.data(withJSONObject: arr, options: [])
        guard let json = String(data: data, encoding: .utf8) else { return }
        try await sendText("451-\(json)")
        try await sendBinary(attachment)
    }

    public func emitBeControlled(header: UUBeControlledHeader, connectOptions: Data) async throws {
        try await emitBinaryEvent(
            name: "be-controlled",
            header: header.jsonObject(),
            attachment: connectOptions
        )
    }

    public func emitSoac(_ soac: UUSoacMessage) async throws {
        let encoder = JSONEncoder()
        let soacData = try encoder.encode(soac)
        let soacObj = try JSONSerialization.jsonObject(with: soacData)
        let payload: Any
        if let cid = soac.clientId {
            payload = ["client_id": cid, "data": soacObj]
        } else {
            payload = soacObj
        }
        let arr: [Any] = ["soac", payload]
        let data = try JSONSerialization.data(withJSONObject: arr, options: [])
        guard let json = String(data: data, encoding: .utf8) else { return }
        try await sendText("42\(json)")
    }

    private func sendText(_ text: String) async throws {
        guard let task else { throw UUHTTPError.transport(URLError(.notConnectedToInternet)) }
        try await task.send(.string(text))
    }

    private func sendBinary(_ data: Data) async throws {
        guard let task else { throw UUHTTPError.transport(URLError(.notConnectedToInternet)) }
        try await task.send(.data(data))
    }

    private func receiveLoop() {
        guard let task else { return }
        task.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.onEvent?(.disconnected(error.localizedDescription))
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleText(text)
                case .data:
                    break
                @unknown default:
                    break
                }
                self.receiveLoop()
            }
        }
    }

    private func handleText(_ txt: String) {
        if txt.hasPrefix("0") {
            Task { try? await sendText("40") }
            return
        }
        if txt == "2" {
            Task { try? await sendText("3") }
            return
        }
        if txt.hasPrefix("40") {
            onEvent?(.connected)
            ackCounter += 1
            let packet = "42\(ackCounter)[\"room_info\"]"
            Task { try? await sendText(packet) }
            return
        }
        if txt.hasPrefix("43") {
            if let idx = txt.firstIndex(of: "["),
               let data = String(txt[idx...]).data(using: .utf8) {
                onEvent?(.roomInfoAck(data))
            }
            return
        }
        if txt.hasPrefix("42") {
            let payload = String(txt.dropFirst(2))
            guard let data = payload.data(using: .utf8),
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [Any],
                  arr.count >= 1,
                  let name = arr[0] as? String else { return }
            let rest: Data?
            if arr.count >= 2 {
                rest = try? JSONSerialization.data(withJSONObject: arr[1])
            } else {
                rest = Data()
            }
            switch name {
            case "soac":
                if let rest,
                   let msg = try? JSONDecoder().decode(UUSoacMessage.self, from: rest) {
                    onEvent?(.soac(msg))
                } else if let rest,
                          let wrap = try? JSONSerialization.jsonObject(with: rest) as? [String: Any] {
                    let innerObj = wrap["data"] ?? wrap
                    if let innerData = try? JSONSerialization.data(withJSONObject: innerObj),
                       var msg = try? JSONDecoder().decode(UUSoacMessage.self, from: innerData) {
                        if msg.clientId == nil { msg.clientId = wrap["client_id"] as? String }
                        onEvent?(.soac(msg))
                    }
                }
            case "be-controlled":
                onEvent?(.beControlled(rest ?? Data()))
            case "released":
                onEvent?(.released)
            case "left", "leave":
                onEvent?(.left)
            default:
                onEvent?(.rawEvent(name: name, payload: rest ?? Data()))
            }
        }
    }
}
