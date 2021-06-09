//
//  WebSocket.swift
//  WebSocketDemo
//
//  Created by David Crooks on 07/09/2020.
//  Copyright © 2020 David Crooks. All rights reserved.
//

import Foundation
import Combine
import OSLog

public enum SocketData<T:Codable> {
    case message(String)
    case codable(T)
    case uncodable(Data)
}

public final class CodableWebSocket<T:Codable>:Publisher,Subscriber {

    public typealias Output = Result<SocketData<T>,Error>
    public typealias Input = SocketData<T>
    public typealias Failure = Error
    let webSocketTask: URLSessionWebSocketTask
    public var combineIdentifier = CombineIdentifier()

    public convenience init(urlRequest: URLRequest, session: URLSession? = nil) {
        let urlSession = session ?? .shared
        self.init(webSocketTask: urlSession.webSocketTask(with: urlRequest))
    }

    public convenience init(url: URL, session: URLSession? = nil) {
        let urlSession = session ?? .shared
        self.init(webSocketTask: urlSession.webSocketTask(with: url))
    }

    public convenience init(url: URL, protocols: [String] = [], session: URLSession? = nil) {
        let urlSession = session ?? .shared
        self.init(webSocketTask: urlSession.webSocketTask(with: url, protocols: protocols))
    }

    private init(webSocketTask: URLSessionWebSocketTask) {
        self.webSocketTask = webSocketTask
        webSocketTask.resume()
    }
    
    // MARK: Publisher
    
    public func receive<S>(subscriber: S) where S: Subscriber, CodableWebSocket.Failure == S.Failure, CodableWebSocket.Output == S.Input {
        let subscription = CodableWebsocketSubscription(subscriber: subscriber, socket:webSocketTask)
        subscriber.receive(subscription: subscription)
    }
    
    // MARK: Subscriber
    
    public func receive(subscription: Subscription) {
        subscription.request(.unlimited)
    }

    public func receive(_ input: SocketData<T>) -> Subscribers.Demand {
        let message: URLSessionWebSocketTask.Message
        
        switch input {
        case .message(let string):
            message = URLSessionWebSocketTask.Message.string(string)
        case .codable(let codable):
            do {
                let data = try JSONEncoder().encode(codable)
                message = URLSessionWebSocketTask.Message.data(data)
            } catch {
                os_log(.error, log: .module, "Error during encoding WebSocket message: %@", error.description)
                assertionFailure("Error during encoding WebSocket message")
                return .none
            }

        case .uncodable(let data):
            message = URLSessionWebSocketTask.Message.data(data)
        }

        webSocketTask.send(message, completionHandler: { error in
            guard let error = error else { return }
            os_log(.error, log: .module, "Unable to send websocket message: %@", error.description)
        })

        return .unlimited
    }

    public func receive(completion: Subscribers.Completion<Error>) {
        os_log(.info, log: .module, "Completion")
    }
}

extension CodableWebSocket {
    public func codable()-> AnyPublisher<T, CodableWebSocket<T>.Failure> {
        return compactMap { result -> T? in
            guard case .success(let socketdata) = result,
                  case .codable(let codable) = socketdata
            else { return nil }
            return codable
        }
        .eraseToAnyPublisher()
    }
}

extension OSLog {
    /// OSLog instance for CodableWebSocket module
    static let module: OSLog = OSLog(subsystem: "CodableWebSocket", category: .pointsOfInterest)
}

extension Error {
    var ns: NSError {
        self as NSError
    }

    /// Usually it's more informative than Error.localizedDescription
    var description: String {
        ns.description
    }
}
