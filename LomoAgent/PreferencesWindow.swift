//
//  PreferencesWindow.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 3/7/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa
import os.log

let PREF_DEBUG_MODE = "PrefDebugMode"
let PREF_HOME_DIR = "PrefHomeDir"
let PREF_PORT = "PrefPort"

class PreferencesWindow: NSWindowController, NSWindowDelegate {

    @IBOutlet weak var homeDirTextField: NSTextFieldCell!

    @IBOutlet weak var portTextField: NSTextField!

    @IBOutlet weak var debugModeCheckBox: NSButton!

    @IBAction func onDebugModeClick(_ sender: Any) {
        UserDefaults.standard.set(debugModeCheckBox.state == .on, forKey: PREF_DEBUG_MODE)
    }

    @IBAction func onPortChange(_ sender: Any) {
        let port = portTextField.stringValue
        os_log("Save port: %{public}s", log: .ui, port)
        UserDefaults.standard.set(port, forKey: PREF_PORT)
    }

    @IBAction func onOpenPath(_ sender: Any) {
        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: homeDirTextField.stringValue)])
    }

    @IBAction func onSelectPath(_ sender: Any) {
        let dialog = NSOpenPanel();

        dialog.title                   = "Choose the home directory";
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = true;
        dialog.canCreateDirectories    = true;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseFiles          = false;

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if let result = dialog.url {
                homeDirTextField.stringValue = result.path
                UserDefaults.standard.set(result.path, forKey: PREF_HOME_DIR)
                os_log("Save home dir: %{public}s", log: .ui, homeDirTextField.stringValue)
            }
        }
    }

    override var windowNibName : String! {
        return "PreferencesWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
        self.window?.center()
        self.window?.makeKeyAndOrderFront(nil)

        if UserDefaults.standard.bool(forKey: PREF_DEBUG_MODE) {
            debugModeCheckBox.state = .on
        } else {
            debugModeCheckBox.state = .off
        }
        os_log("Debug Mode: %d", log: .ui, debugModeCheckBox.state == .on)

        if let homeDir = UserDefaults.standard.string(forKey: PREF_HOME_DIR) {
            homeDirTextField.stringValue = homeDir
            os_log("Home dir: %{public}s", log: .ui, homeDir)
        }

        if let port = UserDefaults.standard.string(forKey: PREF_PORT) {
            portTextField.stringValue = port
            os_log("Port: %{public}s", log: .ui, port)
        } else {
            portTextField.stringValue = "8000"
            UserDefaults.standard.set(portTextField.stringValue, forKey: PREF_PORT)
        }
    }

    func windowWillClose(_ notification: Notification) {
    }
}
