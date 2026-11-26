package com.qujianma.qujianma

import kotlin.system.exitProcess

/**
 * Runs inside Shizuku's privileged shell process to restore our AccessibilityService
 * when the OS kills or disables it, so users don't have to re-enable it manually.
 */
class ShizukuUserService : IShizukuKeepAliveService.Stub() {

    override fun ensureAccessibilityEnabled(packageName: String, serviceComponent: String): Boolean {
        return try {
            val current = runShell("settings", "get", "secure", "enabled_accessibility_services")
                .trim()
                .let { if (it == "null") "" else it }

            val existingList = current
                .split(':')
                .map { it.trim() }
                .filter { it.isNotEmpty() }
                .toMutableList()

            val shortComponent = "$packageName/.QuickScanAccessibilityService"
            val hadOurs = existingList.removeAll {
                it.equals(serviceComponent, ignoreCase = true) ||
                    it.equals(shortComponent, ignoreCase = true)
            }

            // On HyperOS/MIUI/ColorOS, the OS often kills the service process while leaving
            // the setting string intact. Toggling it off briefly forces AccessibilityManagerService
            // to re-bind and revive the service process.
            if (hadOurs) {
                val withoutOurs = existingList.joinToString(":")
                runShell("settings", "put", "secure", "enabled_accessibility_services", withoutOurs)
                try {
                    Thread.sleep(160L)
                } catch (_: InterruptedException) {
                }
            }

            existingList.add(serviceComponent)
            val updated = existingList.joinToString(":")
            runShell("settings", "put", "secure", "enabled_accessibility_services", updated)
            runShell("settings", "put", "secure", "accessibility_enabled", "1")

            // Best-effort battery/background whitelist to reduce OS kills
            try {
                runShell("dumpsys", "deviceidle", "whitelist", "+$packageName")
            } catch (_: Throwable) {
            }

            true
        } catch (_: Throwable) {
            false
        }
    }

    override fun destroy() {
        exitProcess(0)
    }

    private fun runShell(vararg cmd: String): String {
        val process = ProcessBuilder(*cmd)
            .redirectErrorStream(true)
            .start()
        val output = process.inputStream.bufferedReader().use { it.readText() }
        process.waitFor()
        return output
    }
}
