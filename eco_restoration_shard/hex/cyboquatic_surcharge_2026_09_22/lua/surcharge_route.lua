local SurchargeRoute = {}

function SurchargeRoute.decide(media_type, fog_confidence, calibrated, sample_collected)
    if type(media_type) ~= "string" then
        return "hold_for_human_review", "media type is unavailable"
    end

    if type(fog_confidence) ~= "number" or fog_confidence < 0.0 or fog_confidence > 1.0 then
        return "hold_for_human_review", "FOG confidence is outside valid bounds"
    end

    if media_type == "unmodeled" then
        return "hold_for_human_review", "unmodeled media must not be routed automatically"
    end

    if not calibrated then
        return "hold_for_human_review", "field sensor calibration is not confirmed"
    end

    if not sample_collected then
        return "hold_for_human_review", "confirmatory sample is required before routing"
    end

    if fog_confidence < 0.70 then
        return "hold_for_human_review", "FOG classification confidence is below the review threshold"
    end

    if media_type == "aqueous" or media_type == "sediment" or media_type == "biosolids" then
        return "accept_with_monitoring", "known media with sufficient evidence"
    end

    return "hold_for_human_review", "media type has no approved routing predicate"
end

return SurchargeRoute
