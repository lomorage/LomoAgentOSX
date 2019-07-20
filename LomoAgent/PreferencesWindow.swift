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

extension Notification.Name {
    static let NotifySettingsChanged = NSNotification.Name("NotifySettingsChanged")
    static let NotifyExit = NSNotification.Name("NotifyExit")
    static let NotifyStart = NSNotification.Name("NotifyStart")
}

func getIFAddresses() -> [String] {
    var addresses = [String]()

    // Get list of all interfaces on the local machine:
    var ifaddr : UnsafeMutablePointer<ifaddrs>?
    guard getifaddrs(&ifaddr) == 0 else { return [] }
    guard let firstAddr = ifaddr else { return [] }

    // For each interface ...
    for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
        let flags = Int32(ptr.pointee.ifa_flags)
        let addr = ptr.pointee.ifa_addr.pointee

        // Check for running IPv4. Skip the loopback interface and IPv6 interfaces(AF_INET6).
        if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
            if addr.sa_family == UInt8(AF_INET) {

                // Convert interface address to a human readable string:
                var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if (getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                    let address = String(cString: hostname)
                    addresses.append(address)
                }
            }
        }
    }

    freeifaddrs(ifaddr)
    return addresses
}

class PreferencesWindow: NSWindowController, NSWindowDelegate {

    @IBOutlet weak var homeDirTextField: NSTextFieldCell!

    @IBOutlet weak var portTextField: NSTextField!

    @IBOutlet weak var debugModeCheckBox: NSButton!

    @IBOutlet weak var openButton: NSButton!

    @IBOutlet weak var imageQRCode: NSImageView!

    @IBAction func onDebugModeClick(_ sender: Any) {
        let oldState = UserDefaults.standard.bool(forKey: PREF_DEBUG_MODE)
        let newState = (debugModeCheckBox.state == .on)
        if newState != oldState {
            UserDefaults.standard.set(newState, forKey: PREF_DEBUG_MODE)
            NotificationCenter.default.post(name: .NotifySettingsChanged, object: self)
        }
    }

    @IBAction func onPortChange(_ sender: Any) {
        let oldPort = UserDefaults.standard.string(forKey: PREF_PORT)
        let port = portTextField.stringValue
        if oldPort != port {
            os_log("Save port: %{public}s", log: .ui, port)
            UserDefaults.standard.set(port, forKey: PREF_PORT)
            generateQRCode()
            NotificationCenter.default.post(name: .NotifySettingsChanged, object: self)
        }
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
                openButton.isEnabled = true

                let oldHomeDir = UserDefaults.standard.string(forKey: PREF_HOME_DIR)
                if oldHomeDir != homeDirTextField.stringValue {
                    UserDefaults.standard.set(homeDirTextField.stringValue, forKey: PREF_HOME_DIR)
                    os_log("Save home dir: %{public}s", log: .ui, homeDirTextField.stringValue)
                    NotificationCenter.default.post(name: .NotifySettingsChanged, object: self)
                    // todo: move files in directory
                }
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
        self.window?.level = .floating

        if UserDefaults.standard.bool(forKey: PREF_DEBUG_MODE) {
            debugModeCheckBox.state = .on
        } else {
            debugModeCheckBox.state = .off
        }
        os_log("Debug Mode: %d", log: .ui, debugModeCheckBox.state == .on)

        homeDirTextField.isEditable = false
        if let homeDir = UserDefaults.standard.string(forKey: PREF_HOME_DIR) {
            homeDirTextField.stringValue = homeDir
            os_log("Home dir: %{public}s", log: .ui, homeDir)
            openButton.isEnabled = true
        } else {
            openButton.isEnabled = false
        }

        if let port = UserDefaults.standard.string(forKey: PREF_PORT) {
            portTextField.stringValue = port
            os_log("Port: %{public}s", log: .ui, port)
        } else {
            portTextField.stringValue = "8000"
            UserDefaults.standard.set(portTextField.stringValue, forKey: PREF_PORT)
        }

        generateQRCode()
    }

    func generateQRCode() {
        imageQRCode.wantsLayer = true
        let addresses = getIFAddresses()
        if let firstAddr = addresses.first {
            let url = "http://\(firstAddr):\(portTextField.stringValue)"
            guard let data = url.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
                return
            }
            imageQRCode.image = QRCodeImageWith(data: data, size: imageQRCode.frame.size.width)
        }
    }

    func windowWillClose(_ notification: Notification) {
    }
}
