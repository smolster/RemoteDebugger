//
//  AppDelegate.swift
//  RDSampleApp-iOS
//
//  Created by Swain Molster on 7/28/18.
//  Copyright © 2018 Swain Molster. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    let window: UIWindow = UIWindow(frame: UIScreen.main.bounds)

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        self.window.rootViewController = UINavigationController(rootViewController: ViewController())
        self.window.makeKeyAndVisible()
        return true
    }

}

