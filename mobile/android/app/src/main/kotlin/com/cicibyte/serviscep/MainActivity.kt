package com.cicibyte.serviscep

import android.app.Activity
import android.content.Intent
import android.provider.ContactsContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Rehberden kişi seçme köprüsü.
 *
 * Kasıtlı olarak READ_CONTACTS izni İSTENMEZ: sistemin kendi kişi
 * seçicisi (ACTION_PICK) açılır, kullanıcı tek bir kişiyi kendi
 * iradesiyle seçer ve Android yalnızca o kaydın URI'sine geçici okuma
 * hakkı verir. Böylece uygulama tüm rehbere erişme izni istemek zorunda
 * kalmaz (bkz. AndroidManifest.xml'deki izin disiplini — kullanılmayan
 * medya izinleri de aynı gerekçeyle kaldırılmıştı).
 */
class MainActivity : FlutterActivity() {
    private val channelName = "com.cicibyte.serviscep/contact_picker"
    private val pickContactRequestCode = 9101
    private var pendingResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result -> handle(call, result) }
    }

    private fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "pickContact") {
            result.notImplemented()
            return
        }
        if (pendingResult != null) {
            result.error("IN_PROGRESS", "Zaten açık bir kişi seçimi var.", null)
            return
        }

        val intent = Intent(
            Intent.ACTION_PICK,
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI
        )
        try {
            pendingResult = result
            startActivityForResult(intent, pickContactRequestCode)
        } catch (e: Exception) {
            pendingResult = null
            result.error("NO_PICKER", "Cihazda rehber uygulaması bulunamadı.", null)
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        // Diğer tüm istekler (image_picker, mobile_scanner vb.) eklentilere
        // gitmeye devam etmeli — yalnızca kendi kodumuzu araya alıyoruz.
        if (requestCode != pickContactRequestCode) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }

        val result = pendingResult ?: return
        pendingResult = null

        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            result.success(null) // kullanıcı vazgeçti
            return
        }

        try {
            contentResolver.query(
                uri,
                arrayOf(
                    ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                    ContactsContract.CommonDataKinds.Phone.NUMBER
                ),
                null, null, null
            ).use { cursor ->
                if (cursor != null && cursor.moveToFirst()) {
                    result.success(
                        mapOf(
                            "name" to cursor.getString(0),
                            "phone" to cursor.getString(1)
                        )
                    )
                } else {
                    result.success(null)
                }
            }
        } catch (e: Exception) {
            result.error("READ_FAILED", "Kişi okunamadı: ${e.message}", null)
        }
    }
}
