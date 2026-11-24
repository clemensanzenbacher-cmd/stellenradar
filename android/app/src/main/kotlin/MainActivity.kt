// Liegt bewusst direkt unter kotlin/ (kurzer Pfad); das Paket bestimmt die Zeile unten.
package de.clemens.stellenradar

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        legeBenachrichtigungskanalAn()
    }

    /** Kanal mit hoher Wichtigkeit: Meldung erscheint oben als Banner, mit Ton und Vibration. */
    private fun legeBenachrichtigungskanalAn() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val kanal = NotificationChannel(
            "neue_stellen",
            "Neue Stellen",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Sofort-Meldung bei neuen Praktika und Trainee-Stellen"
            enableVibration(true)
            enableLights(true)
        }
        getSystemService(NotificationManager::class.java)?.createNotificationChannel(kanal)
    }
}
