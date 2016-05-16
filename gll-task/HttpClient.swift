//
//  HttpClient.swift
//  gll-task
//
//  Created by Rostyslav Kobizsky on 5/15/16.
//  Copyright © 2016 Rostyslav Kobizsky. All rights reserved.
//

import Foundation
import MobileCoreServices

protocol MultipartFormData {
    func appendPart(fileData: NSData, name: String, fileName: String, mimeType: String)
    func appendPart(fileURL: NSURL, name: String) -> Bool
    func append(parameters: [String: String])

}

extension NSMutableData: MultipartFormData {
    
    private struct AssociatedKeys {
        static var boundary = "boundary"
    }
    
    //this lets us check to see if the item is supposed to be displayed or not
    private var boundary : String {
        get {
            guard let boundary = objc_getAssociatedObject(self, &AssociatedKeys.boundary) as? String else {
                let newBoundary = generateBoundaryString()
                
                objc_setAssociatedObject(self, &AssociatedKeys.boundary, newBoundary, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
                
                return newBoundary
            }
            return boundary
        }
        
        set(value) { }
    }
    
    private func generateBoundaryString() -> String {
        return "Boundary-\(NSUUID().UUIDString)"
    }
    
    private func appendString(string: String) {
        let data = string.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: true)
        appendData(data!)
    }
    
    func appendPart(fileData: NSData, name: String, fileName: String, mimeType: String) {
        self.appendString("--\(boundary)\r\n")
        self.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName)\"\r\n")
        self.appendString("Content-Type: \(mimeType)\r\n\r\n")
        self.appendData(fileData)
        self.appendString("\r\n")
    }
    
    func appendPart(fileURL: NSURL, name: String) -> Bool {
        
        let fileName = fileURL.lastPathComponent
        
        guard let data = try? NSData(contentsOfFile: fileURL.path!, options: NSDataReadingOptions()) else {
            return false
        }
        
        let mimetype = mimeTypeForPath(fileURL.path!)
        
        self.appendString("--\(boundary)\r\n")
        self.appendString("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(fileName!)\"\r\n")
        self.appendString("Content-Type: \(mimetype)\r\n\r\n")
        self.appendData(data)
        self.appendString("\r\n")
        
        return true
    }
    
    func append(parameters: [String: String]) {
        for (key, value) in parameters {
            self.appendString("--\(boundary)\r\n")
            self.appendString("Content-Disposition: form-data; name=\"\(key)\"\r\n\r\n")
            self.appendString("\(value)\r\n")
        }
    }
    
    func closeBody() {
        appendString("--\(boundary)--\r\n")
    }
    
    func mimeTypeForPath(path: String) -> String {
        let url = NSURL(fileURLWithPath: path)
        let pathExtension = url.pathExtension
        
        if let uti = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension! as NSString, nil)?.takeRetainedValue() {
            if let mimetype = UTTypeCopyPreferredTagWithClass(uti, kUTTagClassMIMEType)?.takeRetainedValue() {
                return mimetype as String
            }
        }
        return "application/octet-stream"
    }
}

class HttpClient: NSObject, NSURLSessionDelegate {
    
    enum Method: Int, CustomStringConvertible {
        case POST
        case GET
        case PUT
        case DELETE
        
        var description: String {
            switch self {
            case .POST:
                return "POST"
            case .GET:
                return "GET"
            case .PUT:
                return "PUT"
            case .DELETE:
                return "DELETE"
            }
        }
        static var count: Int { return Method.DELETE.rawValue + 1}
    }
    
    lazy var queue: NSOperationQueue = {
        let queue = NSOperationQueue()
        queue.name = "com.HttpClient.queue"
        queue.maxConcurrentOperationCount = 3
        return queue
    } ()
    
    lazy var session: NSURLSession = {
        return NSURLSession(configuration: NSURLSessionConfiguration.defaultSessionConfiguration(), delegate: self, delegateQueue: self.queue)
    } ()
    
    

    
    var baseURL: NSURL
    init(baseURL: NSURL) {
        self.baseURL = baseURL
        super.init()
    }
    
