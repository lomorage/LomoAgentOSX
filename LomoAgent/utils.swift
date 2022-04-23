//
//  utils.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 7/20/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Cocoa
import Foundation
import CocoaLumberjack
import CatCrypto

func dialogAlert(message: String, info: String)
{
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = info
    alert.alertStyle = NSAlert.Style.warning
    alert.addButton(withTitle: alertOk)
    alert.runModal()
}

func dialogOKCancel(message: String, info: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = info
    alert.alertStyle = .warning
    alert.addButton(withTitle: alertOk)
    alert.addButton(withTitle: alertCancel)
    return alert.runModal() == .alertFirstButtonReturn
}

func getBasePath() -> String? {
    let paths = NSSearchPathForDirectoriesInDomains(.applicationSupportDirectory, .userDomainMask, true)
    let basePath = NSURL(fileURLWithPath: paths[0]).appendingPathComponent("lomod")
    var baseDir: String? = basePath!.path
    if !FileManager.default.fileExists(atPath: basePath!.path) {
        do {
            try FileManager.default.createDirectory(atPath: basePath!.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            DDLogError("Unable to create directory \(error.debugDescription)")
            baseDir = nil
        }
    }

    return baseDir
}

func getLogDir() -> String? {
    let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
    let logPath = NSURL(fileURLWithPath: paths[0]).appendingPathComponent("Logs")?.appendingPathComponent("lomod")
    var logDir: String? = logPath!.path
    if !FileManager.default.fileExists(atPath: logPath!.path) {
        do {
            try FileManager.default.createDirectory(atPath: logPath!.path, withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            DDLogError("Unable to create directory \(error.debugDescription)")
            logDir = nil
        }
    }

    return logDir
}

protocol NetworkSession {
    func loadData(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void, sync group: DispatchGroup?)

    func uploadFile(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void)

    func uploadFile(with request: URLRequest, fromFile fileURL: URL) -> URLSessionTask

    func downloadFile(with request: URLRequest) -> URLSessionTask

    func reqData(with req: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void, sync group: DispatchGroup?)

    func cancelTasksById(id: Int)

    func stop()
}

extension URLSession: NetworkSession {
    func loadData(with url: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void, sync group: DispatchGroup?) {
        let task = dataTask(with: url) { data, response, error in
            completionHandler(data, response, error)
            group?.leave()
        }
        task.resume()
    }

    func reqData(with req: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void, sync group: DispatchGroup?) {
        let task = dataTask(with: req) { data, response, error in
            completionHandler(data, response, error)
            group?.leave()
        }
        task.resume()
    }

    func uploadFile(with request: URLRequest, fromFile fileURL: URL, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Swift.Void) {
        let task = uploadTask(with: request, fromFile: fileURL, completionHandler: completionHandler)
        task.resume()
    }

    func uploadFile(with request: URLRequest, fromFile fileURL: URL) -> URLSessionTask {
        let task = uploadTask(with: request, fromFile: fileURL)
        return task
    }

    func downloadFile(with request: URLRequest) -> URLSessionTask {
        let task = downloadTask(with: request)
        return task
    }

    private func cancelTasksByUrl(tasks: [URLSessionTask], url: String)
    {
        for task in tasks {
            if (task.currentRequest?.url?.description.starts(with: url))! {
                task.cancel()
            }
        }
    }

    func cancelTasksById(id: Int)
    {
        getTasksWithCompletionHandler {
            (dataTasks, uploadTasks, downloadTasks) -> Void in

            for task in dataTasks {
                if (task.taskIdentifier == id) {
                    //DDLogInfo("cancelTasksById in dataTasks: \(id)")
                    task.cancel()
                    return
                }
            }
            for task in uploadTasks {
                if (task.taskIdentifier == id) {
                    //DDLogInfo("cancelTasksById in uploadTasks: \(id)")
                    task.cancel()
                    return
                }
            }
            for task in downloadTasks {
                if (task.taskIdentifier == id) {
                    //DDLogInfo("cancelTasksById in downloadTasks: \(id)")
                    task.cancel()
                    return
                }
            }
        }
    }

    private func cancelTasks(tasks: [URLSessionTask])
    {
        for task in tasks {
            //DDLogInfo("cancelTasks: \(task.taskIdentifier)")
            task.cancel()
        }
    }

    func stop() {
        getTasksWithCompletionHandler {
            (dataTasks, uploadTasks, downloadTasks) -> Void in
            self.cancelTasks(tasks: dataTasks)
            self.cancelTasks(tasks: uploadTasks)
            self.cancelTasks(tasks: downloadTasks)
        }
    }
}

func runCommand(cmd : String, args : String...) -> (output: [String], error: [String], exitCode: Int32) {

    var output : [String] = []
    var error : [String] = []

    let task = Process()
    task.launchPath = cmd
    task.arguments = args

    let outpipe = Pipe()
    task.standardOutput = outpipe
    let errpipe = Pipe()
    task.standardError = errpipe

    task.launch()

    let outdata = outpipe.fileHandleForReading.readDataToEndOfFile()
    if var string = String(data: outdata, encoding: .utf8) {
        string = string.trimmingCharacters(in: .newlines)
        output = string.components(separatedBy: "\n")
    }

    let errdata = errpipe.fileHandleForReading.readDataToEndOfFile()
    if var string = String(data: errdata, encoding: .utf8) {
        string = string.trimmingCharacters(in: .newlines)
        error = string.components(separatedBy: "\n")
    }

    task.waitUntilExit()
    let status = task.terminationStatus

    return (output, error, status)
}

func getEncryptPassword(_ username: String, _ password: String) -> String? {
    let SALT_POSTFIX = "@lomorage.lomoware" // salt length need at least 8
    let argon2Crypto = CatArgon2Crypto()
    argon2Crypto.context.mode = .argon2id
    argon2Crypto.context.salt = username + SALT_POSTFIX
    let methodStart = Date()
    let hashResult = argon2Crypto.hash(password: password)
    let methodFinish = Date()
    let executionTime = methodFinish.timeIntervalSince(methodStart)
    DDLogInfo("getEncryptPassword time: \(executionTime)")
    guard hashResult.error == nil else {
        DDLogError("getEncryptPassword error: \(hashResult.error!.errorDescription!))")
        return nil
    }

    return hashResult.hexStringValue()
}

class Version {
    var year: Int
    var month: Int
    var day: Int
    var hour: Int
    var min: Int
    var sec: Int
    var hash: String

    init?(ver: String) {
        let items = ver.split(separator: ".")
        guard items.count == 4 else {
            return nil
        }
        let dateStrs =  items[0].split(separator: "_")
        guard dateStrs.count == 3 else {
            return nil
        }
        guard let y = Int(dateStrs[0]),
            let m = Int(dateStrs[1]),
            let d = Int(dateStrs[2]) else {
                return nil
        }
        guard m > 0 && m < 13 && d > 0 && d < 32 else {
            return nil
        }

        let timeStrs =  items[1].split(separator: "_")
        guard timeStrs.count == 3 else {
            return nil
        }
        guard let hour = Int(timeStrs[0]),
            let min = Int(timeStrs[1]),
            let sec = Int(timeStrs[2]) else {
                return nil
        }
        guard hour >= 0 && hour < 24
            && min >= 0 && min < 61
            && sec >= 0 && sec < 61 else {
                return nil
        }

        self.year = y
        self.month = m
        self.day = d
        self.hour = hour
        self.min = min
        self.sec = sec
        self.hash = String(items[3])
    }

    static func < (lhs: Version, rhs: Version) -> Bool {
        if lhs.year < rhs.year {
            return true
        } else if lhs.year > rhs.year {
            return false
        }

        if lhs.month < rhs.month {
            return true
        } else if lhs.month > rhs.month {
            return false
        }

        if lhs.day < rhs.day {
            return true
        } else if lhs.day > rhs.day {
            return false
        }

        if lhs.hour < rhs.hour {
            return true
        } else if lhs.hour > rhs.hour {
            return false
        }

        if lhs.min < rhs.min {
            return true
        } else if lhs.min > rhs.min {
            return false
        }

        if lhs.sec < rhs.sec {
            return true
        } else if lhs.sec > rhs.sec {
            return false
        }

        return false
    }
}

func getPerferredLangWithoutRegionAndScript() -> String {
    let items1 = Locale.current.identifier.split(separator: "_")
    let langWithoutRegion = String(items1.first!)
    let items2 = langWithoutRegion.split(separator: "-")
    return String(items2.first!)
}
