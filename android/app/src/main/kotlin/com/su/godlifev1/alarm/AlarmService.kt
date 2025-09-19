package com.su.godlifev1.alarm

import android.app.*
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.RingtoneManager
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator
import androidx.core.app.NotificationCompat
import androidx.core.app.PendingIntentCompat
import com.su.godlifev1.R
import androidx.core.app.NotificationManagerCompat

class AlarmService : Service() {

    companion object {
        private const val CHANNEL_ID = "alarm_channel"
        private const val NOTIF_ID = 999000
        private const val ACTION_START = "START_ALARM"

        fun start(context: Context, title: String = "알람") {
            val i = Intent(context, AlarmService::class.java).apply {
                action = ACTION_START
                putExtra("title", title)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
        }

        fun stop(context: Context) {
            val i = Intent(context, AlarmService::class.java)
            context.stopService(i)
            try {
                val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                nm.cancel(NOTIF_ID)
            } catch (_: Exception) { }
        }
    }

    private var player: MediaPlayer? = null
    private var vibrator: Vibrator? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_START) {
            val title = intent.getStringExtra("title") ?: "알람"
            startForeground(NOTIF_ID, buildNotification(title))
            startSoundAndVibrate()
            // 잠금화면 풀스크린 띄우기
            showFullscreen()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        stopSoundAndVibrate()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val ch = NotificationChannel(
                CHANNEL_ID,
                "Alarm",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null) // 소리는 MediaPlayer로 별도 재생
                enableVibration(false) // 진동은 Vibrator로 별도 제어
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(ch)
        }
    }

    private fun buildNotification(title: String): Notification {
        // STOP 액션
        val stopPi = PendingIntent.getBroadcast(
            this,
            1000,
            Intent(this, AlarmActionReceiver::class.java).setAction("com.su.godlifev1.ALARM_STOP"),
            PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        // 풀스크린 인텐트
        val fsPi = PendingIntent.getActivity(
            this,
            1001,
            Intent(this, AlarmActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
            PendingIntent.FLAG_UPDATE_CURRENT or
                    (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText("알람이 울리는 중…")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .addAction(NotificationCompat.Action(0, "정지", stopPi))
            .setFullScreenIntent(fsPi, true)
            .build()
    }

    private fun startSoundAndVibrate() {
        // 기본 알람 사운드
        val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        player = MediaPlayer().apply {
            setDataSource(this@AlarmService, uri)
            isLooping = true
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            )
            prepare()
            start()
        }

        vibrator = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val effect = VibrationEffect.createWaveform(longArrayOf(0, 800, 400), 0)
            vibrator?.vibrate(effect)
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(longArrayOf(0, 800, 400), 0)
        }
    }

    private fun stopSoundAndVibrate() {
        runCatching { player?.stop() }
        runCatching { player?.release() }
        player = null
        runCatching { vibrator?.cancel() }
        vibrator = null
    }

    private fun showFullscreen() {
        val i = Intent(this, AlarmActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(i)
    }
}