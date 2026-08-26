package com.familycalendar.family_calendar

import android.app.admin.DevicePolicyManager
import android.content.Context
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        maybeStartKioskLockTask()
    }

    override fun onResume() {
        super.onResume()
        maybeStartKioskLockTask()
    }

    private fun maybeStartKioskLockTask() {
        if (!packageName.endsWith(".kiosk")) return
        val dpm = getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager
        if (dpm.isDeviceOwnerApp(packageName)) {
            startLockTask()
        }
    }
}
