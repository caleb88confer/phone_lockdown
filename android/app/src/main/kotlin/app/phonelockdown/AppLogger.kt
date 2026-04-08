package app.phonelockdown

import android.util.Log

object AppLogger {
    private const val PREFIX = "PhoneLockdown"

    fun d(tag: String, msg: String) = Log.d("$PREFIX/$tag", msg)
    fun i(tag: String, msg: String) = Log.i("$PREFIX/$tag", msg)
    fun w(tag: String, msg: String) = Log.w("$PREFIX/$tag", msg)
    fun w(tag: String, msg: String, t: Throwable) = Log.w("$PREFIX/$tag", msg, t)
    fun e(tag: String, msg: String) = Log.e("$PREFIX/$tag", msg)
    fun e(tag: String, msg: String, t: Throwable) = Log.e("$PREFIX/$tag", msg, t)
}
