//
//  AppDelegate.swift
//  LomoAgentLauncher
//
//  Created by Jiantao Fu on 9/1/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        let mainAppIdentifier = "lomoware.lomorage.LomoAgent"
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == mainAppIdentifier }.isEmpty

        if !isRunning {
            DistributedNotificationCenter.default().addObserver(self,
                                                                selector: #selector(self.terminate),
                                                                name: .killLauncher,
                                                                object: mainAppIdentifier)

            let path = Bundle.main.bundlePath as NSString
            var components = path.pathComponents
            components.removeLast(4)

            let newPath = NSString.path(withComponents: components)

//            let alert = NSAlert()
//            alert.messageText = "launching path: \(newPath)"
//            alert.alertStyle = NSAlert.Style.warning
//            alert.addButton(withTitle: "OK")
//            alert.runModal()

            NSWorkspace.shared.launchApplication(newPath)
        }
        else {
            self.terminate()
        }
    }

    @objc func terminate() {
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

}

