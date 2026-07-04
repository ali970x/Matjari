package com.matjari.matjari

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.StatFs
import android.provider.OpenableColumns
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.HttpURLConnection
import java.net.URL
import org.json.JSONObject
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private var pendingUploadResult: MethodChannel.Result? = null
    private var pendingUploadArgs: UploadArgs? = null
    private lateinit var channel: MethodChannel

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "matjari/native")
        channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    "downloadApk" -> downloadApkOnly(
                        url = call.argument("url"),
                        fileName = call.argument("fileName"),
                        downloadId = call.argument("downloadId"),
                        result = result,
                    )
                    "downloadedApks" -> result.success(downloadedApks())
                    "installDownloadedApk" -> result.success(
                        installDownloadedApk(call.argument("filePath")),
                    )
                    "removeDownloadedApk" -> result.success(
                        removeDownloadedApk(
                            key = call.argument("key"),
                            filePath = call.argument("filePath"),
                        ),
                    )
                    "openPackage" -> result.success(openPackage(call.argument("packageName")))
                    "installedVersionCode" -> result.success(installedVersionCode(call.argument("packageName")))
                    "resolveInstalledPackageByName" -> result.success(
                        resolveInstalledPackageByName(call.argument("appName")),
                    )
                    "packageAliases" -> result.success(packageAliases())
                    "deviceStorageInfo" -> result.success(deviceStorageInfo())
                    "openSupportEmail" -> result.success(
                        openSupportEmail(
                            email = call.argument("email"),
                            subject = call.argument("subject"),
                        ),
                    )
                    "saveSession" -> {
                        saveSession(call.argument("session"))
                        result.success(true)
                    }
                    "loadSession" -> result.success(loadSession())
                    "clearSession" -> {
                        clearSession()
                        result.success(true)
                    }
                    "rememberPackageAlias" -> {
                        rememberPackageAlias(
                            key = call.argument("key"),
                            packageName = call.argument("packageName"),
                        )
                        result.success(true)
                    }
                    "pickAndUpload" -> pickAndUpload(
                        endpoint = call.argument("endpoint"),
                        token = call.argument("token"),
                        fieldName = call.argument("fieldName"),
                        mimeType = call.argument("mimeType"),
                        allowMultiple = call.argument<Boolean>("allowMultiple") == true,
                        result = result,
                    )
                    else -> result.notImplemented()
                }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != PICK_UPLOAD_REQUEST) return

        val result = pendingUploadResult ?: return
        val args = pendingUploadArgs
        pendingUploadResult = null
        pendingUploadArgs = null

        if (resultCode != Activity.RESULT_OK || data == null || args == null) {
            result.success(null)
            return
        }

        val uris = mutableListOf<Uri>()
        val clipData = data.clipData
        if (clipData != null) {
            for (index in 0 until clipData.itemCount) {
                uris.add(clipData.getItemAt(index).uri)
            }
        } else {
            data.data?.let { uris.add(it) }
        }

        if (uris.isEmpty()) {
            result.success(null)
            return
        }

        Thread {
            try {
                val selectedFiles = selectedUploadFiles(uris)
                val response = uploadMultipart(args, uris)
                runOnUiThread {
                    result.success(
                        mapOf(
                            "response" to response,
                            "selectedFiles" to selectedFiles,
                        ),
                    )
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("UPLOAD_FAILED", error.message ?: "Upload failed", null)
                }
            }
        }.start()
    }

    private fun downloadApkOnly(
        url: String?,
        fileName: String?,
        downloadId: String?,
        result: MethodChannel.Result,
    ) {
        if (url.isNullOrBlank()) {
            result.error("BAD_URL", "APK URL is required", null)
            return
        }

        Thread {
            try {
                if (!downloadId.isNullOrBlank()) removeDownloadedApk(key = downloadId, filePath = null)
                val apkFile = downloadApk(url, fileName, downloadId)
                val packageInfo = readApkPackageInfo(apkFile)
                if (!downloadId.isNullOrBlank()) {
                    rememberDownloadedApk(downloadId, apkFile, packageInfo)
                }
                runOnUiThread {
                    result.success(downloadedApkPayload(apkFile, packageInfo))
                }
            } catch (error: Exception) {
                runOnUiThread {
                    result.error("DOWNLOAD_FAILED", error.message ?: "APK download failed", null)
                }
            }
        }.start()
    }

    private fun downloadedApks(): Map<String, Map<String, Any?>> {
        val prefs = getSharedPreferences(DOWNLOAD_PREFS, MODE_PRIVATE)
        val result = mutableMapOf<String, Map<String, Any?>>()
        val staleKeys = mutableListOf<String>()

        for ((key, value) in prefs.all) {
            val raw = value as? String ?: continue
            val payload = try {
                JSONObject(raw)
            } catch (_: Exception) {
                staleKeys.add(key)
                continue
            }
            val filePath = payload.optString("filePath")
            val file = File(filePath)
            if (filePath.isBlank() || !file.exists()) {
                staleKeys.add(key)
                continue
            }
            result[key] = mapOf(
                "filePath" to file.absolutePath,
                "packageName" to payload.optString("packageName").takeIf { it.isNotBlank() },
                "versionCode" to payload.optLong("versionCode").takeIf { payload.has("versionCode") },
                "versionName" to payload.optString("versionName").takeIf { it.isNotBlank() },
                "fileSize" to file.length(),
                "savedAt" to payload.optString("savedAt").takeIf { it.isNotBlank() },
            )
        }

        if (staleKeys.isNotEmpty()) {
            val editor = prefs.edit()
            staleKeys.forEach { editor.remove(it) }
            editor.apply()
        }

        return result
    }

    private fun installDownloadedApk(filePath: String?): Boolean {
        val file = downloadedFile(filePath) ?: return false
        return openApkInstaller(file)
    }

    private fun removeDownloadedApk(key: String?, filePath: String?): Boolean {
        val prefs = getSharedPreferences(DOWNLOAD_PREFS, MODE_PRIVATE)
        var removed = false

        if (!key.isNullOrBlank()) {
            val raw = prefs.getString(key, null)
            if (!raw.isNullOrBlank()) {
                val storedPath = try {
                    JSONObject(raw).optString("filePath")
                } catch (_: Exception) {
                    null
                }
                removed = deleteDownloadedFile(storedPath) || removed
            }
            prefs.edit().remove(key).apply()
        }

        removed = deleteDownloadedFile(filePath) || removed
        return removed
    }

    private fun openPackage(packageName: String?): Boolean {
        if (packageName.isNullOrBlank()) return false

        return try {
            val intent = packageManager.getLaunchIntentForPackage(packageName) ?: return false
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            startActivity(intent)
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun installedVersionCode(packageName: String?): Long? {
        if (packageName.isNullOrBlank()) return null

        return try {
            val info = packageManager.getPackageInfo(packageName, 0)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                info.longVersionCode
            } else {
                @Suppress("DEPRECATION")
                info.versionCode.toLong()
            }
        } catch (_: Exception) {
            null
        }
    }

    private fun resolveInstalledPackageByName(appName: String?): Map<String, Any?>? {
        val wanted = normalizeAppLabel(appName)
        if (wanted.isBlank()) return null

        val apps = try {
            packageManager.getInstalledApplications(0)
        } catch (_: Exception) {
            return null
        }

        val matches = apps.mapNotNull { app ->
            if (app.packageName == packageName) return@mapNotNull null
            val label = try {
                packageManager.getApplicationLabel(app).toString()
            } catch (_: Exception) {
                return@mapNotNull null
            }
            val normalized = normalizeAppLabel(label)
            if (normalized.isBlank()) return@mapNotNull null

            val score = when {
                normalized == wanted -> 3
                normalized.contains(wanted) -> 2
                wanted.contains(normalized) -> 1
                else -> 0
            }
            if (score == 0) null else ResolvedInstalledApp(app.packageName, label, score)
        }

        val match = matches.maxWithOrNull(
            compareBy<ResolvedInstalledApp> { it.score }
                .thenByDescending { it.label.length },
        ) ?: return null

        return mapOf(
            "packageName" to match.packageName,
            "label" to match.label,
            "versionCode" to installedVersionCode(match.packageName),
        )
    }

    private fun normalizeAppLabel(value: String?): String {
        return value
            ?.lowercase()
            ?.replace(Regex("[^a-z0-9]+"), "")
            ?: ""
    }

    private fun packageAliases(): Map<String, String> {
        return getSharedPreferences(ALIAS_PREFS, MODE_PRIVATE)
            .all
            .mapNotNull { (key, value) ->
                if (value is String && value.isNotBlank()) key to value else null
            }
            .toMap()
    }

    private fun rememberPackageAlias(key: String?, packageName: String?) {
        if (key.isNullOrBlank() || packageName.isNullOrBlank()) return
        getSharedPreferences(ALIAS_PREFS, MODE_PRIVATE)
            .edit()
            .putString(key, packageName)
            .apply()
    }

    private fun saveSession(session: String?) {
        if (session.isNullOrBlank()) return
        getSharedPreferences(SESSION_PREFS, MODE_PRIVATE)
            .edit()
            .putString(SESSION_KEY, session)
            .apply()
    }

    private fun loadSession(): String? {
        return getSharedPreferences(SESSION_PREFS, MODE_PRIVATE)
            .getString(SESSION_KEY, null)
    }

    private fun clearSession() {
        getSharedPreferences(SESSION_PREFS, MODE_PRIVATE)
            .edit()
            .remove(SESSION_KEY)
            .apply()
    }

    private fun deviceStorageInfo(): Map<String, Long> {
        val stat = StatFs(filesDir.absolutePath)
        return mapOf(
            "totalBytes" to stat.totalBytes,
            "freeBytes" to stat.availableBytes,
        )
    }

    private fun openSupportEmail(email: String?, subject: String?): Boolean {
        if (email.isNullOrBlank()) return false
        val intent = Intent(Intent.ACTION_SENDTO).apply {
            data = Uri.parse("mailto:$email")
            putExtra(Intent.EXTRA_SUBJECT, subject ?: "Matjari help and feedback")
            putExtra(
                Intent.EXTRA_TEXT,
                "Hello Matjari support,\n\nApp version: 1.1.4+6\nIssue:\n",
            )
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun pickAndUpload(
        endpoint: String?,
        token: String?,
        fieldName: String?,
        mimeType: String?,
        allowMultiple: Boolean,
        result: MethodChannel.Result,
    ) {
        if (pendingUploadResult != null) {
            result.error("PICKER_BUSY", "Another file picker is already open", null)
            return
        }
        if (endpoint.isNullOrBlank() || token.isNullOrBlank() || fieldName.isNullOrBlank()) {
            result.error("BAD_ARGS", "Upload endpoint, token, and field name are required", null)
            return
        }

        pendingUploadResult = result
        pendingUploadArgs = UploadArgs(endpoint, token, fieldName)

        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = mimeType ?: "*/*"
            putExtra(Intent.EXTRA_ALLOW_MULTIPLE, allowMultiple)
        }

        try {
            startActivityForResult(intent, PICK_UPLOAD_REQUEST)
        } catch (error: ActivityNotFoundException) {
            pendingUploadResult = null
            pendingUploadArgs = null
            result.error("NO_PICKER", "No file picker is available", null)
        }
    }

    private fun uploadMultipart(args: UploadArgs, uris: List<Uri>): String {
        val boundary = "----Matjari${System.currentTimeMillis()}"
        val lineBreak = "\r\n"
        val connection = (URL(args.endpoint).openConnection() as HttpURLConnection).apply {
            requestMethod = "POST"
            doOutput = true
            connectTimeout = 60000
            readTimeout = 120000
            setRequestProperty("Authorization", "Bearer ${args.token}")
            setRequestProperty("Content-Type", "multipart/form-data; boundary=$boundary")
        }

        connection.outputStream.use { output ->
            for (uri in uris) {
                val fileName = displayName(uri)
                val mimeType = contentResolver.getType(uri) ?: "application/octet-stream"
                output.write("--$boundary$lineBreak".toByteArray())
                output.write(
                    "Content-Disposition: form-data; name=\"${args.fieldName}\"; filename=\"$fileName\"$lineBreak"
                        .toByteArray(),
                )
                output.write("Content-Type: $mimeType$lineBreak$lineBreak".toByteArray())
                contentResolver.openInputStream(uri)?.use { input ->
                    input.copyTo(output)
                } ?: throw IllegalStateException("Could not open selected file")
                output.write(lineBreak.toByteArray())
            }
            output.write("--$boundary--$lineBreak".toByteArray())
        }

        val status = connection.responseCode
        val stream = if (status in 200..299) connection.inputStream else connection.errorStream
        val response = stream?.use { input ->
            val buffer = ByteArrayOutputStream()
            input.copyTo(buffer)
            buffer.toString("UTF-8")
        } ?: ""

        if (status !in 200..299) {
            throw IllegalStateException(response.ifBlank { "Upload failed with HTTP $status" })
        }

        return response
    }

    private fun selectedUploadFiles(uris: List<Uri>): List<Map<String, Any?>> {
        return uris.map { uri ->
            val name = displayName(uri)
            val size = uploadFileSize(uri)
            val packageInfo = if (name.endsWith(".apk", ignoreCase = true)) {
                inspectContentApk(uri, name)
            } else {
                null
            }
            mapOf(
                "originalName" to name,
                "size" to size,
                "packageName" to packageInfo?.packageName,
                "versionCode" to packageInfo?.versionCode,
                "versionName" to packageInfo?.versionName,
            )
        }
    }

    private fun uploadFileSize(uri: Uri): Long? {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.SIZE)
            if (index >= 0 && cursor.moveToFirst() && !cursor.isNull(index)) {
                return cursor.getLong(index)
            }
        }
        return null
    }

    private fun inspectContentApk(uri: Uri, fileName: String): ApkPackageInfo? {
        val safeName = safeApkName(fileName)
        val inspectDir = File(cacheDir, "upload-inspect").apply {
            mkdirs()
        }
        inspectDir.listFiles()?.forEach { file -> file.delete() }
        val apkFile = File(inspectDir, safeName)
        contentResolver.openInputStream(uri)?.use { input ->
            FileOutputStream(apkFile).use { output ->
                input.copyTo(output)
            }
        } ?: return null
        return readApkPackageInfo(apkFile)
    }

    private fun downloadApk(url: String, fileName: String?, downloadId: String?): File {
        val downloadsDir = File(cacheDir, "downloads").apply {
            mkdirs()
        }

        val safeName = safeApkName(fileName)
        val apkFile = File(downloadsDir, "${System.currentTimeMillis()}-$safeName")
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 60000
            readTimeout = 180000
            instanceFollowRedirects = true
            setRequestProperty("User-Agent", "Matjari Android")
        }

        val status = connection.responseCode
        if (status !in 200..299) {
            val error = connection.errorStream?.bufferedReader()?.use { it.readText() }
            throw IllegalStateException(error?.ifBlank { null } ?: "Download failed with HTTP $status")
        }

        val totalBytes = max(connection.contentLengthLong, 0L)
        var downloadedBytes = 0L
        var lastProgressSentAt = 0L
        sendDownloadProgress(downloadId, downloadedBytes, totalBytes)

        connection.inputStream.use { input ->
            FileOutputStream(apkFile).use { output ->
                val buffer = ByteArray(DEFAULT_BUFFER_SIZE)
                while (true) {
                    val count = input.read(buffer)
                    if (count == -1) break
                    output.write(buffer, 0, count)
                    downloadedBytes += count

                    val now = System.currentTimeMillis()
                    if (now - lastProgressSentAt > 180L) {
                        lastProgressSentAt = now
                        sendDownloadProgress(downloadId, downloadedBytes, totalBytes)
                    }
                }
            }
        }

        if (apkFile.length() <= 0L) {
            throw IllegalStateException("Downloaded APK is empty")
        }

        sendDownloadProgress(downloadId, apkFile.length(), max(totalBytes, apkFile.length()))
        return apkFile
    }

    @Suppress("DEPRECATION")
    private fun readApkPackageInfo(apkFile: File): ApkPackageInfo? {
        val info = packageManager.getPackageArchiveInfo(apkFile.absolutePath, 0) ?: return null
        val versionCode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.longVersionCode
        } else {
            info.versionCode.toLong()
        }
        return ApkPackageInfo(info.packageName, versionCode, info.versionName)
    }

    private fun downloadedApkPayload(
        apkFile: File,
        packageInfo: ApkPackageInfo?,
    ): Map<String, Any?> {
        return mapOf(
            "filePath" to apkFile.absolutePath,
            "packageName" to packageInfo?.packageName,
            "versionCode" to packageInfo?.versionCode,
            "versionName" to packageInfo?.versionName,
            "fileSize" to apkFile.length(),
            "savedAt" to System.currentTimeMillis().toString(),
        )
    }

    private fun rememberDownloadedApk(
        key: String,
        apkFile: File,
        packageInfo: ApkPackageInfo?,
    ) {
        val payload = JSONObject()
            .put("filePath", apkFile.absolutePath)
            .put("fileSize", apkFile.length())
            .put("savedAt", System.currentTimeMillis().toString())
        packageInfo?.packageName?.let { payload.put("packageName", it) }
        packageInfo?.versionCode?.let { payload.put("versionCode", it) }
        packageInfo?.versionName?.let { payload.put("versionName", it) }

        getSharedPreferences(DOWNLOAD_PREFS, MODE_PRIVATE)
            .edit()
            .putString(key, payload.toString())
            .apply()
    }

    private fun downloadedFile(filePath: String?): File? {
        if (filePath.isNullOrBlank()) return null
        val downloadsDir = File(cacheDir, "downloads").canonicalFile
        val file = File(filePath).canonicalFile
        if (!file.path.startsWith(downloadsDir.path)) return null
        if (!file.exists() || !file.name.endsWith(".apk", ignoreCase = true)) return null
        return file
    }

    private fun deleteDownloadedFile(filePath: String?): Boolean {
        val file = downloadedFile(filePath) ?: return false
        return try {
            file.delete()
        } catch (_: Exception) {
            false
        }
    }

    private fun sendDownloadProgress(downloadId: String?, downloadedBytes: Long, totalBytes: Long) {
        if (downloadId.isNullOrBlank()) return

        val progress = if (totalBytes > 0L) {
            (downloadedBytes.toDouble() / totalBytes.toDouble()).coerceIn(0.0, 1.0)
        } else {
            null
        }

        runOnUiThread {
            channel.invokeMethod(
                "downloadProgress",
                mapOf(
                    "downloadId" to downloadId,
                    "downloadedBytes" to downloadedBytes,
                    "totalBytes" to totalBytes,
                    "progress" to progress,
                ),
            )
        }
    }

    private fun openApkInstaller(apkFile: File): Boolean {
        val uri = FileProvider.getUriForFile(
            this,
            "${applicationContext.packageName}.fileprovider",
            apkFile,
        )
        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(uri, APK_MIME_TYPE)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        return try {
            startActivity(intent)
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: Exception) {
            false
        }
    }

    private fun safeApkName(fileName: String?): String {
        val rawName = fileName
            ?.takeIf { it.isNotBlank() }
            ?.replace(Regex("[^A-Za-z0-9._-]"), "-")
            ?: "matjari-app.apk"
        return if (rawName.endsWith(".apk", ignoreCase = true)) rawName else "$rawName.apk"
    }

    private fun displayName(uri: Uri): String {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (index >= 0 && cursor.moveToFirst()) {
                return cursor.getString(index)
            }
        }
        return "upload-${System.currentTimeMillis()}"
    }

    data class UploadArgs(
        val endpoint: String,
        val token: String,
        val fieldName: String,
    )

    data class ApkPackageInfo(
        val packageName: String,
        val versionCode: Long,
        val versionName: String?,
    )

    data class ResolvedInstalledApp(
        val packageName: String,
        val label: String,
        val score: Int,
    )

    companion object {
        private const val PICK_UPLOAD_REQUEST = 9401
        private const val APK_MIME_TYPE = "application/vnd.android.package-archive"
        private const val ALIAS_PREFS = "matjari_package_aliases"
        private const val DOWNLOAD_PREFS = "matjari_downloaded_apks"
        private const val SESSION_PREFS = "matjari_session"
        private const val SESSION_KEY = "session_json"
    }
}
