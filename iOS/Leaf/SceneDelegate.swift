//
//  SceneDelegate.swift
//  leaf
//
//  Created by Laurent Fournier on 23/05/2020.
//  Copyright © 2020 Laurent Fournier. All rights reserved.
//

import UIKit
import SwiftUI

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var auth: authController = authController()
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
         
        auth.tapAdd(self)
        
        if let windowScene = scene as? UIWindowScene {
            let win = UIWindow(windowScene: windowScene)
            //if auth.read(self) {
            let cv = ContentView()
            win.rootViewController = UIHostingController(rootView: cv)
            //} else { win.rootViewController = UIHostingController(rootView: CVError()) }
            self.window = win
            win.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {}

    func sceneDidBecomeActive(_ scene: UIScene) {}

    func sceneWillResignActive(_ scene: UIScene) {}

    func sceneWillEnterForeground(_ scene: UIScene) {}

    func sceneDidEnterBackground(_ scene: UIScene) {}


}

