package com.qujianma.qujianma

import android.content.ComponentName
import android.content.Context
import android.content.ServiceConnection
import android.content.pm.PackageManager
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import rikka.shizuku.Shizuku
import java.util.concurrent.atomic.AtomicBoolean

object ShizukuKeepAliveManager {
    private val mainHandler = Handler(Looper.getMainLooper())
    private val restoring = AtomicBoolean(false)
    private val callbackLock = Any()
    private val pendingCallbacks = mutableListOf<(Boolean) -> Unit>()

    fun isShizukuRunning(): Boolean {
        return try {
            Shizuku.pingBinder()
        } catch (_: Throwable) {
            false
        }
    }

    fun isShizukuPermissionGranted(): Boolean {
        return try {
            if (!Shizuku.pingBinder()) return false
            if (Shizuku.isPreV11()) return false
            Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED
        } catch (_: Throwable) {
            false
        }
    }

    fun requestPermission(requestCode: Int): Boolean {
        return try {
            if (!Shizuku.pingBinder() || Shizuku.isPreV11()) return false
            if (Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED) return true
            Shizuku.requestPermission(requestCode)
            true
        } catch (_: Throwable) {
            false
        }
    }

    fun restoreAccessibilityAsync(context: Context, onComplete: ((Boolean) -> Unit)? = null) {
        if (!isShizukuPermissionGranted()) {
            onComplete?.let { mainHandler.post { it(false) } }
            return
        }

        if (onComplete != null) {
            synchronized(callbackLock) {
                pendingCallbacks.add(onComplete)
            }
        }

        // If a restore is already in flight, queued callbacks will receive its result when done.
        if (!restoring.compareAndSet(false, true)) {
            return
        }

        val appContext = context.applicationContext
        val serviceArgs = Shizuku.UserServiceArgs(
            ComponentName(appContext.packageName, ShizukuUserService::class.java.name)
        )
            .daemon(false)
            .processNameSuffix("shizuku_keepalive")
            .debuggable(false)
            .version(2)

        val completed = AtomicBoolean(false)
        lateinit var connection: ServiceConnection

        fun finish(success: Boolean) {
            if (!completed.compareAndSet(false, true)) return
            restoring.set(false)
            try {
                Shizuku.unbindUserService(serviceArgs, connection, true)
            } catch (_: Throwable) {
            }
            val callbacks = synchronized(callbackLock) {
                val copy = pendingCallbacks.toList()
                pendingCallbacks.clear()
                copy
            }
            mainHandler.post {
                for (cb in callbacks) {
                    cb(success)
                }
            }
        }

        connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                if (binder == null || !binder.pingBinder()) {
                    finish(false)
                    return
                }
                Thread {
                    val ok = try {
                        val remote = IShizukuKeepAliveService.Stub.asInterface(binder)
                        val component =
                            "${appContext.packageName}/${QuickScanAccessibilityService::class.java.name}"
                        remote.ensureAccessibilityEnabled(appContext.packageName, component)
                    } catch (_: Throwable) {
                        false
                    }
                    finish(ok)
                }.start()
            }

            override fun onServiceDisconnected(name: ComponentName?) {
                finish(false)
            }
        }

        // Timeout guard so callbacks never hang
        mainHandler.postDelayed({ finish(false) }, 3500L)

        try {
            Shizuku.bindUserService(serviceArgs, connection)
        } catch (_: Throwable) {
            finish(false)
        }
    }
}
