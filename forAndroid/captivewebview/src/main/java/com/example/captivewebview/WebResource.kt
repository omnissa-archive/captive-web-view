// Copyright 2019 Omnissa, LLC.  
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import android.content.Context
import android.net.Uri
import android.webkit.MimeTypeMap
import android.webkit.WebResourceRequest
import android.webkit.WebResourceResponse
import java.io.File
import java.io.IOException
import java.io.InputStream
import java.lang.Exception
import java.nio.charset.Charset

class WebResource { companion object {
    private val htmlContentType = MimeTypeMap.
        getSingleton().getMimeTypeFromExtension("html")
//    private val utf8Charset = Charset.forName("UTF-8")

    private fun htmlStream(
        title: String, bodyDivs: String, charset: Charset = Charsets.UTF_8
    ) : InputStream
    {
        // ToDo HTML escape on title.
        return """<!DOCTYPE html>
            <html>
            <head>
            <style>
                body {font-family: sans-serif;}
            </style>
            <title>${title}</title>
            </head>
            <body
                ><h1>${title}</h1
                >${bodyDivs}</body>
            </html>""".
            trimIndent().byteInputStream(charset)
    }

    private fun preHTML(
        title: String, message: String, charset: Charset = Charsets.UTF_8
    ) : InputStream
    {
        return htmlStream(title, "<pre>${message}</pre>", charset)
    }

    private fun exceptionHTML(
        title: String, exception: Exception, charset: Charset = Charsets.UTF_8
    ) : InputStream
    {
        return htmlStream(title, "<div>${exception}</div>", charset)
    }

    fun assetResponse(
        request: WebResourceRequest, context: Context
    ) : WebResourceResponse
    {
        return assetResponse(request.url, context)
    }

    fun assetResponse(uri: Uri, context: Context) : WebResourceResponse {
        // It'd be nice to use Paths here but it's API level 26, which is too
        // high.
        // https://developer.android.com/reference/kotlin/java/nio/file/Paths
        // println("assetResponse \"${uri.path}\" ${uri.pathSegments}")

        val (assetStream, assetException) = this.getStream(uri, context)

        val extension: String =
            MimeTypeMap.getFileExtensionFromUrl(uri.toString())
        var contentType: String? =
            MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
        // TOTH
        // https://github.com/blackberry/BlackBerry-Dynamics-Android-Samples/blob/67463b625a25b9fa532e26c45acdcc12284c1090/AndroidWebView/application/src/main/java/com/example/jahawkins/webviewspike/LocalWebResource.java#L51
        if (contentType == null) {
            if (extension.equals("js", true)) {
                contentType = "application/javascript"
            }
            else if (extension.equals("json", true)) {
                contentType = "application/json"
            }
            else if (assetStream == null) {
                // No asset found, and no content type from the extension. Take
                // a punt and return an html error.
                contentType = htmlContentType
            }
        }

        val statusCode = if (assetException == null) 200 else 404
        val reasonPhrase = assetException?.toString() ?: "OK"

        return WebResourceResponse(
            contentType,
            null,
            statusCode,
            reasonPhrase,
            null,
            assetStream ?:
            if (contentType.equals(htmlContentType, true)) {
                exceptionHTML("Asset Exception", assetException!!)
            }
            else {
                object : InputStream() {
                    override fun read(): Int {
                        return -1
                    }
                }
            }
        )
    }

    fun findAsset(context: Context,
                  name:String = "main.json",
                  path:String = "",
                  results:MutableList<String> = mutableListOf()
    ) : MutableList<String>
    {
        // Following line is useful when debugging.
        // val list = context.assets.list(path)
        context.assets?.list(path)?.filter{listed -> !(
                listed == "webkit" || listed == "images" || listed == null)}
        ?.forEach {listed ->
            val listedPath = if (path == "") listed else "$path/$listed"
            if (listed == name) {
                results.add(listedPath)
            }
            findAsset(context, name, listedPath, results)
         }
        return results
    }

    private data class GetStreamReturn(
        val stream: InputStream?, val ioException: IOException?
    )

    private fun getStream(uri: Uri, context: Context): GetStreamReturn {
        val assetPath = uri.pathSegments.joinToString(File.separator)
        var assetException: IOException? = null
        val assetStream: InputStream? = try {
            context.assets.open(assetPath)
        } catch (exception: IOException) {
            assetException = exception
            null
        }

        if (assetStream == null) {
            val builtinPath =
                "library" + File.separator + uri.lastPathSegment
            val builtinStream = try {
                context.assets.open(builtinPath)
            } catch (exception: IOException) {
                null
            }
            if (builtinStream != null) {
                return GetStreamReturn(builtinStream, null)
            }
        }

        return GetStreamReturn(assetStream, assetException)
    }

    fun htmlErrorResponse(code: Int, message: String): WebResourceResponse {
        val stream = preHTML(code.toString(), message)
        val response = WebResourceResponse(
            htmlContentType, null, code, message, null, stream)
        return response
    }
}}