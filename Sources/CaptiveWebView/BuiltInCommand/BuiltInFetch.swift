// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

import Foundation

private enum KEY: String {
    typealias RawValue = String
    
    // Common keys.
    case parameters
    
    // Keys used by `fetch` command.
    case resource, options, method, body, bodyObject, headers,
         status, statusText, message, text, json, ok,
         peerCertificate, DER, length, httpReturn
    case keys, type, value
}

// Convenience extension to facilitate use of the KEY enumeration as keys in a
// dictionary. TOTH for the setter:
// https://www.avanderlee.com/swift/custom-subscripts/#making-a-read-and-write-subscript
extension Dictionary where Key == String {
    fileprivate subscript(_ key:KEY) -> Value? {
        get { self[key.rawValue] }
        set { self[key.rawValue] = newValue }
    }
    
    @discardableResult fileprivate mutating func removeValue(
        forKey key: KEY
    ) -> Value?
    {
        return removeValue(forKey: key.rawValue)
    }

}

public extension CaptiveWebView.BuiltInCommand {
    static func builtInFetch(
        _ commandDictionary: [String:Any]
    ) throws -> [String:Any?]
    {
        return try builtInFetch(commandDictionary, nil)
    }
    
    // Utility function that can be called directly, even from macOS.
    static func builtInFetch(
        _ commandDictionary: [String:Any], _ cause:((NSError) -> Void)?
    ) throws -> [String:Any?]
    {
        let url:URL
        let options:[String:Any]?
        do {
            (url, options) = try parseFetchParameters(commandDictionary)
        }
        catch let fetchError as FetchError {
            if let nsError = fetchError.cause { cause?(nsError) }
            return fetchError.jsonAble(0)
        }
        
        let request:URLRequest
        do {
            request = try buildRequest(url, options)
        }
        catch let fetchError as FetchError {
            if let nsError = fetchError.cause { cause?(nsError) }
            return fetchError.jsonAble(0)
        }
        
        let fetchedData:Data?
        var details:[String:Any]
        do {
            (fetchedData, details) = try actualFetch(request)
        }
        catch let fetchError as FetchError {
            if let nsError = fetchError.cause { cause?(nsError) }
            return fetchError.jsonAble(2)
        }
        
        // -   If the HTTP request was OK but the JSON parsing failed,
        //     return the JSON exception.
        // -   If the HTTP request wasn't OK but the JSON parsing succeeded,
        //     the parsed object will be included in the details.
        //
        // Note that parseJSON always invokes the callback, even if it throws.
        let jsonException:FetchError?
        do {
            try parseJSON(fetchedData) {text, json in
                details[.text] = text
                details[.json] = json
            }
            jsonException = nil
        }
        catch  let fetchError as FetchError {
            if let nsError = fetchError.cause { cause?(nsError) }
            jsonException = fetchError
        }
        
        if details[.ok] as? Bool ?? false {
            if let jsonException = jsonException {
                // If JSON parsing failed, boost some details properties to
                // the top of the return object.
                let peerCertificate = details.removeValue(
                    forKey: .peerCertificate)
                let text = details.removeValue(forKey: .text)
                details.removeValue(forKey: .json)
                var return_ = jsonException.jsonAble(3)
                return_[.httpReturn] = details
                return_[.text] = text
                return_[.peerCertificate] = peerCertificate
                return return_
            }
        }
        return details
    }
}

private func parseFetchParameters(
    _ commandDictionary: [String:Any]
) throws -> (URL, [String:Any]?)
{
    guard let parameters = commandDictionary[.parameters] as? [String:Any]
    else {
        throw FetchError(
            "Fetch command had no `parameters` key, or its value"
            + " isn't type JSONObject.",
            dictionary: commandDictionary,
            missingKey: KEY.parameters
        )
    }
    guard let resource = parameters[.resource] as? String else {
        throw FetchError(
            "Fetch command parameters had no `resource` key, or its"
            + " value isn't type String.",
            dictionary: parameters,
            missingKey: KEY.resource
        )
    }
    guard let url = URL(string: resource) else {
        throw FetchError("Resource couldn't be parsed to a URL.")
            .appending(KEY.resource, resource)
    }

    return (url, parameters[.options] as? [String:Any])
}

private func buildRequest(
    _ url:URL, _ options:[String:Any]?
) throws -> URLRequest
{
    var request = URLRequest(url: url)
    
    guard let options = options else {return request}
    
    if let method = options[.method] as? String {
        request.httpMethod = method
    }
    if let body = options[.body] as? String {
        request.httpBody = body.data(using: .utf8)
        request.addValue(
            "application/json", forHTTPHeaderField: "Content-Type")
    }
    if let bodyObject = options[.bodyObject]
        as? Dictionary<String, Any>
    {
        var httpBody:Data
        guard JSONSerialization.isValidJSONObject(bodyObject) else {
            throw FetchError(
                "Fetch `bodyObject` isn't valid JSON.", [.value: bodyObject])
        }
        httpBody = try JSONSerialization.data(withJSONObject: bodyObject)
        httpBody.append(contentsOf: "\r\n\r\n".utf8)
        request.httpBody = httpBody
        request.addValue(
            "application/json", forHTTPHeaderField: "Content-Type")
    }
    if let headers = options[.headers] as? Dictionary<String, String>
    {
        for header in headers {
            request.addValue(
                header.value, forHTTPHeaderField: header.key)
        }
    }

    return request
}


