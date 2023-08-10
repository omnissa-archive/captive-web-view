// Copyright 2023 VMware, Inc.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto

import com.example.captivecrypto.storedkey.StoredKey
import org.json.JSONObject

import com.example.captivewebview.CauseIterator
import com.example.captivewebview.opt
import com.example.captivewebview.put
import com.example.captivewebview.to
import kotlinx.serialization.ExperimentalSerializationApi
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.*
import org.json.JSONArray
import java.security.*
import java.util.*
import kotlin.Exception

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

    // These import statements at the top of the file make `KEY` constants
    // usable as JSONObject keys and as keys in `to` mappings.
    //
    //     import com.example.captivewebview.opt
    //     import com.example.captivewebview.put
    //     import com.example.captivewebview.to
    private enum class KEY {
        parameters, alias, failed, type,

        sentinel, ciphertext, decryptedSentinel, passed, storage,

        results;

        override fun toString(): String {
            return this.name
        }
    }

    companion object {
        // The kotlinx.serialization library doesn't seem to interface with the
        // native JSONObject class. This helper creates a JSONObject via a JSON
        // string generated by the library.
        //
        // The helper also removes the `type` property from the `key`
        // sub-object, if any. The `type` property is added by the
        // kotlinx.serialization library, as a class discriminator. This code
        // doesn't need a discriminator because the JSON never gets deserialised
        // back.
        @OptIn(ExperimentalSerializationApi::class)
        private inline fun <reified SERIALIZABLE>deserialise(
            serializable: SERIALIZABLE
        ): JSONObject
        {
            return JSONObject(Json.encodeToString(serializable)).also {
                (it.opt("key") as? JSONObject)?.remove("type")
            }
        }
    }

    override fun commandResponse(command: String?, jsonObject: JSONObject)
            : JSONObject
    {

        // All commands here insert a `results` item into the input JSON object.
        return when(Command.matching(command)) {
            Command.capabilities -> jsonObject.put(KEY.results,
                JSONObject(StoredKey.capabilities(this)))

            Command.deleteAll -> jsonObject.put(KEY.results, deserialise(
                StoredKey.deleteAll()))

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

                jsonObject.put(KEY.results, testKey(alias, sentinel))
            }

            Command.summariseStore -> jsonObject.put(KEY.results,
                JSONArray(StoredKey.describeAll().map {
                    // Add an empty `storage` property, to be consistent with
                    // the iOS implementation.
                    deserialise(it).put(KEY.storage, "")
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

                jsonObject.put(KEY.results, deserialise(
                    StoredKey.generateKeyNamed(alias)))
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

                jsonObject.put(KEY.results, deserialise(
                    StoredKey.generateKeyPairNamed(alias)))
            }

            Command.ready -> jsonObject

            else -> super.commandResponse(command, jsonObject)
        }
    }

    @OptIn(ExperimentalSerializationApi::class)
    private fun testKey(alias: String, sentinel: String): JSONArray {
        val entryDescription = StoredKey.describeKeyNamed(alias)
        val result = JSONArray(listOf(JSONObject()
            .put(KEY.type, entryDescription.entryClassName)
            .put(KEY.alias, entryDescription.name)
        ))

        val encrypted = try {
            StoredKey.encipherWithKeyNamed(sentinel, alias).also {
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
                KEY.failed to if (exceptions.length() == 1) exceptions[0]
                else exceptions)))
            return result
        }

        val decrypted = try {
            StoredKey.decipherWithKeyNamed(encrypted, alias).also {
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
                KEY.failed to if (exceptions.length() == 1) exceptions[0]
                else exceptions)))
            return result
        }

        return result
    }
}
