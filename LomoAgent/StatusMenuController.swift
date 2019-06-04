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
    var stateTimer: Timer!

    let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    @IBOutlet weak var restartMenuItem: NSMenuItem!

    @IBAction func settingsClicked(_ sender: Any) {
        preferencesWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func aboutClicked(_ sender: Any) {
        aboutWindow.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @IBAction func quitClicked(_ sender: Any) {
        stopLomod()
        NotificationCenter.default.removeObserver(self)
        stateTimer.invalidate()
        NSApplication.shared.terminate(self)
    }

    @IBAction func restartClicked(_ sender: NSMenuItem) {
        sender.isEnabled = false
        stopLomod()
        startLomod()
        sender.isEnabled = true
    }

    @objc func onStart(_ notification: Notification) {
        killLomod()
        startLomod()
    }

    @objc func onExit(_ notification: Notification) {
        quitClicked(self)
    }

    @objc func onHomeDirChanged(_ notification: Notification) {
        stopLomod()
        startLomod()
    }

    override func awakeFromNib() {
        // Insert code here to initialize your application
        let icon = NSImage(named: "statusIcon")
        statusItem.image = icon
        statusItem.menu = statusMenu

        preferencesWindow = PreferencesWindow()
        aboutWindow = AboutWindow()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onHomeDirChanged(_:)),
                                               name: .NotifyHomeDirChanged,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onStart(_:)),
                                               name: .NotifyStart,
                                               object: nil)

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(onExit(_:)),
                                               name: .NotifyExit,
                                               object: nil)

        stateTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(checkLomodState), userInfo: nil, repeats: true)
    }

    @objc func checkLomodState() {
        if let task = lomodTask, task.isRunning {
            restartMenuItem.image = NSImage(named: NSImage.statusAvailableName)
        } else {
            restartMenuItem.image = NSImage(named: NSImage.statusUnavailableName)
            if lomodTask != nil {
                stopLomod()
            }
        }
    }

    func getBasePath() -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
        let basePath = NSURL(fileURLWithPath: paths[0]).appendingPathComponent("lomod")
        var baseDir: String? = basePath!.path
        if !FileManager.default.fileExists(atPath: basePath!.path) {
            do {
                try FileManager.default.createDirectory(atPath: basePath!.path, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                os_log("Unable to create directory %{public}s", log: .logic, type: .error, error.debugDescription)
                baseDir = nil
            }
        }

        return baseDir
    }

    func getLogPath() -> String? {
        let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
        let logPath = NSURL(fileURLWithPath: paths[0]).appendingPathComponent("Logs")?.appendingPathComponent("lomod")
        var logDir: String? = logPath!.path
        if !FileManager.default.fileExists(atPath: logPath!.path) {
            do {
                try FileManager.default.createDirectory(atPath: logPath!.path, withIntermediateDirectories: true, attributes: nil)
            } catch let error as NSError {
                os_log("Unable to create directory %{public}s", log: .logic, type: .error, error.debugDescription)
                logDir = nil
            }
        }

        return logDir
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
                let logDir = getLogPath(),
                let port = UserDefaults.standard.string(forKey: PREF_PORT) {

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
            } else {
                os_log("Need set home directory first", log: .logic, type: .error)
                lomodTask = nil
                preferencesWindow.showWindow(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
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

    func killLomod() {
        let p = Process.launchedProcess(launchPath: "/usr/bin/killall", arguments: ["lomod"])
        p.waitUntilExit()
    }
}
