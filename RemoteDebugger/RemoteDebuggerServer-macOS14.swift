//
//  RemoteDebuggerServer-macOS14.swift
//  RemoteDebugger
//
//  Created by Swain Molster on 7/28/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import Foundation

#if canImport(Network)
import Network

@available(iOSApplicationExtension 12.0, *)
@available(OSXApplicationExtension 10.14, *)
final public class RemoteDebuggerServer {
    
    private let onReceive: (Data) -> Void
    private let listener = try! NWListener(parameters: .tcp)!
    private let queue = DispatchQueue(label: "Remote Debugger Server")
    
    private lazy var reader: JSONOverTCPReader = .init { [unowned self] jsonData in
        self.onReceive(jsonData)
    }
    
    private var currentConnection: NWConnection?
    
    public init(onReceive: @escaping (Data) -> Void) {
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
        connection.receive(minimumIncompleteLength: 0, maximumLength: 1024) { [unowned self] data, context, _, error in
            if let data = data {
                self.reader.read(data)
                self.receive(on: connection)
            } else if let error = error {
                print("Encountered error in receiving data. Error: \(error). Context: \(context.debugDescription)")
            }
        }
    }
    
    public func send(data: Data) {
        guard let currentConnection = currentConnection else {
            // TODO: Enqueue early sends.
            return
        }
        
        var data = data
        JSONOverTCPEncoder().prepare(jsonData: &data)
        
        print("Sending data with size \(data.count) to client.")
        
        currentConnection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Finished sending data to client, but found error: \(error)")
            } else {
                print("Finished sending data to client successfully.")
            }
        })
    }
    
}

#endif
