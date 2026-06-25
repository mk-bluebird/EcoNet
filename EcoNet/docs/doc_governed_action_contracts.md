!-- filename doc_governed_action_contracts.md --
!-- destination EcoNet/docs/doc_governed_action_contracts.md --
!-- repo-target github.com/mk-bluebird/EcoNet --

# Governed Action Contracts and Hex Commitments

This document describes how governed action requests from AI-chat, agents, and platforms are turned into effective contracts via Virta-Sys, using strict hex commitments and HASHONLY semantics.

## 1. Roles and components

- GovernedActionRequest2026v1 (ALN)
- governed_action_request_2026v1 (SQLite)
- EffectiveActionContract2026v1 (ALN)
- effective_action_contract_2026v1 (SQLite)
- HexCommitmentPolicy2026v1 (ALN)
- Virta-Sys contract completion module

## 2. Request lifecycle

- A chat or agent issues a high-level request.
- The front-end generates a GovernedActionRequest row:
  - Binds identityid and soicref.
  - Computes payloadpartialhash and schemahash.
  - Fills neurorightsref and blacklistref.
  - Computes evidencehex and signinghex.
- The request is inserted into governed_action_request_2026v1 and becomes immutable.

## 3. Virta-Sys completion

- Virta-Sys loads the governed action request.
- It validates:
  - Neurorights policy via neurorightsref.
  - Blacklist policy via blacklistref.
- It decides:
  - lane, kerband, rohrisk via lane governors and KER/Lyapunov logic.
  - ecoimpactclass and topologyrisk via eco per-joule and topology audit.
- It completes payload:
  - Uses payloadschemaid definition to fill all required fields.
- It derives:
  - contenthashhex over the canonical contract object.
  - rohanchorhex encoding RoH and neurorights context.

The resulting EffectiveActionContract row in effective_action_contract_2026v1 is append-only and becomes the only object that actuator stacks and financial systems may trust.

## 4. Hex commitments and HASHONLY

HexCommitmentPolicy2026v1 defines which fields are commitments, which algorithm they use, and how canonicalization is performed.

Key fields include:

- identityhex, brainbindinghex, continuityhash
- neuroattributehash, medicalattributehash
- evidencehex, contenthashhex, rohanchorhex

All neuromedical commitments remain HASHONLY; no raw neuro or medical payloads are stored in governed or effective contract tables.

## 5. Integration expectations

- EcoNet and Eco-Fort:
  - Must use the provided SQL migrations and ALN specs as the canonical schemas.
- Virta-Sys:
  - Must use virta_sys_contract_completion.rs as the non-actuating completion engine, extended to call existing lane, KER, Lyapunov, neurorights, blacklist, and eco modules.
- Agents and AI-chat:
  - May only interact with contracts via ALN and the governed_action_request_2026v1 surface, never directly with actuators.

This pattern ensures that a consented request and AI response can serve as a complete contract while all sensitive details are protected behind mathematically verifiable hex commitments.
