//
//  AboutWindow.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 3/20/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa

class AboutWindow: NSWindowController {

    @IBOutlet weak var iconImage: NSImageView!
    
    @IBOutlet weak var versionLabel: NSTextField!

    override var windowNibName : String! {
        return "AboutWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        iconImage.image = NSImage(named: NSImage.Name("AppIcon"))
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            versionLabel.stringValue = "ver: \(version)"
        }

    }
    
}
