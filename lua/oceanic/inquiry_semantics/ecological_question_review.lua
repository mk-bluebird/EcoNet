-- SPDX-License-Identifier: MIT OR Apache-2.0
--
-- Ecological Question Review
-- Lua 5.4.7 or later. Standard library only.
--
-- Credit:
-- bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
--
-- Credit is document attribution and configured workstream metadata only.
-- It establishes no identity, consent, authorization, or authority.
--
-- PUBLIC-SOURCE NOTICE
-- This file contains no field observations, credentials, private locations,
-- participant records, external integrations, or embedded operational data.
--
-- DATA-HANDLING CONTRACT
-- No I/O, logging, networking, storage, callbacks, or actuation is performed.
-- normalize() returns copied supplied text: treat that result as restricted.
-- evaluate() and screen() do not return supplied text, but their metadata may
-- still reveal sensitive context. Do not automatically publish their outputs.
-- public_notice() consumes no question data and returns fixed wording.
--
-- SCOPE
-- Structural screening only.
-- No scientific review, applicability verification, permission determination,
-- prediction, model fitting, diagnosis, or participant ranking.
--
-- INPUT FORMAT
-- Lua tables only.
-- nil means absence. Explicit JSON null is outside this interface.
-- No automatic translation, trimming, case folding, or Unicode normalization.
--
-- SUCCESS ENVELOPE
-- {ok=true,value=...}
--
-- ERROR ENVELOPE
-- {ok=false,error={code=...,path=...,message_key=...,args={}}}
--
-- MODULE EXPORTS
-- describe()
-- normalize(raw)
-- screen(normalized)
-- evaluate(raw)
-- public_notice()
-- self_test()
--
-- Exported tables are ordinary Lua tables, not a security or immutable-type
-- boundary. Internal policy constants are captured locally.

if type(utf8) ~= "table"
    or type(utf8.codes) ~= "function" then
    error("ENV_UTF8_LIBRARY_REQUIRED", 0)
end

local M = {}

local MODULE_VERSION = "1.0.0"
local SCHEMA_VERSION = 1
local FIELD_SET_VERSION = "1.0.0"
local INTENT_RULE_VERSION = "1.0.0"
local TEXT_POLICY_VERSION = "1.0.0"
local OUTCOME_SET_VERSION = "1.0.0"

local MAX_TEXT_BYTES = 4000

local CORE_FIELDS = {
    "subject",
    "relationship",
    "response",
    "spatial_scope",
    "temporal_scope",
    "measurement_basis",
    "evidence_basis"
}

local INTENT_ORDER = {
    "describe",
    "compare",
    "explain",
    "forecast",
    "design_monitoring"
}

local FIELD_ORDER = {
    "subject",
    "relationship",
    "response",
    "spatial_scope",
    "temporal_scope",
    "measurement_basis",
    "evidence_basis",
    "comparison_basis",
    "competing_explanations",
    "event_definition",
    "issue_time",
    "forecast_horizon",
    "evaluation_basis",
    "sampling_basis",
    "forecast_alignment"
}

local ATOMIC_REQUIREMENTS = {
    describe = {},
    compare = {"comparison_basis"},
    explain = {"competing_explanations"},
    forecast = {
        "event_definition",
        "issue_time",
        "forecast_horizon",
        "evaluation_basis"
    },
    design_monitoring = {"sampling_basis"}
}

local STATE_ORDER = {
    "supplied",
    "unknown",
    "not_collected",
    "withheld",
    "declared_not_applicable",
    "absent"
}

local FIELD_SET = {}
local INTENT_SET = {}
local TAG_SET = {}

for _, field in ipairs(FIELD_ORDER) do
    FIELD_SET[field] = true
end

for _, intent in ipairs(INTENT_ORDER) do
    INTENT_SET[intent] = true
end

for _, state in ipairs(STATE_ORDER) do
    if state ~= "absent" then
        TAG_SET[state] = true
    end
end

local PLACEHOLDER_ORDER = {
    "TODO",
    "TBD",
    "<placeholder>"
}

local PLACEHOLDERS = {}
for _, value in ipairs(PLACEHOLDER_ORDER) do
    PLACEHOLDERS[value] = true
end

