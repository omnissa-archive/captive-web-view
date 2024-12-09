// Copyright 2023 Omnissa, LLC.
// SPDX-License-Identifier: BSD-2-Clause

package com.example.captivecrypto.storedkey

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.security.keystore.KeyInfo
import android.security.keystore.KeyProperties
import android.security.keystore.StrongBoxUnavailableException
import java.security.KeyStore
import java.security.Security
import java.util.*
import javax.crypto.SecretKeyFactory

fun deviceCapabilities(context: Context):Map<String, Any> = mapOf(
    "build" to mapOf(
        "device" to Build.DEVICE,
        "display" to Build.DISPLAY,
        "version sdk_int" to Build.VERSION.SDK_INT,
        "manufacturer" to Build.MANUFACTURER,
        "model" to Build.MODEL,
        "brand" to Build.BRAND,
        "product" to Build.PRODUCT,
        "time" to formattedDate(Date(Build.TIME), false)
    ),
    "systemAvailableFeatures" to context.packageManager
        .systemAvailableFeatures.map {
            (it.name ?: it.toString()) + " ${it.version}"
        }.sorted(),
    "hasSystemFeature40" to mapOf(
        "FEATURE_HARDWARE_KEYSTORE" to
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    context.packageManager.hasSystemFeature(
                        PackageManager.FEATURE_HARDWARE_KEYSTORE, 40)
                else unavailableMessage(Build.VERSION_CODES.S),
        "FEATURE_STRONGBOX_KEYSTORE" to
                context.packageManager.hasSystemFeature(
                    PackageManager.FEATURE_STRONGBOX_KEYSTORE, 40)
    ),
    "hasSystemFeature" to mapOf(
        "FEATURE_HARDWARE_KEYSTORE" to
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                    context.packageManager.hasSystemFeature(
                        PackageManager.FEATURE_HARDWARE_KEYSTORE)
                else unavailableMessage(Build.VERSION_CODES.S),
        "FEATURE_STRONGBOX_KEYSTORE" to
                context.packageManager.hasSystemFeature(
                    PackageManager.FEATURE_STRONGBOX_KEYSTORE)
    ),
    "canProtectKeyWithHardwareSecurity" to canProtectKeyWithHardwareSecurity(),
    "canProtectKeyWithStrongBox" to canProtectKeyWithStrongBox(),
    "date" to formattedDate(Date(), true)
) + Security.getProviders().map {
    it.name to it.toMap() + mapOf( "info" to it.info )
}

private fun canProtectKeyWithHardwareSecurity() = keyGeneratorGeneric(
    UUID.randomUUID().toString(), KEY.AndroidKeyStore.name
).generateKey().run {
    val keyInfo = SecretKeyFactory.getInstance(algorithm)
        .getKeySpec(this, KeyInfo::class.java) as KeyInfo
    KeyStore.getInstance(KEY.AndroidKeyStore.name).apply { load(null) }
        .deleteEntry(keyInfo.keystoreAlias)

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
        when (keyInfo.securityLevel) {
            KeyProperties.SECURITY_LEVEL_TRUSTED_ENVIRONMENT,
            KeyProperties.SECURITY_LEVEL_STRONGBOX -> true

            else -> false
        }
    else keyInfo.isInsideSecureHardware
}

private fun canProtectKeyWithStrongBox() = try {
    val alias = UUID.randomUUID().toString()
    keyGeneratorStrongBox(alias, KEY.AndroidKeyStore.name).generateKey()
    KeyStore.getInstance(KEY.AndroidKeyStore.name)
        .apply { load(null) }
        .deleteEntry(alias)
    true
}
catch (exception: StrongBoxUnavailableException) { false }
