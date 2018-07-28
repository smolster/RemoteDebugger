//
//  Server.swift
//  UniversalDebugger-macOS
//
//  Created by Swain Molster on 7/28/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import Foundation
import Cocoa

public struct Update<State> {
    let state: State
    let action: String
    let image: NSImage
}

internal struct DebugData<State: Codable>: Codable {
    let state: State
    let action: String
    let png: Data
    
    public func toUpdate() -> Update<State>? {
        guard let image = NSImage(data: self.png) else { return nil }
        return .init(state: self.state, action: self.action, image: image)
    }
}

#if !canImport(Network)

final public class RemoteDebuggerServer<State: Codable>: NSObject, NetServiceDelegate {
    
    private let onReceive: (Update<State>) -> Void
    private let service = NetService(domain: "local", type: "_debug._tcp", name: "remote-debugger")
    
    private var writer: BufferedWriter?
    private var reader: BufferedReader?
    
    public private(set) var isConnected: Bool = false
    
    public init(onReceive: @escaping (Update<State>) -> Void) {
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
                self.onReceive(debugData.toUpdate())
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
