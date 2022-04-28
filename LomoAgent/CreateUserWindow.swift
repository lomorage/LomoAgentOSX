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
        let username = userNameTextField.stringValue
        let password = passwordTextField.stringValue

        if let encryptedPwd = getEncryptPassword(username, password), let lomodService = getLomodService(),
           let homeDir = UserDefaults.standard.string(forKey: PREF_HOME_DIR) {
            DDLogInfo("Create user, username: \(username)")
            var result = createUserFailLocalized
            if lomodService.createUser(username: username, encryptPassword: encryptedPwd, homedir: homeDir) {
                result = createUserSuccLocalized
                NotificationCenter.default.post(name: .NotifyUserChanged, object: self)
                dialogAlert(message: result, info: "")
                self.window?.close()
            } else {
                dialogAlert(message: result, info: "")
            }
        }
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
