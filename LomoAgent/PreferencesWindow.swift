//
//  PreferencesWindow.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 3/7/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa
import ServiceManagement
import CocoaLumberjack

let PREF_START_ON_BOOT = "PrefStartOnBoot"
let PREF_DEBUG_MODE = "PrefDebugMode"
let PREF_HOME_DIR = "PrefHomeDir"
let PREF_BACKUP_DIR = "PrefBackupDir"
let PREF_LOMOD_PORT = "PrefPort"
let PREF_ADMIN_TOKEN = "PrefAdminToken"
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

class PreferencesWindow: NSWindowController, NSWindowDelegate {

    @IBOutlet weak var homeDirTextField: NSTextFieldCell!

    @IBOutlet weak var backupDirTextField: NSTextField!

    @IBOutlet weak var portTextField: NSTextField!

    @IBOutlet weak var ipTextField: NSTextField!

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
        let oldPort = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT)
        let port = portTextField.stringValue
        let p = Int(port)
        guard p != nil && p! >= 1024 && p! <= 49151 else {
            dialogAlert(message: invalidPortLocalized, info: invalidPortTipsLocalized)
            return
        }
        if oldPort != port {
            DDLogInfo("Save port: \(port)")
            UserDefaults.standard.set(port, forKey: PREF_LOMOD_PORT)
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

    @IBAction func onUnsetBackupPath(_ sender: NSButton) {
        guard backupDirTextField.stringValue != "" else {
            DDLogError("onUnsetBackupPath, backupDisk empty")
            dialogAlert(message: errorUnsetBackupLocalized, info: "")
            return
        }

        if dialogOKCancel(message: unsetBackup, info: "") {
            let backupDir = backupDirTextField.stringValue
            backupDirTextField.stringValue = ""
            DDLogInfo("Unset backup dir: \(backupDir)")

            if let lomodService = getLomodService() {
                let succ = lomodService.unsetRedundancyBackup()
                if (succ) {
                    UserDefaults.standard.set(backupDirTextField.stringValue, forKey: PREF_BACKUP_DIR)
                    dialogAlert(message: succUnsetBackupLocalized, info: "")
                } else {
                    DDLogError("unset \(backupDir) failed")
                    backupDirTextField.stringValue = backupDir
                    dialogAlert(message: errorUnsetBackupLocalized, info: "")
                }
            }
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
                        DDLogInfo("Save home dir: \(homeDirTextField.stringValue)")
                        NotificationCenter.default.post(name: .NotifySettingsChanged, object: self)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                            self.generateQRCode()
                        }
                        // todo: move files in directory
                    }
                } else if sender == selectBackupButton {
                    guard result.path != homeDirTextField.stringValue else {
                        DDLogError("setRedundancyBackup, backupDisk can't be the same as homeDir")
                        dialogAlert(
                            message: errorChooseBackupLocalized,
                            info: errorChooseBackupMsgLocalized
                        )
                        return
                    }

                    guard result.path != "" else {
                        DDLogError("setRedundancyBackup, backupDisk empty")
                        return
                    }

                    backupDirTextField.stringValue = result.path
                    openBackupButton.isEnabled = true

                    let oldBackupDir = UserDefaults.standard.string(forKey: PREF_BACKUP_DIR)
                    if oldBackupDir != backupDirTextField.stringValue {
                        UserDefaults.standard.set(backupDirTextField.stringValue, forKey: PREF_BACKUP_DIR)
                        DDLogInfo("Save backup dir: \(backupDirTextField.stringValue)")

                        if let lomodService = getLomodService() {
                            let succ = lomodService.setRedundancyBackup(backupDisk: backupDirTextField.stringValue)
                            if (!succ) {
                                backupDirTextField.stringValue = ""
                            }
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
        DDLogInfo("Debug Mode: \(debugModeCheckBox.state == .on)")

        if UserDefaults.standard.bool(forKey: PREF_START_ON_BOOT) {
            startOnBootCheckBox.state = .on
        } else {
            startOnBootCheckBox.state = .off
        }
        DDLogInfo("Start on boot: \(startOnBootCheckBox.state == .on)")

        homeDirTextField.isEditable = false
        if let homeDir = UserDefaults.standard.string(forKey: PREF_HOME_DIR) {
            homeDirTextField.stringValue = homeDir
            DDLogInfo("Home dir: \(homeDir)")
            openHomeButton.isEnabled = true
        } else {
            openHomeButton.isEnabled = false
        }

        backupDirTextField.isEditable = false
        if let backupDir = UserDefaults.standard.string(forKey: PREF_BACKUP_DIR) {
            backupDirTextField.stringValue = backupDir
            DDLogInfo("Backup dir: \(backupDir)")
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

        if let port = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT) {
            portTextField.stringValue = port
            DDLogInfo("Port: \(port)")
        } else {
            portTextField.stringValue = "8000"
            UserDefaults.standard.set(portTextField.stringValue, forKey: PREF_LOMOD_PORT)
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
                    ipTextField.stringValue = firstAddr
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
