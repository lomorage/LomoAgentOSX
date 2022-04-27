//
//  CreateUserWindow.swift
//  LomoAgent
//
//  Created by jeromy on 4/27/22.
//  Copyright © 2022 lomoware. All rights reserved.
//

import Foundation
import Cocoa
import CocoaLumberjack

class CreateUserWindow: NSWindowController {
    @IBOutlet weak var userNameTextField: NSTextField!

    @IBOutlet weak var passwordTextField: NSSecureTextField!

    @IBAction func onCancelClicked(_ sender: Any) {
        self.window?.close()
    }

    @IBAction func onOkClicked(_ sender: Any) {
    }

    override var windowNibName : String! {
        return "CreateUserWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)
        self.window?.level = .modalPanel
        NSApp.activate(ignoringOtherApps: true)
    }
}
