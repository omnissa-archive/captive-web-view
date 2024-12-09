// Copyright 2023 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

import Foundation
#if !os(macOS)
import MobileCoreServices
#endif
import os.log

public extension CaptiveWebView.WebResource {
    
    static func findFile(under: URL = Bundle.main.bundleURL,
                         tailComponents: [String],
                         results: [String]? = nil
    ) -> URL?
    {
        guard let foundURL = findFileURL(
                under: under, tail: tailComponents
        ) else {
            return nil
        }

        let resolvedUnder = under.resolvingSymlinksInPath()

        // https://developer.apple.com/documentation/foundation/nsurl/1415965-resolvingsymlinksinpath
        // "If the name of the receiving path begins with /private, this
        // property strips off the /private designator, provided the
        // result is the name of an existing file."

        let underComponents = resolvedUnder.pathComponents
        let returnComponents = foundURL.resolvingSymlinksInPath().pathComponents
                
        var underIndex = underComponents.startIndex
        var returnIndex = returnComponents.startIndex
        while
            underIndex < underComponents.endIndex,
            returnIndex < returnComponents.endIndex
        {
            if underComponents[underIndex] ==
                returnComponents[returnIndex]
            {
                underComponents.formIndex(after: &underIndex)
                returnComponents.formIndex(after: &returnIndex)
            }
            else {
                break
            }
        }
                
        // URL(fileURLWithPath:relativeTo:) seems to be the only
        // constructor that results in a file URL with a base URL.
        //
        // If the first parameter is the empty string, the resulting URL
        // always has a "." component there. It can be removed by
        // standardizing but that also seems to remove the base URL, and
        // hence the relative path with be an absolute path.
        //
        // The code here solves that by constructing with the first of
        // the return components, then appending each of the rest.
        //
        // That can't be done if there are no components, i.e. if the
        // return path is the same as the `under` URL. In that case,
        // return a URL with a "." component; there's no alternative.

        if returnIndex >= returnComponents.endIndex {
            return URL(fileURLWithPath: "", relativeTo: resolvedUnder)
        }
        
        var returnURL = URL(
            fileURLWithPath: returnComponents[returnIndex],
            relativeTo: resolvedUnder)
        returnComponents[returnIndex.advanced(by: 1)...].forEach {
            returnURL.appendPathComponent($0)
        }
        return returnURL
    }
    
    // Constants for parameters that control the enumerator.
    //
    // Option not to enumerate sub-directory contents.
    static let skipDescendants:FileManager.DirectoryEnumerationOptions = [
        .skipsSubdirectoryDescendants]
    //
    // Resource key for the isDirectory check, as a Set for the enumerator, and
    // as an array for the resourceValues access.
    static let isDirectorySet = Set<URLResourceKey>([.isDirectoryKey])
    static let isDirectoryArray = Array(isDirectorySet)
    
    private static func findFileURL(
        under: URL, tail: [String]) -> URL?
    {
        let resolvedUnder = under.resolvingSymlinksInPath()

        // options:.producesRelativePathURLs would have saved all the code to
        // generate a relative path, below, but:
        //
        //   'producesRelativePathURLs' is only available in application
        //   extensions for iOS 13.0 or newer
        //
        // There are other enumeration options in FileManager. If this one stops
        // working, for example because of a tricky symbolic link situation,
        // then try one of the others.

        guard let pathEnumerator = FileManager.default.enumerator(
            at: resolvedUnder,
            includingPropertiesForKeys: isDirectoryArray,
            options: skipDescendants,
            errorHandler: nil
        ) else
        {
                return nil
        }
        
        // Sub-directories get accumulated here and then searched afterwards,
        // recursively, if the target isn't found here.
        // Some directories will never contain web resources, for example the
        // META-INF sub-directory, and could in theory be omitted from the
        // search. In practice however those directories aren't known at build
        // time. So instead the code accumulates all the sub-directories but
        // then sorts the array so that the unexpected ones are searched last.
        var directories:Array<URL> = []

        for case let pathURL as URL in pathEnumerator {
            let isDirectory:Bool = (
                try? pathURL.resourceValues(forKeys: isDirectorySet)
            )?.isDirectory ?? false
            if isDirectory {
                directories.append(pathURL)
                continue
            }

            let path = pathURL.pathComponents
            // First component will be "/" but that'll be the only / in there.

            // Check if the pathURL has the required tail components.
            var pathIndex = path.index(before: path.endIndex)
            var tailIndex = tail.index(before: tail.endIndex)
            while tailIndex >= tail.startIndex {
                if pathIndex < path.startIndex {
                    // Path ran out before matching everything.
                    break
                }
                if path[pathIndex] != tail[tailIndex] {
                    break
                }
                // This component matches; check the next one.
                path.formIndex(before: &pathIndex)
                tail.formIndex(before: &tailIndex)
            }

            if tailIndex < tail.startIndex {
                return pathURL
            }
        }
        
        // If the code reaches this point then the `under` URL has been
        // enumerated without finding the required file. Now try the
        // sub-directories, attempting to search those expected to contain web
        // resources first.
        
        directories.sort {
            // Sort by favour, then by lexicographic order.
            if favoured($0) {
                if !favoured($1) { return true }
            }
            else {
                if favoured($1) { return false }
            }
            return $0.absoluteString < $1.absoluteString
        }
        
        for directory in directories {
            guard let found = findFileURL(under: directory, tail: tail) else {
                continue
            }
            return found
        }
        
        return nil
    }
    
    // Returns false if the URL isn't expected to contain web resources, and
    // true otherwise.
    private static func favoured(_ url: URL) -> Bool {
        guard let lastComponent = url.pathComponents.last else {
            return true
        }
        if lastComponent == "META-INF"
            || lastComponent.hasSuffix(".lproj")
            || lastComponent.hasPrefix("_")
        {
            return false
        }
        return true
    }

    static func getMIMEType(_ fileURL:URL) throws -> String {
        // TOTH:
        // https://stackoverflow.com/questions/31243371/path-extension-and-mime-type-of-file-in-swift#comment80791976_40003309
        
        guard let fileExtension:CFString = fileURL.pathExtension as CFString? else {
            throw CaptiveWebViewError("No file extension in " +
                String(describing: fileURL))
        }
        
        guard let utiString = UTTypeCreatePreferredIdentifierForTag(
            kUTTagClassFilenameExtension, fileExtension, nil)?
            .takeRetainedValue() else
        {
            throw CaptiveWebViewError("Null type identifier")
        }
        
        // Following code to get the UTI seems nicer but relies on there being a
        // real file. This function is also called with a made-up URL, like
        // file:/body.json, to get a proper MIME type for JSON data.
        //
        //     let values = try fileURL.resourceValues(forKeys:[.typeIdentifierKey])
        //     guard let utiString:String = values.typeIdentifier else {
        //         throw CaptiveWebViewError("null type identifier")
        //     }

        guard let mimeType = UTTypeCopyPreferredTagWithClass(
            utiString, kUTTagClassMIMEType)?.takeRetainedValue() else
        {
            throw CaptiveWebViewError("Null MIME type")
        }
        
        return mimeType as String
    }
    
    static func bodyFrom(request:URLRequest) -> Dictionary<String, Any>? {
        guard let bodyData = request.httpBody else {
            return nil
        }

        let bodyObject: Any
        do {
            bodyObject = try JSONSerialization.jsonObject(
                with: bodyData,
                options: JSONSerialization.ReadingOptions.allowFragments)
        }
        catch {
            return nil
        }
        return bodyObject as? Dictionary<String, Any> 
    }
}
