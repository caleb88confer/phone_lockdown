package app.phonelockdown

import android.content.Context
import android.content.SharedPreferences
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

/**
 * Centralized access to encrypted SharedPreferences.
 * On first use after upgrade, migrates existing plain-text prefs to encrypted storage.
 */
object PrefsHelper {

    private const val PLAIN_PREFS_NAME = "lockdown_prefs"
    private const val ENCRYPTED_PREFS_NAME = "lockdown_prefs_encrypted"
    private const val MIGRATION_KEY = "prefsMigrated"

    @Volatile
    private var cachedPrefs: SharedPreferences? = null

    fun getPrefs(context: Context): SharedPreferences {
        cachedPrefs?.let { return it }

        synchronized(this) {
            cachedPrefs?.let { return it }

            val appContext = context.applicationContext
            val masterKey = MasterKey.Builder(appContext)
                .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
                .build()

            val encryptedPrefs = EncryptedSharedPreferences.create(
                appContext,
                ENCRYPTED_PREFS_NAME,
                masterKey,
                EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
                EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
            )

            if (!encryptedPrefs.getBoolean(MIGRATION_KEY, false)) {
                migrateFromPlainPrefs(appContext, encryptedPrefs)
            }

            cachedPrefs = encryptedPrefs
            return encryptedPrefs
        }
    }

    private fun migrateFromPlainPrefs(context: Context, encryptedPrefs: SharedPreferences) {
        val plainPrefs = context.getSharedPreferences(PLAIN_PREFS_NAME, Context.MODE_PRIVATE)
        val allEntries = plainPrefs.all

        if (allEntries.isEmpty()) {
            encryptedPrefs.edit().putBoolean(MIGRATION_KEY, true).apply()
            return
        }

        AppLogger.i("Prefs", "Migrating ${allEntries.size} entries from plain to encrypted prefs")

        val editor = encryptedPrefs.edit()
        for ((key, value) in allEntries) {
            when (value) {
                is Boolean -> editor.putBoolean(key, value)
                is String -> editor.putString(key, value)
                is Int -> editor.putInt(key, value)
                is Long -> editor.putLong(key, value)
                is Float -> editor.putFloat(key, value)
                is Set<*> -> {
                    @Suppress("UNCHECKED_CAST")
                    editor.putStringSet(key, value as Set<String>)
                }
            }
        }
        editor.putBoolean(MIGRATION_KEY, true)
        editor.apply()

        // Delete plain-text prefs file
        plainPrefs.edit().clear().apply()
        AppLogger.i("Prefs", "Migration complete, plain prefs cleared")
    }
}
