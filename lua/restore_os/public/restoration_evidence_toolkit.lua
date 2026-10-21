-- SPDX-License-Identifier: MIT OR Apache-2.0
--[[
RESTORE-OS | Restoration Evidence Toolkit
=======================================

A collaborative, dependency-free Lua 5.4 module for ecological research.

PUBLIC API
----------
quantity(spec)                  Validate a sourced bounded quantity.
add(a, b)                       Add compatible quantities.
subtract(a, b)                  Preserve signed differences.
multiply(a, b)                  Multiply by a dimensionless quantity.
ratio(a, b)                     Divide quantities having the same unit.
water_balance(record)           Account for tower water and storage change.
wetland_et(record)              Convert area and integrated ET depth to volume.
thermal_energy(record)          Integrate interval-mean thermal power.
incremental_benefit(record)     Compare an outcome with a counterfactual.
demand_residual(record)         Screen authorized facility/aggregate demand.
search_record(record)           Record search results without inferring absence.
render(result, view)            Produce qualified, plain-text review output.
self_test()                     Run embedded synthetic regression fixtures.

QUANTITY FORMAT
---------------
{
    model = "BOUNDS",
    lo = lower_bound,
    hi = upper_bound,
    unit = "m3",
    scenario_kind = "OBSERVATIONAL_RECORD",
    sources = {{
        source_ref = "controlled/source/reference",
        method_ref = "documented/method/reference",
        period_ref = "documented/observation/period",
        evidence_class = "MEASURED"
    }}
}

Every public function returns a result envelope.
For a successful quantity calculation, use result.quantities.value.

MODEL LIMITS
------------
* Bounds are supplied limits, not confidence intervals.
* No probability distribution or independence is assumed.
* Ordinary floating-point arithmetic is used; outward rounding is not verified.
* Provenance references are retained, not authenticated.
* A search miss does not establish absence.
* An anomaly does not establish cause or violation.
* These functions grant no permission or certification.
* Input tables and returned tables are not cryptographically protected.

FORMULAS
--------
R_V     = M - E - B - D - O - Delta_V
V_ET    = area_m2 * integrated_ET_mm / 1000
E_heat  = mean_power_kW * duration_hours
Delta_B = outcome_with - counterfactual
r_load  = observed_mean_power - expected_mean_power

CONTRIBUTOR NOTES
-----------------
Keep arithmetic in the shared private helpers below.
Add a regression fixture for each new operation or failure mode.
Do not introduce hidden I/O, residential inference, or automatic actions.
Do not replace unknown values with zero.
Do not remove qualifiers from rendered results.

SOVEREIGN-ATTRIBUTION
bostrom18sd2ujv24ual9c9pshtxys6j8knh6xaead9ye7
]]

local M = {
    version = "1.0.0",
    name = "RESTORE-OS Restoration Evidence Toolkit",
    symbols = {
        water_residual = "R_V",
        evapotranspiration_volume = "V_ET",
        thermal_energy = "E_heat",
        incremental_benefit = "Delta_B",
        demand_residual = "r_load"
    }
}

local VERSION = "1.0.0"
local CAVEAT =
    "Research calculation only: supplied evidence is not independently verified. " ..
    "Not a safety clearance, permit, legal determination, or authorization."

local units = {
    ["1"] = true, m3 = true, m2 = true, mm = true,
    s = true, h = true, kW_th = true, kWh_th = true,
    kW_e = true, kWh_e = true, kg_dry = true,
    kgCO2e = true, degC = true, K = true
}

local kinds = {
    FIXTURE = true, MODEL_SCENARIO = true, OBSERVATIONAL_RECORD = true
}

local evidence_classes = {
    MEASURED = true, MODELED = true, CLAIMED = true, FIXTURE = true
}

local function finite(x)
    return type(x) == "number" and x == x
        and x ~= math.huge and x ~= -math.huge
end

local function text(x)
    return type(x) == "string" and #x <= 512
        and x:match("%S") ~= nil and not x:find("[%z\1-\31\127]")
end

local function fail(code, field, detail, missing)
    error({
        code = code, field = field, detail = detail,
        category = missing and "MISSING" or "INVALID"
    }, 0)
