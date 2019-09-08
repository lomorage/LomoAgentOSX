//
//  PreferencesWindow.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 3/7/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa
import ServiceManagement
import os.log

let PREF_START_ON_BOOT = "PrefStartOnBoot"
let PREF_DEBUG_MODE = "PrefDebugMode"
let PREF_HOME_DIR = "PrefHomeDir"
let PREF_BACKUP_DIR = "PrefBackupDir"
let PREF_PORT = "PrefPort"
let LOCAL_HOST = "127.0.0.1"

extension Notification.Name {
    static let NotifySettingsChanged = NSNotification.Name("NotifySettingsChanged")
    static let NotifyIpChanged = NSNotification.Name("NotifyIpChanged")
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

func dialogAlert(message: String, info: String)
{
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = info
    alert.alertStyle = NSAlert.Style.warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

class PreferencesWindow: NSWindowController, NSWindowDelegate {

    @IBOutlet weak var homeDirTextField: NSTextFieldCell!

    @IBOutlet weak var backupDirTextField: NSTextField!

    @IBOutlet weak var portTextField: NSTextField!

    @IBOutlet weak var debugModeCheckBox: NSButton!

    @IBOutlet weak var startOnBootCheckBox: NSButton!

    @IBOutlet weak var openHomeButton: NSButton!

    @IBOutlet weak var selectHomeButton: NSButton!

    @IBOutlet weak var openBackupButton: NSButton!

    @IBOutlet weak var selectBackupButton: NSButton!

    @IBOutlet weak var imageQRCode: NSImageView!

    @IBOutlet weak var lastBackupLabel: NSTextField!

    @IBOutlet weak var userTipsLabel: NSTextField!

    @IBAction func onDebugModeClick(_ sender: Any) {
        let oldState = UserDefaults.standard.bool(forKey: PREF_DEBUG_MODE)
        let newState = (debugModeCheckBox.state == .on)
        if newState != oldState {
            UserDefaults.standard.set(newState, forKey: PREF_DEBUG_MODE)
            NotificationCenter.default.post(name: .NotifySettingsChanged, object: self)
        }
    }

    @IBAction func onStartOnBootClick(_ sender: Any) {
        let oldState = UserDefaults.standard.bool(forKey: PREF_START_ON_BOOT)
        let newState = (startOnBootCheckBox.state == .on)
        if newState != oldState {
            UserDefaults.standard.set(newState, forKey: PREF_START_ON_BOOT)
            SMLoginItemSetEnabled(launcherAppId as CFString, newState)
        }
    }

    @IBAction func onPortChange(_ sender: Any) {
        let oldPort = UserDefaults.standard.string(forKey: PREF_PORT)
        let port = portTextField.stringValue
        let p = Int(port)
        guard p != nil && p! >= 1024 && p! <= 49151 else {
            dialogAlert(message: invalidPortLocalized, info: invalidPortTipsLocalized)
            return
        }
        if oldPort != port {
            os_log("Save port: %{public}s", log: .ui, port)
            UserDefaults.standard.set(port, forKey: PREF_PORT)
            generateQRCode()
            NotificationCenter.default.post(name: .NotifySettingsChanged, object: self)
        }
    }

    @IBAction func onOpenPath(_ sender: NSButton) {
        if sender == openHomeButton {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: homeDirTextField.stringValue)])
        } else if sender == openBackupButton {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: backupDirTextField.stringValue)])
        }
    }

    @IBAction func onSelectPath(_ sender: NSButton) {
        let dialog = NSOpenPanel();

        if sender == selectHomeButton {
            dialog.title = chooseHomeDirLocalized;
        } else if sender == selectBackupButton {
            dialog.title = chooseBackupDirLocalized;
        }
        dialog.showsResizeIndicator    = true;
        dialog.showsHiddenFiles        = false;
        dialog.canChooseDirectories    = true;
        dialog.canCreateDirectories    = true;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseFiles          = false;

        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if let result = dialog.url {
                if sender == selectHomeButton {
                    guard result.path != backupDirTextField.stringValue else {
                        dialogAlert(
                            message: errorChooseHomeLocalized,
                            info: errorChooseHomeMsgLocalized
                        )
                        return
                    }

                    homeDirTextField.stringValue = result.path
                    openHomeButton.isEnabled = true

                    let oldHomeDir = UserDefaults.standard.string(forKey: PREF_HOME_DIR)
                    if oldHomeDir != homeDirTextField.stringValue {
                        UserDefaults.standard.set(homeDirTextField.stringValue, forKey: PREF_HOME_DIR)
                        os_log("Save home dir: %{public}s", log: .ui, homeDirTextField.stringValue)
                        NotificationCenter.default.post(name: .NotifySettingsChanged, object: self)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.generateQRCode()
                        }
                        // todo: move files in directory
                    }
                } else if sender == selectBackupButton {
                    guard result.path != homeDirTextField.stringValue else {
                        dialogAlert(
                            message: errorChooseBackupLocalized,
                            info: errorChooseBackupMsgLocalized
                        )
                        return
                    }

                    backupDirTextField.stringValue = result.path
                    openBackupButton.isEnabled = true

                    let oldBackupDir = UserDefaults.standard.string(forKey: PREF_BACKUP_DIR)
                    if oldBackupDir != backupDirTextField.stringValue {
                        UserDefaults.standard.set(backupDirTextField.stringValue, forKey: PREF_BACKUP_DIR)
                        os_log("Save backup dir: %{public}s", log: .ui, backupDirTextField.stringValue)

                        if let lomodService = getLomodService() {
                            _ = lomodService.setRedundancyBackup(backupDisk: backupDirTextField.stringValue)
                        }
                    }
                }
            }
        }
    }

    override var windowNibName : String! {
        return "PreferencesWindow"
    }

    override func windowDidLoad() {
        super.windowDidLoad()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onIpChanged(_:)),
                                               name: .NotifyIpChanged,
                                               object: nil)

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

        if UserDefaults.standard.bool(forKey: PREF_START_ON_BOOT) {
            startOnBootCheckBox.state = .on
        } else {
            startOnBootCheckBox.state = .off
        }
        os_log("Start on boot: %d", log: .ui, startOnBootCheckBox.state == .on)

        homeDirTextField.isEditable = false
        if let homeDir = UserDefaults.standard.string(forKey: PREF_HOME_DIR) {
            homeDirTextField.stringValue = homeDir
            os_log("Home dir: %{public}s", log: .ui, homeDir)
            openHomeButton.isEnabled = true
        } else {
            openHomeButton.isEnabled = false
        }

        backupDirTextField.isEditable = false
        if let backupDir = UserDefaults.standard.string(forKey: PREF_BACKUP_DIR) {
            backupDirTextField.stringValue = backupDir
            os_log("Backup dir: %{public}s", log: .ui, backupDir)
            openBackupButton.isEnabled = true
        } else {
            openBackupButton.isEnabled = false
        }

        self.lastBackupLabel.isHidden = true
        if let lomodService = getLomodService() {
            if lomodService.finalBackupTime != "" {
                self.lastBackupLabel.isHidden = false
                self.lastBackupLabel.stringValue = lastBackupLocalized + lomodService.finalBackupTime
            }
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

    @objc func onIpChanged(_ notification: Notification) {
        generateQRCode()
    }

    func generateQRCode() {
        if let lomodService = getLomodService() {
            imageQRCode.wantsLayer = true
            if let addresses = lomodService.getListenIPs() {
                if let firstAddr = addresses.first {
                    let url = "http://\(firstAddr):\(portTextField.stringValue)"
                    guard let data = url.data(using: String.Encoding.utf8, allowLossyConversion: false) else {
                        return
                    }
                    userTipsLabel.textColor = .black
                    userTipsLabel.stringValue = userTipsScanQRCode
                    imageQRCode.image = QRCodeImageWith(data: data, size: imageQRCode.frame.size.width)
                }
            } else {
                userTipsLabel.textColor = .red
                userTipsLabel.stringValue = userTipsNeedConfigureHomeDir
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if homeDirTextField.stringValue == "" {
            dialogAlert(message: homeDirRequiredLocalized, info: "")
            return false
        } else {
            return true
        }
    }
}
