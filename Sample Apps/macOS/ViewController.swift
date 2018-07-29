//
//  ViewController.swift
//  RDSampleApp-macOS
//
//  Created by Swain Molster on 7/28/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import Cocoa
import RemoteDebugger_macOS

struct MyState: Codable {
    let sample: String
}

class ViewController: NSSplitViewController {
    
    let server = RemoteDebuggerServer { debugData in
        print("Received data: \(debugData)")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
    }
}

