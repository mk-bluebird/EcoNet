package org.mkbluebird.cyberquatic.sync

import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.location.Location
import android.os.BatteryManager
import kotlinx.coroutines.*
import org.mkbluebird.cyberquatic.api.CyboquaticAPI
import org.mkbluebird.cyberquatic.db.KERDatabase
import org.mkbluebird.cyberquatic.db.KERScore
import java.util.*

sealed class SyncResult {
    data class Success(val updatedCount: Int) : SyncResult()
    data class Skipped(val reason: String) : SyncResult()
    data class Failed(val error: String) : SyncResult()
}

interface LocationProvider {
    suspend fun getCurrentLocation(): Location?
    suspend fun getDistanceTo(latitude: Double, longitude: Double): Float
}

class AdaptiveSyncStrategy(
    private val context: Context,
    private val api: CyboquaticAPI,
    private val db: KERDatabase,
    private val locationProvider: LocationProvider
) {
    companion object {
        const val SYNC_RADIUS_METERS = 1000.0
        const val BATTERY_THRESHOLD = 20
        const val MIN_SYNC_INTERVAL_MS = 60_000L
        const val MAX_BATCH_SIZE = 50
    }

    private var lastSyncTimestamp: Long = 0

    suspend fun performAdaptiveSync(): SyncResult = withContext(Dispatchers.IO) {
        try {
            val batteryLevel = getBatteryLevel()
            if (batteryLevel < BATTERY_THRESHOLD) {
                return@withContext SyncResult.Skipped("Low battery: $batteryLevel%")
            }

            val timeSinceLastSync = System.currentTimeMillis() - lastSyncTimestamp
            if (timeSinceLastSync < MIN_SYNC_INTERVAL_MS) {
                return@withContext SyncResult.Skipped("Sync interval not elapsed")
            }

            val location = locationProvider.getCurrentLocation()
                ?: return@withContext SyncResult.Skipped("Location unavailable")

            val nearbyNodes = db.kerDao().getNodesWithin(
                lat = location.latitude,
                lon = location.longitude,
                radiusMeters = SYNC_RADIUS_METERS
            )

            if (nearbyNodes.isEmpty()) {
                return@withContext SyncResult.Skipped("No nodes within ${SYNC_RADIUS_METERS}m")
            }

            val updates = nearbyNodes.take(MAX_BATCH_SIZE).map { node ->
                async {
                    try {
                        api.getKERScore(node.nodeId)
                    } catch (e: Exception) {
                        null
                    }
                }
            }.awaitAll()

            val validUpdates = updates.mapNotNull { response ->
                response?.body()?.takeIf { it.isValid() }
            }

            if (validUpdates.isNotEmpty()) {
                db.kerDao().insertAll(validUpdates)
                lastSyncTimestamp = System.currentTimeMillis()
                SyncResult.Success(validUpdates.size)
            } else {
                SyncResult.Failed("No valid updates received")
            }

        } catch (e: Exception) {
            SyncResult.Failed("Sync exception: ${e.message}")
        }
    }

    private fun getBatteryLevel(): Int {
        val batteryStatus: Intent? = context.registerReceiver(
            null,
            IntentFilter(Intent.ACTION_BATTERY_CHANGED)
        )
        
        val level = batteryStatus?.getIntExtra(BatteryManager.EXTRA_LEVEL, -1) ?: -1
        val scale = batteryStatus?.getIntExtra(BatteryManager.EXTRA_SCALE, -1) ?: -1
        
        return if (level >= 0 && scale > 0) {
            (level * 100 / scale)
        } else {
            100
        }
    }

    suspend fun scheduleOptimalSync(): DateTime? = withContext(Dispatchers.Default) {
        val currentBattery = getBatteryLevel()
        
        if (currentBattery >= BATTERY_THRESHOLD + 20) {
            return@withContext null
        }

        val hoursUntilCharge = estimateHoursUntilCharge()
        
        if (hoursUntilCharge <= 2) {
            Calendar.getInstance().apply {
                add(Calendar.HOUR_OF_DAY, hoursUntilCharge)
            }.time
        } else {
            null
        }
    }

    private fun estimateHoursUntilCharge(): Int {
        val calendar = Calendar.getInstance()
        val currentHour = calendar.get(Calendar.HOUR_OF_DAY)
        
        return when {
            currentHour < 6 -> 6 - currentHour
            currentHour < 22 -> 22 - currentHour
            else -> (24 - currentHour) + 6
        }
    }
}

data class DateTime(val time: Date)

fun KERScore.isValid(): Boolean {
    return knowledge in 0.0..1.0 &&
           energy in 0.0..1.0 &&
           risk in 0.0..1.0 &&
           ecoWealth in 0.0..1.0 &&
           nodeId.isNotBlank()
}

class GeofencingLocationProvider(private val context: Context) : LocationProvider {
    
    override suspend fun getCurrentLocation(): Location? = withContext(Dispatchers.IO) {
        null
    }
    
    override suspend fun getDistanceTo(latitude: Double, longitude: Double): Float {
        return 0f
    }
}
