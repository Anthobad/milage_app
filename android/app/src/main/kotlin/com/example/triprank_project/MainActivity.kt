package com.example.triprank_project

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        private const val CHANNEL = "com.triprank.app/google_maps"
        private const val GOOGLE_MAPS_PACKAGE = "com.google.android.apps.maps"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isGoogleMapsInstalled" -> {
                    result.success(isGoogleMapsInstalled())
                }
                "launchGoogleMapsNavigation" -> {
                    val latitude = call.argument<Double>("latitude")
                    val longitude = call.argument<Double>("longitude")
                    val name = call.argument<String?>("name")

                    if (latitude == null || longitude == null) {
                        result.error(
                            "INVALID_ARGS",
                            "latitude and longitude are required",
                            null
                        )
                        return@setMethodCallHandler
                    }

                    val launched = launchGoogleMapsNavigation(latitude, longitude, name)
                    result.success(launched)
                }
                else -> result.notImplemented()
            }
        }
    }

    // -------------------------------------------------------------------------
    // Private helpers
    // -------------------------------------------------------------------------

    private fun isGoogleMapsInstalled(): Boolean {
        return try {
            packageManager.getPackageInfo(GOOGLE_MAPS_PACKAGE, 0)
            true
        } catch (e: PackageManager.NameNotFoundException) {
            false
        }
    }

    /**
     * Launches Google Maps with turn-by-turn navigation to the given coordinates.
     *
     * Uses the google.navigation URI scheme which specifically targets Google Maps.
     * The intent is forced to use the Google Maps package so no app chooser is shown
     * and no other navigation app is used as a fallback.
     */
    private fun launchGoogleMapsNavigation(
        latitude: Double,
        longitude: Double,
        destinationName: String? = null
    ): Boolean {
        return try {
            // google.navigation:q=lat,lng targets turn-by-turn navigation in Google Maps.
            // Using the explicit package ensures only Google Maps handles the intent.
            val query = if (destinationName != null) {
                Uri.encode(destinationName)
            } else {
                "$latitude,$longitude"
            }
            val uriString = "google.navigation:q=$latitude,$longitude"
            val uri = Uri.parse(uriString)

            val intent = Intent(Intent.ACTION_VIEW, uri).apply {
                setPackage(GOOGLE_MAPS_PACKAGE)
                // FLAG_ACTIVITY_NEW_TASK is required when starting from a service/non-activity context.
                // We're in an Activity context here, but the flag doesn't hurt.
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }

            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
