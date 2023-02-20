//
//  StatusMenuController.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 3/5/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa
import CocoaLumberjack

class StatusMenuController: NSObject {

    @IBOutlet weak var statusMenu: NSMenu!
    var settingsMenuItem: NSMenuItem!
    var preferencesWindow: PreferencesWindow?
    var userWindow: UserWindow!
    var aboutWindow: AboutWindow!
    var lomodTask: Process?
    var lomoWebTask: Process?
    var updateTimer: Timer = Timer()
    var guideUrlPoped = false
    let stateReaptingTimer = RepeatingTimer(timeInterval: 1)
    let pingReaptingTimer = RepeatingTimer(timeInterval: 5)
    static let autoUpdateHour = 4
    static let autoUpdateMinute = 0
    static let pingTimeoutSec = 180.0
    var pingTimeout = Date(timeIntervalSinceNow: pingTimeoutSec)

    var lomodService: LomodService!

    var listenIp = ""

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let lomoUpdate = LomoUpgrade(url: LOMO_UPGRADE_URL)
    let updateQueue = DispatchQueue(label: "lomo.update")

    @IBOutlet weak var restartMenuItem: NSMenuItem!

    @IBAction func settingsClicked(_ sender: Any) {
        preferencesWindow?.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func onClickCustomizeViewMenu(_ sender: Any) {

        guard let menuItem = sender as? NSMenuItem, let menuIdentifier = menuItem.identifier else { return }

        var layout = WebdavLayout.viewYearMonthDay
        
        switch menuIdentifier.rawValue {
            case "menuYear": layout = .viewYear
            case "menuYearMonth": layout = .viewYearMonth
            case "menuYearMonthDay": layout = .viewYearMonthDay
            default: break
        }

        DDLogInfo("Check layout to :\(layout)")

        lomodService.setWebDAVLayout(layout: layout)

        let mountDir = "/tmp/Lomorage"
        var succ = true
        if !FileManager.default.fileExists(atPath: mountDir) {
            do {
                try FileManager.default.createDirectory(atPath: mountDir, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                DDLogError("Unable to create directory \(error.debugDescription)")
                succ = false
            }
        }

        guard succ else {
            return
        }

        let task = Process()
        task.launchPath = "/sbin/mount_webdav"
        task.arguments = ["http://127.0.0.1:8004/", mountDir]
        task.launch()
        task.waitUntilExit()

        NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: mountDir)])
    }

    @IBAction func usersClicked(_ sender: Any) {
        userWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func importClicked(_ sender: Any) {
        let lomoWebPort = String(UserDefaults.standard.integer(forKey: PREF_LOMOD_PORT))
        if let url = URL(string: "http://" + listenIp + ":" + lomoWebPort) {
            NSWorkspace.shared.open(url)
        } else {
            DDLogError("Error openning lomo-web url")
        }
    }

    @IBAction func aboutClicked(_ sender: Any) {
        aboutWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    fileprivate func doExit() {
        stopLomoService()
        NotificationCenter.default.removeObserver(self)
        stateReaptingTimer.suspend()
        pingReaptingTimer.suspend()
        updateTimer.invalidate()
        NSApplication.shared.terminate(self)
    }

    @IBAction func quitClicked(_ sender: Any) {
        if dialogOKCancel(message: quitApp, info: "") {
            doExit()
        }
    }

    @IBAction func restartClicked(_ sender: NSMenuItem) {
        sender.isEnabled = false
        stopLomoService()
        startLomoService()
        sender.isEnabled = true
    }

    @objc func onStart(_ notification: Notification) {
        killLomoService()
        startLomoService()
        update()
    }

    @objc func onExit(_ notification: Notification) {
        doExit()
    }

    @objc func onSettingsChanged(_ notification: Notification) {
        stopLomoService()
        startLomoService()
    }

    override func awakeFromNib() {
        // Insert code here to initialize your application
        let icon = NSImage(named: "statusIcon")
        statusItem.image = icon
        statusItem.menu = statusMenu

        preferencesWindow = PreferencesWindow()
        userWindow = UserWindow()
        aboutWindow = AboutWindow()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onSettingsChanged(_:)),
                                               name: .NotifySettingsChanged,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onStart(_:)),
                                               name: .NotifyStart,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onExit(_:)),
                                               name: .NotifyExit,
                                               object: nil)

        stateReaptingTimer.eventHandler = checkLomodState
        pingReaptingTimer.eventHandler = pingLomod
        stateReaptingTimer.resume()
        pingReaptingTimer.resume()

        scheduleAutoUpdate()

        lomodService = getLomodService()

        DispatchQueue.global().async {
            NotificationCenter.default.post(name: .NotifyStart, object: self)
        }
    }

    func getSecondsOffsetTo(hour: Int, minute: Int) -> Int {
        let today = Date()
        var calendar = Calendar.current
        calendar.timeZone = .current
        let components = calendar.dateComponents([.hour, .minute, .second], from: today)

        let secondsSinceToday = components.hour! * 60 * 60 + components.minute! * 60 + components.second!
        let targetSeconds = hour * 60 * 60 + minute * 60
        if targetSeconds > secondsSinceToday {
            return targetSeconds - secondsSinceToday
        } else {
            return 24 * 60 * 60 + targetSeconds - secondsSinceToday
        }
    }

    func scheduleAutoUpdate() {
        let offset = getSecondsOffsetTo(hour: StatusMenuController.autoUpdateHour, minute: StatusMenuController.autoUpdateMinute)

        updateTimer = Timer.scheduledTimer(timeInterval: Double(offset), target: self, selector: #selector(pingLomod), userInfo: nil, repeats: false)
    }

    func autoUpdate() {
        update()
        scheduleAutoUpdate()
    }

    @objc func checkLomodState() {
        if let task = lomodTask, task.isRunning {
            if lomodService.getSystemInfo() != nil {
                restartMenuItem.image = NSImage(named: NSImage.statusAvailableName)
            } else {
                restartMenuItem.image = NSImage(named: NSImage.statusPartiallyAvailableName)
            }
        } else {
            restartMenuItem.image = NSImage(named: NSImage.statusUnavailableName)
            if lomodTask != nil {
                stopLomoService()
            }
        }
    }

    @objc func pingLomod() {
        lomodService.checkServerStatus { (systemInfo, connectErr) in
            if connectErr == nil {
                DDLogError("pingLomod succ!")
                self.pingTimeout = Date(timeIntervalSinceNow: StatusMenuController.pingTimeoutSec)

                DispatchQueue.main.async {
                    self.lomodService.getUserList()
                }

                if let info = systemInfo, info.systemStatus <= 0, !self.guideUrlPoped {
                    let preferredLang = getPerferredLangWithoutRegionAndScript()
                    var url = URL(string: "https://lomosw.lomorage.com/en/index.html")
                    if preferredLang == "zh" {
                        url = URL(string: "https://lomosw.lomorage.com/zh/index.html")
                    }
                    NSWorkspace.shared.open(url!)
                    self.guideUrlPoped = true
                }

                if let ipList = self.lomodService.getListenIPs() {
                    if let firstIp = ipList.first, firstIp != self.listenIp {
                        self.listenIp = firstIp
                        NotificationCenter.default.post(name: .NotifyIpChanged, object: self)
                    }
                }
            } else {
                DDLogError("pingLomod error!")
                if Date() >= self.pingTimeout && UserDefaults.standard.string(forKey: PREF_HOME_DIR) != nil {
                    DispatchQueue.main.async {
                        if let prefWindow = self.preferencesWindow,
                           prefWindow.userTipsLabel.stringValue != userTipsReportIssue{
                            prefWindow.showWindow(nil)
                            prefWindow.userTipsLabel.textColor = .red
                            prefWindow.userTipsLabel.stringValue = userTipsReportIssue
                            if let logDir = getLogDir() {
                                NSWorkspace.shared.open(URL(fileURLWithPath: logDir))
                            }
                            NSApp.activate(ignoringOtherApps: true)
                        }
                    }
                }
            }
        }
    }

    fileprivate func showWindowToSetHomeDir() {
        DispatchQueue.main.async {
            if let prefWindow = self.preferencesWindow {
                prefWindow.showWindow(nil)
                prefWindow.userTipsLabel.textColor = .red
                prefWindow.userTipsLabel.stringValue = userTipsConfigureHomeDirAndWaitStart
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func startLomod() {
        guard lomodTask == nil else {
            DDLogInfo("lomod already started!")
            return
        }

        lomodTask = Process()
        if let task = lomodTask,
           let executablePath = Bundle.main.executableURL?.deletingLastPathComponent() {
            let lomodPath = executablePath.path + "/lomod"
            DDLogInfo("lomod Path: \(lomodPath)")

            UserDefaults.standard.set(UUID().uuidString, forKey: PREF_ADMIN_TOKEN)

            if let homeDir = UserDefaults.standard.string(forKey: PREF_HOME_DIR),
                let baseDir = getBasePath(),
                let logDir = getLogDir(),
                let port = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT),
                let uuid = UserDefaults.standard.string(forKey: PREF_ADMIN_TOKEN) {

                DDLogInfo("Home Dir: \(homeDir)")
                DDLogInfo("Base Dir: \(baseDir)")
                DDLogInfo("Log Dir: \(logDir)")

                task.launchPath = lomodPath
                task.arguments = ["--mount-dir", homeDir,
                                  "--base", baseDir,
                                  "--log-dir", logDir,
                                  "--port", port,
                                  "--admin-token", uuid,
                                  "--exe-dir", executablePath.path + "/"]
                if UserDefaults.standard.bool(forKey: PREF_DEBUG_MODE) {
                    task.arguments?.append("--debug")
                }

                DDLogInfo("lomod args: \(task.arguments)")
                task.launch()

                DDLogInfo("lomod is running: \(task.isRunning), pid = \(task.processIdentifier)")

                if task.isRunning {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.pingLomod()
                    }
                }
            } else {
                DDLogError("Need set home directory first")
                lomodTask = nil
                showWindowToSetHomeDir()
            }
        }
    }

    func startLomoService() {
        startLomod()
    }

    func stopLomod() {
        if let task = lomodTask, task.isRunning {
            DDLogInfo("lomod terminate, pid = \(task.processIdentifier)")
            task.terminate()
        } else if lomodTask != nil {
            DDLogError("lomod already terminate with error \(String(describing: lomodTask!.terminationReason))")
        }
        lomodTask = nil
    }

    func stopLomoService() {
        stopLomod()
    }

    func killLomoService() {
        let p = Process.launchedProcess(launchPath: "/usr/bin/killall", arguments: ["lomod"])
        p.waitUntilExit()
    }

    @objc func update() {
        updateQueue.async {
            self.lomoUpdate.update()
        }
    }
}
