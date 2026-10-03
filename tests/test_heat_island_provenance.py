from __future__ import annotations

import hashlib
import importlib.util
import tempfile
import unittest
from pathlib import Path

MODULE_PATH = Path(__file__).resolve().parents[1] / "python" / "heat_island_provenance.py"
SPEC = importlib.util.spec_from_file_location("heat_island_provenance", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
provenance = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(provenance)


class HeatIslandProvenanceTests(unittest.TestCase):
    def vocabulary(self) -> dict:
        return {
            "vocabulary_id": "heat_island_method_vocabulary",
            "vocabulary_version": "1.0.0",
            "description": (
                "Closed categorical local vocabulary for heat-island interventions."
            ),
            "method_codes": [
                "tree_canopy",
                "cool_roof",
                "cool_pavement",
                "shade_structure",
                "permeable_surface",
                "monitoring_only"
            ],
            "prohibited_method_content": [
                "free_text",
                "person_name",
                "residential_address",
                "organization_name"
            ],
            "extension_rule": {
                "automatic_extension": False,
                "required_process": [
                    "review",
                    "version",
                    "sha256_commitment"
                ],
                "retroactive_relabeling": False
            }
        }

    def record(self, source_bytes: bytes) -> dict:
        vocabulary = self.vocabulary()
        vocabulary_digest = provenance.sha256_hex(provenance.canonical_json(vocabulary))
        source_digest = hashlib.sha256(source_bytes).hexdigest()

        record = {
            "schema_version": "1.0.0",
            "record_type": "intervention_declaration",
            "record_id": "intervention_0001",
            "created_at": "2026-10-02T17:19:00+00:00",
            "session_id": "summer_recovery_2026",
            "intervention": {
                "location": {
                    "location_kind": "corridor_segment",
                    "zone_reference": "north_cooling_corridor_a",
                    "location_precision_meters": 50,
                    "location_normalization": "zone_reference_only"
                },
                "method": {
                    "method_code": "tree_canopy"
                },
                "heat_metric_H": {
                    "metric": "surface_temperature",
                    "value": 43.2,
                    "unit": "degC",
                    "measurement_window": "summer_afternoon_window"
                },
                "role": "field_steward",
                "session": "summer_recovery_2026"
            },
            "method_vocabulary": {
                "vocabulary_id": "heat_island_method_vocabulary",
                "vocabulary_version": "1.0.0",
                "vocabulary_sha256": vocabulary_digest
            },
            "source_reference": {
                "source_kind": "local_field_note",
                "source_commitment_sha256": source_digest,
                "verification_state": "declared_unverified",
                "verification_message": "DECLARED; SOURCE BYTES NOT AVAILABLE LOCALLY"
            },
            "retention": {
                "retain_until": "2031-10-02T00:00:00+00:00",
                "deletion_method": "secure_local_deletion"
            },
            "previous_commitment_sha256": None,
            "commitment_sha256": ""
        }
        record["commitment_sha256"] = provenance.commitment_for_record(record)
        return record

    def test_canonical_json_is_deterministic_for_reordered_objects(self) -> None:
        first = {
            "z": [3, 2, 1],
            "a": {"unicode": "café", "null_value": None}
        }
        second = {
            "a": {"null_value": None, "unicode": "café"},
            "z": [3, 2, 1]
        }

        self.assertEqual(
            provenance.canonical_json(first),
            provenance.canonical_json(second),
        )
        self.assertEqual(
            provenance.sha256_hex(provenance.canonical_json(first)),
            provenance.sha256_hex(provenance.canonical_json(second)),
        )

    def test_unavailable_source_remains_declared_unverified(self) -> None:
        source_bytes = b"local field note"
        record = self.record(source_bytes)

        report = provenance.verify_record(
            record=record,
            vocabulary=self.vocabulary(),
            predecessor=None,
            source_path=None,
        )

        self.assertEqual(report["review_status"], "declared_unverified")
        self.assertEqual(
            report["message"],
            "DECLARED; SOURCE BYTES NOT AVAILABLE LOCALLY",
        )

    def test_matching_local_source_becomes_locally_verified(self) -> None:
        source_bytes = b"local field note"
        record = self.record(source_bytes)

        with tempfile.TemporaryDirectory() as directory:
            source_path = Path(directory) / "field-note.txt"
            source_path.write_bytes(source_bytes)

            report = provenance.verify_record(
                record=record,
                vocabulary=self.vocabulary(),
                predecessor=None,
                source_path=source_path,
            )

        self.assertEqual(report["review_status"], "locally_verified")
        self.assertEqual(report["message"], "LOCALLY VERIFIED")

    def test_claimed_local_verification_fails_when_source_is_absent(self) -> None:
        source_bytes = b"local field note"
        record = self.record(source_bytes)
        record["source_reference"]["verification_state"] = "locally_verified"
        record["source_reference"]["verification_message"] = "LOCALLY VERIFIED"
        record["commitment_sha256"] = provenance.commitment_for_record(record)

        report = provenance.verify_record(
            record=record,
            vocabulary=self.vocabulary(),
            predecessor=None,
            source_path=None,
        )

        self.assertEqual(report["review_status"], "incomplete_or_invalid")

    def test_location_rejects_address_like_zone_reference(self) -> None:
        source_bytes = b"local field note"
        record = self.record(source_bytes)
        record["intervention"]["location"]["zone_reference"] = "123_main_street"
        record["commitment_sha256"] = provenance.commitment_for_record(record)

        report = provenance.verify_record(
            record=record,
            vocabulary=self.vocabulary(),
            predecessor=None,
            source_path=None,
        )

        self.assertEqual(report["review_status"], "incomplete_or_invalid")

    def test_method_must_be_in_closed_vocabulary(self) -> None:
        source_bytes = b"local field note"
        record = self.record(source_bytes)
        record["intervention"]["method"]["method_code"] = "vendor_named_shade_system"
        record["commitment_sha256"] = provenance.commitment_for_record(record)

        report = provenance.verify_record(
            record=record,
            vocabulary=self.vocabulary(),
            predecessor=None,
            source_path=None,
        )

        self.assertEqual(report["review_status"], "incomplete_or_invalid")

    def test_record_mutation_breaks_commitment(self) -> None:
        source_bytes = b"local field note"
        record = self.record(source_bytes)
        record["intervention"]["heat_metric_H"]["value"] = 49.9

        report = provenance.verify_record(
            record=record,
            vocabulary=self.vocabulary(),
            predecessor=None,
            source_path=None,
        )

        self.assertEqual(report["review_status"], "incomplete_or_invalid")

    def test_invalid_predecessor_fails_closed(self) -> None:
        source_bytes = b"local field note"
        record = self.record(source_bytes)

        report = provenance.verify_record(
            record=record,
            vocabulary=self.vocabulary(),
            predecessor="f" * 64,
            source_path=None,
        )

        self.assertEqual(report["review_status"], "incomplete_or_invalid")


if __name__ == "__main__":
    unittest.main()
