//
//  AppDelegate.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 3/5/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa
import CocoaLumberjack
import CrashReporter

let launcherAppId = "lomoware.lomorage.LomoAgentLauncher"

class LogFormatter: NSObject, DDLogFormatter {
    let threadUnsafeDateFormatter: DateFormatter

    override init() {
        threadUnsafeDateFormatter = DateFormatter()
        threadUnsafeDateFormatter.formatterBehavior = .behavior10_4
        threadUnsafeDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss:SSS"

        super.init()
    }

    func format(message logMessage: DDLogMessage) -> String? {
        let dateAndTime = threadUnsafeDateFormatter.string(from: logMessage.timestamp)

        var logLevel: String
        let logFlag = logMessage.flag
        if logFlag.contains(.error) {
            logLevel = "E"
        } else if logFlag.contains(.warning){
            logLevel = "W"
        } else if logFlag.contains(.info) {
            logLevel = "I"
        } else if logFlag.contains(.debug) {
            logLevel = "D"
        } else if logFlag.contains(.verbose) {
            logLevel = "V"
        } else {
            logLevel = "?"
        }

        let formattedLog = "\(dateAndTime) [\(logMessage.threadID)] |\(logLevel)| [\(logMessage.fileName) \(logMessage.function ?? "nil")] #\(logMessage.line): \(logMessage.message)"

        return formattedLog;
    }
}

func setupSigHandler() {
    signal(SIGTERM) { signal in
        DDLogInfo("Interrupted! Cleaning up...")
        NotificationCenter.default.post(name: .NotifyExit, object: nil)
    }
}

func getLomodService() -> LomodService? {
    guard let appDelegate = NSApplication.shared.delegate as? AppDelegate else {
        DDLogError("getLomodService, error when getting AppDelegate")
        return nil
    }

    return appDelegate.lomodService
}

extension Notification.Name {
    static let killLauncher = Notification.Name("killLauncher")
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let lomodService = LomodService()

    private var fileLogger: DDFileLogger!

    internal var isDebuggerAttached: Bool {
      var info = kinfo_proc()
      var mib : [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
      var size = MemoryLayout<kinfo_proc>.stride
      let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
      assert(junk == 0, "sysctl failed")
      return (info.kp_proc.p_flag & P_TRACED) != 0
    }

    func setFileLoggerLevel(_ loglevel: DDLogLevel) {
        DDLogInfo("set log level to: \(loglevel.rawValue)")
        DDLog.remove(fileLogger)
        DDLog.add(fileLogger, with: loglevel)
        DDLog.remove(DDASLLogger.sharedInstance)
        DDLog.add(DDASLLogger.sharedInstance, with: loglevel)
    }

    func setupLogger() {
        // console app
        DDASLLogger.sharedInstance.logFormatter = LogFormatter()
        DDLog.add(DDASLLogger.sharedInstance, with: .info)

        let logFileManager = DDLogFileManagerDefault.init(logsDirectory: getLogDir())
        fileLogger = DDFileLogger.init(logFileManager: logFileManager)
        fileLogger.rollingFrequency = TimeInterval(60*60*24)
        fileLogger.logFileManager.maximumNumberOfLogFiles = 7
        fileLogger.maximumFileSize = 10*1024*1024
        fileLogger.logFileManager.logFilesDiskQuota = 50*1024*1024
        fileLogger.logFormatter = LogFormatter()
        DDLog.add(fileLogger, with: .warning)

        var logLevel = DDLogLevel.info;
        if UserDefaults.standard.bool(forKey: PREF_DEBUG_MODE) {
            logLevel = DDLogLevel.verbose;
        }
        setFileLoggerLevel(logLevel)

        DDLogInfo("logging to \(String(describing: fileLogger.logFileManager.logsDirectory))")
    }

    private func loadCrashLog() {
        // Try loading the crash report.
        let config = PLCrashReporterConfig(signalHandlerType: .mach, symbolicationStrategy: .all)
        guard let crashReporter = PLCrashReporter(configuration: config) else {
            DDLogWarn("Could not create an instance of PLCrashReporter")
            return
        }

        if crashReporter.hasPendingCrashReport() {
            do {
                let data = try crashReporter.loadPendingCrashReportDataAndReturnError()

                // Retrieving crash reporter data.
                let report = try PLCrashReport(data: data)

                // We could send the report from here, but we'll just print out some debugging info instead.
                if let text = PLCrashReportTextFormatter.stringValue(for: report, with: PLCrashReportTextFormatiOS) {
                    DDLogError("=============>CrashReport")
                    DDLogError(text)
                    DDLogError("CrashReport<=============")
                } else {
                    DDLogWarn("CrashReporter: can't convert report to text")
                }
            } catch let error {
                DDLogWarn("CrashReporter failed to load and parse with error: \(error)")
            }
        }

        // Purge the report.
        crashReporter.purgePendingCrashReport()
    }

    func applicationWillFinishLaunching(_ aNotification: Notification) {
        let version = Bundle.main.infoDictionary?["CFBundleVersion"] as! String
        let arguments = CommandLine.arguments
        var exit = false
        for arg in arguments {
            if arg == "--version" {
                print("\(version)")
                NotificationCenter.default.post(name: .NotifyExit, object: self)
                exit = true
                break
            }
        }

        // Uncomment and implement isDebuggerAttached to safely run this code with a debugger.
        // See: https://github.com/microsoft/plcrashreporter/blob/2dd862ce049e6f43feb355308dfc710f3af54c4d/Source/Crash%20Demo/main.m#L96
        if !isDebuggerAttached {
            // It is strongly recommended that local symbolication only be enabled for non-release builds.
            // Use [] for release versions.
            let config = PLCrashReporterConfig(signalHandlerType: .mach, symbolicationStrategy: .all)
            guard let crashReporter = PLCrashReporter(configuration: config) else {
                print("Could not create an instance of PLCrashReporter")
                return
            }

            // Enable the Crash Reporter.
            do {
                try crashReporter.enableAndReturnError()
            } catch let error {
                print("Warning: Could not enable crash reporter: \(error)")
            }
        }
        if !exit {
            setupLogger()
            loadCrashLog()
            DDLogInfo("LomoAgent version: \(version)")
            UserDefaults.standard.set(UUID().uuidString, forKey: PREF_ADMIN_TOKEN)
            // NotificationCenter.default.post(name: .NotifyStart, object: self)
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupSigHandler()
        let runningApps = NSWorkspace.shared.runningApplications
        let isRunning = !runningApps.filter { $0.bundleIdentifier == launcherAppId }.isEmpty

        if isRunning {
            DistributedNotificationCenter.default().post(
                name: .killLauncher,
                object: Bundle.main.bundleIdentifier!
            )
        }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
}

