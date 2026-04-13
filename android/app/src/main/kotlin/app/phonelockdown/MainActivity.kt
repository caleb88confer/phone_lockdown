package app.phonelockdown

import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class MainActivity : FlutterActivity() {
    private val channelName = Constants.METHOD_CHANNEL

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        scheduleServiceMonitor()

        val permissionManager = PermissionManager(this)
        val blockingStateManager = BlockingStateManager(this)
        val appListHelper = AppListHelper(applicationContext)

        val handler = MethodChannelHandler(
            permissionManager = permissionManager,
            blockingStateManager = blockingStateManager,
            appListHelper = appListHelper,
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler(handler)
    }

    private fun scheduleServiceMonitor() {
        val workRequest = PeriodicWorkRequestBuilder<ServiceMonitorWorker>(
            15, TimeUnit.MINUTES
        ).build()

        WorkManager.getInstance(applicationContext).enqueueUniquePeriodicWork(
            ServiceMonitorWorker.WORK_NAME,
            ExistingPeriodicWorkPolicy.KEEP,
            workRequest
        )
    }
}