class CertificateKeepingDelegate: NSObject, URLSessionDelegate {
    var peerSize: Int? = nil
    var peerBase64: String? = nil
                
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (
            URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // This `defer` statement will causes the default challenge handling to
        // take place after any guard else or at the end of the function.
        defer { completionHandler(.performDefaultHandling, nil) }

        // TOTH https://stackoverflow.com/a/34223292/7657675
        guard let trust = challenge.protectionSpace.serverTrust else { return }
        guard let peerCertificate =
                SecTrustGetCertificateAtIndex(trust, 0)
        else {
            return
        }
        
        // Check URLCredential class. TOTH.
        // https://stackoverflow.com/a/67618848/7657675

        let certificateData = SecCertificateCopyData(peerCertificate)
        let data = CFDataGetBytePtr(certificateData)
        let size = CFDataGetLength(certificateData)
        peerSize = size
        let cert1 = NSData(bytes: data, length: size)
        peerBase64 = cert1.base64EncodedString()
    }
    
}

private func actualFetch(_ request:URLRequest) throws -> (Data?, [String:Any]) {
    let certificateKeepingDelegate = CertificateKeepingDelegate()
    // Using the `ephemeral` session should cause the delegate challenge receiver
    // to be invoked every time. Other session types could cache the trust
    // result.
    let session = URLSession(
        configuration: URLSessionConfiguration.ephemeral,
        delegate: certificateKeepingDelegate,
        delegateQueue: nil
    )
    defer { session.finishTasksAndInvalidate() }

    var fetchedData:Data? = nil
    var httpResponse:HTTPURLResponse? = nil
    var fetchError:Error? = nil

    // TOTH synchronous HTTP request.
    // https://stackoverflow.com/a/64476948/7657675
    let group = DispatchGroup()
    group.enter()

    // Reference for the response object is here.
    // https://github.com/omnissa-archive/captive-web-view/blob/19-detailed-fetch-errors/documentation/reference.md#why-is-there-a-bridged-fetch-command-as-well-as-the-option-to-use-javascript-fetch
    let task = session.dataTask(with: request) {(data, response, error) in
        defer { group.leave() }
        fetchError = error
        httpResponse = response as? HTTPURLResponse
        fetchedData = data
    }
    task.resume()
    group.wait()

    
    // ToDo add something about this particular error.
    // -1103 Error Domain=NSURLErrorDomain Code=-1103 "resource exceeds maximum size"
    // See and TOTH https://stackoverflow.com/a/56973866/7657675

    if let nsError = fetchError as? NSError {
        throw FetchError(nsError)
    }
    
    // By now the delegate challenge receiver must have been invoked, if a
    // connection was made.
    
    var details:[String:Any] = [:]
    // iOS doesn't seem to make available the status text returned by the
    // server. Second best is to get a description looked up from the status
    // code.
    if let statusCode = httpResponse?.statusCode {
        details[.status] = statusCode
        details[.statusText] = HTTPURLResponse.localizedString(
            forStatusCode: statusCode)
        details[.ok] = statusCode >= 200 && statusCode < 300
    }
    else {
        details[.status] = nil
        details[.statusText] = nil
        details[.ok] = false
    }

    details[.headers] = httpResponse?.allHeaderFields.withStringKeys()
    // https://developer.apple.com/documentation/foundation/httpurlresponse

    var peerCertificate:[String:Any] = [:]
    peerCertificate[.DER] = certificateKeepingDelegate.peerBase64
    peerCertificate[.length] = certificateKeepingDelegate.peerSize
    
    details[.peerCertificate] = peerCertificate
    
    return (fetchedData, details)
}

private extension Dictionary where Key == AnyHashable {
    func withStringKeys() -> [String: Value] {
        return Dictionary<String, Value>(uniqueKeysWithValues: self.map {
            (String(describing:$0), $1)
        })
    }
}

private func parseJSON(
    _ data:Data?, _ callback:((String?, Any?) -> Void)) throws
{
    guard let data = data else {
        callback(nil, nil)
        return
    }
    let text = String(data: data, encoding: .utf8) ?? String(describing: data)
    let jsonAny:Any
    do {
        jsonAny = try JSONSerialization.jsonObject(
            with: data,
            options: JSONSerialization.ReadingOptions.allowFragments)
    }
    catch {
        // Not JSON format.
        callback(text, nil)
        // The error always is an NSError, Xcode says.
        throw FetchError(error as NSError)
    }
    
    guard let json:Any = jsonAny as? [String:Any] ?? jsonAny as? [Any] else {
        // JSON format but not of the required type.
        callback(text, nil)
        throw FetchError("Expected Object or Array.", [
            .type: String(describing: jsonAny), .value:text])
    }
    callback(text, json)
}
