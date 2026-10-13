package dev.game_webview_component

import android.app.Activity
import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * 组件内部通道：open/getUrl/close。仅供组件自身运转，不是业务数据通道；
 * 业务交互请用 webview_flutter 的 JS 通道或自建 MethodChannel（见 README）。
 */
class GameWebViewComponentPlugin : FlutterPlugin, ActivityAware, MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null
    private var applicationContext: Context? = null
    private var activity: Activity? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        applicationContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel?.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        applicationContext = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "open" -> {
                val url = call.arguments as? String
                if (url.isNullOrEmpty()) {
                    result.error("ARG", "empty url", null)
                    return
                }
                val host = activity
                if (host == null) {
                    result.error("STATE", "no foreground activity", null)
                    return
                }
                GameWebViewActivity.launch(host, url)
                result.success(null)
            }
            "prewarm" -> {
                // 提前拉起 :game_webview 进程并预建引擎/WebView；失败静默回退冷启动。
                val ctx = applicationContext
                if (ctx == null) {
                    result.error("STATE", "no context", null)
                    return
                }
                GameWebViewWarmup.prewarm(ctx)
                result.success(null)
            }
            "getUrl" -> result.success((activity as? GameWebViewActivity)?.gameUrl)
            "close" -> {
                activity?.finish()
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    companion object {
        const val CHANNEL_NAME = "dev.game_webview_component/channel"
    }
}
