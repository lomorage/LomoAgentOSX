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
    var pipe: Pipe!
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
        NSApplication.shared.terminate(self)
    }

    @IBAction func restartClicked(_ sender: NSMenuItem) {
        sender.isEnabled = false
        stopLomod()
        startLomod()
        sender.isEnabled = true
    }

    override func awakeFromNib() {
        // Insert code here to initialize your application
        let icon = NSImage(named: "statusIcon")
        statusItem.image = icon
        statusItem.menu = statusMenu

        preferencesWindow = PreferencesWindow()
        aboutWindow = AboutWindow()

        killLomod()
        startLomod()
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
                let port = UserDefaults.standard.string(forKey: PREF_PORT) {

                os_log("Home Dir: %{public}s", log: .logic, homeDir)
                os_log("Base Dir: %{public}s", log: .logic, baseDir)

                task.launchPath = lomodPath
                task.arguments = ["--mount-dir", homeDir,
                                  "--base", baseDir,
                                  "--port", port,
                                  "--exe-dir", executablePath.path + "/",
                                  "--enable-mdns"]
                if UserDefaults.standard.bool(forKey: PREF_DEBUG_MODE) {
                    task.arguments?.append("--debug")
                }
                pipe = Pipe()
                task.standardOutput = pipe
                task.standardError = pipe
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
            let handle = pipe.fileHandleForReading
            let data = handle.readDataToEndOfFile()
            let output = String (data: data, encoding: String.Encoding.utf8)
            os_log("lomod already terminate with error: %{public}s", log: .logic, type: .error,  output!)
        }
        lomodTask = nil
    }

    func killLomod() {
        let p = Process.launchedProcess(launchPath: "/usr/bin/killall", arguments: ["lomod"])
        p.waitUntilExit()
    }
}
