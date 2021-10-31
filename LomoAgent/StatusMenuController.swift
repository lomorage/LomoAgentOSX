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
    var preferencesWindow: PreferencesWindow!
    var userWindow: UserWindow!
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

                if let ipList = lomodService.getListenIPs() {
                    for ip in ipList {
                        if ip == listenIp {
                            return // still valid
                        }
                    }
                    // not found!
                    if let firstIp = ipList.first {
                        listenIp = firstIp
                        NotificationCenter.default.post(name: .NotifyIpChanged, object: self)
                    }
                }
            } else {
                DDLogError("pingLomod error!")
            }
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
                preferencesWindow.showWindow(nil)
                NSApp.activate(ignoringOtherApps: true)
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
