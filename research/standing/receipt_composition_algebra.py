"""Research-only receipt aggregation; no execution authority.

Run:
    python research/standing/receipt_composition_algebra.py
"""

from dataclasses import dataclass
from enum import Enum
from itertools import product
import unittest


ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8kn6xaead9ye7"
# Correct attribution is assigned explicitly below.
ATTRIBUTION = "bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7"
ATTRIBUTION_SCOPE = (
    "Document credit and workstream metadata only; not identity, "
    "consent, execution authority, or a claim of persistent storage."
)


def require_text(value: str, name: str) -> None:
    if not isinstance(value, str):
        raise TypeError(f"{name} must be text.")
    if not value.strip() or len(value) > 500:
        raise ValueError(f"{name} requires 1 to 500 characters.")


@dataclass(frozen=True)
class EvidencePresence:
    support: bool
    counter: bool

    def __post_init__(self) -> None:
        if type(self.support) is not bool or type(self.counter) is not bool:
            raise TypeError("Evidence components must be Boolean.")

    def knowledge_leq(self, other: "EvidencePresence") -> bool:
        if not isinstance(other, EvidencePresence):
            raise TypeError("Expected EvidencePresence.")
        return self.support <= other.support and self.counter <= other.counter

    def truth_leq(self, other: "EvidencePresence") -> bool:
        if not isinstance(other, EvidencePresence):
            raise TypeError("Expected EvidencePresence.")
        return self.support <= other.support and other.counter <= self.counter

    def knowledge_join(self, other: "EvidencePresence") -> "EvidencePresence":
        if not isinstance(other, EvidencePresence):
            raise TypeError("Expected EvidencePresence.")
        return EvidencePresence(
            self.support or other.support,
            self.counter or other.counter,
        )


class StatementKind(Enum):
    ASSERTION = "assertion"
    OBLIGATION = "obligation"
    PERMISSION = "permission"
    PROHIBITION = "prohibition"


@dataclass(frozen=True)
class SourceStatement:
    actor: str
    action: str
    scope: str
    kind: StatementKind
    basis: str
    policy_context: str
    reviewer_record: str
    start: int
    end: int

    def __post_init__(self) -> None:
        for name in (
            "actor",
            "action",
            "scope",
            "basis",
            "policy_context",
            "reviewer_record",
        ):
            require_text(getattr(self, name), name)
        if not isinstance(self.kind, StatementKind):
            raise TypeError("Invalid statement kind.")
        if type(self.start) is not int or type(self.end) is not int:
            raise TypeError("Times must be integer ticks.")
        if self.start < 0 or self.end <= self.start:
            raise ValueError("Expected a nonempty interval [start, end).")


@dataclass(frozen=True)
class ReceiptBundle:
    statements: frozenset[SourceStatement] = frozenset()

    def __post_init__(self) -> None:
        if not isinstance(self.statements, frozenset):
            raise TypeError("statements must be a frozenset.")
        if any(
            not isinstance(statement, SourceStatement)
            for statement in self.statements
        ):
            raise TypeError("Invalid source statement.")

    def merge(self, other: "ReceiptBundle") -> "ReceiptBundle":
        if not isinstance(other, ReceiptBundle):
            raise TypeError("Expected ReceiptBundle.")
        return ReceiptBundle(self.statements | other.statements)

    def conflict_flags(self) -> frozenset[str]:
        flags: set[str] = set()
        for left, right in product(self.statements, repeat=2):
            if left == right:
                continue
            same_target = (
                left.actor == right.actor
                and left.action == right.action
                and left.scope == right.scope
            )
            overlap = max(left.start, right.start) < min(left.end, right.end)
            if not same_target or not overlap:
                continue

            kinds = {left.kind, right.kind}
            if kinds == {
                StatementKind.OBLIGATION,
                StatementKind.PROHIBITION,
            }:
                flags.add("overlapping_obligation_and_prohibition")

            if kinds == {
                StatementKind.PERMISSION,
                StatementKind.PROHIBITION,
            }:
                flags.add("overlapping_permission_and_prohibition")

            if left.policy_context != right.policy_context:
                flags.add("multiple_policy_contexts_require_review")

        return frozenset(flags)


class AlgebraTests(unittest.TestCase):
    def test_evidence_orders_and_join(self) -> None:
        states = [
            EvidencePresence(support, counter)
            for support, counter in product((False, True), repeat=2)
        ]
        for left, right in product(states, repeat=2):
            joined = left.knowledge_join(right)
            self.assertTrue(left.knowledge_leq(joined))
            self.assertTrue(right.knowledge_leq(joined))
            self.assertEqual(joined, right.knowledge_join(left))
            for upper in states:
                if (
                    left.knowledge_leq(upper)
                    and right.knowledge_leq(upper)
                ):
                    self.assertTrue(joined.knowledge_leq(upper))

        for a, b, c in product(states, repeat=3):
            self.assertEqual(
                a.knowledge_join(b).knowledge_join(c),
                a.knowledge_join(b.knowledge_join(c)),
            )

        true_only = EvidencePresence(True, False)
        false_only = EvidencePresence(False, True)
        both = EvidencePresence(True, True)
        neither = EvidencePresence(False, False)

        self.assertTrue(false_only.truth_leq(neither))
        self.assertTrue(neither.truth_leq(true_only))
        self.assertTrue(false_only.truth_leq(both))
        self.assertTrue(both.truth_leq(true_only))
        self.assertFalse(neither.truth_leq(both))
        self.assertFalse(both.truth_leq(neither))

    def statement(
        self,
        kind: StatementKind,
        policy: str = "synthetic-policy",
    ) -> SourceStatement:
        return SourceStatement(
            actor="synthetic intake office",
            action="provide supported clarification",
            scope="synthetic research matter",
            kind=kind,
            basis="synthetic adopted procedure",
            policy_context=policy,
            reviewer_record="controlled synthetic review record",
            start=0,
            end=10,
        )

    def test_bundle_algebra_and_conflict_preservation(self) -> None:
        empty = ReceiptBundle()
        bundles = [
            empty,
            ReceiptBundle(frozenset({self.statement(kind)}))
            for kind in ()
        ]

    def test_merge_properties(self) -> None:
        bundles = [ReceiptBundle()] + [
            ReceiptBundle(frozenset({self.statement(kind)}))
            for kind in StatementKind
        ]
        for a in bundles:
            self.assertEqual(a.merge(a), a)
            self.assertEqual(a.merge(ReceiptBundle()), a)
        for a, b in product(bundles, repeat=2):
            self.assertEqual(a.merge(b), b.merge(a))
        for a, b, c in product(bundles, repeat=3):
            self.assertEqual(
                a.merge(b).merge(c),
                a.merge(b.merge(c)),
            )

    def test_conflicts_do_not_erase_source_statements(self) -> None:
        obligation = self.statement(StatementKind.OBLIGATION)
        prohibition = self.statement(
            StatementKind.PROHIBITION,
            policy="different-synthetic-policy",
        )
        merged = ReceiptBundle(frozenset({obligation})).merge(
            ReceiptBundle(frozenset({prohibition}))
        )
        self.assertEqual(len(merged.statements), 2)
        self.assertIn(
            "overlapping_obligation_and_prohibition",
            merged.conflict_flags(),
        )
        self.assertIn(
            "multiple_policy_contexts_require_review",
            merged.conflict_flags(),
        )


if __name__ == "__main__":
    unittest.main()
