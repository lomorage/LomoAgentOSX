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
let PREF_BACKUP_DIR = "PrefBackupDir"
let PREF_PORT = "PrefPort"
let LOCAL_HOST = "127.0.0.1"

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

func dialogAlert(message: String, info: String)
{
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = info
    alert.alertStyle = NSAlert.Style.warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

struct BackupRecordItem {
    let backupOutput: String
    let lastBackupTime: String
    let lastBackupSuccTime: String
}

struct SystemInfo {
    let os: String
    let apiVer: String
    let timezoneOffset: Int32
    let systemStatus: Int32
    var backupRecords = [String: BackupRecordItem]()

    init(os: String, apiVer: String, timezoneOffset: Int32, systemStatus: Int32) {
        self.os = os
        self.apiVer = apiVer
        self.timezoneOffset = timezoneOffset
        self.systemStatus = systemStatus
    }
}

class Member {
    var userName: String!
    var userId: Int!
    var backupDir: String!
    var homeDir: String!
}

class PreferencesWindow: NSWindowController, NSWindowDelegate {

    @IBOutlet weak var homeDirTextField: NSTextFieldCell!

    @IBOutlet weak var backupDirTextField: NSTextField!

    @IBOutlet weak var portTextField: NSTextField!

    @IBOutlet weak var debugModeCheckBox: NSButton!

    @IBOutlet weak var openHomeButton: NSButton!

    @IBOutlet weak var selectHomeButton: NSButton!

    @IBOutlet weak var openBackupButton: NSButton!

    @IBOutlet weak var selectBackupButton: NSButton!

    @IBOutlet weak var imageQRCode: NSImageView!

    @IBOutlet weak var lastBackupLabel: NSTextField!

    private var networkSession: NetworkSession!

    private var members = [Member]()

    private var systemInfo: SystemInfo?

    var finalBackupTime: String = ""

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

                        var allSucc = true
                        for m in members {
                            let succ = setRedundencyBackup(username: m.userName, backupDisk: backupDirTextField.stringValue)
                            if !succ {
                                allSucc = false
                            }
                        }

                        if !allSucc {
                            dialogAlert(message: setBackupDirFailedLocalized, info: "")
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

        let defaultConfiguration = URLSessionConfiguration.default
        defaultConfiguration.allowsCellularAccess = false
        defaultConfiguration.timeoutIntervalForRequest = 20
        networkSession = URLSession(configuration: defaultConfiguration)

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

        if let port = UserDefaults.standard.string(forKey: PREF_PORT) {
            portTextField.stringValue = port
            os_log("Port: %{public}s", log: .ui, port)
        } else {
            portTextField.stringValue = "8000"
            UserDefaults.standard.set(portTextField.stringValue, forKey: PREF_PORT)
        }

        generateQRCode()

        _ = checkServerStatus()
        getUserList()
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

    func setRedundencyBackup(username: String, backupDisk: String) -> Bool {
        var ret = false
        let port = UserDefaults.standard.string(forKey: PREF_PORT)
        guard port != nil else {
            os_log("setRedundencyBackup, port not ready yet", log: .logic, type: .error)
            return false
        }

        if let url = URL(string: "http://\(LOCAL_HOST):\(port!)/system/backup") {
            var json = [String:Any]()
            json["Username"] = username
            json["DestDisk"] = backupDisk

            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: [])
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "POST"
                urlRequest.httpBody = data
                urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")

                let opGroup = DispatchGroup()
                opGroup.enter()
                self.networkSession.reqData(with: urlRequest, completionHandler: { (data, response, error) in
                    if let error = error {
                        os_log("setRedundencyBackup, error: %{public}s", log: .logic, type: .error, error.localizedDescription)
                    } else if let httpresp = response as? HTTPURLResponse {
                        if httpresp.statusCode == 200 {
                            os_log("setRedundencyBackup for %{public}s succ", log: .logic, username)
                            ret = true
                        } else {
                            os_log("setRedundencyBackup, error: %{public}s", log: .logic, type: .error, String(describing: response))
                        }
                    } else {
                        os_log("setRedundencyBackup, error: %{public}s", log: .logic, type: .error, String(describing: response))
                    }
                }, sync: opGroup)
                opGroup.wait()
            } catch {
                os_log("setRedundencyBackup, failed: %{public}s", log: .logic, type: .error, error.localizedDescription)
            }
        }
        return ret
    }

    func getUserList() {
        if let port = UserDefaults.standard.string(forKey: PREF_PORT) {
            if let url = URL(string: "http://\(LOCAL_HOST):\(port)/user") {
                networkSession.reqData(with: URLRequest(url: url), completionHandler: { (data, response, error) in
                    if let error = error {
                        os_log("fetchContactList, userList error: %{public}s", log: .logic, type: .error, error.localizedDescription)
                    } else if let data = data, let httpresp = response as? HTTPURLResponse {
                        if httpresp.statusCode == 200, let jsonResult = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            os_log("fetchContactList, json response:  %{public}@", log: .logic, jsonResult!)

                            if let userList = jsonResult?["Users"] as? [Any] {
                                for userItem in userList {
                                    if let keyVal = userItem as? [String: Any] {
                                        let m = Member()
                                        m.userName = keyVal["Name"] as? String
                                        m.userId = keyVal["ID"] as? Int
                                        m.backupDir = keyVal["BackupDir"] as? String
                                        m.homeDir = keyVal["HomeDir"] as? String
                                        self.members.append(m)
                                    }
                                }
                            }

                        } else {
                            os_log("fetchContactList, userList error: %{public}s\n%{public}@", log: .logic, type: .error, String(data: data, encoding: .utf8)!, httpresp)
                        }
                    } else {
                        os_log("fetchContactList, userList error: %{public}@", log: .logic, type: .error, String(describing: response))
                    }
                }, sync: nil)
            }
        }
    }

    func checkServerStatus() -> (SystemInfo?, Error?) {
        var networkError: Error?
        if let port = UserDefaults.standard.string(forKey: PREF_PORT) {
            if let url = URL(string: "http://\(LOCAL_HOST):\(port)/system") {
                let opGroup = DispatchGroup()
                opGroup.enter()
                os_log("check server status: %{public}s", log: .logic, String(describing: url))
                networkSession.loadData(with: url, completionHandler: { (data, response, error) in
                    if let error = error {
                        networkError = error
                        os_log("check server status error: %{public}s", log: .logic, type: .error, error.localizedDescription)
                    } else if let httpresp = response as? HTTPURLResponse,
                        httpresp.statusCode == 200 {
                        if let data = data {
                            do {
                                let jsonResult = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                                os_log("check server status, json response:  %{public}@", log: .logic, jsonResult)
                                if let osSystem = jsonResult["OS"] as? String,
                                    let apiVer = jsonResult["APIVersion"] as? String,
                                    let status = jsonResult["SystemStatus"] as? Int32,
                                    let timeZoneOffset = jsonResult["TimezoneOffset"] as? Int32
                                {
                                    self.systemInfo = SystemInfo(os: osSystem, apiVer: apiVer, timezoneOffset: timeZoneOffset, systemStatus: status)

                                    if let lastBackup = jsonResult["LastBackup"] as? [String: Any] {
                                        for record in lastBackup {
                                            if let backupItem = record.value as? [String: Any] {
                                                if let backoutOutput = backupItem["AssetRetCode"] as? String,
                                                    let lastBackupTime = backupItem["LastAssetBackup"] as? String,
                                                    let lastBackupSuccTime = backupItem["LastAssetSuccess"] as? String
                                                {
                                                    self.finalBackupTime = lastBackupTime
                                                    self.systemInfo!.backupRecords[record.key] =
                                                        BackupRecordItem(
                                                            backupOutput: backoutOutput,
                                                            lastBackupTime: lastBackupTime,
                                                            lastBackupSuccTime: lastBackupSuccTime
                                                    )
                                                } else {
                                                    os_log("checkServerStatus, wrong \"LastBackup\" format", log: .logic, type: .error)
                                                }
                                            }
                                        }
                                    }
                                }
                            } catch let error as NSError {
                                print("Failed to load: \(error.localizedDescription), \(String(describing: data))")
                            }
                        } else {
                            os_log("checkServerStatus, not able to convert %{public}s to String", log: .logic, type: .error, String(describing: data))
                        }
                    } else {
                        os_log("check server status failure:", log: .logic, type: .error, String(describing: response))
                    }
                }, sync: opGroup)
                opGroup.wait()
            }
        }

        if finalBackupTime != "" {
            DispatchQueue.main.async {
                self.lastBackupLabel.isHidden = false
                self.lastBackupLabel.stringValue = lastBackupLocalized + self.finalBackupTime
            }
        }

        return (systemInfo, networkError)
    }
}
