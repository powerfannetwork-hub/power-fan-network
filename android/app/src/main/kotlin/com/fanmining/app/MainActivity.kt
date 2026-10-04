package com.fanmining.app

import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.collect
import kotlinx.coroutines.launch
import me.didit.sdk.Configuration
import me.didit.sdk.DiditSdk
import me.didit.sdk.DiditSdkState
import me.didit.sdk.VerificationResult
import java.util.concurrent.atomic.AtomicBoolean

class MainActivity : FlutterActivity() {

    private val deviceChannelName =
        "power_fan/device"

    private val kycChannelName =
        "power_fan/didit"

    private val mainScope =
        CoroutineScope(
            SupervisorJob() +
                Dispatchers.Main.immediate
        )

    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(
            flutterEngine
        )

        // ============================================================
        // DEVICE CHANNEL
        // ============================================================

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            deviceChannelName
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "getAndroidId" -> {

                    try {

                        val androidId =
                            Settings.Secure.getString(
                                contentResolver,
                                Settings.Secure.ANDROID_ID
                            )

                        if (androidId.isNullOrBlank()) {

                            result.error(
                                "ANDROID_ID_UNAVAILABLE",
                                "Android device ID is unavailable.",
                                null
                            )

                        } else {

                            result.success(
                                androidId
                            )
                        }

                    } catch (e: Exception) {

                        result.error(
                            "ANDROID_ID_ERROR",
                            e.message
                                ?: "Unable to read Android device ID.",
                            null
                        )
                    }
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        // ============================================================
        // DIDIT KYC CHANNEL
        // ============================================================

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            kycChannelName
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "startVerificationWithWorkflow" -> {

                    startDiditVerification(
                        call,
                        result
                    )
                }

                else -> {
                    result.notImplemented()
                }
            }
        }

        // ============================================================
        // INITIALIZE DIDIT
        // ============================================================

        try {

            if (!DiditSdk.isInitialized()) {

                DiditSdk.initialize(
                    applicationContext
                )
            }

        } catch (_: Exception) {
            // The request path reports the actual
            // initialization error to Flutter.
        }
    }

    // ================================================================
    // START DIDIT VERIFICATION
    // ================================================================

    private fun startDiditVerification(
        call: MethodCall,
        result: MethodChannel.Result
    ) {

        val workflowId =
            call.argument<String>(
                "workflowId"
            )

        val vendorData =
            call.argument<String>(
                "vendorData"
            )

        // ============================================================
        // VALIDATE WORKFLOW
        // ============================================================

        if (workflowId.isNullOrBlank()) {

            result.error(
                "INVALID_WORKFLOW_ID",
                "Didit workflow ID is missing.",
                null
            )

            return
        }

        // ============================================================
        // VALIDATE USER
        // ============================================================

        if (vendorData.isNullOrBlank()) {

            result.error(
                "INVALID_VENDOR_DATA",
                "Didit vendor data is missing.",
                null
            )

            return
        }

        // ============================================================
        // INITIALIZE SDK
        // ============================================================

        try {

            if (!DiditSdk.isInitialized()) {

                DiditSdk.initialize(
                    applicationContext
                )
            }

        } catch (e: Exception) {

            result.error(
                "DIDIT_INIT_ERROR",
                e.message
                    ?: "Unable to initialize Didit SDK.",
                null
            )

            return
        }

        // ============================================================
        // RESULT GUARD
        // ============================================================

        val delivered =
            AtomicBoolean(false)

        // Prevent Didit UI from being launched
        // more than once for one request.
        val uiLaunched =
            AtomicBoolean(false)

        var stateJob: Job? = null

        // ============================================================
        // SUCCESS
        // ============================================================

        fun deliverSuccess(
            value: Map<String, Any?>
        ) {

            if (
                delivered.compareAndSet(
                    false,
                    true
                )
            ) {

                stateJob?.cancel()

                result.success(
                    value
                )
            }
        }

        // ============================================================
        // ERROR
        // ============================================================

        fun deliverError(
            code: String,
            message: String
        ) {

            if (
                delivered.compareAndSet(
                    false,
                    true
                )
            ) {

                stateJob?.cancel()

                result.error(
                    code,
                    message,
                    null
                )
            }
        }

        try {

            // ========================================================
            // OBSERVE DIDIT STATE
            // ========================================================

            stateJob =
                mainScope.launch {

                    DiditSdk.state.collect { state ->

                        when (state) {

                            // ==================================================
                            // READY
                            // ==================================================

                            is DiditSdkState.Ready -> {

                                if (
                                    uiLaunched.compareAndSet(
                                        false,
                                        true
                                    )
                                ) {

                                    try {

                                        DiditSdk.launchVerificationUI(
                                            this@MainActivity
                                        )

                                    } catch (e: Exception) {

                                        deliverError(
                                            "DIDIT_UI_ERROR",
                                            e.message
                                                ?: "Unable to open Didit verification UI."
                                        )
                                    }
                                }
                            }

                            // ==================================================
                            // SDK ERROR
                            // ==================================================

                            is DiditSdkState.Error -> {

                                deliverError(
                                    "DIDIT_SDK_ERROR",
                                    state.message
                                )
                            }

                            // ==================================================
                            // LOADING / IDLE / CREATING SESSION
                            // ==================================================

                            else -> {
                                // Wait for Ready or Error.
                            }
                        }
                    }
                }

            // ========================================================
            // CREATE DIDIT SESSION
            // ========================================================

            DiditSdk.startVerification(
                workflowId = workflowId,
                vendorData = vendorData,
                configuration = Configuration(
                    loggingEnabled = true
                )
            ) { verificationResult ->

                when (verificationResult) {

                    // ==================================================
                    // COMPLETED
                    // ==================================================

                    is VerificationResult.Completed -> {

                        deliverSuccess(
                            mapOf(
                                "type" to
                                    "completed",

                                "sessionId" to
                                    verificationResult
                                        .session
                                        .sessionId,

                                "status" to
                                    verificationResult
                                        .session
                                        .status
                                        .rawValue
                            )
                        )
                    }

                    // ==================================================
                    // CANCELLED
                    // ==================================================

                    is VerificationResult.Cancelled -> {

                        deliverSuccess(
                            mapOf(
                                "type" to
                                    "cancelled",

                                "sessionId" to
                                    verificationResult
                                        .session
                                        ?.sessionId,

                                "status" to
                                    verificationResult
                                        .session
                                        ?.status
                                        ?.rawValue
                            )
                        )
                    }

                    // ==================================================
                    // FAILED
                    // ==================================================

                    is VerificationResult.Failed -> {

                        deliverSuccess(
                            mapOf(
                                "type" to
                                    "failed",

                                "errorType" to
                                    verificationResult
                                        .error
                                        .javaClass
                                        .simpleName,

                                "errorMessage" to
                                    (
                                        verificationResult
                                            .error
                                            .message
                                            ?: "Didit verification failed."
                                    ),

                                "sessionId" to
                                    verificationResult
                                        .session
                                        ?.sessionId
                            )
                        )
                    }
                }
            }

        } catch (e: Exception) {

            deliverError(
                "DIDIT_START_ERROR",
                e.message
                    ?: "Unable to start Didit verification."
            )
        }
    }

    // ================================================================
    // CLEANUP
    // ================================================================

    override fun onDestroy() {

        mainScope.cancel()

        super.onDestroy()
    }
}
