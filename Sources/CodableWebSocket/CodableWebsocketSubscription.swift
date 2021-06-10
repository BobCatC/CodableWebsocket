//
//  CodableWebsocketSubscription.swift
//  CodableWebSocketExample
//
//  Created by David Crooks on 18/09/2020.
//  Copyright © 2020 David Crooks. All rights reserved.
//

import Foundation
import Combine
import OSLog

final class CodableWebsocketSubscription<SubscriberType: Subscriber, IncomingType: Decodable>: Subscription where SubscriberType.Input == Result<SocketData<IncomingType>, Error>, SubscriberType.Failure == Error {

    private var subscriber: SubscriberType?
    let webSocketTask: URLSessionWebSocketTask

    init(subscriber: SubscriberType, socket: URLSessionWebSocketTask) {
        self.subscriber = subscriber
        webSocketTask = socket
        receive()
    }

    func request(_ demand: Subscribers.Demand) {
        // Nothing to do here
    }

    func cancel() {
        subscriber = nil
    }

    func receive() {
        webSocketTask
            .receive { [weak self] result in
                self?.handle(result: result)
            }
    }

    private func handle(result: Result<URLSessionWebSocketTask.Message, Error>) {
        let newResult = result.map { message -> SocketData<IncomingType> in
            switch message {
            case .string(let str):
                guard let data = str.data(using: .utf8) else { return .message(str) }
                do {
                    let decoded = try JSONDecoder().decode(IncomingType.self, from: data)
                    return .codable(decoded)
                } catch {
                    os_log(.info, log: .module, "Unable to decode %@ from string message", String(describing: IncomingType.self))
                    return .message(str)
                }

            case .data(let data):
                do {
                    let decoded = try JSONDecoder().decode(IncomingType.self, from: data)
                    return .codable(decoded)
                } catch {
                    os_log(.error, log: .module, "Error during decoding websocket message: %@", error.description)
                    return .uncodable(data)
                }

            @unknown default:
                fatalError()
            }
        }

        if case Result.failure(let error) = newResult, webSocketTask.closeCode != .invalid {
            subscriber?.receive(completion: .failure(error))
        }
        else {
            _ = subscriber?.receive(newResult)
        }

        receive()
    }
}
