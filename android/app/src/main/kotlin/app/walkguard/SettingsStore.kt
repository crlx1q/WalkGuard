package app.walkguard

import android.content.Context
import app.walkguard.core.GuardSettings
import org.json.JSONObject

class SettingsStore(context: Context) {
    private val preferences = context.getSharedPreferences("walkguard", Context.MODE_PRIVATE)
    fun load(): GuardSettings = runCatching {
        val json = JSONObject(preferences.getString("settings", "{}") ?: "{}")
        GuardSettings.fromStoredMap(json.keys().asSequence().associateWith { json.get(it) })
    }.getOrDefault(GuardSettings())
    fun save(settings: GuardSettings) {
        check(preferences.edit().putString("settings", JSONObject(settings.toStoredMap()).toString()).commit()) {
            "Не удалось сохранить настройки"
        }
    }
}