    func post(path: String?, data: NSData? = nil, parameters: [String: String]? = nil,
                headers: [String: String]? = nil,
                completion: (NSData?, NSURLResponse?, NSError?) -> Void)
    {
        request(method: .POST,
                data: data,
                path: path,
                parameters: parameters,
                headers: headers,
                completion: completion)
    }
    func get(path: String?, data: NSData? = nil, parameters: [String: String]? = nil,
                headers: [String: String]? = nil,
                completion: (NSData?, NSURLResponse?, NSError?) -> Void)
    {
        request(method: .GET,
                data: data,
                path: path,
                parameters: parameters,
                headers: headers,
                completion: completion)
    }
    func put(path: String?, data: NSData? = nil, parameters: [String: String]? = nil,
                headers: [String: String]? = nil,
                completion: (NSData?, NSURLResponse?, NSError?) -> Void)
    {
        request(method: .PUT,
                data: data,
                path: path,
                parameters: parameters,
                headers: headers,
                completion: completion)
    }
    func delete(path: String?, data: NSData? = nil, parameters: [String: String]? = nil,
                headers: [String: String]? = nil,
                completion: (NSData?, NSURLResponse?, NSError?) -> Void)
    {
        request(method: .DELETE,
                data: data,
                path: path,
                parameters: parameters,
                headers: headers,
                completion: completion)
    }
    
    func multipartRequest(method method: Method = .POST,
                                 multipart: ((MultipartFormData) -> Void),
                                 path: String?,
                                 parameters: [String: String]? = nil,
                                 headers: [String: String]? = nil,
                                 cachePolicy: NSURLRequestCachePolicy = .ReloadIgnoringLocalCacheData,
                                 timeoutInterval: NSTimeInterval = 30,
                                 completion: (NSData?, NSURLResponse?, NSError?) -> Void)
    {
        let components = NSURLComponents(URL: baseURL, resolvingAgainstBaseURL: true)!
        components.path = path
        let request = NSMutableURLRequest(URL: components.URL!,
                                          cachePolicy: cachePolicy,
                                          timeoutInterval: timeoutInterval)
        request.HTTPMethod = method.description
        
        let body = NSMutableData()
        request.setValue("multipart/form-data; boundary=\(body.boundary)", forHTTPHeaderField: "Content-Type")
        if parameters != nil {
            body.append(parameters!)
        }
        multipart(body)
        body.closeBody()
        request.HTTPBody = body
        
        if (headers != nil) {
            for (key, value) in headers! {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        NSLog("\(request)")
        let task = session.dataTaskWithRequest(request, completionHandler: completion)
        task.resume()

    }
    
    func request(method method: Method = .GET,
                 data: NSData? = nil,
                 path: String?,
                 parameters: [String: String]? = nil,
                 headers: [String: String]? = nil,
                 cachePolicy: NSURLRequestCachePolicy = .ReloadIgnoringLocalCacheData,
                 timeoutInterval: NSTimeInterval = 30,
                 completion: (NSData?, NSURLResponse?, NSError?) -> Void)
    {
        let components = NSURLComponents(URL: baseURL, resolvingAgainstBaseURL: true)!
        components.path = path
        if let queryParams = parameters {
            var queryItems = [NSURLQueryItem]()
            for (key, value) in queryParams {
                queryItems.append(NSURLQueryItem(name: key, value: value))
            }
            components.queryItems = queryItems
        }
        
        let request = NSMutableURLRequest(URL: components.URL!,
                                          cachePolicy: cachePolicy,
                                          timeoutInterval: timeoutInterval)
        request.HTTPMethod = method.description
        
        if (data != nil) {
            request.HTTPBody = data
            request.setValue(String(data!.length), forHTTPHeaderField: "Content-Length")
        }
        
        if (headers != nil) {
            for (key, value) in headers! {
                request.addValue(value, forHTTPHeaderField: key)
            }
        }
        NSLog("\(request)")
        let task = session.dataTaskWithRequest(request, completionHandler: completion)
        task.resume()
    }
}