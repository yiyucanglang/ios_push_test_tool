import Foundation
import CryptoKit

struct APNsRequest {
    let keyID: String
    let teamID: String
    let bundleID: String
    let deviceToken: String
    let payload: Data
    let privateKeyPem: String
    let environment: APNsEnvironment
}

struct APNsResponse {
    let statusCode: Int
    let body: String
    let apnsID: String?
}

enum APNsClientError: LocalizedError {
    case invalidURL
    case signingFailed(String)
    case badResponse
    case response(statusCode: Int, reason: String?, apnsID: String?, body: String)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无法构建 APNs 请求 URL"
        case .signingFailed(let reason):
            return "JWT 签名失败：\(reason)"
        case .badResponse:
            return "无法识别 APNs 返回"
        case let .response(status, reason, apnsID, body):
            var components: [String] = ["APNs 返回状态码 \(status)"]
            if let reason, !reason.isEmpty {
                components.append("原因：\(reason)")
            }
            if let apnsID, !apnsID.isEmpty {
                components.append("APNs ID：\(apnsID)")
            }
            if !body.isEmpty {
                components.append("返回体：\(body)")
            }
            return components.joined(separator: "，")
        }
    }
}

struct APNsClient {
    func send(request: APNsRequest) async throws -> APNsResponse {
        let jwt = try makeJWT(for: request)

        guard let url = URL(string: "\(request.environment.baseURL)/3/device/\(request.deviceToken)") else {
            throw APNsClientError.invalidURL
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.httpBody = request.payload
        urlRequest.setValue("bearer \(jwt)", forHTTPHeaderField: "authorization")
        urlRequest.setValue(request.bundleID, forHTTPHeaderField: "apns-topic")
        urlRequest.setValue("alert", forHTTPHeaderField: "apns-push-type")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.httpAdditionalHeaders = [
            "User-Agent": "APNsPushTester/1.0"
        ]

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw APNsClientError.badResponse
        }

        let bodyText = String(data: data, encoding: .utf8) ?? ""
        let apnsID = httpResponse.value(forHTTPHeaderField: "apns-id")
        let errorReason = APNsClient.decodeErrorReason(from: data)

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw APNsClientError.response(
                statusCode: httpResponse.statusCode,
                reason: errorReason,
                apnsID: apnsID,
                body: bodyText
            )
        }

        return APNsResponse(statusCode: httpResponse.statusCode, body: bodyText, apnsID: apnsID)
    }
}

private extension APNsClient {
    func makeJWT(for request: APNsRequest) throws -> String {
        do {
            let privateKey = try P256.Signing.PrivateKey(pemRepresentation: request.privateKeyPem)
            let headerJSON = try JSONSerialization.data(withJSONObject: [
                "alg": "ES256",
                "kid": request.keyID
            ])
            let payloadJSON = try JSONSerialization.data(withJSONObject: [
                "iss": request.teamID,
                "iat": Int(Date().timeIntervalSince1970)
            ])

            let headerPart = base64URLEncode(headerJSON)
            let payloadPart = base64URLEncode(payloadJSON)
            let signingInput = Data("\(headerPart).\(payloadPart)".utf8)

            let signature = try privateKey.signature(for: signingInput)
            let signaturePart = base64URLEncode(signature.rawRepresentation)

            return "\(headerPart).\(payloadPart).\(signaturePart)"
        } catch {
            throw APNsClientError.signingFailed(error.localizedDescription)
        }
    }

    func base64URLEncode(_ data: Data) -> String {
        data
            .base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private extension APNsClient {
    struct APNSErrorPayload: Decodable {
        let reason: String
        let timestamp: String?
    }

    static func decodeErrorReason(from data: Data) -> String? {
        guard !data.isEmpty else { return nil }

        do {
            let payload = try JSONDecoder().decode(APNSErrorPayload.self, from: data)
            return payload.reason
        } catch {
            return nil
        }
    }
}

enum APNsEnvironment: String, CaseIterable, Identifiable {
    case sandbox
    case production

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sandbox: return "开发环境"
        case .production: return "生产环境"
        }
    }

    var baseURL: String {
        switch self {
        case .sandbox: return "https://api.sandbox.push.apple.com"
        case .production: return "https://api.push.apple.com"
        }
    }
}
