//
//  WebSocket.swift
//  WebSocketDemo
//
//  Created by David Crooks on 07/09/2020.
//  Copyright © 2020 David Crooks. All rights reserved.
//

import Foundation
import Combine

enum SocketData<T:Codable> {
    case message(String)
    case codable(T)
    case uncodable(Data)
}

final class CodableWebSocket<T:Codable>:Publisher,Subscriber {
  
    typealias Output = Result<SocketData<T>,Error>
    typealias Input =  SocketData<T>
    typealias Failure = Error
    let webSocketTask:URLSessionWebSocketTask
    var combineIdentifier: CombineIdentifier = CombineIdentifier()
    
    init(url:URL)
    {
        let urlSession = URLSession(configuration: .default)
        webSocketTask = urlSession.webSocketTask(with:url)
        webSocketTask.resume()
    }
    
    // MARK: Publisher
    
    func receive<S>(subscriber: S) where S : Subscriber, CodableWebSocket.Failure == S.Failure, CodableWebSocket.Output == S.Input {
        let subscription = CodableWebsocketSubscription(subscriber: subscriber, socket:webSocketTask)
        subscriber.receive(subscription: subscription)
    }
    
    // MARK: Subscriber
    
    func receive(subscription: Subscription) {
        subscription.request(.unlimited)
    }

    func receive(_ input: SocketData<T>) -> Subscribers.Demand {
        let message:URLSessionWebSocketTask.Message
        
        switch input {
        
        case .message(let string):
            message = URLSessionWebSocketTask.Message.string(string)
        case .codable(let codable):
            if let data = try? JSONEncoder().encode(codable) {
                message = URLSessionWebSocketTask.Message.data(data)
            }
            else {
                fatalError()
            }
        case .uncodable(let data):
            message = URLSessionWebSocketTask.Message.data(data)
        }
    
        webSocketTask.send(message, completionHandler: {
            error in
            if let error = error {
                if  self.webSocketTask.closeCode != .invalid {
                    //closed!
                }
                Swift.print("ERROR on send \(error)")
            }
        })
        return .unlimited
    }

    func receive(completion: Subscribers.Completion<Error>) {
        Swift.print("Completion")
    }
    
}

extension CodableWebSocket {
    func codable()-> AnyPublisher<T, CodableWebSocket<T>.Failure> {
        return compactMap{ result -> T? in
            guard case  Result<SocketData<T>,Error>.success(let socketdata) = result,
                case SocketData.codable(let codable) = socketdata
            else { return nil }
            return codable
        }.eraseToAnyPublisher()
    }
}