end

local function need(ok, code, field, detail, missing)
    if not ok then fail(code, field, detail, missing) end
end

local function plain(t, field)
    need(type(t) == "table" and getmetatable(t) == nil,
        "E_RECORD", field, "Plain table required.")
end

local function sequence(t, field)
    plain(t, field)
    local n, count = #t, 0
    for key in pairs(t) do
        need(type(key) == "number" and key % 1 == 0 and key >= 1 and key <= n,
            "E_SEQUENCE", field, "Dense sequence required.")
        count = count + 1
    end
    need(n > 0 and count == n, "E_SEQUENCE", field,
        "Nonempty dense sequence required.")
    return n
end

local function sources(list)
    local out, seen = {}, {}
    for i = 1, sequence(list, "sources") do
        local s = list[i]
        plain(s, "sources.entry")
        for _, key in ipairs({"source_ref", "method_ref", "period_ref"}) do
            need(text(s[key]), "E_SOURCE_REQUIRED", "sources." .. key,
                "Documented reference required.", true)
        end
        need(evidence_classes[s.evidence_class], "E_EVIDENCE_CLASS",
            "sources.evidence_class", "Controlled evidence class required.")
        local values = {s.source_ref, s.method_ref, s.period_ref, s.evidence_class}
        local encoded = {}
        for j, value in ipairs(values) do
            encoded[j] = #value .. ":" .. value
        end
        local key = table.concat(encoded)
        if not seen[key] then
            seen[key] = true
            out[#out + 1] = {
                source_ref = s.source_ref, method_ref = s.method_ref,
                period_ref = s.period_ref, evidence_class = s.evidence_class
            }
        end
    end
    return out
end

local function q(x)
    plain(x, "quantity")
    need(x.model == "BOUNDS", "E_MODEL", "quantity.model",
        "BOUNDS required; no implicit GUM conversion.")
    need(units[x.unit], "E_UNIT", "quantity.unit", "Supported unit required.")
    need(kinds[x.scenario_kind], "E_SCENARIO_KIND", "quantity.scenario_kind",
        "Explicit scenario kind required.")
    need(finite(x.lo) and finite(x.hi), "E_NONFINITE", "quantity",
        "Finite lower and upper bounds required.")
    need(x.lo <= x.hi, "E_REVERSED_BOUNDS", "quantity", "Reversed bounds.")
    local provenance = sources(x.sources)
    local kind = x.scenario_kind
    for _, s in ipairs(provenance) do
        if s.evidence_class == "FIXTURE" then
            kind = "FIXTURE"
        elseif kind == "OBSERVATIONAL_RECORD"
            and s.evidence_class ~= "MEASURED" then
            kind = "MODEL_SCENARIO"
        end
    end
    return {
        model = "BOUNDS", lo = x.lo, hi = x.hi, unit = x.unit,
        scenario_kind = kind, sources = provenance,
        operation = x.operation or "INPUT",
        numerical_enclosure_verified = false
    }
end

