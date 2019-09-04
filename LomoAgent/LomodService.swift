//
//  LomodService.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 7/21/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Foundation
import os.log

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
    var listenIPs = [String]()
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

class LomodService
{
    private var networkSession: NetworkSession!

    private var members = [Member]()

    private var systemInfo: SystemInfo?

    private(set) public var finalBackupTime: String = ""

    init() {
        let defaultConfiguration = URLSessionConfiguration.default
        defaultConfiguration.allowsCellularAccess = false
        defaultConfiguration.timeoutIntervalForRequest = 20
        networkSession = URLSession(configuration: defaultConfiguration)
    }

    func setRedundancyBackup(backupDisk: String) -> Bool {
        guard backupDisk != "" else {
            os_log("setRedundancyBackup, backupDisk empty", log: .logic, type: .error)
            return false
        }
        if members.count > 0 {
            var allSucc = true
            for m in members {
                if m.backupDir != backupDisk {
                    let succ = setRedundancyBackup(username: m.userName, backupDisk: backupDisk)
                    if !succ {
                        allSucc = false
                    }
                }
            }

            if !allSucc {
                dialogAlert(message: setBackupDirFailedLocalized, info: "")
            }
            return allSucc
        } else {
            os_log("setRedundancyBackup, no members ready yet, will retry later", log: .logic, type: .error)
            return false
        }
    }

    func setRedundancyBackup(username: String, backupDisk: String) -> Bool {
        guard backupDisk != "" else {
            os_log("setRedundancyBackup, backupDisk empty", log: .logic, type: .error)
            return false
        }
        let port = UserDefaults.standard.string(forKey: PREF_PORT)
        guard port != nil else {
            os_log("setRedundancyBackup, port not ready yet", log: .logic, type: .error)
            return false
        }

        var ret = false
        os_log("setRedundancyBackup for %{public}s to %{public}s", log: .logic, username, backupDisk)

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
                        os_log("setRedundancyBackup, error: %{public}s", log: .logic, type: .error, error.localizedDescription)
                    } else if let httpresp = response as? HTTPURLResponse {
                        if httpresp.statusCode == 200 {
                            os_log("setRedundancyBackup for %{public}s succ", log: .logic, username)
                            ret = true
                        } else {
                            os_log("setRedundancyBackup, error: %{public}s", log: .logic, type: .error, String(describing: response))
                        }
                    } else {
                        os_log("setRedundancyBackup, error: %{public}s", log: .logic, type: .error, String(describing: response))
                    }
                }, sync: opGroup)
                opGroup.wait()
            } catch {
                os_log("setRedundancyBackup, failed: %{public}s", log: .logic, type: .error, error.localizedDescription)
            }
        }
        return ret
    }

    func getListenIPs() -> [String]? {
        return self.systemInfo?.listenIPs
    }

    func getUserList() {
        if let port = UserDefaults.standard.string(forKey: PREF_PORT) {
            if let url = URL(string: "http://\(LOCAL_HOST):\(port)/user") {
                let opGroup = DispatchGroup()
                opGroup.enter()
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
                }, sync: opGroup)
                opGroup.wait()
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

                                    if let listenIPs = jsonResult["ListenIPs"] as? [String] {
                                        for ip in listenIPs {
                                            self.systemInfo?.listenIPs.append(ip)
                                        }
                                    }

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

        return (systemInfo, networkError)
    }
}
