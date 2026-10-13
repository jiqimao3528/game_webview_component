package dev.game_webview_component

import android.app.Activity
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

/**
 * 游戏容器 Activity，运行在独立进程 :game_webview（清单在本组件内声明，自动合并进宿主）。
 * API 28 及以上使用独立的 WebView 数据目录。
 *
 * 打开时优先复用 [GameWebViewWarmup] 预建的 FlutterEngine，
 * 没有预热成果则回退为 FlutterActivity 默认的冷启动。预热引擎单次使用：
 * 关闭后销毁并在后台重建一个供下次打开。
 *
 * 自定义游戏页可继承本类并覆写 [getInitialRoute]；
 * [launch] 用于打开默认页面。
 */
open class GameWebViewActivity : FlutterActivity() {
    val gameUrl: String? get() = intent?.getStringExtra(EXTRA_URL)

    // 游戏进程内 main() 按初始路由决定运行游戏页（release AOT 下不用第二 Dart 入口）。
    override fun getInitialRoute(): String = ROUTE_GAME

    /** 取出预热引擎（取出即移出缓存，保证单次使用；并发的第二次 open 回退冷启动）。 */
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        val cache = FlutterEngineCache.getInstance()
        val cached = cache.get(GameWebViewWarmup.CACHED_ENGINE_ID)
        if (cached != null) {
            cache.remove(GameWebViewWarmup.CACHED_ENGINE_ID)
            return cached
        }
        return super.provideFlutterEngine(context)
    }

    // 引擎从缓存取出后由当前 Activity 独占，结束或重建时统一销毁。
    override fun shouldDestroyEngineWithHost(): Boolean = true

    override fun onDestroy() {
        super.onDestroy()
        if (isFinishing) {
            // 正常关闭后预建下次打开所需的引擎。
            GameWebViewWarmup.warm(applicationContext)
        }
    }

    companion object {
        const val EXTRA_URL = "url"
        const val ROUTE_GAME = "game"

        fun launch(activity: Activity, url: String) {
            activity.startActivity(
                Intent(activity, GameWebViewActivity::class.java)
                    .putExtra(EXTRA_URL, url)
            )
        }
    }
}
