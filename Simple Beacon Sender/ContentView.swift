import SwiftUI

struct ContentView: View {
    @State private var urlString: String = "http://192.168.86.62:2000" // <-- replace with your server URL
    @State private var sending: Bool = false
    @State private var lastResponse: String = ""

    // Two example payloads (must be JSON-serializable)
    private let payloadA: [String: Any] = [
        "type": "A",
        "message": "Hello from iOS",
        "items": ["alpha", "beta"],
        "meta": ["env": "dev"]
    ]

    private let payloadB: [String: Any] = [
        "type": "B",
        "user": ["id": 42, "email": "demo@example.com"],
        "flags": ["beta": true, "gdpr": false]
    ]

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                TextField("Destination URL (http/https)", text: $urlString)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .padding(12)
                    .accessibilityIdentifier("urlTextField")
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.3)))

                HStack(spacing: 12) {
                    Button(action: { self.sendFromFile("login") }) {
                        Label("Send Beacon A", systemImage: sending ? "hourglass" : "paperplane.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sending)
                    .accessibilityIdentifier("sendAButton")

                    Button(action: { self.sendFromFile("login") }) {
                        Label("Send Beacon B", systemImage: sending ? "hourglass" : "paperplane")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .disabled(sending)
                    .accessibilityIdentifier("sendBButton")

                }

                GroupBox(label: Text("Last response")) {
                    ScrollView {
                        Text(lastResponse.isEmpty ? "<no response yet>" : lastResponse)
                            .font(.system(.body, design: .monospaced))
                            .accessibilityIdentifier("lastResponseText")
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 4)
                    }
                    .frame(maxHeight: 220)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("JSON Sender")
        }
    }

    private func sendJSON(_ payload: [String: Any]) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            lastResponse = "Invalid URL"
            return
        }
        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            lastResponse = "Invalid JSON payload"
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        sending = true
        lastResponse = "Sending…\(prettyPrint(payload))→ \(url.absoluteString)"

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                self.sending = false
                if let error = error {
                    self.lastResponse = "Error: \(error.localizedDescription)"
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
//                let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty>"
//                self.lastResponse = "Status: \(status)\(text)"
                self.lastResponse = "Status: \(status)"
            }
        }.resume()
    }

    private func prettyPrint(_ obj: Any) -> String {
        guard JSONSerialization.isValidJSONObject(obj),
              let d = try? JSONSerialization.data(withJSONObject: obj, options: [.prettyPrinted]),
              let s = String(data: d, encoding: .utf8) else {
            return String(describing: obj)
        }
        return s
    }

    private func sendJSONData(_ data: Data) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            lastResponse = "Invalid URL"
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = data

        sending = true
        lastResponse = "Sending…\(prettyPrint(data))→ \(url.absoluteString)"

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                self.sending = false
                if let error = error {
                    self.lastResponse = "Error: \(error.localizedDescription)"
                    return
                }
                let status = (response as? HTTPURLResponse)?.statusCode ?? 0
//                let text = data.flatMap { String(data: $0, encoding: .utf8) } ?? "<empty>"
                self.lastResponse = "Status: \(status)"
            }
        }.resume()
    }
    
    private func loadJSONData(resource name: String) throws -> Data {
        if let url = Bundle.main.url(forResource: name, withExtension: "json") {
            return try Data(contentsOf: url)
        }
        throw NSError(domain: "ContentView", code: 1, userInfo: [NSLocalizedDescriptionKey: "\(name).json not found in app bundle"])
    }
    
    private func sendFromFile(_ resourceName: String) {
        do {
            let data = try loadJSONData(resource: resourceName)
            sendJSONData(data)
        } catch {
            lastResponse = "Failed to load \(resourceName).json: \(error.localizedDescription)"
        }
    }
}
