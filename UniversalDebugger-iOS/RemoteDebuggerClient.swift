//
//  Client.swift
//  UniversalDebugger-iOS
//
//  Created by Swain Molster on 7/28/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import Foundation
import UIKit

internal struct DebugData<State: Codable>: Codable {
    let state: State
    let action: String
    let png: Data
}
#if !canImport(Network)

final public class RemoteDebuggerClient<State: Codable>: NSObject, NetServiceBrowserDelegate {
    
    private let browser = NetServiceBrowser()
    private let queue = DispatchQueue(label: "Remote Debugger Client")
    private let onReceive: (State) -> Void
    
    private var writer: BufferedWriter?
    private var reader: BufferedReader?
    
    public private(set) var isConnected: Bool = false
    
    public init(onReceive: @escaping (State) -> Void) {
        self.onReceive = onReceive
        super.init()
        self.browser.delegate = self
        self.browser.searchForServices(ofType: "_debug._tcp", inDomain: "local")
    }
    
    public func netServiceBrowser(_ browser: NetServiceBrowser, didFind service: NetService, moreComing: Bool) {
        self.isConnected = true
        var inputStream: InputStream?
        var outputStream: OutputStream?
        service.getInputStream(&inputStream, outputStream: &outputStream)
        if let output = outputStream {
            writer = BufferedWriter(output) { [unowned self] result in
                print(result)
                self.writer = nil
            }
        }
        
        if let input = inputStream {
            
            var decoder = JSONOverTCPDecoder<State> { [unowned self] newState in
                if let state = newState {
                    self.onReceive(state)
                } else {
                    print("Error")
                }
            }
            
            reader = BufferedReader(input) { result in
                switch result {
                case .chunk(let data):
                    decoder.decode(data)
                default:
                    print(result)
                }
            }
        }
    }
    
    public func send(newState: State, action: String, snapshot: UIView) {
        guard let writer = writer else {
            print("Wait until isConnectedß = true")
            return
        }
        let image = snapshot.capture()!
        
        let imageData = image.jpegData(compressionQuality: 1.0)!
        
        let debugData = DebugData<State>(state: newState, action: action, png: nil)
        
        let data = try! JSONOverTCPEncoder().encode(debugData)
        print("Sending data of size: \(data.count)")
        writer.write(data: data)
    }
}
#endif

