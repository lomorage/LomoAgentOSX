//
//  StatusMenuController.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 3/5/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa
import os.log

class StatusMenuController: NSObject {

    @IBOutlet weak var statusMenu: NSMenu!
    var settingsMenuItem: NSMenuItem!
    var preferencesWindow: PreferencesWindow!
    var aboutWindow: AboutWindow!
    var lomodTask: Process?
    var lomoWebTask: Process?
    var stateTimer: Timer!
    var pingTimer: Timer = Timer()
    var updateTimer: Timer = Timer()
    static let stateTimerIntervalSec = 1.0
    static let pingTimerIntervalSec = 30.0
    static let autoUpdateHour = 4
    static let autoUpdateMinute = 0

    var listenIp = ""

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let lomoUpdate = LomoUpgrade(url: LOMO_UPGRADE_URL)
    let updateQueue = DispatchQueue(label: "lomo.update")

    @IBOutlet weak var restartMenuItem: NSMenuItem!

    @IBAction func settingsClicked(_ sender: Any) {
        preferencesWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func importClicked(_ sender: Any) {
        let lomoWebPort = String(UserDefaults.standard.integer(forKey: PREF_LOMOD_PORT) + 1)
        if let url = URL(string: "http://" + listenIp + ":" + lomoWebPort) {
            NSWorkspace.shared.open(url)
        } else {
            os_log("Error openning lomo-web url", log: .logic, type: .error)
        }
    }

    @IBAction func aboutClicked(_ sender: Any) {
        aboutWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    fileprivate func doExit() {
        stopLomoService()
        NotificationCenter.default.removeObserver(self)
        stateTimer.invalidate()
        pingTimer.invalidate()
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

        stateTimer = Timer.scheduledTimer(timeInterval: StatusMenuController.stateTimerIntervalSec, target: self, selector: #selector(checkLomodState), userInfo: nil, repeats: true)
        pingTimer = Timer.scheduledTimer(timeInterval: StatusMenuController.pingTimerIntervalSec, target: self, selector: #selector(pingLomod), userInfo: nil, repeats: true)

        scheduleAutoUpdate()
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
            restartMenuItem.image = NSImage(named: NSImage.statusAvailableName)
        } else {
            restartMenuItem.image = NSImage(named: NSImage.statusUnavailableName)
            if lomodTask != nil {
                stopLomoService()
            }
        }
    }

    @objc func pingLomod() {
        if let lomodService = getLomodService() {
            let (_, err) = lomodService.checkServerStatus()
            if err == nil {
                lomodService.getUserList()
                if let backupDir = UserDefaults.standard.string(forKey: PREF_BACKUP_DIR) {
                    _ = lomodService.setRedundancyBackup(backupDisk: backupDir)
                }

                if let ipList = lomodService.getListenIPs() {
                    for ip in ipList {
                        if ip == listenIp {
                            return // still valid
                        }
                    }
                    // not found!
                    if let firstIp = ipList.first {
                        listenIp = firstIp
                        // need restart lomo-web
                        stopLomoWeb()
                        startLomoWeb()
                        NotificationCenter.default.post(name: .NotifyIpChanged, object: self)
                    }
                }
            } else {
                os_log("pingLomod error!", log: .logic, type: .error)
            }
        }
    }

    func startLomod() {
        guard lomodTask == nil else {
            os_log("lomod already started!")
            return
        }

        lomodTask = Process()
        if let task = lomodTask,
           let executablePath = Bundle.main.executableURL?.deletingLastPathComponent() {
            let lomodPath = executablePath.path + "/lomod"
            os_log("lomod Path: %{public}s", log: .logic, lomodPath)

            if let homeDir = UserDefaults.standard.string(forKey: PREF_HOME_DIR),
                let baseDir = getBasePath(),
                let logDir = getLogDir(),
                let port = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT) {

                os_log("Home Dir: %{public}s", log: .logic, homeDir)
                os_log("Base Dir: %{public}s", log: .logic, baseDir)
                os_log("Log Dir: %{public}s", log: .logic, logDir)

                task.launchPath = lomodPath
                task.arguments = ["--mount-dir", homeDir,
                                  "--base", baseDir,
                                  "--log-dir", logDir,
                                  "--port", port,
                                  "--exe-dir", executablePath.path + "/",
                                  "--no-mount"]
                if UserDefaults.standard.bool(forKey: PREF_DEBUG_MODE) {
                    task.arguments?.append("--debug")
                }
                task.launch()

                os_log("lomod is running: %d, pid = %d", log: .logic, task.isRunning, task.processIdentifier)

                if task.isRunning {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        self.pingLomod()
                    }
                }
            } else {
                os_log("Need set home directory first", log: .logic, type: .error)
                lomodTask = nil
                preferencesWindow.showWindow(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func startLomoWeb() {
        guard lomoWebTask == nil else {
            os_log("lomo-web already started!")
            return
        }

        lomoWebTask = Process()
        if let task = lomoWebTask,
           let executablePath = Bundle.main.executableURL?.deletingLastPathComponent() {
            let lomoWebPath = executablePath.path + "/lomo-web"
            os_log("lomo-web Path: %{public}s", log: .logic, lomoWebPath)

            if let lomodPort = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT) {
                let lomoWebPort = UserDefaults.standard.integer(forKey: PREF_LOMOD_PORT) + 1
                task.launchPath = lomoWebPath
                task.arguments = ["--baseport", lomodPort,
                                  "--port", String(lomoWebPort)]
                task.launch()

                os_log("lomo-web is running: %d, pid = %d", log: .logic, task.isRunning, task.processIdentifier)
            } else {
                os_log("Need set Lomorage service port first", log: .logic, type: .error)
                lomoWebTask = nil
                preferencesWindow.showWindow(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func startLomoService() {
        startLomod()
        startLomoWeb()
    }

    func stopLomod() {
        if let task = lomodTask, task.isRunning {
            os_log("lomod terminate, pid = %d", log: .ui, task.processIdentifier)
            task.terminate()
        } else if lomodTask != nil {
            os_log("lomod already terminate with error: %{public}s", log: .logic, type: .error)
        }
        lomodTask = nil
    }

    func stopLomoWeb() {
        if let task = lomoWebTask, task.isRunning {
            os_log("lomo-web terminate, pid = %d", log: .ui, task.processIdentifier)
            task.terminate()
        } else if lomoWebTask != nil {
            os_log("lomo-web already terminate with error: %{public}s", log: .logic, type: .error)
        }
        lomoWebTask = nil
    }

    func stopLomoService() {
        stopLomoWeb()
        stopLomod()
    }

    func killLomoService() {
        var p = Process.launchedProcess(launchPath: "/usr/bin/killall", arguments: ["lomod"])
        p.waitUntilExit()

        p = Process.launchedProcess(launchPath: "/usr/bin/killall", arguments: ["lomo-web"])
        p.waitUntilExit()
    }

    @objc func update() {
        updateQueue.async {
            self.lomoUpdate.update()
        }
    }
}