-- Explicit application policy, not a runtime Unicode database.
local WHITESPACE = {
    [0x0009] = true,
    [0x000A] = true,
    [0x000B] = true,
    [0x000C] = true,
    [0x000D] = true,
    [0x0020] = true,
    [0x0085] = true,
    [0x00A0] = true,
    [0x1680] = true,
    [0x2000] = true,
    [0x2001] = true,
    [0x2002] = true,
    [0x2003] = true,
    [0x2004] = true,
    [0x2005] = true,
    [0x2006] = true,
    [0x2007] = true,
    [0x2008] = true,
    [0x2009] = true,
    [0x200A] = true,
    [0x2028] = true,
    [0x2029] = true,
    [0x202F] = true,
    [0x205F] = true,
    [0x3000] = true
}

local function ok(value)
    return {ok = true, value = value}
end

local function fail(code, path)
    return {
        ok = false,
        error = {
            code = code,
            path = path,
            message_key = "ecological_question_review." .. code,
            args = {}
        }
    }
end

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function copy_array(input)
    local output = {}
    for i, value in ipairs(input) do
        output[i] = value
    end
    return output
end

local function shape(value, required, optional, path)
    if type(value) ~= "table" then
        return fail("E_RECORD_TYPE", path)
    end
    if getmetatable(value) ~= nil then
        return fail("E_METATABLE", path)
    end

    local allowed = {}
    local maximum = #required + #optional

    for _, key in ipairs(required) do
        allowed[key] = true
        if rawget(value, key) == nil then
            return fail("E_MISSING_MEMBER", path)
        end
    end

    for _, key in ipairs(optional) do
        allowed[key] = true
    end

    local count = 0
    for key in next, value do
        count = count + 1
        if count > maximum or not allowed[key] then
            return fail("E_UNKNOWN_MEMBER", path)
        end
    end

    return ok(true)
end

local function array_length(value, maximum, allow_empty, path)
    if not plain(value) then
        return fail("E_ARRAY_TYPE", path)
    end

    local count, highest = 0, 0

    for key in next, value do
        count = count + 1

        if count > maximum then
            return fail("E_ARRAY_LIMIT", path)
        end

        if type(key) ~= "number"
            or key % 1 ~= 0
            or key < 1
            or key > maximum then
            return fail("E_ARRAY_SHAPE", path)
        end

        if key > highest then
            highest = key
        end
    end

    if count ~= highest or (count == 0 and not allow_empty) then
        return fail("E_ARRAY_SHAPE", path)
    end

    return ok(count)
end

