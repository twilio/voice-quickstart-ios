//
//  WebSocketClient.swift
//  Twilio Voice Quickstart - ClientNotificationWebhookExample
//
//  Copyright © Twilio, Inc. All rights reserved.
//

import Foundation

protocol WebSocketClientDelegate: AnyObject {
    func webSocketClientDidConnect(_ client: WebSocketClient)
    func webSocketClient(_ client: WebSocketClient, didReceiveMessage message: String)
    func webSocketClient(_ client: WebSocketClient, didReceiveData data: Data)
    func webSocketClient(_ client: WebSocketClient, didDisconnectWithError error: Error?)
}

enum WebSocketClientError: Error {
    case invalidServerResponse
    case missingWebSocketURL
    case httpStatus(Int, String?)
    case notConnected
}

final class WebSocketClient: NSObject {

    let serverBaseURL: URL
    let connectionId: String

    weak var delegate: WebSocketClientDelegate?

    private let delegateQueue: DispatchQueue
    private let httpSession: URLSession
    private var wsSession: URLSession?
    private var task: URLSessionWebSocketTask?
    private var isConnected = false

    init(serverBaseURL: URL,
         connectionId: String,
         delegateQueue: DispatchQueue = .main) {
        self.serverBaseURL = serverBaseURL
        self.connectionId = connectionId
        self.delegateQueue = delegateQueue
        self.httpSession = URLSession(configuration: .ephemeral)
        super.init()
    }

    // MARK: - Public API

    /// POSTs to `/connect`, then opens a WebSocket to the URL the server returns.
    func connect(completion: @escaping (Result<Void, Error>) -> Void) {
        postJSON(path: "/connect", body: ["connectionId": connectionId]) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                self.dispatchToDelegateQueue { completion(.failure(error)) }

            case .success(let json):
                guard
                    let urlString = json["url"] as? String,
                    let wsURL = URL(string: urlString)
                else {
                    self.dispatchToDelegateQueue { completion(.failure(WebSocketClientError.missingWebSocketURL)) }
                    return
                }
                self.openWebSocket(url: wsURL)
                self.dispatchToDelegateQueue { completion(.success(())) }
            }
        }
    }

    /// Closes the WebSocket and POSTs to `/disconnect`.
    func disconnect(completion: ((Result<Void, Error>) -> Void)? = nil) {
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        wsSession?.invalidateAndCancel()
        wsSession = nil
        isConnected = false

        postJSON(path: "/disconnect", body: ["connectionId": connectionId]) { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success:
                self.dispatchToDelegateQueue { completion?(.success(())) }
            case .failure(let error):
                self.dispatchToDelegateQueue { completion?(.failure(error)) }
            }
        }
    }

    // MARK: - WebSocket lifecycle

    private func openWebSocket(url: URL) {
        let session = URLSession(configuration: .default,
                                 delegate: self,
                                 delegateQueue: nil)
        let task = session.webSocketTask(with: url)
        self.wsSession = session
        self.task = task
        task.resume()
        receiveNext()
    }

    private func receiveNext() {
        guard let task = task else { return }
        task.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .failure(let error):
                self.handleDisconnect(error: error)

            case .success(let message):
                switch message {
                case .string(let text):
                    self.dispatchToDelegateQueue {
                        self.delegate?.webSocketClient(self, didReceiveMessage: text)
                    }
                case .data(let data):
                    self.dispatchToDelegateQueue {
                        self.delegate?.webSocketClient(self, didReceiveData: data)
                    }
                @unknown default:
                    break
                }
                self.receiveNext()
            }
        }
    }

    private func handleDisconnect(error: Error?) {
        guard isConnected else { return }
        isConnected = false
        task = nil
        wsSession?.invalidateAndCancel()
        wsSession = nil
        dispatchToDelegateQueue {
            self.delegate?.webSocketClient(self, didDisconnectWithError: error)
        }
    }

    // MARK: - HTTP helpers

    private func postJSON(path: String,
                          body: [String: Any],
                          completion: @escaping (Result<[String: Any], Error>) -> Void) {
        guard let url = URL(string: path, relativeTo: serverBaseURL) else {
            completion(.failure(WebSocketClientError.invalidServerResponse))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        } catch {
            completion(.failure(error))
            return
        }

        let task = httpSession.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let http = response as? HTTPURLResponse else {
                completion(.failure(WebSocketClientError.invalidServerResponse))
                return
            }

            let bodyText = data.flatMap { String(data: $0, encoding: .utf8) }
            guard (200..<300).contains(http.statusCode) else {
                completion(.failure(WebSocketClientError.httpStatus(http.statusCode, bodyText)))
                return
            }

            let json: [String: Any]
            if let data = data,
               let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                json = parsed
            } else {
                json = [:]
            }
            completion(.success(json))
        }
        task.resume()
    }

    private func dispatchToDelegateQueue(_ block: @escaping () -> Void) {
        delegateQueue.async(execute: block)
    }
}

// MARK: - URLSessionWebSocketDelegate

extension WebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didOpenWithProtocol protocolName: String?) {
        isConnected = true
        dispatchToDelegateQueue {
            self.delegate?.webSocketClientDidConnect(self)
        }
    }

    func urlSession(_ session: URLSession,
                    webSocketTask: URLSessionWebSocketTask,
                    didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
                    reason: Data?) {
        handleDisconnect(error: nil)
    }
}
