package dev.game_webview_component

import android.app.Application
import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.net.Uri
import android.os.Build
import android.webkit.WebView

/**
 * 进程启动自动初始化（ContentProvider.onCreate 早于 Application.onCreate），
 * 宿主无需改自己的 Application：游戏进程使用独立 WebView 数据目录。
 * 注意 API 28 以下无 setDataDirectorySuffix，多进程共用目录会崩溃，组件不支持。
 */
class GameWebViewInitProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        val context = context ?: return true
        val processName =
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) Application.getProcessName()
            else "?"
        val isGameProcess = processName == context.packageName + GAME_PROCESS_SUFFIX
        android.util.Log.i(
            "GameWebViewInit",
            "process=$processName isGame=$isGameProcess"
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P && isGameProcess) {
            WebView.setDataDirectorySuffix("game_webview")
        }
        return true
    }

    override fun query(
        uri: Uri, projection: Array<out String>?, selection: String?,
        selectionArgs: Array<out String>?, sortOrder: String?
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
    override fun update(
        uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?
    ): Int = 0

    companion object {
        const val GAME_PROCESS_SUFFIX = ":game_webview"
    }
}
