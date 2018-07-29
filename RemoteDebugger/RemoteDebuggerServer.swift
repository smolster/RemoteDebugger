//
//  Server.swift
//  UniversalDebugger-macOS
//
//  Created by Swain Molster on 7/28/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import Foundation

#if !canImport(Network)

final public class RemoteDebuggerServer<State: Codable>: NSObject, NetServiceDelegate {
    
    private let onReceive: (DebugData<State>) -> Void
    private let service = NetService(domain: "local", type: "_debug._tcp", name: "remote-debugger")
    
    private var writer: BufferedWriter?
    private var reader: BufferedReader?
    
    public private(set) var isConnected: Bool = false
    
    public init(onReceive: @escaping (DebugData<State>) -> Void) {
        self.onReceive = onReceive
        super.init()
        service.publish(options: .listenForConnections)
        service.delegate = self
    }
    
    public func netService(_ sender: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {
        self.isConnected = true
        var decoder = JSONOverTCPDecoder<DebugData<State>> { [unowned self] result in
            switch result {
            case .success(let debugData):
                self.onReceive(debugData)
            }
        }
        
        reader = BufferedReader(inputStream) { result in
            switch result {
            case .chunk(let data):
                decoder.decode(data)
            default:
                print("Received read event: \(result)")
            }
        }
        
        writer = BufferedWriter(outputStream) { result in
            print(result)
        }
    }
    
    public func send(newState: State) throws {
        guard let writer = writer else {
            // TODO: Enqueue this state.
            print("It is not safe to call RemoteDebuggerServer.send(newState:) until RemoteDebuggerServer.isConnected is true.")
            return
        }
        
        writer.write(data: try JSONOverTCPEncoder().encode(newState))
    }
}

#endif
