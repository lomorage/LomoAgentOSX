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

func getLomodService() -> LomodService? {
    guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else {
        os_log("getLomodService, error when getting AppDelegate", log: .logic, type: .error)
        return nil
    }

    return appDelegate.lomodService
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var lomodService = LomodService()

    func applicationWillFinishLaunching(_ aNotification: Notification) {
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        let arguments = CommandLine.arguments
        var exit = false
        for arg in arguments {
            if arg == "--version" {
                print("\(version)")
                NotificationCenter.default.post(name: .NotifyExit, object: self)
                exit = true
                break
            }
        }

        if !exit {
            os_log("LomoAgent version: %{public}s", log: .logic, version)
            NotificationCenter.default.post(name: .NotifyStart, object: self)
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

