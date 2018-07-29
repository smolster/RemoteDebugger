//
//  RemoteDebuggerClient-iOS12.swift
//  UniversalDebugger-iOS
//
//  Created by Swain Molster on 7/28/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import Foundation

#if canImport(UIKit)
import UIKit
#endif

#if canImport(Network)
import Network
#endif

@available(iOSApplicationExtension 12.0, *)
@available(OSXApplicationExtension 10.14, *)
final public class RemoteDebuggerClient<State: Codable> {
    
    private let queue = DispatchQueue(label: "Remote Debugger Client")
    
    private let connection: NWConnection = .init(
        to: .service(name: "remote-debugger", type: "_remote-debug._tcp", domain: "local", interface: nil),
        using: .tcp
    )
    private let onReceive: (State) -> Void
    
    public var isConnected: Bool {
        return connection.state == .ready
    }
    
    public init(onReceive: @escaping (State) -> Void) {
        self.onReceive = onReceive
        
        connection.stateUpdateHandler = { state in
            print("Connection state update to: \(state)")
        }
        
        connection.start(queue: queue)
        
        var decoder = JSONOverTCPDecoder<State> { [unowned self] result in
            switch result {
            case .success(let newState):
                self.onReceive(newState)
            case .decodingError(let error):
                print("Decoding Error: \(error)")
            }
        }
        
        // Begin receiving
        connection.receive(minimumIncompleteLength: 0, maximumLength: 1024) { data, _, _, error in
            if let data = data {
                decoder.decode(data)
            }
            
            if let error = error {
                print("Received error from connection: \(error)")
            }
        }
    }
    
    #if canImport(UIKit)
    
    public func send(newState: State, action: String, snapshot: UIView) {
        let image = snapshot.capture()!
        
        let imageData = image.jpegData(compressionQuality: 1.0)!
        
        let debugData = DebugData(state: newState, action: action, png: imageData)
        
        let data = try! JSONOverTCPEncoder().encode(debugData)
        print("Sending data of size \(data.count)")
        connection.send(content: data, completion: .contentProcessed { error in
            if let error = error {
                print("Finished sending, but found error: \(error)")
            } else {
                print("Finished sending debug data successfuly.")
            }
        })
    }
    
    #endif
    
}

