// Copyright 2020 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto

import android.os.Build
import org.json.JSONObject

import com.example.captivewebview.CauseIterator
import com.example.captivewebview.DefaultActivityMixIn
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import org.json.JSONArray
import java.security.*
import java.text.SimpleDateFormat
import java.util.*
import kotlin.Exception

object FancyDate {
    private val formats = listOf("dd", "MMM", "yyyy HH:MM", " z")

    operator fun invoke(date:Date, withZone:Boolean):String {
        return formats
            .filter { withZone || it.trim() != "z"}
            .map { SimpleDateFormat(it, Locale.getDefault()) }
            .map { it.format(date).run {
                if (it.toPattern() == "MMM") toLowerCase(Locale.getDefault())
                else this
            } }
            .joinToString("")
    }
}


class MainActivity: com.example.captivewebview.DefaultActivity() {
    // Android Studio warns that `ready` should start with a capital letter but
    // it shouldn't because it has to match what gets sent from the JS layer.
    private enum class Command {
        capabilities, deleteAll, encrypt, summariseStore,
        generateKey, generatePair, ready, UNKNOWN;

        companion object {
            fun matching(string: String?): Command? {
                return if (string == null) null
                else try { valueOf(string) }
                catch (exception: Exception) { UNKNOWN }
            }
        }
    }

    enum class KEY {
        parameters, alias, string,

        summary, services, algorithm, `class`, type,

        sentinel, ciphertext, decryptedSentinel, passed,

        testResults,

        AndroidKeyStore;

        override fun toString(): String {
            return this.name
        }
    }

    // Enables members of the KEY enumeration to be used as keys in mappings
    // from String to any, for example as mapOf() parameters.
    private infix fun <VALUE> KEY.to(that: VALUE): Pair<String, VALUE> {
        return this.name to that
    }

    private fun JSONObject.opt(key: KEY): Any? {
        return this.opt(key.name)
    }

    private fun JSONObject.put(key: KEY, value: Any?): JSONObject {
        return this.put(key.name, value)
    }

    // fun KeyStore.Companion.getInstance(key: KEY): KeyStore {
    //    return KeyStore.getInstance(key.name)
    // }
    // This'd be nice but Kotlin can't extend the companion of a Java class.
    // https://stackoverflow.com/questions/33911457/how-can-one-add-static-methods-to-java-classes-in-kotlin

    companion object {
        fun providersSummary():Map<String, Any> {
            val returning = mutableMapOf<String, Any>(
                "build" to mapOf(
                    "device" to Build.DEVICE,
                    "display" to Build.DISPLAY,
                    "manufacturer" to Build.MANUFACTURER,
                    "model" to Build.MODEL,
                    "brand" to Build.BRAND,
                    "product" to Build.PRODUCT,
                    "time" to FancyDate(Date(Build.TIME), false)
                ),
                "date" to FancyDate(Date(), true)
            )
            return Security.getProviders().map {
                it.name to it.toMap()
            }.toMap(returning)
        }

        fun providerSummay(providerName:String):Map<String, Any> {
            return Security.getProvider(providerName).run { mapOf(
                name to mapOf(
                    KEY.string to toString(),
                    KEY.summary to toMap(),
                    KEY.services to services.map { service -> mapOf(
                        KEY.algorithm to service.algorithm,
                        KEY.`class` to service.className,
                        KEY.type to service.type,
                        KEY.summary to service.toString()
                    )}
                )
            ) }
        }

    }

