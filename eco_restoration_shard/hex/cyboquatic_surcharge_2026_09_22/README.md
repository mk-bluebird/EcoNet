# Cyboquatic Surcharge Blast-Radius Shard

This artifact set evaluates wastewater/canal surcharge observations for restoration machinery safety. It is a decision-support and maintenance-triage tool, not an automated actuator or eligibility system.

## Domain selection

`2026-09-22` has digit sum `23`; `23 mod 7 = 2`, selecting the third zero-indexed task in the daily rotation: surcharge-breach blast-radius tables with SQLite indexes, C++, and Java.

## Layout

- `sql/cyboquatic_surcharge_shard.sql`: SQLite schema, strict invariants, indexed blast-radius views.
- `cpp/surcharge_blast_radius.cpp`: offline C++ evaluator with bounded inputs and explicit operator-review outputs.
- `java/SurchargeBlastRadius.java`: Java 21-compatible equivalent for workstation or gateway use.
- `kotlin/SurchargeReview.kt`: Kotlin review-gate model for accessible operator-facing decision support.
- `lua/surcharge_route.lua`: Lua FOG routing predicate for known and unmodeled media.
- `aln/surcharge_governance.aln`: ALN v2 provenance, consent, retention, review, and KER constraints.

## Safety boundary

No file controls pumps, valves, gates, chemical dosing, or other machinery. A `hold_for_human_review` result must be resolved through the authorized local safety procedure.

## Build

```sh
c++ -std=c++20 -O2 -Wall -Wextra -Wpedantic cpp/surcharge_blast_radius.cpp -o surcharge_blast_radius
javac --release 21 java/SurchargeBlastRadius.java
kotlinc kotlin/SurchargeReview.kt -include-runtime -d surcharge-review.jar
sqlite3 cyboquatic.db < sql/cyboquatic_surcharge_shard.sql
```

## Metrics

- `knowledge_factor`: 0.80; determined from field-validated sensors, calibration status, and complete provenance.
- `eco_impact_value`: 0.82; higher for promptly contained releases near restoration corridors.
- `harm_risk`: 0.28; conservative because field samples and unknown media require review.
- `accessibility_impact`: 0.88; supports human-readable reasons and non-punitive fallback review.
- `rights_alignment`: 0.94; minimizes disclosure, avoids identity inference, and requires authorized human review for consequential action.
