//
//  ViewController.swift
//  RemoteDebugger-macOS
//
//  Created by Swain Molster on 7/27/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import Cocoa
import UniversalDebugger_macOS

struct MyState: Codable {
    let sample: String
}

class ViewController: NSViewController {
    
    var server: RemoteDebuggerServer<MyState>?

    override func viewDidLoad() {
        super.viewDidLoad()
        self.server = RemoteDebuggerServer<MyState>(onReceive: { update in
            update
            print(update)
        })
    }


}
