// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivewebview

import org.json.JSONObject

// The extensions in this file make the members of an enum class usable as
// JSONObject keys and as String values in the left sides of `to` mappings. They
// can be imported individually.
//
// Code that attempts to use an enum member as a JSONObject key without
// importing will generate a build-time error, which is good. Fix by adding
// individual import statements like these.
//
//     import com.example.captivewebview.opt
//     import com.example.captivewebview.put
//
// Code that attempts to use an enum member as the String left side of a `to`
// mapping might only generate a run-time error, which is difficult to
// troubleshoot. Fix by adding an individual import statement like this.
//
//     import com.example.captivewebview.to

inline fun <reified T: Enum<T>> JSONObject.opt(key: T)
: Any? = opt(key.name)

inline fun <reified T: Enum<T>> JSONObject.put(key: T, value: Any?)
: JSONObject = put(key.name, value)

inline fun <reified T: Enum<T>> JSONObject.putOpt(key: T, value: Any?)
: JSONObject = putOpt(key.name, value)

inline fun <reified T: Enum<T>> JSONObject.remove(key: T)
: Any? = remove(key.name)

// Enables members of the any enumeration to be used as keys in mappings
// from String to any, for example as mapOf() parameters.
// Also blocks direct use of the enum in mappings.
inline infix fun <reified T: Enum<T>, VALUE> T.to(that: VALUE)
: Pair<String, VALUE> = this.name to that
