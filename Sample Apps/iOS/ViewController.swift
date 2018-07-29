//
//  ViewController.swift
//  RDSampleApp-iOS
//
//  Created by Swain Molster on 7/28/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import UIKit
import RemoteDebugger_iOS

struct MyState: Codable {
    let sample: String
}

class ViewController: UIViewController {
    let client = RemoteDebuggerClient<MyState> { newState in
        print("New state received: \(newState)")
    }
    
    let button = UIButton(type: .roundedRect)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        
        self.button.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(button)
        
        button.addTarget(self, action: #selector(buttonPressed), for: .touchUpInside)
        
        NSLayoutConstraint.activate([
            button.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            button.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 200),
            button.heightAnchor.constraint(equalToConstant: 50)
            ])
        
        button.setTitle("Send State", for: .init())
    }
    
    @objc func buttonPressed() {
        client.send(newState: MyState(sample: "First state!"), action: "sample action", snapshot: UIApplication.shared.windows[0])
    }
    
}
