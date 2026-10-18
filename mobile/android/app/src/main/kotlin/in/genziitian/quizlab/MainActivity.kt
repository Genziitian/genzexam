// `in` is a reserved word in Kotlin, so it must be wrapped in backticks here.
package `in`.genziitian.quizlab

import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "in.genziitian.quizlab/app_icon"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "setIcon" -> {
                    val icon = call.argument<String>("icon") ?: "default"
                    val success = switchAppIcon(icon)
                    result.success(success)
                }
                "getCurrentIcon" -> {
                    result.success(currentAppIcon())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun switchAppIcon(icon: String): Boolean {
        return try {
            val pm = applicationContext.packageManager
            val pkg = applicationContext.packageName

            val defaultAlias = ComponentName(pkg, "$pkg.MainActivityDefault")
            val proAlias = ComponentName(pkg, "$pkg.MainActivityPro")

            val isPro = icon.equals("pro", ignoreCase = true)

            // Enable desired alias first so launcher never has zero components
            pm.setComponentEnabledSetting(
                if (isPro) proAlias else defaultAlias,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )

            // Disable alternative alias
            pm.setComponentEnabledSetting(
                if (isPro) defaultAlias else proAlias,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )

            true
        } catch (e: Exception) {
            false
        }
    }

    private fun currentAppIcon(): String {
        return try {
            val pm = applicationContext.packageManager
            val pkg = applicationContext.packageName
            val proAlias = ComponentName(pkg, "$pkg.MainActivityPro")
            val state = pm.getComponentEnabledSetting(proAlias)
            if (state == PackageManager.COMPONENT_ENABLED_STATE_ENABLED) "pro" else "default"
        } catch (e: Exception) {
            "default"
        }
    }
}
