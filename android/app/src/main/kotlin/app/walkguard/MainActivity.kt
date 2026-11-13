package app.walkguard

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var bridge: WalkGuardPlugin? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = WalkGuardPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }
    override fun onResume() { super.onResume(); bridge?.visible = true; bridge?.refresh() }
    override fun onPause() { bridge?.visible = false; super.onPause() }
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        bridge?.onPermissionResult(requestCode)
    }
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        bridge?.dispose(); bridge = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
