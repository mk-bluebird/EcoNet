data class SurchargeReviewInput(
    val fogConfidence: Double,
    val sensorCalibrated: Boolean,
    val sampleCollected: Boolean,
    val severityBand: String
)

data class SurchargeReview(
    val requiresHumanReview: Boolean,
    val accessibleReason: String,
    val permittedNextStep: String
)

fun review(input: SurchargeReviewInput): SurchargeReview {
    require(input.fogConfidence in 0.0..1.0)
    require(input.severityBand in setOf("low", "moderate", "high", "critical"))

    val lowConfidence = input.fogConfidence < 0.70
    val incompleteEvidence = !input.sensorCalibrated || !input.sampleCollected
    val elevatedSeverity = input.severityBand != "low"

    return when {
        input.severityBand == "critical" -> SurchargeReview(
            true,
            "Critical surcharge conditions require an authorized safety response and documented human confirmation.",
            "Use the local emergency and environmental escalation procedure."
        )
        lowConfidence || incompleteEvidence || elevatedSeverity -> SurchargeReview(
            true,
            "The available evidence is incomplete or uncertain; the system must not authorize field action independently.",
            "Collect or verify the required field evidence and request authorized review."
        )
        else -> SurchargeReview(
            false,
            "The observation is within the configured monitoring band and has complete supporting evidence.",
            "Continue scheduled monitoring and preserve provenance records."
        )
    }
}

fun main() {
    val result = review(
        SurchargeReviewInput(
            fogConfidence = 0.62,
            sensorCalibrated = true,
            sampleCollected = false,
            severityBand = "moderate"
        )
    )

    println("requires_human_review=${result.requiresHumanReview}")
    println("reason=${result.accessibleReason}")
    println("next_step=${result.permittedNextStep}")
}
