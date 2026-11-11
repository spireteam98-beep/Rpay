package com.wayaki.app

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth
// for the Face / fingerprint prompt.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // "fareenn/sound": short UI sounds without an extra audio plugin.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "fareenn/sound")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "paymentSuccess" -> {
                        playRaw(R.raw.payment_success)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // USAGE_MEDIA plays on the music stream, which Android does not mute
    // when the ringer is in silent or vibrate mode (unlike the notification
    // stream) - a card payment confirmation must always be heard, without
    // the merchant having to touch the device's volume.
    private fun playRaw(resId: Int) {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_MEDIA)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val player = MediaPlayer.create(this, resId, attrs, 0) ?: return
        player.setOnCompletionListener { it.release() }
        player.setVolume(1f, 1f)
        player.start()
    }
}
