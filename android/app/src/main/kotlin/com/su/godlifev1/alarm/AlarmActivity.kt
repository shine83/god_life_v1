package com.su.godlifev1.alarm

import android.app.Activity
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Bundle
import android.view.Gravity
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import com.su.godlifev1.R

class AlarmActivity : Activity() {

    private var player: MediaPlayer? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // 잠금화면 위로
        @Suppress("DEPRECATION")
        window.addFlags(
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON
        )

        // 간단한 레이아웃 (XML 없이)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(48, 48, 48, 48)
        }

        val title = TextView(this).apply {
            text = intent.getStringExtra("title") ?: "알람"
            textSize = 24f
        }

        val stop = Button(this).apply {
            text = "정지"
            setOnClickListener {
                stopSound()
                // 리시버로 액션 전달 (선택)
                sendBroadcast(Intent("com.su.godlifev1.ALARM_STOP"))
                finish()
            }
        }

        val snooze = Button(this).apply {
            text = "스누즈 5분"
            setOnClickListener {
                stopSound()
                sendBroadcast(Intent("com.su.godlifev1.ALARM_SNOOZE"))
                finish()
            }
        }

        root.addView(title)
        root.addView(stop)
        root.addView(snooze)
        setContentView(root)

        startSound()
    }

    private fun startSound() {
        // 단순 예시: 시스템 링톤 재생
        player = MediaPlayer().apply {
            setAudioStreamType(AudioManager.STREAM_ALARM)
            val uri = android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
            setDataSource(this@AlarmActivity, uri)
            isLooping = true
            prepare()
            start()
        }
    }

    private fun stopSound() {
        player?.run {
            stop()
            release()
        }
        player = null
    }

    override fun onDestroy() {
        stopSound()
        super.onDestroy()
    }
}