#!/usr/bin/env python3
"""
Local-only heat-island intervention provenance utility.

The implementation:
- validates a privacy-minimizing intervention record;
- canonicalizes JSON with deterministic UTF-8 sorted-key serialization;
- applies a restricted RFC 8785-compatible profile;
- produces and verifies SHA-256 commitments;
- validates closed method vocabularies;
- prevents source state from being promoted to locally verified when
  the required local bytes are unavailable.

Dependencies: Python standard library only.
Network access: none.
Hash algorithm: SHA-256 only.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import sys
import unicodedata
from decimal import Decimal
from pathlib import Path
from typing import Any

HEX_64 = re.compile(r"^[a-f0-9]{64}$")
LOCAL_ID = re.compile(r"^[a-z][a-z0-9_-]{7,127}$")
ZONE_ID = re.compile(r"^[a-z][a-z0-9_-]{2,159}$")
METHOD_CODE = re.compile(r"^[a-z][a-z0-9_]{2,63}$")
PATH_HINT = re.compile(r"^[a-zA-Z0-9._/-]{1,512}$")

SUPPORTED_SCHEMA_VERSION = "1.0.0"
REQUIRED_DECLARATION_FIELDS = {
    "schema_version",
    "record_type",
    "record_id",
    "created_at",
    "session_id",
    "intervention",
    "method_vocabulary",
    "source_reference",
    "retention",
    "previous_commitment_sha256",
    "commitment_sha256",
}

VALID_RECORD_TYPES = {
    "intervention_declaration",
    "intervention_evidence_binding",
    "intervention_review",
    "intervention_correction",
}

VALID_LOCATION_KINDS = {
    "public_asset_zone",
    "corridor_segment",
    "park_segment",
    "restoration_cell",
    "public_right_of_way_segment",
    "community_governed_zone",
}

VALID_LOCATION_NORMALIZATIONS = {
    "zone_reference_only",
    "rounded_grid_coordinates",
    "public_asset_boundary_generalized",
    "corridor_segment_generalized",
}

VALID_ROLES = {
    "planner",
    "field_steward",
    "installer",
    "maintenance_steward",
    "environmental_monitor",
    "municipal_reviewer",
    "community_observer",
}

VALID_METRICS = {
    "surface_temperature",
    "air_temperature",
    "mean_radiant_temperature",
    "heat_index",
    "thermal_comfort_proxy",
}

VALID_UNITS = {"degC", "degF", "index", "unitless"}

VALID_SOURCE_KINDS = {
    "local_measurement_export",
    "local_field_note",
    "local_work_record",
    "local_photo_bundle",
    "local_community_review_note",
    "local_maintenance_record",
}

VALID_VERIFICATION_STATES = {
    "declared_unverified",
    "locally_verified",
    "verification_failed",
    "superseded",
}

STATE_TO_MESSAGE = {
    "declared_unverified": "DECLARED; SOURCE BYTES NOT AVAILABLE LOCALLY",
    "locally_verified": "LOCALLY VERIFIED",
    "verification_failed": "VERIFICATION FAILED",
    "superseded": "INCOMPLETE RECORD",
}

ADDRESS_LIKE = re.compile(
    r"(?i)(\b\d{1,6}\s+[a-z0-9][a-z0-9 .'-]{1,80}\b"
    r"|\b(?:apt|apartment|unit|suite|room|lot|parcel|house)\b"
    r"|\b(?:st|street|ave|avenue|rd|road|dr|drive|blvd|boulevard|ln|lane)\b)"
)

PROHIBITED_LOCATION_TEXT = re.compile(
    r"(?i)(resident|household|tenant|owner|person|patient|device|account|"
    r"phone|email|biometric|neural|medical|credential)"
)


class ProvenanceError(ValueError):
    """Raised when a record violates local provenance or privacy invariants."""


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ProvenanceError(message)


def normalize_unicode(value: str) -> str:
    normalized = unicodedata.normalize("NFC", value)
    require(
        normalized == value,
        "all strings must already be normalized to Unicode NFC",
    )
    for character in value:
        category = unicodedata.category(character)
        require(
            category not in {"Cc", "Cs"},
            "control characters and surrogate code points are prohibited",
        )
    return normalized


def validate_json_value(value: Any) -> None:
    if value is None or isinstance(value, bool):
        return

    if isinstance(value, str):
        normalize_unicode(value)
        return

    if isinstance(value, int):
        return

    if isinstance(value, float):
        require(math.isfinite(value), "JSON numbers must be finite")
        require(
            value == 0.0 or not math.copysign(1.0, value) < 0.0,
            "negative zero is prohibited",
        )
        return

    if isinstance(value, list):
        for item in value:
            validate_json_value(item)
        return

    if isinstance(value, dict):
        for key, item in value.items():
            require(isinstance(key, str), "JSON object keys must be strings")
            normalize_unicode(key)
            validate_json_value(item)
        return

    raise ProvenanceError(f"unsupported JSON value type: {type(value).__name__}")


def canonical_number(value: int | float) -> str:
    """
    Restricted JCS-compatible numeric profile.

    Inputs accepted from standard JSON parsing are integers or finite floats.
    Integer values serialize as ordinary decimal integers. Floating-point values
    use a shortest round-trip decimal representation, reject negative zero,
    remove a redundant '.0', and normalize the exponent marker to lowercase.

    This profile is intended for local deterministic artifacts. Deployments
    requiring exact full RFC 8785 ECMAScript number serialization should use an
    independently tested JCS implementation and preserve these validation rules.
    """
    if isinstance(value, bool):
        raise ProvenanceError("booleans are not numbers")

    if isinstance(value, int):
        return str(value)

    require(math.isfinite(value), "JSON numbers must be finite")
    require(
        value == 0.0 or math.copysign(1.0, value) > 0.0,
        "negative zero is prohibited",
    )

    rendered = repr(value).lower()
    if rendered.endswith(".0") and "e" not in rendered:
        rendered = rendered[:-2]

    if "e" in rendered:
        mantissa, exponent = rendered.split("e", 1)
        exponent_integer = int(exponent)
        rendered = f"{mantissa}e{exponent_integer}"

    Decimal(rendered)
    return rendered


def canonical_json(value: Any) -> bytes:
    """
    Canonical JSON profile used by this repository:

    - UTF-8 encoding, no BOM;
    - all strings are Unicode NFC;
    - keys sorted lexicographically by Unicode code point;
    - no insignificant whitespace;
    - JSON strings use json.dumps escaping with ensure_ascii=False;
    - null remains literal null and is not omitted;
    - arrays preserve declared order;
    - finite numbers only; negative zero prohibited;
    - duplicate object keys rejected during parsing.
    """
    validate_json_value(value)

    if value is None:
        return b"null"

    if value is True:
        return b"true"

    if value is False:
        return b"false"

    if isinstance(value, str):
        return json.dumps(
            value,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")

    if isinstance(value, (int, float)) and not isinstance(value, bool):
        return canonical_number(value).encode("ascii")

    if isinstance(value, list):
        return (
            b"["
            + b",".join(canonical_json(item) for item in value)
            + b"]"
        )

    if isinstance(value, dict):
        keys = sorted(value.keys())
        rendered_items = []
        for key in keys:
            encoded_key = canonical_json(key)
            encoded_value = canonical_json(value[key])
            rendered_items.append(encoded_key + b":" + encoded_value)
        return b"{" + b",".join(rendered_items) + b"}"

    raise ProvenanceError(f"unsupported JSON value type: {type(value).__name__}")


def sha256_hex(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def commitment_for_record(record: dict[str, Any]) -> str:
    committed = dict(record)
    committed.pop("commitment_sha256", None)
    return sha256_hex(canonical_json(committed))


def parse_json_without_duplicate_keys(path: Path) -> Any:
    def reject_duplicates(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
        parsed: dict[str, Any] = {}
        for key, value in pairs:
            if key in parsed:
                raise ProvenanceError(f"duplicate JSON object key: {key!r}")
            parsed[key] = value
        return parsed

    try:
        with path.open("r", encoding="utf-8") as handle:
            return json.load(handle, object_pairs_hook=reject_duplicates)
    except FileNotFoundError as error:
        raise ProvenanceError(f"file not found: {path}") from error
    except UnicodeDecodeError as error:
        raise ProvenanceError(f"file is not valid UTF-8: {path}") from error
    except json.JSONDecodeError as error:
        raise ProvenanceError(f"invalid JSON in {path}: {error}") from error


def validate_sha256(value: Any, field: str, allow_null: bool = False) -> None:
    if value is None and allow_null:
        return
    require(
        isinstance(value, str) and HEX_64.fullmatch(value),
        f"{field} must be a lowercase 64-character SHA-256 digest",
    )


def validate_location(location: Any) -> None:
    require(isinstance(location, dict), "intervention.location must be an object")
    required = {
        "location_kind",
        "zone_reference",
        "location_precision_meters",
        "location_normalization",
    }
    missing = sorted(required.difference(location))
    require(not missing, f"location missing fields: {', '.join(missing)}")

    allowed = required | {"latitude", "longitude"}
    unexpected = sorted(set(location).difference(allowed))
    require(not unexpected, f"location has unexpected fields: {', '.join(unexpected)}")

    require(
        location["location_kind"] in VALID_LOCATION_KINDS,
        "location_kind is not permitted",
    )
    zone_reference = location["zone_reference"]
    require(
        isinstance(zone_reference, str) and ZONE_ID.fullmatch(zone_reference),
        "zone_reference must be a non-address local zone identifier",
    )
    require(
        not ADDRESS_LIKE.search(zone_reference)
        and not PROHIBITED_LOCATION_TEXT.search(zone_reference),
        "zone_reference contains prohibited person-adjacent or address-like content",
    )

    precision = location["location_precision_meters"]
    require(
        isinstance(precision, (int, float))
        and not isinstance(precision, bool)
        and math.isfinite(float(precision))
        and 10 <= precision <= 10000,
        "location_precision_meters must be between 10 and 10000",
    )

    normalization = location["location_normalization"]
    require(
        normalization in VALID_LOCATION_NORMALIZATIONS,
        "location_normalization is not permitted",
    )

    has_latitude = "latitude" in location
    has_longitude = "longitude" in location

    if normalization == "zone_reference_only":
        require(
            not has_latitude and not has_longitude,
            "zone_reference_only must not carry coordinates",
        )
        return

    require(
        has_latitude and has_longitude,
        "coordinate-based location normalization requires latitude and longitude",
    )
    latitude = location["latitude"]
    longitude = location["longitude"]
    require(
        isinstance(latitude, (int, float)) and -90 <= latitude <= 90,
        "latitude must be numeric and within [-90, 90]",
    )
    require(
        isinstance(longitude, (int, float)) and -180 <= longitude <= 180,
        "longitude must be numeric and within [-180, 180]",
    )


def validate_method_vocabulary(vocabulary: Any) -> set[str]:
    require(isinstance(vocabulary, dict), "method vocabulary must be an object")
    required = {
        "vocabulary_id",
        "vocabulary_version",
        "description",
        "method_codes",
        "prohibited_method_content",
        "extension_rule",
    }
    missing = sorted(required.difference(vocabulary))
    require(not missing, f"method vocabulary missing fields: {', '.join(missing)}")
    require(
        vocabulary["vocabulary_id"] == "heat_island_method_vocabulary",
        "unexpected vocabulary_id",
    )
    require(
        isinstance(vocabulary["vocabulary_version"], str)
        and re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", vocabulary["vocabulary_version"]),
        "vocabulary_version must follow semantic version syntax",
    )
    require(
        isinstance(vocabulary["method_codes"], list)
        and len(vocabulary["method_codes"]) > 0,
        "method_codes must be a non-empty list",
    )

    codes = set()
    for code in vocabulary["method_codes"]:
        require(
            isinstance(code, str) and METHOD_CODE.fullmatch(code),
            "every method code must be a constrained categorical identifier",
        )
        require(
            code not in codes,
            f"duplicate method code: {code}",
        )
        codes.add(code)

    return codes


def validate_method_binding(record: dict[str, Any], vocabulary: dict[str, Any]) -> None:
    method_codes = validate_method_vocabulary(vocabulary)
    binding = record["method_vocabulary"]
    require(isinstance(binding, dict), "method_vocabulary must be an object")
    require(
        binding.get("vocabulary_id") == vocabulary["vocabulary_id"],
        "method vocabulary identifier does not match local vocabulary",
    )
    require(
        binding.get("vocabulary_version") == vocabulary["vocabulary_version"],
        "method vocabulary version does not match local vocabulary",
    )
    expected_digest = sha256_hex(canonical_json(vocabulary))
    require(
        binding.get("vocabulary_sha256") == expected_digest,
        "method vocabulary SHA-256 digest does not match local vocabulary",
    )

    method = record["intervention"]["method"]
    require(isinstance(method, dict), "intervention.method must be an object")
    code = method.get("method_code")
    require(
        isinstance(code, str) and METHOD_CODE.fullmatch(code),
        "method_code is malformed",
    )
    require(
        code in method_codes,
        "method_code is not in the locally verified closed vocabulary",
    )


def validate_intervention(intervention: Any, session_id: str) -> None:
    require(isinstance(intervention, dict), "intervention must be an object")
    required = {"location", "method", "heat_metric_H", "role", "session"}
    missing = sorted(required.difference(intervention))
    require(not missing, f"intervention missing fields: {', '.join(missing)}")
    require(
        set(intervention).issubset(required),
        "intervention contains undeclared fields",
    )

    validate_location(intervention["location"])

    require(intervention["role"] in VALID_ROLES, "intervention role is not permitted")
    require(
        intervention["session"] == session_id,
        "intervention session must exactly match top-level session_id",
    )

    heat_metric = intervention["heat_metric_H"]
    require(isinstance(heat_metric, dict), "heat_metric_H must be an object")
    heat_required = {"metric", "value", "unit", "measurement_window"}
    require(
        heat_required.issubset(heat_metric),
        "heat_metric_H is missing required fields",
    )
    require(
        heat_metric["metric"] in VALID_METRICS,
        "heat metric is not permitted",
    )
    require(
        isinstance(heat_metric["value"], (int, float))
        and not isinstance(heat_metric["value"], bool)
        and math.isfinite(float(heat_metric["value"])),
        "heat metric value must be finite and numeric",
    )
    require(heat_metric["unit"] in VALID_UNITS, "heat metric unit is not permitted")
    require(
        isinstance(heat_metric["measurement_window"], str)
        and ZONE_ID.fullmatch(heat_metric["measurement_window"]),
        "measurement_window must be a local non-personal identifier",
    )


def validate_source_reference(source_reference: Any) -> None:
    require(isinstance(source_reference, dict), "source_reference must be an object")
    required = {
        "source_kind",
        "source_commitment_sha256",
        "verification_state",
        "verification_message",
    }
    missing = sorted(required.difference(source_reference))
    require(not missing, f"source_reference missing fields: {', '.join(missing)}")

    allowed = required | {"local_source_relative_path"}
    unexpected = sorted(set(source_reference).difference(allowed))
    require(
        not unexpected,
        f"source_reference has unexpected fields: {', '.join(unexpected)}",
    )

    require(
        source_reference["source_kind"] in VALID_SOURCE_KINDS,
        "source_kind is not permitted",
    )
    validate_sha256(
        source_reference["source_commitment_sha256"],
        "source_commitment_sha256",
    )

    state = source_reference["verification_state"]
    require(
        state in VALID_VERIFICATION_STATES,
        "verification_state is not permitted",
    )
    require(
        source_reference["verification_message"] == STATE_TO_MESSAGE[state],
        "verification_message does not match verification_state",
    )

    path_hint = source_reference.get("local_source_relative_path")
    if path_hint is not None:
        require(
            isinstance(path_hint, str) and PATH_HINT.fullmatch(path_hint),
            "local_source_relative_path is malformed",
        )


def validate_record_structure(record: Any, vocabulary: dict[str, Any]) -> None:
    require(isinstance(record, dict), "record must be an object")
    missing = sorted(REQUIRED_DECLARATION_FIELDS.difference(record))
    require(not missing, f"record missing fields: {', '.join(missing)}")
    unexpected = sorted(set(record).difference(REQUIRED_DECLARATION_FIELDS))
    require(not unexpected, f"record has unexpected fields: {', '.join(unexpected)}")

    require(
        record["schema_version"] == SUPPORTED_SCHEMA_VERSION,
        "unsupported schema_version",
    )
    require(
        record["record_type"] in VALID_RECORD_TYPES,
        "record_type is not permitted",
    )
    require(
        isinstance(record["record_id"], str) and LOCAL_ID.fullmatch(record["record_id"]),
        "record_id must be a local non-personal identifier",
    )
    require(
        isinstance(record["session_id"], str) and LOCAL_ID.fullmatch(record["session_id"]),
        "session_id must be a local non-personal identifier",
    )
    require(
        isinstance(record["created_at"], str)
        and record["created_at"].endswith("+00:00"),
        "created_at must be an explicit UTC timestamp",
    )

    validate_intervention(record["intervention"], record["session_id"])
    validate_method_binding(record, vocabulary)
    validate_source_reference(record["source_reference"])

    retention = record["retention"]
    require(isinstance(retention, dict), "retention must be an object")
    require(
        set(retention) == {"retain_until", "deletion_method"},
        "retention must contain only retain_until and deletion_method",
    )
    require(
        isinstance(retention["retain_until"], str)
        and retention["retain_until"].endswith("+00:00"),
        "retain_until must be an explicit UTC timestamp",
    )
    require(
        retention["deletion_method"]
        in {"secure_local_deletion", "cryptographic_erasure", "archival_review_required"},
        "deletion_method is not permitted",
    )

    validate_sha256(
        record["previous_commitment_sha256"],
        "previous_commitment_sha256",
        allow_null=True,
    )
    validate_sha256(record["commitment_sha256"], "commitment_sha256")


def verify_source_bytes(record: dict[str, Any], source_path: Path | None) -> dict[str, Any]:
    """
    Preserves declared-versus-verified state.

    No path, unreadable file, or unavailable source bytes produce
    declared_unverified. A digest mismatch produces verification_failed.
    Only exact locally available bytes may produce locally_verified.
    """
    expected = record["source_reference"]["source_commitment_sha256"]

    if source_path is None:
        return {
            "verification_state": "declared_unverified",
            "verification_message": STATE_TO_MESSAGE["declared_unverified"],
            "reason": "No local source path was supplied to the reviewing device.",
        }

    try:
        source_bytes = source_path.read_bytes()
    except OSError:
        return {
            "verification_state": "declared_unverified",
            "verification_message": STATE_TO_MESSAGE["declared_unverified"],
            "reason": "The declared source bytes are not available locally.",
        }

    actual = sha256_hex(source_bytes)
    if actual != expected:
        return {
            "verification_state": "verification_failed",
            "verification_message": STATE_TO_MESSAGE["verification_failed"],
            "reason": "Local source bytes do not match the declared SHA-256 commitment.",
            "actual_source_commitment_sha256": actual,
        }

    return {
        "verification_state": "locally_verified",
        "verification_message": STATE_TO_MESSAGE["locally_verified"],
        "reason": "Local source bytes match the declared SHA-256 commitment.",
        "actual_source_commitment_sha256": actual,
    }


def verify_record(
    record: dict[str, Any],
    vocabulary: dict[str, Any],
    predecessor: str | None,
    source_path: Path | None,
) -> dict[str, Any]:
    try:
        validate_record_structure(record, vocabulary)

        require(
            record["previous_commitment_sha256"] == predecessor,
            "predecessor commitment does not match the expected local chain head",
        )

        expected_record_commitment = commitment_for_record(record)
        require(
            expected_record_commitment == record["commitment_sha256"],
            "record commitment does not match canonical record bytes",
        )

        source_report = verify_source_bytes(record, source_path)
        declared_state = record["source_reference"]["verification_state"]

        if declared_state == "locally_verified":
            require(
                source_report["verification_state"] == "locally_verified",
                "record claims local verification but local evidence bytes do not verify",
            )

        if source_report["verification_state"] == "verification_failed":
            return {
                "review_status": "verification_failed",
                "message": STATE_TO_MESSAGE["verification_failed"],
                "record_commitment_sha256": record["commitment_sha256"],
                "source": source_report,
            }

        if source_report["verification_state"] != "locally_verified":
            return {
                "review_status": "declared_unverified",
                "message": STATE_TO_MESSAGE["declared_unverified"],
                "record_commitment_sha256": record["commitment_sha256"],
                "source": source_report,
            }

        return {
            "review_status": "locally_verified",
            "message": STATE_TO_MESSAGE["locally_verified"],
            "record_commitment_sha256": record["commitment_sha256"],
            "source": source_report,
        }

    except ProvenanceError as error:
        return {
            "review_status": "incomplete_or_invalid",
            "message": STATE_TO_MESSAGE["verification_failed"],
            "reason": str(error),
        }


def command_digest_vocabulary(args: argparse.Namespace) -> int:
    vocabulary = parse_json_without_duplicate_keys(Path(args.vocabulary))
    validate_method_vocabulary(vocabulary)
    print(sha256_hex(canonical_json(vocabulary)))
    return 0


def command_canonicalize(args: argparse.Namespace) -> int:
    value = parse_json_without_duplicate_keys(Path(args.input))
    sys.stdout.buffer.write(canonical_json(value))
    sys.stdout.buffer.write(b"\n")
    return 0


def command_verify(args: argparse.Namespace) -> int:
    record = parse_json_without_duplicate_keys(Path(args.record))
    vocabulary = parse_json_without_duplicate_keys(Path(args.vocabulary))

    predecessor = args.predecessor
    if predecessor == "null":
        predecessor_value: str | None = None
    else:
        validate_sha256(predecessor, "--predecessor")
        predecessor_value = predecessor

    source_path = Path(args.source) if args.source else None
    report = verify_record(
        record=record,
        vocabulary=vocabulary,
        predecessor=predecessor_value,
        source_path=source_path,
    )
    print(json.dumps(report, sort_keys=True, indent=2))
    return 0 if report["review_status"] == "locally_verified" else 3


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Local-only heat-island intervention provenance verifier."
    )
    commands = parser.add_subparsers(dest="command", required=True)

    digest_vocabulary = commands.add_parser(
        "digest-vocabulary",
        help="Validate and SHA-256 commit a local closed method vocabulary.",
    )
    digest_vocabulary.add_argument("--vocabulary", required=True)
    digest_vocabulary.set_defaults(handler=command_digest_vocabulary)

    canonicalize = commands.add_parser(
        "canonicalize",
        help="Emit deterministic canonical JSON bytes for a local JSON value.",
    )
    canonicalize.add_argument("--input", required=True)
    canonicalize.set_defaults(handler=command_canonicalize)

    verify = commands.add_parser(
        "verify",
        help="Verify a local intervention record, vocabulary binding, chain link, and source bytes.",
    )
    verify.add_argument("--record", required=True)
    verify.add_argument("--vocabulary", required=True)
    verify.add_argument(
        "--predecessor",
        required=True,
        help="Expected predecessor SHA-256 digest or literal null for a genesis record.",
    )
    verify.add_argument(
        "--source",
        help="Optional local source file. Its absence cannot produce locally_verified status.",
    )
    verify.set_defaults(handler=command_verify)

    return parser


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    try:
        return args.handler(args)
    except (ProvenanceError, OSError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