local function inspect_text(value)
    if type(value) ~= "string" then
        return fail("E_TEXT_TYPE", "input.frame.declaration")
    end

    if #value > MAX_TEXT_BYTES then
        return fail("E_TEXT_LIMIT", "input.frame.declaration")
    end

    if #value == 0 then
        return fail("E_TEXT_EMPTY", "input.frame.declaration")
    end

    local whitespace_only = true
    local non_ascii_whitespace = false
    local contains_c1 = false
    local forbidden_control = false

    local valid = pcall(function()
        for _, codepoint in utf8.codes(value) do
            if codepoint > 0x10FFFF
                or (codepoint >= 0xD800 and codepoint <= 0xDFFF) then
                error("invalid_unicode_scalar", 0)
            end

            if not WHITESPACE[codepoint] then
                whitespace_only = false
            elseif codepoint > 0x7F then
                non_ascii_whitespace = true
            end

            if codepoint >= 0x80 and codepoint <= 0x9F then
                contains_c1 = true
            end

            if codepoint == 0x7F
                or (codepoint < 0x20
                    and codepoint ~= 0x09
                    and codepoint ~= 0x0A
                    and codepoint ~= 0x0D) then
                forbidden_control = true
            end
        end
    end)

    if not valid then
        return fail("E_TEXT_UTF8", "input.frame.declaration")
    end

    if forbidden_control then
        return fail("E_TEXT_CONTROL", "input.frame.declaration")
    end

    if whitespace_only and not non_ascii_whitespace then
        return fail("E_TEXT_EMPTY", "input.frame.declaration")
    end

    local reviews = {}

    if whitespace_only and non_ascii_whitespace then
        reviews[#reviews + 1] = "R_UNICODE_WHITESPACE_ONLY"
    end

    if contains_c1 then
        reviews[#reviews + 1] = "R_C1_CONTROL_PRESENT"
    end

    if PLACEHOLDERS[value] then
        reviews[#reviews + 1] = "R_REGISTERED_PLACEHOLDER_TEXT"
    end

    return ok(reviews)
end

local function validate_declaration(value)
    local checked = shape(
        value,
        {"tag"},
        {"text"},
        "input.frame.declaration"
    )
    if not checked.ok then
        return checked
    end

    if type(value.tag) ~= "string" or not TAG_SET[value.tag] then
        return fail("E_DECLARATION_TAG", "input.frame.declaration")
    end

    if value.tag ~= "supplied" then
        if rawget(value, "text") ~= nil then
            return fail("E_UNEXPECTED_CONTENT", "input.frame.declaration")
        end
        return ok({})
    end

    if rawget(value, "text") == nil then
        return fail("E_TEXT_MISSING", "input.frame.declaration")
    end

    return inspect_text(value.text)
end

local function validate(raw)
    local checked = shape(
        raw,
        {"schema_version", "intents", "frame"},
        {},
        "input"
    )
    if not checked.ok then
        return checked
    end

    if raw.schema_version ~= SCHEMA_VERSION then
        return fail("E_SCHEMA_VERSION", "input.schema_version")
    end

    checked = array_length(
        raw.intents, #INTENT_ORDER, false, "input.intents")
    if not checked.ok then
        return checked
    end

    local selected = {}

    for _, intent in ipairs(raw.intents) do
        if type(intent) ~= "string" or not INTENT_SET[intent] then
            return fail("E_INTENT_VALUE", "input.intents")
        end
        if selected[intent] then
            return fail("E_INTENT_DUPLICATE", "input.intents")
        end
        selected[intent] = true
    end

    if not plain(raw.frame) then
        return fail("E_FRAME_TYPE", "input.frame")
    end

    local count = 0
    for field in next, raw.frame do
        count = count + 1
        if count > #FIELD_ORDER
            or type(field) ~= "string"
            or not FIELD_SET[field] then
            return fail("E_UNKNOWN_MEMBER", "input.frame")
        end
    end

    -- Registry order makes validation-error precedence deterministic.
    for _, field in ipairs(FIELD_ORDER) do
        local declaration = rawget(raw.frame, field)
        if declaration ~= nil then
            checked = validate_declaration(declaration)
            if not checked.ok then
                return checked
            end
        end
    end

    return ok(selected)
end

local function normalize_validated(raw, selected)
    local output = {
        schema_version = SCHEMA_VERSION,
        intents = {},
        frame = {}
    }

    for _, intent in ipairs(INTENT_ORDER) do
        if selected[intent] then
            output.intents[#output.intents + 1] = intent
        end
    end

    for _, field in ipairs(FIELD_ORDER) do
        local declaration = rawget(raw.frame, field)
        if declaration ~= nil then
            local copied = {tag = declaration.tag}
            if declaration.tag == "supplied" then
                copied.text = declaration.text
            end
            output.frame[field] = copied
        end
    end

    return output
end

local function requirements(selected)
    local required = {}
    for _, field in ipairs(CORE_FIELDS) do
        required[field] = true
    end

    for _, intent in ipairs(INTENT_ORDER) do
        if selected[intent] then
            for _, field in ipairs(ATOMIC_REQUIREMENTS[intent]) do
                required[field] = true
            end
        end
    end

    local interactions = {}

    if selected.compare and selected.forecast then
        required.forecast_alignment = true
        interactions[1] = {
            rule_code = "R_COMPARE_FORECAST_ALIGNMENT",
            rule_version = INTENT_RULE_VERSION,
            triggering_intents = {"compare", "forecast"},
            introduced_fields = {"forecast_alignment"},
            satisfaction = "not_assessed"
        }
    end

    local ordered = {}
    for _, field in ipairs(FIELD_ORDER) do
        if required[field] then
            ordered[#ordered + 1] = field
        end
    end

    return ordered, required, interactions
end

local function build_report(normalized, selected)
    local ordered, required_set, interactions = requirements(selected)

    if #ordered == 0 then
        return fail("E_REGISTRY_CONTRACT", "registry")
    end

    local partition = {}
    for _, state in ipairs(STATE_ORDER) do
        partition[state] = {}
    end

    local clarifications = {}
    local review_items = {}
    local additional = {}
    local declared_count, supplied_count = 0, 0

    for _, field in ipairs(ordered) do
        local declaration = rawget(normalized.frame, field)
        local state = declaration and declaration.tag or "absent"
        local bucket = partition[state]
        bucket[#bucket + 1] = field

        if declaration then
            declared_count = declared_count + 1
        end

        if state == "supplied" then
            supplied_count = supplied_count + 1
        else
            clarifications[#clarifications + 1] = {
                field = field,
                declaration_tag = state,
                prompt_key = state == "withheld"
                    and "question.review_narrower_scope"
                    or "question.review_declared_gap",
                participation_required = false,
                disclosure_required = false
            }
        end
    end

    for _, field in ipairs(FIELD_ORDER) do
        local declaration = rawget(normalized.frame, field)

        if declaration then
            if not required_set[field] then
                additional[#additional + 1] = field
            end

            if declaration.tag == "supplied" then
                local inspected = inspect_text(declaration.text)
                for _, code in ipairs(inspected.value) do
                    review_items[#review_items + 1] = {
                        field = field,
                        code = code,
                        scope = "text_policy_only"
                    }
                end
            end
        end
    end

    local outcome = "structurally_accepted"
    if #clarifications > 0 or #review_items > 0 then
        outcome = "accepted_with_clarifications"
    end

    return ok({
        module_version = MODULE_VERSION,
        schema_version = SCHEMA_VERSION,
        field_set_version = FIELD_SET_VERSION,
        intent_rule_version = INTENT_RULE_VERSION,
        text_policy_version = TEXT_POLICY_VERSION,
        outcome_set_version = OUTCOME_SET_VERSION,
        outcome = outcome,
        canonical_intents = copy_array(normalized.intents),
        required_fields = ordered,
        declaration_partition = partition,
        additional_declared_fields = additional,
        interaction_records = interactions,
        clarifications = clarifications,
        review_items = review_items,
        coverage = {
            required_count = #ordered,
            declared_count = declared_count,
            supplied_count = supplied_count,
            declaration_ratio = declared_count / #ordered,
            supplied_ratio = supplied_count / #ordered,
            denominator_scope = "registered_required_fields"
        },
        report_handling = "restricted_metadata_do_not_auto_publish",
        supplied_text_returned = false,
        assessment_scope = "structural_only",
        scientific_support_assessed = false,
        applicability_verified = false,
        permission_assessed = false,
        participant_competence_assessed = false,
        privacy_guarantee_established = false
    })
end

function M.describe()
    return ok({
        module_version = MODULE_VERSION,
        schema_version = SCHEMA_VERSION,
        field_set_version = FIELD_SET_VERSION,
        intent_rule_version = INTENT_RULE_VERSION,
        text_policy_version = TEXT_POLICY_VERSION,
        outcome_set_version = OUTCOME_SET_VERSION,
        supported_outcomes = {
            "structurally_accepted",
            "accepted_with_clarifications"
        },
        registered_fields = copy_array(FIELD_ORDER),
        registered_intents = copy_array(INTENT_ORDER),
        declaration_states = copy_array(STATE_ORDER),
        exact_placeholder_text = copy_array(PLACEHOLDER_ORDER),
        maximum_supplied_text_bytes = MAX_TEXT_BYTES,
        null_policy = "nil_is_absent_explicit_serializer_null_unsupported",
        c1_policy = "accept_with_review",
        normalization = "intent_order_and_detached_copy_only",
        side_effects = "none"
    })
end

function M.normalize(raw)
    local checked = validate(raw)
    if not checked.ok then
        return checked
    end
    return ok(normalize_validated(raw, checked.value))
end

function M.screen(normalized)
    local checked = validate(normalized)
    if not checked.ok then
        return checked
    end

    local canonical = normalize_validated(normalized, checked.value)
    for i, intent in ipairs(normalized.intents) do
        if intent ~= canonical.intents[i] then
            return fail("E_NOT_NORMALIZED", "input.intents")
        end
    end

    return build_report(canonical, checked.value)
end

function M.evaluate(raw)
    local checked = validate(raw)
    if not checked.ok then
        return checked
    end

    local normalized = normalize_validated(raw, checked.value)
    return build_report(normalized, checked.value)
end

function M.public_notice()
    return ok({
        notice_version = "1.0.0",
        text =
            "This component checks declared question structure only. "
            .. "It does not verify scientific conclusions, permission, "
            .. "or information outside the stated scope.",
        question_data_consumed = false,
        release_approval_established = false
    })
end

function M.self_test()
    local results = {}

    local function test(name, fn)
        local passed = pcall(fn)
        results[#results + 1] = {
            name = name,
            passed = passed,
            failure_detail = passed and "none"
                or "synthetic_test_failed"
        }
    end

    local function draft()
        return {
            schema_version = 1,
            intents = {"describe"},
            frame = {}
        }
    end

    local function equal(left, right)
        if type(left) ~= type(right) then return false end
        if type(left) ~= "table" then return left == right end

        for key, value in pairs(left) do
            if not equal(value, right[key]) then return false end
        end
        for key in pairs(right) do
            if rawget(left, key) == nil then return false end
        end
        return true
    end

    test("empty_draft_has_seven_required_gaps", function()
        local r = M.evaluate(draft())
        assert(r.ok)
        assert(r.value.coverage.required_count == 7)
        assert(#r.value.clarifications == 7)
    end)

    test("withheld_is_declared_not_supplied", function()
        local x = draft()
        x.frame.spatial_scope = {tag = "withheld"}
        local r = M.evaluate(x)
        assert(r.ok)
        assert(r.value.coverage.declared_count == 1)
        assert(r.value.coverage.supplied_count == 0)
        assert(r.value.declaration_partition.withheld[1]
            == "spatial_scope")
    end)

    test("literal_unknown_and_zero_remain_text", function()
        local x = draft()
        x.frame.subject = {tag = "supplied", text = "unknown"}
        x.frame.response = {tag = "supplied", text = "0"}
        local r = M.evaluate(x)
        assert(r.ok and r.value.coverage.supplied_count == 2)
    end)

    test("placeholder_is_retained_with_review", function()
        local x = draft()
        x.frame.subject = {tag = "supplied", text = "TODO"}
        local r = M.evaluate(x)
        assert(r.ok)
        assert(r.value.coverage.supplied_count == 1)
        assert(r.value.review_items[1].code
            == "R_REGISTERED_PLACEHOLDER_TEXT")
    end)

    test("normalization_is_idempotent_and_detached", function()
        local x = draft()
        x.intents = {"forecast", "compare"}
        x.frame.subject = {tag = "supplied", text = "Synthetic lake"}

        local first = M.normalize(x)
        assert(first.ok)
        local second = M.normalize(first.value)
        assert(second.ok and equal(first.value, second.value))

        first.value.frame.subject.text = "Changed output"
        assert(x.frame.subject.text == "Synthetic lake")
        assert(second.value.frame.subject.text == "Synthetic lake")
    end)

    test("noncanonical_screen_input_is_rejected", function()
        local x = draft()
        x.intents = {"forecast", "compare"}
        local r = M.screen(x)
        assert(not r.ok and r.error.code == "E_NOT_NORMALIZED")
    end)

    test("composite_requirement_is_explicit", function()
        local x = draft()
        x.intents = {"compare", "forecast"}
        local r = M.evaluate(x)
        assert(r.ok)
        assert(r.value.interaction_records[1].rule_code
            == "R_COMPARE_FORECAST_ALIGNMENT")
        assert(r.value.interaction_records[1].satisfaction
            == "not_assessed")
        assert(r.value.coverage.required_count == 13)
    end)

    test("unknown_key_errors_have_no_fingerprint", function()
        local a, b = draft(), draft()
        a.frame.SYNTHETIC_PRIVATE_KEY_A = {tag = "unknown"}
        b.frame.SYNTHETIC_PRIVATE_KEY_B = {tag = "unknown"}
        local ra, rb = M.evaluate(a), M.evaluate(b)
        assert(not ra.ok and not rb.ok)
        assert(equal(ra, rb))
        assert(next(ra.error.args) == nil)
    end)

    test("metatables_are_rejected", function()
        local r = M.evaluate(setmetatable(draft(), {}))
        assert(not r.ok and r.error.code == "E_METATABLE")
    end)

    test("withheld_payload_is_rejected", function()
        local x = draft()
        x.frame.subject = {tag = "withheld", text = "Synthetic"}
        local r = M.evaluate(x)
        assert(not r.ok and r.error.code == "E_UNEXPECTED_CONTENT")
    end)

    test("invalid_utf8_is_rejected", function()
        local x = draft()
        x.frame.subject = {tag = "supplied", text = "\237\160\128"}
        local r = M.evaluate(x)
        assert(not r.ok and r.error.code == "E_TEXT_UTF8")
    end)

    test("unicode_whitespace_is_reviewed_not_hidden", function()
        local x = draft()
        x.frame.subject = {
            tag = "supplied",
            text = utf8.char(0x00A0)
        }
        local r = M.evaluate(x)
        assert(r.ok)
        assert(r.value.review_items[1].code
            == "R_UNICODE_WHITESPACE_ONLY")
    end)

    test("text_boundary_is_in_bytes", function()
        local x = draft()
        x.frame.subject = {
            tag = "supplied",
            text = utf8.char(0x00E9):rep(2000)
        }
        assert(M.evaluate(x).ok)
        x.frame.subject.text = x.frame.subject.text .. "x"
        local r = M.evaluate(x)
        assert(not r.ok and r.error.code == "E_TEXT_LIMIT")
    end)

    test("additional_fields_do_not_change_denominator", function()
        local x = draft()
        x.frame.forecast_alignment = {tag = "unknown"}
        local r = M.evaluate(x)
        assert(r.ok)
        assert(r.value.coverage.required_count == 7)
        assert(r.value.coverage.declared_count == 0)
        assert(r.value.additional_declared_fields[1]
            == "forecast_alignment")
    end)

    test("complete_frame_is_structural_only", function()
        local x = draft()
        for _, field in ipairs(CORE_FIELDS) do
            x.frame[field] = {
                tag = "supplied",
                text = "Synthetic declared content"
            }
        end
        local r = M.evaluate(x)
        assert(r.ok)
        assert(r.value.outcome == "structurally_accepted")
        assert(r.value.assessment_scope == "structural_only")
        assert(not r.value.scientific_support_assessed)
        assert(not r.value.permission_assessed)
    end)

    test("production_partition_handles_216_assignments", function()
        local fields = {"subject", "response", "evidence_basis"}
        local cases = 0

        for a = 1, #STATE_ORDER do
            for b = 1, #STATE_ORDER do
                for c = 1, #STATE_ORDER do
                    local x = draft()
                    local selected = {a, b, c}

                    for i, field in ipairs(fields) do
                        local state = STATE_ORDER[selected[i]]
                        if state ~= "absent" then
                            x.frame[field] = {tag = state}
                            if state == "supplied" then
                                x.frame[field].text = "Synthetic"
                            end
                        end
                    end

                    local r = M.evaluate(x)
                    assert(r.ok)

                    local seen, count = {}, 0
                    for _, state in ipairs(STATE_ORDER) do
                        for _, field in ipairs(
                            r.value.declaration_partition[state]) do
                            assert(not seen[field])
                            seen[field] = true
                            count = count + 1
                        end
                    end

                    assert(count == 7)
                    for i, field in ipairs(fields) do
                        local expected = STATE_ORDER[selected[i]]
                        local found = false
                        for _, item in ipairs(
                            r.value.declaration_partition[expected]) do
                            if item == field then found = true end
                        end
                        assert(found)
                    end

                    cases = cases + 1
                end
            end
        end
        assert(cases == 216)
    end)

    test("public_notice_is_fixed_and_detached", function()
        local first = M.public_notice()
        local second = M.public_notice()
        assert(first.ok and second.ok)
        assert(equal(first, second))
        assert(first.value ~= second.value)
        assert(not first.value.question_data_consumed)
    end)

    local passed, failed = 0, 0
    for _, item in ipairs(results) do
        if item.passed then
            passed = passed + 1
        else
            failed = failed + 1
        end
    end

    return ok({
        module_version = MODULE_VERSION,
        fixtures = "synthetic",
        tests = results,
        passed_count = passed,
        failed_count = failed,
        numerical_tolerances = "not_applicable",
        formal_proof_established = false,
        scientific_validation_established = false
    })
end

return M
