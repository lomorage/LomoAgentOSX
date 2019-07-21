//
//  utils.swift
//  LomoAgent
//
//  Created by Jiantao Fu on 7/20/19.
//  Copyright © 2019 lomoware. All rights reserved.
//

import Foundation

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