local function derive(a, b, lo, hi, unit, operation)
    local combined = {}
    for _, operand in ipairs({a, b}) do
        for _, s in ipairs(operand.sources) do combined[#combined + 1] = s end
    end
    local kind = "OBSERVATIONAL_RECORD"
    if a.scenario_kind == "FIXTURE" or b.scenario_kind == "FIXTURE" then
        kind = "FIXTURE"
    elseif a.scenario_kind == "MODEL_SCENARIO"
        or b.scenario_kind == "MODEL_SCENARIO" then
        kind = "MODEL_SCENARIO"
    end
    return q({
        model = "BOUNDS", lo = lo, hi = hi, unit = unit,
        scenario_kind = kind, sources = combined, operation = operation
    })
end

local function compatible(a, b)
    need(a.unit == b.unit, "E_UNIT_MISMATCH", "operands",
        "Matching units required.")
end

local function add(a, b)
    compatible(a, b)
    return derive(a, b, a.lo + b.lo, a.hi + b.hi, a.unit, "ADD")
end

local function subtract(a, b)
    compatible(a, b)
    return derive(a, b, a.lo - b.hi, a.hi - b.lo, a.unit, "SUBTRACT")
end

local function products(a, b)
    local p = {a.lo * b.lo, a.lo * b.hi, a.hi * b.lo, a.hi * b.hi}
    for i = 1, 4 do
        need(finite(p[i]), "E_NONFINITE", "product", "Product overflow.")
    end
    return math.min(table.unpack(p)), math.max(table.unpack(p))
end

local function read(x, unit, field, nonnegative)
    local value = q(x)
    need(value.unit == unit, "E_UNIT_MISMATCH", field, "Unexpected unit.")
    need(not nonnegative or value.lo >= 0, "E_NEGATIVE", field,
        "Nonnegative quantity required.")
    return value
end

local function result(fn)
    local ok, quantities, findings, warnings = pcall(fn)
    local out = {
        version = VERSION,
        status = "SCREEN_ONLY",
        status_sentence = "Research screen only: supplied records were processed.",
        caveat = CAVEAT,
        quantities = {}, findings = {}, warnings = {},
        physical_action_authorized = false,
        scientific_claim_verified = false,
        regulatory_compliance_established = false,
        public_data_release_authorized = false
    }
    if not ok then
        local e = type(quantities) == "table" and quantities or {
            code = "E_INTERNAL", field = "", detail = "Unexpected failure."
        }
        out.status = e.category == "MISSING" and "INSUFFICIENT_EVIDENCE" or "HOLD"
        out.status_sentence = "Research screen only: the requested calculation is unresolved."
        out.diagnostic = e
    else
        out.quantities = quantities or {}
        out.findings = findings or {}
        out.warnings = warnings or {}
    end
    return out
end

function M.quantity(spec)
    return result(function() return {value = q(spec)} end)
end

function M.add(a, b)
    return result(function() return {value = add(q(a), q(b))} end)
end

function M.subtract(a, b)
    return result(function() return {value = subtract(q(a), q(b))} end)
end

function M.multiply(a, b)
    return result(function()
        a, b = q(a), q(b)
        need(a.unit == "1" or b.unit == "1", "E_UNIT_ADAPTER_REQUIRED",
            "multiply", "One operand must be dimensionless.")
        local lo, hi = products(a, b)
        local unit = a.unit == "1" and b.unit or a.unit
        return {value = derive(a, b, lo, hi, unit, "MULTIPLY")}
    end)
end

function M.ratio(a, b)
    return result(function()
        a, b = q(a), q(b)
        compatible(a, b)
        need(not (b.lo <= 0 and b.hi >= 0), "E_ZERO_DENOMINATOR",
            "denominator", "Denominator bounds contain zero.")
        local p = {a.lo / b.lo, a.lo / b.hi, a.hi / b.lo, a.hi / b.hi}
        return {value = derive(a, b, math.min(table.unpack(p)),
            math.max(table.unpack(p)), "1", "SAME_UNIT_RATIO")}
    end)
end

function M.water_balance(x)
    return result(function()
        plain(x, "water_balance")
        local residual = read(x.makeup, "m3", "makeup", true)
        for _, name in ipairs({"evaporation", "blowdown", "drift", "other_losses"}) do
            residual = subtract(residual, read(x[name], "m3", name, true))
        end
        residual = subtract(residual,
            read(x.storage_change, "m3", "storage_change", false))
        return {water_residual = residual}, {
            zero_is_inside_supplied_bounds = residual.lo <= 0 and residual.hi >= 0,
            closure_independently_verified = false
        }, {"A residual containing zero does not prove complete or precise accounting."}
    end)
end

function M.wetland_et(x)
    return result(function()
        plain(x, "wetland_et")
        local area = read(x.area, "m2", "area", true)
        local depth = read(x.integrated_depth, "mm", "integrated_depth", true)
        local lo, hi = products(area, depth)
        local volume = derive(area, depth, lo / 1000, hi / 1000,
            "m3", "AREA_TIMES_INTEGRATED_ET_DEPTH")
        return {et_volume = volume}, {}, {
            "Depth must cover the declared period.",
            "Do not subtract ET again from water already metered after wetland losses."
        }
    end)
end

function M.thermal_energy(x)
    return result(function()
        plain(x, "thermal_energy")
        need(x.power_basis == "INTERVAL_MEAN", "E_POWER_BASIS", "power_basis",
            "Instantaneous power cannot stand in for an interval mean.")
        local power = read(x.power, "kW_th", "power", true)
        local duration = q(x.duration)
        need(duration.unit == "s" or duration.unit == "h",
            "E_UNIT_MISMATCH", "duration", "Seconds or hours required.")
        need(duration.lo >= 0, "E_NEGATIVE", "duration", "Nonnegative duration required.")
        local lo, hi = products(power, duration)
        local factor = duration.unit == "s" and 1 / 3600 or 1
        return {thermal_energy = derive(power, duration,
            lo * factor, hi * factor, "kWh_th", "REGISTERED_POWER_TIME_INTEGRATION")},
            {useful_heat_established = false},
            {"Integrated available power is not proof of delivered or useful heat."}
    end)
end

function M.incremental_benefit(x)
    return result(function()
        plain(x, "incremental_benefit")
        need(text(x.counterfactual_ref) and text(x.comparison_scope_ref),
            "E_COUNTERFACTUAL", "counterfactual_ref",
            "Counterfactual and comparison-scope references required.", true)
        local with = q(x.with_intervention)
        local baseline = q(x.counterfactual)
        compatible(with, baseline)
        need(x.direction == "HIGHER_IS_BETTER" or x.direction == "LOWER_IS_BETTER",
            "E_DIRECTION", "direction", "Explicit benefit direction required.")
        local benefit
        if x.direction == "HIGHER_IS_BETTER" then
            benefit = subtract(with, baseline)
        else
            benefit = subtract(baseline, with)
        end
        return {incremental_benefit = benefit}, {
            counterfactual_ref = x.counterfactual_ref,
            comparison_scope_ref = x.comparison_scope_ref,
            causal_attribution_verified = false
        }
    end)
end

function M.demand_residual(x)
    return result(function()
        plain(x, "demand_residual")
        need(x.scope_kind == "OPERATOR_FACILITY"
            or x.scope_kind == "APPROVED_FEEDER_AGGREGATE",
            "E_PRIVATE_ACTIVITY_SCOPE", "scope_kind",
            "Household activity inference is not supported.")
        need(text(x.authority_ref) and text(x.privacy_review_ref)
            and text(x.baseline_ref), "E_DEMAND_BASIS", "references",
            "Authority, privacy, and baseline references required.", true)
        need(x.power_basis == "MATCHED_INTERVAL_MEANS",
            "E_POWER_BASIS", "power_basis", "Matched interval means required.")
        local observed = read(x.observed, "kW_e", "observed", true)
        local expected = read(x.expected, "kW_e", "expected", true)
        return {demand_residual = subtract(observed, expected)}, {
            authority_ref = x.authority_ref,
            privacy_review_ref = x.privacy_review_ref,
            baseline_ref = x.baseline_ref,
            cause = "NOT_DETERMINED",
            violation_determined = false
        }
    end)
end

function M.search_record(x)
    return result(function()
        plain(x, "search_record")
        for _, name in ipairs({
            "scope_ref", "query_template_ref", "dataset_snapshot_ref", "limitations"
        }) do
            need(text(x[name]), "E_SEARCH_BASIS", name,
                "Scoped search reference required.", true)
        end
        local availability = {
            NO_MATCH = "NOT_FOUND_IN_SEARCH",
            MATCH = "AVAILABLE",
            ACCESS_DENIED = "UNAVAILABLE_TO_REQUESTER"
        }
        need(availability[x.outcome] ~= nil, "E_SEARCH_OUTCOME", "outcome",
            "Controlled search outcome required.")
        return {}, {
            availability = availability[x.outcome],
            knowledge = "NOT_ESTABLISHED_BY_SEARCH_ALONE",
            scope_ref = x.scope_ref,
            query_template_ref = x.query_template_ref,
            dataset_snapshot_ref = x.dataset_snapshot_ref,
            limitations = x.limitations,
            absence_inferred = false
        }
    end)
end

function M.render(record, view)
    return result(function()
        plain(record, "result")
        need(record.version == VERSION and record.caveat == CAVEAT,
            "E_RESULT_CONTRACT", "result", "Compatible qualified result required.")
        need(view == "REVIEW" or view == "FIXTURE_REVIEW",
            "E_VIEW", "view", "Controlled review view required.")
        for _, name in ipairs({
            "physical_action_authorized", "scientific_claim_verified",
            "regulatory_compliance_established", "public_data_release_authorized"
        }) do
            need(record[name] == false, "E_AUTHORIZATION_FLAG", name,
                "Non-authorizing flags required.")
        end
        plain(record.quantities, "quantities")
        local keys, values, fixture = {}, {}, false
        for name, value in pairs(record.quantities) do
            need(text(name), "E_FIELD_NAME", "quantities", "Plain field name required.")
            keys[#keys + 1] = name
            values[name] = q(value)
            if values[name].scenario_kind == "FIXTURE" then fixture = true end
        end
        need(not fixture or view == "FIXTURE_REVIEW",
            "E_FIXTURE_VIEW", "view", "Fixture-only review required.")
        table.sort(keys)
        local lines = {}
        if fixture then
            lines[#lines + 1] = "SYNTHETIC FIXTURE — NOT FIELD EVIDENCE"
        end
        lines[#lines + 1] = record.status_sentence
        lines[#lines + 1] = CAVEAT
        for _, name in ipairs(keys) do
            local v = values[name]
            local classes = {}
            for _, s in ipairs(v.sources) do classes[s.evidence_class] = true end
            local labels = {}
            for class in pairs(classes) do labels[#labels + 1] = class end
            table.sort(labels)
            lines[#lines + 1] = string.format(
                "%s: [%.17g, %.17g] %s | BOUNDS | %s | evidence: %s",
                name, v.lo, v.hi, v.unit, v.scenario_kind, table.concat(labels, ", "))
        end
        lines[#lines + 1] =
            "Displayed digits preserve numeric values; they do not establish measurement precision."
        return {}, {format = "PLAIN_TEXT", text = table.concat(lines, "\n")}
    end)
end

function M.self_test()
    return result(function()
        local checks = 0
        local function check(condition)
            need(condition, "E_SELF_TEST", "fixture", "Regression assertion failed.")
            checks = checks + 1
        end
        local function fixture(lo, hi, unit)
            return {
                model = "BOUNDS", lo = lo, hi = hi, unit = unit,
                scenario_kind = "FIXTURE",
                sources = {{
                    source_ref = "synthetic-regression",
                    method_ref = "analytic-fixture",
                    period_ref = "fixture-period",
                    evidence_class = "FIXTURE"
                }}
            }
        end

        local product = M.multiply(fixture(-2, 3, "1"), fixture(-4, 5, "1"))
        check(product.quantities.value.lo == -12)
        check(product.quantities.value.hi == 15)

        local ratio = M.ratio(fixture(1, 2, "m3"), fixture(-1, 1, "m3"))
        check(ratio.status == "HOLD")
        check(ratio.diagnostic.code == "E_ZERO_DENOMINATOR")

        local heat = M.thermal_energy({
            power = fixture(2, 2, "kW_th"),
            duration = fixture(1800, 1800, "s"),
            power_basis = "INTERVAL_MEAN"
        })
        check(heat.quantities.thermal_energy.lo == 1)
        check(heat.quantities.thermal_energy.hi == 1)
        check(M.render(heat, "REVIEW").status == "HOLD")
        check(M.render(heat, "FIXTURE_REVIEW").status == "SCREEN_ONLY")

        local et = M.wetland_et({
            area = fixture(1000, 1000, "m2"),
            integrated_depth = fixture(10, 10, "mm")
        })
        check(et.quantities.et_volume.lo == 10)
        check(et.physical_action_authorized == false)

        return {}, {
            scenario_kind = "FIXTURE",
            checks_completed = checks,
            scope = "Embedded synthetic regression checks only",
            field_validation = false
        }
    end)
end

return M
