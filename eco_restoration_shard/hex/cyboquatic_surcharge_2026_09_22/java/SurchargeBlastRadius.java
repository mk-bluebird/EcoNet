import java.util.Locale;

public final class SurchargeBlastRadius {
    record Input(
        double flowLps,
        double designFlowLps,
        double depthM,
        int durationSeconds,
        double fogConfidence,
        boolean calibrated,
        boolean sampleCollected
    ) {}

    record Result(
        double baseRadiusM,
        double uncertaintyRadiusM,
        double reviewRadiusM,
        String severityBand,
        String disposition
    ) {}

    static Result assess(Input input) {
        if (input.flowLps() < 0.0 || input.designFlowLps() <= 0.0 ||
            input.depthM() < 0.0 || input.durationSeconds() <= 0 ||
            input.fogConfidence() < 0.0 || input.fogConfidence() > 1.0) {
            throw new IllegalArgumentException("input is outside bounded operating range");
        }

        double flowRatio = input.flowLps() / input.designFlowLps();
        double durationFactor = Math.log1p(input.durationSeconds() / 60.0);
        double baseRadius = clamp(
            8.0 + 12.0 * Math.sqrt(Math.max(0.0, flowRatio)) +
            25.0 * input.depthM() + 6.0 * durationFactor,
            0.0, 10000.0
        );

        double uncertaintyMultiplier =
            (1.0 - input.fogConfidence()) +
            (input.calibrated() ? 0.0 : 0.35) +
            (input.sampleCollected() ? 0.0 : 0.25);

        double uncertainty = clamp(baseRadius * uncertaintyMultiplier, 0.0, 10000.0);
        double reviewRadius = clamp(baseRadius + uncertainty, baseRadius, 20000.0);

        double severityScore =
            0.45 * Math.min(flowRatio, 2.0) +
            0.35 * Math.min(input.depthM() / 0.5, 2.0) +
            0.20 * Math.min(input.durationSeconds() / 3600.0, 2.0);

        String severity = "low";
        String disposition = "monitor";
        if (severityScore >= 1.80) {
            severity = "critical";
            disposition = "isolate_and_escalate";
        } else if (severityScore >= 1.10) {
            severity = "high";
            disposition = "hold_for_human_review";
        } else if (severityScore >= 0.60 || input.fogConfidence() < 0.70 ||
                   !input.calibrated() || !input.sampleCollected()) {
            severity = "moderate";
            disposition = "hold_for_human_review";
        }

        return new Result(baseRadius, uncertainty, reviewRadius, severity, disposition);
    }

    static double clamp(double value, double min, double max) {
        return Math.max(min, Math.min(max, value));
    }

    public static void main(String[] args) {
        Input input = new Input(96.0, 70.0, 0.18, 540, 0.62, true, false);
        Result result = assess(input);

        System.out.printf(Locale.ROOT,
            "base_radius_m=%.3f%nuncertainty_radius_m=%.3f%nreview_radius_m=%.3f%nseverity_band=%s%ndisposition=%s%n",
            result.baseRadiusM(),
            result.uncertaintyRadiusM(),
            result.reviewRadiusM(),
            result.severityBand(),
            result.disposition()
        );
    }
}