    override fun commandResponse(
        command: String?,
        jsonObject: JSONObject
    ): JSONObject {

        return when(Command.matching(command)) {
            Command.capabilities -> JSONObject(providersSummary())

            Command.deleteAll ->
                JSONObject(Json.encodeToString(StoredKey.deleteAll()))

            Command.encrypt -> {
                val parameters = jsonObject.opt(KEY.parameters) as? JSONObject
                    ?: throw Exception(listOf(
                        "Command `", Command.encrypt, "` requires `",
                        KEY.parameters, "`."
                    ).joinToString(""))
                val alias = parameters.opt(KEY.alias) as? String
                    ?: throw Exception(listOf(
                        "Command `", Command.encrypt, "` requires `",
                        KEY.parameters, "` with `", KEY.alias, "` element."
                    ).joinToString(""))
                val sentinel = parameters.opt(KEY.sentinel) as? String
                    ?: throw Exception(listOf(
                        "Command `", Command.encrypt, "` requires `",
                        KEY.parameters, "` with `", KEY.sentinel, "` element."
                    ).joinToString(""))

                jsonObject.put(KEY.testResults, testKey(alias, sentinel))
            }

            Command.summariseStore -> jsonObject.put(
                "keyStore",
                JSONArray(StoredKey.describeAll().map {
                    // Add an empty `storage` property, to be consistent with
                    // the iOS implementation, and remove the `type` property
                    // from the `key` sub-object. The `type` property is added
                    // by the kotlinx.serialization library, as a class
                    // discriminator. This code doesn't need a discriminator
                    // because the JSON never gets deserialised back.
                    JSONObject(Json.encodeToString(it))
                        .put("storage", "")
                        .also {
                            (it.get("key") as JSONObject).remove("type")
                        }
                })
            )

            Command.generateKey -> {
                val parameters = jsonObject.opt(KEY.parameters) as? JSONObject
                    ?: throw Exception(listOf(
                        "Command `", Command.encrypt, "` requires `",
                        KEY.parameters, "`."
                    ).joinToString(""))
                val alias = parameters.opt(KEY.alias) as? String
                    ?: throw Exception(listOf(
                        "Command `", Command.encrypt, "` requires `",
                        KEY.parameters, "` with `", KEY.alias, "` element."
                    ).joinToString(""))
                JSONObject(Json.encodeToString(
                    StoredKey.generateKeyWithName(alias)))
            }

            Command.generatePair -> {
                val parameters = jsonObject.opt(KEY.parameters) as? JSONObject
                    ?: throw Exception(listOf(
                        "Command `", Command.encrypt, "` requires `",
                        KEY.parameters, "`."
                    ).joinToString(""))
                val alias = parameters.opt(KEY.alias) as? String
                    ?: throw Exception(listOf(
                        "Command `", Command.encrypt, "` requires `",
                        KEY.parameters, "` with `", KEY.alias, "` element."
                    ).joinToString(""))
                JSONObject(Json.encodeToString(
                    StoredKey.generateKeyPairWithName(alias)))
            }

            Command.ready -> jsonObject

            else -> super.commandResponse(command, jsonObject)
        }
    }


    private fun testKey(alias: String, sentinel: String): JSONArray {
        val result = JSONArray(listOf(JSONObject(mapOf(
            "type" to StoredKey.describeKeyNamed(alias)
        ))))

        val encrypted = try {
            StoredKey.encryptWithStoredKey(sentinel, alias).also {
                result.put(
                    // The ciphertext could be 256 bytes, each represented as a
                    // number in JSON. It's a bit long to replace it with
                    // something shorter here.
                    JSONObject(Json.encodeToString(it))
                        .put(KEY.ciphertext, it.ciphertext.toString())
                )
            }
        }
        catch (exception: Exception) {
            val exceptions = JSONArray(CauseIterator(exception)
                .asSequence().map { it.toString() }.toList())
            result.put(JSONObject(mapOf(
                DefaultActivityMixIn.EXCEPTION_KEY to
                        if (exceptions.length() == 1) exceptions[0]
                        else exceptions)))
            return result
        }

        val decrypted = try {
            StoredKey.decryptWithStoredKey(encrypted, alias).also {
                result.put(JSONObject(mapOf(
                    KEY.decryptedSentinel to it,
                    KEY.passed to sentinel.equals(it)
                )))
            }
        }
        catch (exception: Exception) {
            val exceptions = JSONArray(CauseIterator(exception)
                .asSequence().map { it.toString() }.toList())
            result.put(JSONObject(mapOf(
                DefaultActivityMixIn.EXCEPTION_KEY to
                        if (exceptions.length() == 1) exceptions[0]
                        else exceptions)))
            return result
        }

        return result
    }
}
