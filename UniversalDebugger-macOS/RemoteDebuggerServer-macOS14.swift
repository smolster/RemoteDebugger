//
//  RemoteDebuggerServer-macOS14.swift
//  UniversalDebugger-macOS
//
//  Created by Swain Molster on 7/28/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import Foundation
import AppKit

#if canImport(Network)
import Network

@available(OSXApplicationExtension 10.14, *)
final public class RemoteDebuggerServer<State: Codable> {
    
    private let onReceive: (Update<State>) -> Void
    private let listener = try! NWListener(parameters: .tcp)!
    private let queue = DispatchQueue(label: "Remote Debugger Server")
    
    private lazy var decoder: JSONOverTCPDecoder<DebugData<State>> = .init { [unowned self] result in
        switch result {
        case .success(let debugData):
            self.onReceive(debugData.toUpdate()!)
        case .decodingError(let error):
            print(error)
        }
    }
    
    private var currentConnection: NWConnection?
    
    public init(onReceive: @escaping (Update<State>) -> Void) {
        self.onReceive = onReceive
        
        listener.service = NWListener.Service(name: "remote-debugger", type: "_remote-debug._tcp", domain: "local")
        
        listener.serviceRegistrationUpdateHandler = { change in
            if case .add(let endpoint) = change,
                case .service(let name, let type, let domain, _) = endpoint {
                print("Remote Debugger Server listening with name \(name) and type \(type) on domain \(domain).")
            }
        }
        
        listener.newConnectionHandler = { [unowned self] connection in
            print("Remote Debugger Server received new connection: \(connection)")
            self.currentConnection = connection
            connection.start(queue: self.queue)
            self.receive(on: connection)
        }
        
        listener.stateUpdateHandler = { state in
            print("Remote Debugger Server updated to state: \(state)")
        }
        
        listener.start(queue: queue)
    }
    
    private func receive(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 0, maximumLength: 1024) { [unowned self] data, context, isComplete, error in
            print("Received: \(data), \(context), \(isComplete), \(error)")
            if let data = data {
                self.decoder.decode(data)
                self.receive(on: connection)
            } else {
                print(error)
            }
        }
    }
    
    public func send(newState: State) {
        guard let currentConnection = currentConnection else {
            // TODO: Enqueue early sends.
            return
        }
        
        guard let data = try? JSONOverTCPEncoder().encode(newState) else {
            // TODO: handle this error
            return
        }
        
        print("Sending data with size \(data.count) to client.")
        
        currentConnection.send(content: data, completion: .contentProcessed { error in
            print("Finished sending data to client. Error: \(error)")
        })
    }
    
}

#endif
