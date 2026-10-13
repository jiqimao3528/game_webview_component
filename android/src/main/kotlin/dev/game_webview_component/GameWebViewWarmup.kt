package dev.game_webview_component

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import android.webkit.WebView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * `:game_webview` 进程预热：提前拉起进程、预建 FlutterEngine 并初始化 WebView 运行时，
 * 把 open() 的冷启动成本转移到空闲时机。
 *
 * 预热引擎为单次使用：游戏页取出使用后随关闭销毁，并在后台重建一个供下次打开；
 * 若进程在两次打开之间被系统回收，open() 自动回退为原来的冷启动，行为仍然正确。
 */
object GameWebViewWarmup {
    const val CACHED_ENGINE_ID = "game_webview_engine"
    private const val TAG = "GameWebViewWarmup"
    private const val WARM_WEBVIEW_DESTROY_DELAY_MS = 3000L

    /** 宿主进程调用：拉起 :game_webview 进程执行预热。进程内预热见 [warm]。 */
    fun prewarm(context: Context) {
        try {
            context.startService(Intent(context, GameWebViewWarmupService::class.java))
        } catch (t: Throwable) {
            // 后台启动 Service 受限等场景：放弃预热，下次 open 回退冷启动。
            Log.w(TAG, "prewarm rejected, next open falls back to cold start", t)
        }
    }

    /**
     * 进程内预热（必须在 :game_webview 进程主线程调用；调用方由清单中的
     * android:process 保证）：预建 FlutterEngine 缓存到 [FlutterEngineCache]，
     * 并创建首个 WebView 触发进程级 Chromium 初始化。引擎只建不跑 Dart 入口，
     * Dart main() 仍在游戏页 attach 时按 initialRoute 执行。
     */
    fun warm(context: Context) {
        val appContext = context.applicationContext
        val cache = FlutterEngineCache.getInstance()
        if (cache.get(CACHED_ENGINE_ID) == null) {
            try {
                cache.put(CACHED_ENGINE_ID, FlutterEngine(appContext))
                Log.i(TAG, "engine pre-created")
            } catch (t: Throwable) {
                Log.w(TAG, "engine pre-create failed", t)
            }
        }
        // 进程内首个 WebView 的创建会触发 Chromium 初始化；
        // 该初始化是进程全局的，实例短暂存活后销毁即可，
        // 之后 webview_flutter 自建的 WebView 会直接复用已初始化的运行时。
        // API 28 以下无独立数据目录（组件本就不支持），不做 WebView 预热。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            try {
                val webView = WebView(appContext)
                Handler(Looper.getMainLooper()).postDelayed(
                    { webView.destroy() },
                    WARM_WEBVIEW_DESTROY_DELAY_MS
                )
            } catch (t: Throwable) {
                Log.w(TAG, "webview warm failed", t)
            }
        }
    }
}

/**
 * 空 Service：仅用于把 :game_webview 进程提前拉起并完成预热，做完即停；
 * 进程随后作为空进程驻留一段时间，期间 open() 直接复用预热成果。
 */
class GameWebViewWarmupService : Service() {
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        GameWebViewWarmup.warm(this)
        stopSelf()
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
