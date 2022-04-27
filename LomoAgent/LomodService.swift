//
//  LomodService.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 7/21/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Foundation
import CocoaLumberjack

enum WebdavLayout: Int {
    case viewYearMonthDay = 0
    case viewYearMonth = 1
    case viewYear = 2
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
    var password: String!
}

class LomodService
{
    private var networkSession: NetworkSession!

    private(set) var members = [Member]()

    private var systemInfo: SystemInfo?

    private(set) public var finalBackupTime: String = ""

    init() {
        let defaultConfiguration = URLSessionConfiguration.default
        defaultConfiguration.allowsCellularAccess = false
        defaultConfiguration.timeoutIntervalForRequest = 20
        networkSession = URLSession(configuration: defaultConfiguration)
    }

    func setRedundancyBackup(backupDisk: String) -> Bool {
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
            DDLogError("setRedundancyBackup, no members ready yet, will retry later")
            return false
        }
    }

    func changePassword(for username: String, with password: String) -> Bool {
        DDLogInfo("changePassword for \(username)")
        let port = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT)
        guard port != nil else {
            DDLogError("changePassword, port not ready yet")
            return false
        }

        var ret = false;
        if let url = URL(string: "http://\(LOCAL_HOST):\(port!)/user"),
            let uuid = UserDefaults.standard.string(forKey: PREF_ADMIN_TOKEN) {
            var json = [String:Any]()
            json["Name"] = username
            json["Password"] = password

            do {
                let data = try JSONSerialization.data(withJSONObject: json, options: [])
                var urlRequest = URLRequest(url: url)
                urlRequest.httpMethod = "PUT"
                urlRequest.httpBody = data
                urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
                urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
                urlRequest.setValue("token=\(uuid)", forHTTPHeaderField: "Authorization")

                let opGroup = DispatchGroup()
                opGroup.enter()
                self.networkSession.reqData(with: urlRequest, completionHandler: { (data, response, error) in
                    if let error = error {
                        DDLogError("changePassword, error: \(error.localizedDescription)")
                    } else if let httpresp = response as? HTTPURLResponse {
                        if httpresp.statusCode == 200 {
                            DDLogInfo("changePassword for \(username) succ")
                            ret = true
                        } else {
                            DDLogError("changePassword, error: \(String(describing: response))")
                        }
                    } else {
                        DDLogError("changePassword, error: \(String(describing: response))")
                    }
                }, sync: opGroup)
                opGroup.wait()
            } catch {
                DDLogError("changePassword, failed: \(error.localizedDescription)")
            }
        } else {
            DDLogError("changePassword, failed")
        }
        return ret
    }

    func unsetRedundancyBackup() -> Bool {
        let port = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT)
        guard port != nil else {
            DDLogError("unsetRedundancyBackup, port not ready yet")
            return false
        }

        var ret = false
        DDLogInfo("unsetRedundancyBackup")

        if let adminToken = UserDefaults.standard.string(forKey: PREF_ADMIN_TOKEN),
           let url = URL(string: "http://\(LOCAL_HOST):\(port!)/system/backup") {
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "DELETE"
            urlRequest.setValue("token=\(adminToken)", forHTTPHeaderField: "Authorization")

            let opGroup = DispatchGroup()
            opGroup.enter()
            self.networkSession.reqData(with: urlRequest, completionHandler: { (data, response, error) in
                if let error = error {
                    DDLogError("unsetRedundancyBackup, error: \(error.localizedDescription)")
                } else if let httpresp = response as? HTTPURLResponse {
                    if httpresp.statusCode == 200 {
                        DDLogInfo("unsetRedundancyBackup succ")
                        ret = true
                    } else {
                        DDLogError("unsetRedundancyBackup, error: \(String(describing: response))")
                    }
                } else {
                    DDLogError("unsetRedundancyBackup, error: \(String(describing: response))")
                }
            }, sync: opGroup)
            opGroup.wait()
        } else {
            DDLogError("unsetRedundancyBackup, failed")
        }
        return ret
    }

    func setRedundancyBackup(username: String, backupDisk: String) -> Bool {
        let port = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT)
        guard port != nil else {
            DDLogError("setRedundancyBackup, port not ready yet")
            return false
        }

        var ret = false
        DDLogInfo("setRedundancyBackup for \(username) to \(backupDisk)")

        if let url = URL(string: "http://\(LOCAL_HOST):\(port!)/system/backup"),
            let uuid = UserDefaults.standard.string(forKey: PREF_ADMIN_TOKEN) {
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
                urlRequest.setValue("token=\(uuid)", forHTTPHeaderField: "Authorization")

                let opGroup = DispatchGroup()
                opGroup.enter()
                self.networkSession.reqData(with: urlRequest, completionHandler: { (data, response, error) in
                    if let error = error {
                        DDLogError("setRedundancyBackup, error: \(error.localizedDescription)")
                    } else if let httpresp = response as? HTTPURLResponse {
                        if httpresp.statusCode == 200 {
                            DDLogInfo("setRedundancyBackup for \(username) succ")
                            ret = true
                        } else {
                            DDLogError("setRedundancyBackup, error: \(String(describing: response))")
                        }
                    } else {
                        DDLogError("setRedundancyBackup, error: \(String(describing: response))")
                    }
                }, sync: opGroup)
                opGroup.wait()
            } catch {
                DDLogError("setRedundancyBackup, failed: \(error.localizedDescription)")
            }
        } else {
            DDLogError("setRedundancyBackup, failed")
        }
        return ret
    }

    func setWebDAVLayout(layout: WebdavLayout) -> Bool {
        let port = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT)
        guard port != nil else {
            DDLogError("setWebDAVLayout, port not ready yet")
            return false
        }

        var ret = false
        DDLogInfo("setWebDAVLayout to \(layout)")

        if let url = URL(string: "http://\(LOCAL_HOST):\(port!)/system/conf/webdav_layout/\(layout.rawValue)"),
            let uuid = UserDefaults.standard.string(forKey: PREF_ADMIN_TOKEN) {
            var urlRequest = URLRequest(url: url)
            urlRequest.httpMethod = "POST"
            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
            urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")
            urlRequest.setValue("token=\(uuid)", forHTTPHeaderField: "Authorization")

            let opGroup = DispatchGroup()
            opGroup.enter()
            self.networkSession.reqData(with: urlRequest, completionHandler: { (data, response, error) in
                if let error = error {
                    DDLogError("setWebDAVLayout, error: \(error.localizedDescription)")
                } else if let httpresp = response as? HTTPURLResponse {
                    if httpresp.statusCode == 200 {
                        DDLogInfo("setWebDAVLayout \(layout) succ")
                        ret = true
                    } else {
                        DDLogError("setWebDAVLayout, error: \(String(describing: response))")
                    }
                } else {
                    DDLogError("setWebDAVLayout, error: \(String(describing: response))")
                }
            }, sync: opGroup)
            opGroup.wait()
        } else {
            DDLogError("setWebDAVLayout, failed")
        }

        return ret
    }

    func getListenIPs() -> [String]? {
        return self.systemInfo?.listenIPs
    }

    func getUserList() {
        self.members.removeAll()
        if let port = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT),
            let uuid = UserDefaults.standard.string(forKey: PREF_ADMIN_TOKEN) {
            if let url = URL(string: "http://\(LOCAL_HOST):\(port)/user") {
                let opGroup = DispatchGroup()
                opGroup.enter()
                var urlRequest = URLRequest(url: url)
                urlRequest.setValue("token=\(uuid)", forHTTPHeaderField: "Authorization")
                networkSession.reqData(with: urlRequest, completionHandler: { (data, response, error) in
                    if let error = error {
                        DDLogError("fetchContactList, userList error: \(error.localizedDescription)")
                    } else if let data = data, let httpresp = response as? HTTPURLResponse {
                        if httpresp.statusCode == 200, let jsonResult = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            DDLogInfo("fetchContactList, json response:  \(jsonResult!)")

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
                            DDLogError("fetchContactList, userList error: \(String(data: data, encoding: .utf8)!)\n\(httpresp)")
                        }
                    } else {
                        DDLogError("fetchContactList, userList error: \(String(describing: response))" )
                    }
                }, sync: opGroup)
                opGroup.wait()
            }
        }
    }

    func checkServerStatus(completionHandler: @escaping (SystemInfo?, Error?) -> Swift.Void) {
        var networkError: Error?
        if let port = UserDefaults.standard.string(forKey: PREF_LOMOD_PORT) {
            if let url = URL(string: "http://\(LOCAL_HOST):\(port)/system"),
                let uuid = UserDefaults.standard.string(forKey: PREF_ADMIN_TOKEN){
                DDLogInfo("check server status: \(String(describing: url)), token: \(uuid)")
                var urlRequest = URLRequest(url: url)
                urlRequest.setValue("token=\(uuid)", forHTTPHeaderField: "Authorization")
                networkSession.reqData(with: urlRequest, completionHandler: { (data, response, error) in
                    if let error = error {
                        networkError = error
                        DDLogError("check server status error: \(error.localizedDescription)")
                    } else if let httpresp = response as? HTTPURLResponse,
                        httpresp.statusCode == 200 {
                        if let data = data {
                            do {
                                let jsonResult = try JSONSerialization.jsonObject(with: data) as! [String: Any]
                                DDLogInfo("check server status, json response:  \(jsonResult)")
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
                                                    DDLogError("checkServerStatus, wrong \"LastBackup\" format")
                                                }
                                            }
                                        }
                                    }
                                }
                            } catch let error as NSError {
                                DDLogError("Failed to load: \(error.localizedDescription), \(String(describing: data))")
                            }
                        } else {
                            DDLogError("checkServerStatus, not able to convert \(String(describing: data)) to String")
                        }
                    } else {
                        DDLogError("check server status failure: \(String(describing: response))")
                    }

                    completionHandler(self.systemInfo, networkError)
                }, sync: nil)
            }
        }
    }
}
