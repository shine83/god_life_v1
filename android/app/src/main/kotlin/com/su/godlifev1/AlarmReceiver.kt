package com.su.godlifev1

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import com.su.godlifev1.alarm.AlarmActivity

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val show = Intent(context, AlarmActivity::class.java).apply {
            putExtra("title", intent.getStringExtra("title") ?: "알람")
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS
            )
        }
        context.startActivity(show)
    }
}