package com.su.godlifev1.alarm

import android.app.AlarmManager
import android.app.PendingIntent
import android.app.PendingIntent.FLAG_IMMUTABLE
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

class AlarmActionReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            "com.su.godlifev1.ALARM_STOP" -> {
                Log.d("AlarmActionReceiver", "STOP")
                AlarmService.stop(context)
            }
            "com.su.godlifev1.ALARM_SNOOZE" -> {
                Log.d("AlarmActionReceiver", "SNOOZE")
                scheduleSnooze(context, 5)
                AlarmService.stop(context)
            }
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_LOCKED_BOOT_COMPLETED -> {
                // TODO: 여기서 저장해둔 알람들을 복원하는 로직 추가(필요시)
                Log.d("AlarmActionReceiver", "BOOT_COMPLETED -> restore alarms if needed")
            }
        }
    }

    companion object {
        fun scheduleSnooze(context: Context, minutes: Int) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val at = System.currentTimeMillis() + minutes * 60_000L

            val startServiceIntent = Intent(context, AlarmStartReceiver::class.java)
            val pi = PendingIntent.getBroadcast(
                context,
                1002,
                startServiceIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) FLAG_IMMUTABLE else 0)
            )

            // 알람 시각에 서비스 시작시키는 브로드캐스트(아래 별도 리시버)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pi)
            } else {
                am.setExact(AlarmManager.RTC_WAKEUP, at, pi)
            }
        }
    }
}

/**
 * 스누즈 시간이 됐을 때 AlarmService를 시작시키기 위한 리시버
 */
class AlarmStartReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        AlarmService.start(context, title = "스누즈 알람")
    }
}