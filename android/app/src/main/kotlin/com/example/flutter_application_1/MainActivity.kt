package com.example.flutter_application_1

import android.content.Intent
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.squareup.sdk.inapppayments.InAppPaymentsSdk
import com.squareup.sdk.inapppayments.cardentry.CardEntry
import com.squareup.sdk.inapppayments.cardentry.CardEntryActivityResult

class MainActivity : FlutterFragmentActivity() {
	private val channelName = "freshpunk/square_payments"
	private var pendingResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"initialize" -> {
						val appId = call.argument<String>("applicationId")
						if (appId.isNullOrBlank()) {
							result.error("INVALID_APP_ID", "Square application ID is required", null)
							return@setMethodCallHandler
						}
						InAppPaymentsSdk.squareApplicationId = appId
						result.success(true)
					}
					"tokenizeCard" -> {
						if (pendingResult != null) {
							result.error("IN_PROGRESS", "Card entry already in progress", null)
							return@setMethodCallHandler
						}
						pendingResult = result
						CardEntry.startCardEntryActivity(this)
					}
					else -> result.notImplemented()
				}
			}
	}

	override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
		super.onActivityResult(requestCode, resultCode, data)

		if (requestCode == CardEntry.DEFAULT_CARD_ENTRY_REQUEST_CODE) {
			val pending = pendingResult ?: return
			pendingResult = null

			val result = CardEntry.handleActivityResult(data)
			when (result) {
				is CardEntryActivityResult.Success -> {
					pending.success(result.cardNonce)
				}
				is CardEntryActivityResult.Canceled -> {
					pending.error("CANCELED", "Card entry canceled", null)
				}
				is CardEntryActivityResult.Failure -> {
					pending.error("FAILED", result.errorMessage, null)
				}
				else -> {
					pending.error("UNKNOWN", "Card entry failed", null)
				}
			}
		}
	}
}
