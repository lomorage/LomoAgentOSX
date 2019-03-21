//
//  AppDelegate.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 3/5/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa
import os.log

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier!

    static let ui = OSLog(subsystem: subsystem, category: "UI")
    static let logic = OSLog(subsystem: subsystem, category: "Logic")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }


}

