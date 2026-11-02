#!/usr/bin/env julia
# run.jl -- implementation of manifest P-7Q3 (neutral, version 1)
#
# Usage: julia run.jl <data_dir> <out_dir> <run_ids>
#   run_ids: comma-separated run IDs (e.g. "ORIGIN,U01,U20"), or "all"
#            (ORIGIN + every deviation in manifest section 8, no influence),
#            or "influence" (country-deletion refits of M3-M8 under origin settings).
#            "influence" may also appear inside a comma-separated list.
#
# Reads <data_dir>/gem_extract.csv and <data_dir>/country_year_inputs.csv.
# Writes <out_dir>/results.csv, <out_dir>/constants.json, <out_dir>/session_info.txt.
# A failed fit is recorded (status = failed, error column) and the script continues.
# No raw data rows are printed.

using CSV, DataFrames, MixedModels, GLM, StatsModels, CategoricalArrays, Distributions, JSON3
using LinearAlgebra, Statistics, Random, SHA, Printf, Dates

const SA = MixedModels.SparseArrays   # SparseArrays binding re-exported through MixedModels

# ---------------------------------------------------------------------------------------
# 0. Work-around for a defect in MixedModels 5.9.1
#
# GLMM fitting (PIRLS) calls updateA!(m.LMM), which recomputes the weighted cross-product
# blocks Z_i' W Z_j.  For two grouping factors that each carry more than one random-effects
# column (here: intercept + female at country and at survey), the off-diagonal block is a
# SparseMatrixCSC and MixedModels 5.9.1 only defines the specialised product for
# single-column terms (ReMat{T,1}).  The multi-column case silently falls through to the
# generic LinearAlgebra.mul! for sparse destinations, which returns wrong values, and the
# Cholesky factorisation then fails with PosDefException (or the optimiser wanders off).
# The method below supplies the missing specialisation.  It computes exactly
# C = A' * B over the fixed sparsity pattern of C (the pattern never changes because the
# grouping factors are fixed); it was verified against an explicit Z2' W Z1 product.
# It does not alter the installed package; it adds one method in this script's session.
# ---------------------------------------------------------------------------------------
function LinearAlgebra.mul!(C::SA.SparseMatrixCSC{T},
                            adjA::Adjoint{T,<:MixedModels.ReMat{T,S}},
                            B::MixedModels.ReMat{T,P}) where {T,S,P}
    A = adjA.parent
    m, n = size(A)
    p, q = size(B)
    (m == p && size(C, 1) == n && size(C, 2) == q) || throw(DimensionMismatch("mul!(C, A', B) size mismatch"))
    Ar = A.refs; Br = B.refs
    Az = A.wtz; Bz = B.wtz
    nz = SA.nonzeros(C); rv = SA.rowvals(C); cp = SA.getcolptr(C)
    fill!(nz, zero(T))
    @inbounds for k in 1:m
        ioff = (Int(Ar[k]) - 1) * S
        joff = (Int(Br[k]) - 1) * P
        for jj in 1:P
            j = joff + jj
            bz = Bz[jj, k]
            c1 = Int(cp[j]); c2 = Int(cp[j + 1]) - 1
            for ii in 1:S
                i = ioff + ii
                K = searchsortedfirst(rv, i, c1, c2, Base.Order.Forward)
                (K <= c2 && rv[K] == i) || throw(ArgumentError("C does not have the nonzero pattern of A'B"))
                nz[K] = muladd(Az[ii, k], bz, nz[K])
            end
        end
    end
    return C
end

# ---------------------------------------------------------------------------------------
# 1. Constants: roster, settings, deviation table, model table
# ---------------------------------------------------------------------------------------
const COUNTRIES24 = ["AUS", "AUT", "BEL", "CAN", "CZE", "DNK", "FIN", "FRA", "DEU", "GRC", "ISL", "IRL",
                     "ITA", "JPN", "NLD", "NZL", "NOR", "POL", "PRT", "ESP", "SWE", "CHE", "GBR", "USA"]

const ORIGIN_ROSTER = Dict{String,Vector{Int}}(
    "AUS" => collect(2002:2006), "AUT" => [2005, 2007], "BEL" => collect(2001:2008),
    "CAN" => [2001, 2002, 2003, 2006], "CZE" => [2006], "DNK" => collect(2001:2008),
    "FIN" => collect(2001:2008), "FRA" => collect(2002:2008), "DEU" => vcat(2001:2006, 2008),
    "GRC" => collect(2003:2008), "ISL" => collect(2002:2008), "IRL" => collect(2001:2008),
    "ITA" => vcat(2001:2003, 2005:2008), "JPN" => collect(2001:2008), "NLD" => collect(2002:2008),
    "NZL" => [2001, 2003, 2004, 2005], "NOR" => vcat(2002:2006, 2008), "POL" => [2001, 2002, 2004],
    "PRT" => [2001, 2004, 2007], "ESP" => collect(2002:2008), "SWE" => collect(2001:2007),
    "CHE" => [2002, 2003, 2005, 2007], "GBR" => collect(2001:2008), "USA" => collect(2001:2008))

const SURVEY_VARS = [:leave, :childcare, :parttime, :gdp, :unemp, :epl, :status, :wmgr, :fert]
const X_VARS = [:leave, :leave_sq, :childcare, :parttime]
const C_VARS = [:gdp, :unemp, :epl, :status, :wmgr, :fert]
const FX_VARS = [:female_x_leave, :female_x_leave_sq, :female_x_childcare, :female_x_parttime]
const WILD_TERMS = ["female:leave", "female:leave_sq", "female:childcare", "female:parttime"]

# output term name for each internal column name
function term_label(col::AbstractString)
    col == "(Intercept)" && return col
    startswith(col, "female_x_") && return "female:" * col[10:end]
    return col
end

function origin_settings()
    return Dict{Symbol,Any}(
        :age_rule => :origin,          # U01: 18 <= age
        :employ_rule => :origin,       # U02: GEMWORK in {1,2,6}
        :roster => :origin,            # U05: all surveys of the 24 countries, 2001-2008
        :activity_def => :origin,      # U03, U04
        :dk_zero => false,             # U06: code 8 as 0 for BSTART, OWNMGE, SUSKILL, FEARFAIL, KNOWENT
        :owner_def => :origin,         # U07, U08
        :planb_def => :origin,         # U09, U10
        :bage_def => :origin,          # U11: ln(bage_years + 1)
        :parttime_var => :pt_common_employees_women,  # U12, U13
        :leave_sq_rule => :origin,     # U14: standardize raw leave^2
        :std_rule => :survey,          # U15 :country, U16 :individual
        :leave_lag => 1,               # U17: 0, U18: 2
        :childcare_var => :childcare_interp,          # U19
        :covariance => :zerocorr,      # U20: :unstructured
        :status_rule => :all,          # U22: :sample
        :drop_2001_2002 => false,      # N01
        :growth_def => :origin,        # U23
        :sole_def => :origin,          # U24
        :reml_m5 => false,             # U25
        :r2_fert => false,             # U26
    )
end

const M3_M8 = ["M3", "M4", "M5", "M6", "M7", "M8"]
const M4_M8 = ["M4", "M5", "M6", "M7", "M8"]
const ALL_MODELS = ["M1", "M2", "M3", "M4", "M5", "M6", "M7", "M8", "R1", "R2", "R3"]

# (run_id, settings changed from origin, models to fit) in manifest order
const DEVIATIONS = [
    ("U01", Dict{Symbol,Any}(:age_rule => :U01), M3_M8),
    ("U02", Dict{Symbol,Any}(:employ_rule => :U02), M3_M8),
    ("U03", Dict{Symbol,Any}(:activity_def => :U03), ["M3", "R1"]),
    ("U04", Dict{Symbol,Any}(:activity_def => :U04), ["M3"]),
    ("U05", Dict{Symbol,Any}(:roster => :U05), M3_M8),
    ("U06", Dict{Symbol,Any}(:dk_zero => true), ["M3"]),
    ("U07", Dict{Symbol,Any}(:owner_def => :U07), M4_M8),
    ("U08", Dict{Symbol,Any}(:owner_def => :U08), M4_M8),
    ("U09", Dict{Symbol,Any}(:planb_def => :U09), ["M4"]),
    ("U10", Dict{Symbol,Any}(:planb_def => :U10), ["M4"]),
    ("U11", Dict{Symbol,Any}(:bage_def => :U11), M4_M8),
    ("U12", Dict{Symbol,Any}(:parttime_var => :pt_national_women), M3_M8),
    ("U13", Dict{Symbol,Any}(:parttime_var => :pt_common_total_women), M3_M8),
    ("U14", Dict{Symbol,Any}(:leave_sq_rule => :U14), M3_M8),
    ("U15", Dict{Symbol,Any}(:std_rule => :country), M3_M8),
    ("U16", Dict{Symbol,Any}(:std_rule => :individual), M3_M8),
    ("U17", Dict{Symbol,Any}(:leave_lag => 0), M3_M8),
    ("U18", Dict{Symbol,Any}(:leave_lag => 2), M3_M8),
    ("U19", Dict{Symbol,Any}(:childcare_var => :childcare_pct_gdp_annual), M3_M8),
    ("U20", Dict{Symbol,Any}(:covariance => :unstructured), M3_M8),
    ("U22", Dict{Symbol,Any}(:status_rule => :sample), M3_M8),
    ("U23", Dict{Symbol,Any}(:growth_def => :U23), ["M6"]),
    ("U24", Dict{Symbol,Any}(:sole_def => :U24), M4_M8),
    ("U25", Dict{Symbol,Any}(:reml_m5 => true), ["M5"]),
    ("U26", Dict{Symbol,Any}(:r2_fert => true), ["R2"]),
    ("N01", Dict{Symbol,Any}(:drop_2001_2002 => true), M3_M8),
]
const INFLUENCE_MODELS = M3_M8

struct ModelSpec
    name::String
    outcome::Symbol
    stage::Symbol          # :S1, :S2, :R2, :R3
    family::Symbol         # :logit, :gaussian
    yearref::Int
    years::Union{Nothing,UnitRange{Int}}
    extra::Vector{Symbol}  # extra individual-level terms after F x X
    level::Int             # 1 = M1 terms, 2 = M2 terms (X + C), 3 = M3 terms (+ F x X)
end

const MODELS = Dict{String,ModelSpec}(
    "M1" => ModelSpec("M1", :activity, :S1, :logit, 2001, nothing, Symbol[], 1),
    "M2" => ModelSpec("M2", :activity, :S1, :logit, 2001, nothing, Symbol[], 2),
    "M3" => ModelSpec("M3", :activity, :S1, :logit, 2001, nothing, Symbol[], 3),
    "M4" => ModelSpec("M4", :planb, :S2, :logit, 2001, nothing, [:sole, :bage_c], 3),
    "M5" => ModelSpec("M5", :size, :S2, :gaussian, 2001, nothing, [:sole, :bage_c], 3),
    "M6" => ModelSpec("M6", :growth, :S2, :logit, 2001, nothing, [:sole, :bage_c], 3),
    "M7" => ModelSpec("M7", :newprod, :S2, :logit, 2002, 2002:2008, [:sole, :bage_c], 3),
    "M8" => ModelSpec("M8", :newtech, :S2, :logit, 2008, 2005:2008, [:sole, :bage_c], 3),
    "R1" => ModelSpec("R1", :nascent, :S1, :logit, 2001, nothing, Symbol[], 3),
    "R2" => ModelSpec("R2", :activity, :R2, :logit, 2001, nothing, [:not_employed], 3),
    "R3" => ModelSpec("R3", :activity, :R3, :logit, 2001, nothing, [:skill, :fear, :knows], 3),
)

# survey-level (standardized) variables entering a model's fixed part
function model_survey_vars(spec::ModelSpec, s::Dict{Symbol,Any})
    spec.level == 1 && return Symbol[]
    v = copy(SURVEY_VARS)
    if spec.name == "R2" && !s[:r2_fert]
        filter!(!=(:fert), v)
    end
    return v
end

# ---------------------------------------------------------------------------------------
# 2. Individual-level variables (manifest section 3)
# ---------------------------------------------------------------------------------------
eq(x, v) = !ismissing(x) && x == v
isin(x, vs) = !ismissing(x) && any(==(x), vs)

# screening item: 1 or 100 = yes, 0 = no, 8/9 = missing (U06: 8 -> 0)
function scr(v, dk_zero::Bool)
    ismissing(v) && return missing
    (v == 1 || v == 100) && return 1.0
    v == 0 && return 0.0
    (v == 8 && dk_zero) && return 0.0
    return missing
end
flag01(v) = ismissing(v) ? missing : v == 1 ? 1.0 : v == 0 ? 0.0 : missing
validcount(v) = !ismissing(v) && 0 <= v <= 999998

function derive_individual(raw::DataFrame, s::Dict{Symbol,Any})
    n = nrow(raw)
    d = DataFrame()
    d.id = raw.ID_9817_RDM
    d.iso3 = String.(raw.iso3)
    d.year = Int.(raw.GEM_YR)
    d.survey = string.(d.iso3, "_", d.year)
    d.female = [ismissing(v) ? missing : v == 2 ? 1.0 : v == 1 ? 0.0 : missing for v in raw.GEMSEX]
    d.age = [(ismissing(v) || v == 99 || v == 999) ? missing : Float64(v) for v in raw.GEMAGE]
    d.postsecondary = [ismissing(v) ? missing : isin(v, (1316, 1720)) ? 1.0 : isin(v, (0, 111, 1212)) ? 0.0 : missing
                       for v in raw.GEMEDUC]
    d.employed = [ismissing(v) ? missing : isin(v, (1, 2)) ? 1.0 : isin(v, (3, 4, 5, 6)) ? 0.0 : missing for v in raw.GEMWORK]
    d.not_employed = 1.0 .- d.employed
    d.gemwork = raw.GEMWORK
    dk = s[:dk_zero]::Bool
    bstart = scr.(raw.BSTART, dk)
    ownmge = scr.(raw.OWNMGE, dk)
    d.skill = scr.(raw.SUSKILL, dk)
    d.fear = scr.(raw.FEARFAIL, dk)
    d.knows = scr.(raw.KNOWENT, dk)
    suboanwt = flag01.(raw.SUBOANWT)
    ombaby = flag01.(raw.OMBABYBT)
    omestb = flag01.(raw.OMESTBBT)
    suwage_not1 = [ismissing(v) || v != 1 for v in raw.SUWAGE]   # "SUWAGE is not 1" (missing counts as not 1)

    # activity
    act = s[:activity_def]
    if act == :origin
        d.activity = [(eq(a, 1) || eq(o, 1)) ? 1.0 : (eq(a, 0) && eq(o, 0)) ? 0.0 : missing
                      for (a, o) in zip(suboanwt, ownmge)]
    elseif act == :U03
        d.activity = [((eq(b, 1) && sw) || eq(o, 1)) ? 1.0 : (eq(b, 0) && eq(o, 0)) ? 0.0 : missing
                      for (b, sw, o) in zip(bstart, suwage_not1, ownmge)]
    elseif act == :U04
        d.activity = [(eq(a, 1) || eq(b, 1) || eq(e, 1)) ? 1.0 : (eq(a, 0) && eq(b, 0) && eq(e, 0)) ? 0.0 : missing
                      for (a, b, e) in zip(suboanwt, ombaby, omestb)]
    else
        error("unknown activity_def $act")
    end
    # nascent
    if act == :U03
        d.nascent = [(eq(b, 1) && sw) ? 1.0 : eq(b, 0) ? 0.0 : missing for (b, sw) in zip(bstart, suwage_not1)]
    else
        d.nascent = suboanwt
    end
    # owner
    od = s[:owner_def]
    if od == :origin
        d.owner = ownmge
    elseif od == :U07
        d.owner = omestb
    elseif od == :U08
        d.owner = [ismissing(o) ? missing : (eq(o, 1) && isin(w, (1, 2))) ? 1.0 : 0.0 for (o, w) in zip(ownmge, raw.OMOWN)]
    else
        error("unknown owner_def $od")
    end
    # planb
    pd = s[:planb_def]
    if pd == :origin
        d.planb = [eq(v, 2) ? 1.0 : isin(v, (1, 3, 4, 6)) ? 0.0 : missing for v in raw.OMREASON]
    elseif pd == :U09
        d.planb = [isin(v, (2, 3)) ? 1.0 : isin(v, (1, 4, 6)) ? 0.0 : missing for v in raw.OMREASON]
    elseif pd == :U10
        d.planb = [eq(v, -1) ? 1.0 : isin(v, (0, 1)) ? 0.0 : missing for v in raw.OMWHY]
    else
        error("unknown planb_def $pd")
    end
    # size, growth
    d.size = [validcount(v) ? log(v + 1.0) : missing for v in raw.OMNOWJOB]
    if s[:growth_def] == :origin
        d.growth = [(validcount(a) && validcount(b)) ? ((b - a) > 5 ? 1.0 : 0.0) : missing
                    for (a, b) in zip(raw.OMNOWJOB, raw.OMYR5JOB)]
    elseif s[:growth_def] == :U23
        d.growth = [validcount(b) ? (b > 5 ? 1.0 : 0.0) : missing for b in raw.OMYR5JOB]
    else
        error("unknown growth_def")
    end
    d.newprod = [eq(v, 1) ? 1.0 : isin(v, (2, 3)) ? 0.0 : missing for v in raw.OMNEWCST]
    d.newtech = [isin(v, (1, 2)) ? 1.0 : eq(v, 3) ? 0.0 : missing for v in raw.OMNEWT_5]
    # sole
    if s[:sole_def] == :origin
        d.sole = [eq(v, 1) ? 1.0 : eq(v, 2) ? 0.0 : missing for v in raw.OMOWN]
    elseif s[:sole_def] == :U24
        d.sole = [eq(v, 1) ? 1.0 : (!ismissing(v) && 2 <= v <= 998) ? 0.0 : missing for v in raw.OMOWNERS]
    else
        error("unknown sole_def")
    end
    # business age
    bage_years = [(!ismissing(w) && 1990 <= w <= y) ? Float64(y - w) : missing for (w, y) in zip(raw.OMWAGEYR, d.year)]
    if s[:bage_def] == :origin
        d.bage = [ismissing(b) ? missing : b == 0 ? missing : log(b) for b in bage_years]
    elseif s[:bage_def] == :U11
        d.bage = [ismissing(b) ? missing : log(b + 1.0) for b in bage_years]
    else
        error("unknown bage_def")
    end
    # NBSTATUS coded as a screening item (1 or 100 = yes, 0 = no); U06 does not apply to NBSTATUS
    d.nbstatus = scr.(raw.NBSTATUS, false)
    return d
end

# ---------------------------------------------------------------------------------------
# 3. Roster, sample steps 1-3, survey-level variables (manifest sections 2, 4, 5)
# ---------------------------------------------------------------------------------------
function roster_set(d::DataFrame, s::Dict{Symbol,Any})
    r = Set{Tuple{String,Int}}()
    if s[:roster] == :origin
        for (c, ys) in ORIGIN_ROSTER, y in ys
            push!(r, (c, y))
        end
    elseif s[:roster] == :U05
        c24 = Set(COUNTRIES24)
        for (c, y) in zip(d.iso3, d.year)
            (c in c24 && 2001 <= y <= 2008) && push!(r, (c, y))
        end
    else
        error("unknown roster rule")
    end
    if s[:drop_2001_2002]
        filter!(cy -> !(cy[2] in (2001, 2002)), r)
    end
    return r
end

function step_masks(d::DataFrame, s::Dict{Symbol,Any}, roster)
    n = nrow(d)
    m1 = [((c, y) in roster) for (c, y) in zip(d.iso3, d.year)]
    if s[:age_rule] == :origin
        m2 = [!ismissing(a) && 18 < a < 55 for a in d.age]
    elseif s[:age_rule] == :U01
        m2 = [!ismissing(a) && 18 <= a < 55 for a in d.age]
    else
        error("unknown age_rule")
    end
    if s[:employ_rule] == :origin
        m3 = [eq(e, 1) for e in d.employed]
    elseif s[:employ_rule] == :U02
        m3 = [isin(w, (1, 2, 6)) for w in d.gemwork]
    else
        error("unknown employ_rule")
    end
    return (steps12 = m1 .& m2, steps123 = m1 .& m2 .& m3)
end

# status: proportion NBSTATUS = yes among respondents with NBSTATUS yes/no, per survey
function compute_status(d::DataFrame, pool::AbstractVector{Bool}, s::Dict{Symbol,Any}, roster)
    num = Dict{Tuple{String,Int},Float64}()
    den = Dict{Tuple{String,Int},Int}()
    for i in 1:nrow(d)
        pool[i] || continue
        v = d.nbstatus[i]
        ismissing(v) && continue
        k = (d.iso3[i], d.year[i])
        num[k] = get(num, k, 0.0) + v
        den[k] = get(den, k, 0) + 1
    end
    observed = Dict(k => num[k] / den[k] for k in keys(den))
    out = Dict{Tuple{String,Int},Union{Missing,Float64}}()
    carried = String[]
    for (c, y) in roster
        if haskey(observed, (c, y))
            out[(c, y)] = observed[(c, y)]
        elseif !s[:drop_2001_2002]
            later = sort([k[2] for k in keys(observed) if k[1] == c && k[2] > y])
            if isempty(later)
                out[(c, y)] = missing
            else
                out[(c, y)] = observed[(c, later[1])]
                push!(carried, "$(c)_$(y)<-$(later[1])")
            end
        else
            out[(c, y)] = missing   # N01: no carry-back
        end
    end
    return out, sort(carried)
end

function survey_table(cy::DataFrame, status::Dict, s::Dict{Symbol,Any}, roster)
    idx = Dict{Tuple{String,Int},Int}()
    for i in 1:nrow(cy)
        idx[(String(cy.iso3[i]), Int(cy.year[i]))] = i
    end
    look(c, y, col) = haskey(idx, (c, y)) ? (v = cy[idx[(c, y)], col]; ismissing(v) ? missing : Float64(v)) : missing
    rows = sort(collect(roster))
    st = DataFrame(iso3 = String[], year = Int[], leave = Union{Missing,Float64}[], childcare = Union{Missing,Float64}[],
                   parttime = Union{Missing,Float64}[], gdp = Union{Missing,Float64}[], unemp = Union{Missing,Float64}[],
                   epl = Union{Missing,Float64}[], status = Union{Missing,Float64}[], wmgr = Union{Missing,Float64}[],
                   fert = Union{Missing,Float64}[])
    for (c, y) in rows
        push!(st, (c, y,
                   look(c, y - s[:leave_lag], :leave_fte_weeks),
                   look(c, y, s[:childcare_var]),
                   look(c, y, s[:parttime_var]),
                   look(c, y, :gdp_index_undp),
                   look(c, y, :unemployment_rate),
                   look(c, y, :epl_overall),
                   status[(c, y)],
                   look(c, y, :women_managers_pct),
                   look(c, y, :fertility_rate)))
    end
    st.leave_sq_raw = [ismissing(v) ? missing : v^2 for v in st.leave]
    return st
end

# ---------------------------------------------------------------------------------------
# 4. Standardization constants (manifest section 5)
# ---------------------------------------------------------------------------------------
function m3_stage1_mask(dd::DataFrame, steps123::AbstractVector{Bool})
    m = copy(steps123)
    for v in [:activity, :female, :age, :postsecondary, SURVEY_VARS...]
        m .&= .!ismissing.(dd[!, v])
    end
    return m
end

function std_constants(dd::DataFrame, mask::AbstractVector{Bool}, s::Dict{Symbol,Any})
    vars = s[:leave_sq_rule] == :U14 ? vcat(SURVEY_VARS, :leave_sq_raw) : SURVEY_VARS
    means = Dict{String,Float64}(); sds = Dict{String,Float64}()
    sub = dd[mask, vcat([:iso3, :year], vars)]
    if s[:std_rule] == :individual
        basis = sub
        rule = "individual rows of the M3-equivalent stage-1 sample"
    else
        surveys = unique(sub, [:iso3, :year])
        if s[:std_rule] == :survey
            basis = surveys
            rule = "surveys present in the M3-equivalent stage-1 sample, each counted once"
        elseif s[:std_rule] == :country
            basis = combine(groupby(surveys, :iso3), [v => (x -> mean(skipmissing(x))) => v for v in vars]...)
            rule = "country means over the surveys of the M3-equivalent stage-1 sample"
        else
            error("unknown std_rule")
        end
    end
    for v in vars
        x = collect(skipmissing(basis[!, v]))
        means[string(v)] = mean(x)
        sds[string(v)] = std(x)   # n - 1 divisor
    end
    return (means = means, sds = sds, rule = rule, n_basis = nrow(basis),
            n_surveys = nrow(unique(sub, [:iso3, :year])), n_rows = nrow(sub))
end

function apply_standardization!(dd::DataFrame, k, s::Dict{Symbol,Any})
    for v in SURVEY_VARS
        m = k.means[string(v)]; sd = k.sds[string(v)]
        dd[!, v] = [ismissing(x) ? missing : (x - m) / sd for x in dd[!, v]]
    end
    if s[:leave_sq_rule] == :U14
        m = k.means["leave_sq_raw"]; sd = k.sds["leave_sq_raw"]
        dd[!, :leave_sq] = [ismissing(x) ? missing : (x - m) / sd for x in dd[!, :leave_sq_raw]]
    else
        dd[!, :leave_sq] = [ismissing(x) ? missing : x^2 for x in dd[!, :leave]]
    end
    return dd
end

# ---------------------------------------------------------------------------------------
# 5. Model samples and design (manifest sections 4 and 6)
# ---------------------------------------------------------------------------------------
function model_sample(dd::DataFrame, spec::ModelSpec, s::Dict{Symbol,Any}, masks)
    svars = model_survey_vars(spec, s)
    if spec.stage == :S1 || spec.stage == :R3
        m = copy(masks.steps123)
        need = vcat([:activity, spec.outcome, :female, :age, :postsecondary], svars)
        spec.stage == :R3 && append!(need, [:skill, :fear, :knows])
    elseif spec.stage == :R2
        m = copy(masks.steps12)
        need = vcat([:activity, :female, :age, :postsecondary, :not_employed], svars)
    elseif spec.stage == :S2
        m = masks.steps123 .& [eq(o, 1) for o in dd.owner]
        need = vcat([spec.outcome, :female, :age, :postsecondary, :sole, :bage], svars)
    else
        error("unknown stage")
    end
    if spec.level >= 2
        push!(need, :leave_sq)
    end
    for v in unique(need)
        m .&= .!ismissing.(dd[!, v])
    end
    if spec.years !== nothing
        m .&= [y in spec.years for y in dd.year]
    end
    return dd[m, :]
end

# Build the analysis frame: centering, year dummies, interactions. Returns (frame, cols, info)
function prepare_frame(sub::DataFrame, spec::ModelSpec, s::Dict{Symbol,Any};
                       age_mean = nothing, bage_mean = nothing)
    f = DataFrame()
    f.y = Float64.(sub[!, spec.outcome])
    f.iso3 = String.(sub.iso3)
    f.survey = String.(sub.survey)
    f.id = sub.id
    f.year = sub.year
    f.female = Float64.(sub.female)
    am = age_mean === nothing ? mean(Float64.(sub.age)) : age_mean
    f.age_c = Float64.(sub.age) .- am
    f.age_c2 = f.age_c .^ 2
    f.postsecondary = Float64.(sub.postsecondary)
    cols = ["female", "age_c", "age_c2", "postsecondary"]
    # year dummies
    years_present = sort(unique(sub.year))
    yref = spec.yearref
    yref_note = ""
    if !(yref in years_present) && !isempty(years_present)
        yref = minimum(years_present)
        yref_note = "reference year $(spec.yearref) absent from sample; reference set to $(yref)"
    end
    for y in years_present
        y == yref && continue
        f[!, "year$(y)"] = Float64.(sub.year .== y)
        push!(cols, "year$(y)")
    end
    bm = NaN
    if spec.level >= 2
        for v in vcat(X_VARS, C_VARS)
            (spec.name == "R2" && !s[:r2_fert] && v == :fert) && continue
            f[!, string(v)] = Float64.(sub[!, v])
            push!(cols, string(v))
        end
    end
    if spec.level >= 3
        for v in X_VARS
            f[!, "female_x_$(v)"] = f.female .* f[!, string(v)]
            push!(cols, "female_x_$(v)")
        end
    end
    for v in spec.extra
        if v == :bage_c
            bm = bage_mean === nothing ? mean(Float64.(sub.bage)) : bage_mean
            f.bage_c = Float64.(sub.bage) .- bm
        else
            f[!, string(v)] = Float64.(sub[!, v])
        end
        push!(cols, string(v))
    end
    return f, cols, (age_mean = am, bage_mean = bm, yearref = yref, yref_note = yref_note)
end

sample_hash(ids) = bytes2hex(sha256(join(string.(sort(collect(ids))), ",")))

# ---------------------------------------------------------------------------------------
# 6. Estimation: mixed model, pooled benchmark, wild cluster bootstrap
# ---------------------------------------------------------------------------------------
const OK_RETURN = Set([:SUCCESS, :STOPVAL_REACHED, :FTOL_REACHED, :XTOL_REACHED])

function build_formula(cols::Vector{String}, s::Dict{Symbol,Any}; random::Bool = true)
    fe = term(1) + sum(term.(Symbol.(cols)))
    random || return term(:y) ~ fe
    if s[:covariance] == :zerocorr
        re = zerocorr(term(1) + term(:female) | term(:iso3)) + zerocorr(term(1) + term(:female) | term(:survey))
    elseif s[:covariance] == :unstructured
        re = (term(1) + term(:female) | term(:iso3)) + (term(1) + term(:female) | term(:survey))
    else
        error("unknown covariance")
    end
    return term(:y) ~ fe + re
end

function errstring(e)
    msg = sprint(showerror, e)
    msg = replace(msg, r"\s+" => " ")
    return first(msg, 400)
end

function sd_lookup(vc, grp::Symbol, col::Symbol)
    haskey(vc.σρ, grp) || return missing
    σ = vc.σρ[grp].σ
    haskey(σ, col) || return missing
    return abs(σ[col])   # MixedModels reports σ with the sign of the λ diagonal; the SD is |σ|
end

function fit_mixed(frame::DataFrame, cols::Vector{String}, spec::ModelSpec, s::Dict{Symbol,Any})
    fml = build_formula(cols, s)
    if spec.family == :logit
        routine = "MixedModels.fit(GeneralizedLinearMixedModel, Bernoulli(), LogitLink(); fast=false, nAGQ=1) [Laplace, ML]"
        m = fit(GeneralizedLinearMixedModel, fml, frame, Bernoulli(), LogitLink(); fast = false, nAGQ = 1, progress = false)
        ll = loglikelihood(m); ai = aic(m)
    else
        reml = spec.name == "M5" && s[:reml_m5]
        routine = "MixedModels.fit(MixedModel; REML=$(reml)) [linear mixed model, $(reml ? "REML" : "ML")]"
        m = fit(MixedModel, fml, frame; REML = reml, progress = false)
        if reml
            ll = -objective(m) / 2       # restricted log-likelihood (REML criterion / -2)
            ai = -2 * ll + 2 * dof(m)
        else
            ll = loglikelihood(m); ai = aic(m)
        end
    end
    vc = VarCorr(m)
    rv = m.optsum.returnvalue
    return (model = m, names = coefnames(m), coef = coef(m), se = stderror(m), loglik = ll, aic = ai,
            converged = rv in OK_RETURN, returnvalue = string(rv), singular = issingular(m),
            routine = routine,
            sd_ci = sd_lookup(vc, :iso3, Symbol("(Intercept)")), sd_cf = sd_lookup(vc, :iso3, :female),
            sd_si = sd_lookup(vc, :survey, Symbol("(Intercept)")), sd_sf = sd_lookup(vc, :survey, :female))
end

# CR1 cluster-robust covariance: G/(G-1) * bread * meat * bread
function cr1_cov(X::AbstractMatrix, scores_rowwt::AbstractVector, bread::AbstractMatrix, cl::Vector{Int}, G::Int)
    p = size(X, 2)
    meat = zeros(p, p)
    sg = zeros(p, G)
    @inbounds for i in 1:size(X, 1)
        g = cl[i]; r = scores_rowwt[i]
        for j in 1:p
            sg[j, g] += X[i, j] * r
        end
    end
    meat = sg * sg'
    return (G / (G - 1)) * (bread * meat * bread)
end

function cluster_ids(iso3::Vector{String})
    lv = sort(unique(iso3))
    idx = Dict(c => i for (i, c) in enumerate(lv))
    return [idx[c] for c in iso3], length(lv)
end

function fit_benchmark(frame::DataFrame, cols::Vector{String}, spec::ModelSpec, s::Dict{Symbol,Any})
    fml = build_formula(cols, s; random = false)
    cl, G = cluster_ids(frame.iso3)
    if spec.family == :logit
        g = glm(fml, frame, Binomial(), LogitLink())
        X = modelmatrix(g); y = frame.y; mu = fitted(g)
        w = mu .* (1 .- mu)
        bread = inv(Symmetric(X' * (w .* X)))
        V = cr1_cov(X, y .- mu, bread, cl, G)
        wild = Dict{String,Float64}()
        routine = "GLM.glm(Binomial, LogitLink) pooled; CR1 country-clustered sandwich (G/(G-1)); normal p"
    else
        g = lm(fml, frame)
        X = modelmatrix(g); y = frame.y
        e = y .- X * coef(g)
        bread = inv(Symmetric(X' * X))
        V = cr1_cov(X, e, bread, cl, G)
        wild = wild_cluster_bootstrap(X, y, coefnames(g), coef(g), sqrt.(diag(V)), cl, G)
        routine = "GLM.lm pooled OLS; CR1 country-clustered sandwich (G/(G-1)); normal p; wild cluster bootstrap for F x X"
    end
    bse = sqrt.(max.(diag(V), 0.0))
    bz = coef(g) ./ bse
    bp = 2 .* ccdf.(Normal(), abs.(bz))
    return (names = coefnames(g), se = bse, p = bp, wild = wild, routine = routine)
end

# Wild cluster bootstrap (Rademacher, null imposed, restricted residuals), 999 reps, seed 20261028.
# Weight draws are made once per model and shared across the four F x X terms.
function wild_cluster_bootstrap(X::Matrix{Float64}, y::Vector{Float64}, names::Vector{String},
                                b::Vector{Float64}, se::Vector{Float64}, cl::Vector{Int}, G::Int;
                                B::Int = 999, seed::Int = 20261028)
    rng = Random.Xoshiro(seed)
    W = rand(rng, (-1.0, 1.0), G, B)
    n, p = size(X)
    XtXinv = inv(Symmetric(X' * X))
    out = Dict{String,Float64}()
    for tname in WILD_TERMS
        col = findfirst(==("female_x_" * tname[8:end]), names)
        col === nothing && continue
        tobs = abs(b[col] / se[col])
        keep = setdiff(1:p, col)
        Xr = X[:, keep]
        br = Symmetric(Xr' * Xr) \ (Xr' * y)
        fr = Xr * br
        er = y .- fr
        h = X * XtXinv[:, col]          # β*_t = h' y*
        count = 0
        ystar = similar(y); estar = similar(y)
        bstar = zeros(p)
        for bi in 1:B
            @inbounds for i in 1:n
                ystar[i] = fr[i] + er[i] * W[cl[i], bi]
            end
            bstar .= XtXinv * (X' * ystar)
            estar .= ystar .- X * bstar
            # CR1 variance of β*_t
            sg = zeros(G)
            @inbounds for i in 1:n
                sg[cl[i]] += h[i] * estar[i]
            end
            vt = (G / (G - 1)) * sum(abs2, sg)
            tstar = abs(bstar[col] / sqrt(vt))
            count += (tstar >= tobs)
        end
        out[tname] = count / B
    end
    return out
end

# ---------------------------------------------------------------------------------------
# 7. Result rows
# ---------------------------------------------------------------------------------------
const RESULT_COLS = ["run_id", "model", "deleted_country", "status", "error", "n_obs", "n_countries", "n_surveys",
                     "sample_hash", "term", "estimate", "se", "z", "p", "bench_se", "bench_p", "wild_p", "loglik",
                     "aic", "converged", "singular", "routine", "sd_country_intercept", "sd_country_female",
                     "sd_survey_intercept", "sd_survey_female"]

function empty_row(run_id, model, deleted, status, err, n_obs, n_c, n_s, hash)
    r = Dict{String,Any}(c => missing for c in RESULT_COLS)
    r["run_id"] = run_id; r["model"] = model; r["deleted_country"] = deleted; r["status"] = status
    r["error"] = err; r["n_obs"] = n_obs; r["n_countries"] = n_c; r["n_surveys"] = n_s; r["sample_hash"] = hash
    r["term"] = ""
    return r
end

# Fit one prepared frame and append result rows
function fit_and_record!(rows::Vector, run_id::String, spec::ModelSpec, s::Dict{Symbol,Any},
                         frame::DataFrame, cols::Vector{String}, deleted::String, notes::String)
    n_obs = nrow(frame); n_c = length(unique(frame.iso3)); n_s = length(unique(frame.survey))
    hash = sample_hash(frame.id)
    mixed = nothing; merr = ""
    t0 = time()
    try
        mixed = fit_mixed(frame, cols, spec, s)
    catch e
        merr = errstring(e)
    end
    bench = nothing; berr = ""
    try
        bench = fit_benchmark(frame, cols, spec, s)
    catch e
        berr = errstring(e)
    end
    el = round(time() - t0; digits = 1)
    if mixed === nothing
        r = empty_row(run_id, spec.name, deleted, "failed",
                      String(strip(join(filter(!isempty, [merr, berr == "" ? "" : "benchmark: " * berr, notes]), " | "))),
                      n_obs, n_c, n_s, hash)
        push!(rows, r)
        @info "$(run_id) $(spec.name) $(deleted == "" ? "" : "-" * deleted) FAILED after $(el)s: $(merr)"
        return
    end
    errtxt = strip(join(filter(!isempty, [berr == "" ? "" : "benchmark: " * berr, notes]), " | "))
    for (i, nm) in enumerate(mixed.names)
        r = empty_row(run_id, spec.name, deleted, "ok", errtxt, n_obs, n_c, n_s, hash)
        lab = term_label(nm)
        est = mixed.coef[i]; se = mixed.se[i]
        z = se > 0 ? est / se : missing
        r["term"] = lab; r["estimate"] = est; r["se"] = se; r["z"] = z
        r["p"] = ismissing(z) ? missing : 2 * ccdf(Normal(), abs(z))
        if bench !== nothing
            j = findfirst(==(nm), bench.names)
            if j !== nothing
                r["bench_se"] = bench.se[j]; r["bench_p"] = bench.p[j]
            end
            if spec.name == "M5" && haskey(bench.wild, lab)
                r["wild_p"] = bench.wild[lab]
            end
        end
        r["loglik"] = mixed.loglik; r["aic"] = mixed.aic
        r["converged"] = mixed.converged; r["singular"] = mixed.singular
        r["routine"] = mixed.routine * (bench === nothing ? "" : "; benchmark: " * bench.routine) *
                       "; optimizer return: " * mixed.returnvalue
        r["sd_country_intercept"] = mixed.sd_ci; r["sd_country_female"] = mixed.sd_cf
        r["sd_survey_intercept"] = mixed.sd_si; r["sd_survey_female"] = mixed.sd_sf
        push!(rows, r)
    end
    @info "$(run_id) $(spec.name)$(deleted == "" ? "" : " -" * deleted): n=$(n_obs) countries=$(n_c) surveys=$(n_s) converged=$(mixed.converged) singular=$(mixed.singular) ($(el)s)"
    return
end

# ---------------------------------------------------------------------------------------
# 8. Run drivers
# ---------------------------------------------------------------------------------------
# Prepare everything for one settings dictionary; returns the joined data, masks and constants
function prepare_run(raw::DataFrame, cy::DataFrame, s::Dict{Symbol,Any})
    d = derive_individual(raw, s)
    roster = roster_set(d, s)
    masks = step_masks(d, s, roster)
    pool = s[:status_rule] == :sample ? masks.steps123 : trues(nrow(d))
    status, carried = compute_status(d, pool, s, roster)
    st = survey_table(cy, status, s, roster)
    d.__ord = 1:nrow(d)
    dd = leftjoin(d, st, on = [:iso3, :year]; matchmissing = :equal)
    # leftjoin may reorder rows; restore the original order so that the masks line up
    sort!(dd, :__ord); select!(dd, Not(:__ord)); select!(d, Not(:__ord))
    @assert dd.id == d.id
    m3mask = m3_stage1_mask(dd, masks.steps123)
    k = std_constants(dd, m3mask, s)
    apply_standardization!(dd, k, s)
    return (dd = dd, masks = masks, constants = k, roster = roster, carried = carried, n_roster = length(roster))
end

function run_models!(rows::Vector, run_id::String, models::Vector{String}, s::Dict{Symbol,Any}, prep)
    for mname in models
        spec = MODELS[mname]
        try
            sub = model_sample(prep.dd, spec, s, prep.masks)
            if nrow(sub) == 0
                push!(rows, empty_row(run_id, mname, "", "failed", "empty estimation sample", 0, 0, 0, sample_hash(Int[])))
                continue
            end
            frame, cols, info = prepare_frame(sub, spec, s)
            fit_and_record!(rows, run_id, spec, s, frame, cols, "", info.yref_note)
        catch e
            push!(rows, empty_row(run_id, mname, "", "failed", "sample construction: " * errstring(e), missing, missing, missing, missing))
            @info "$(run_id) $(mname) FAILED in sample construction: $(errstring(e))"
        end
    end
end

function run_influence!(rows::Vector, s::Dict{Symbol,Any}, prep, models::Vector{String} = INFLUENCE_MODELS)
    for mname in models
        spec = MODELS[mname]
        local frame, cols, info
        try
            sub = model_sample(prep.dd, spec, s, prep.masks)
            frame, cols, info = prepare_frame(sub, spec, s)   # centering means from the full origin sample
        catch e
            push!(rows, empty_row("influence", mname, "", "failed", "sample construction: " * errstring(e), missing, missing, missing, missing))
            continue
        end
        for c in sort(unique(frame.iso3))
            keep = frame.iso3 .!= c
            fr = frame[keep, :]
            # drop year dummies that are constant after deletion (year no longer present)
            cols_c = String[]
            for col in cols
                if startswith(col, "year") && all(==(0.0), fr[!, col])
                    continue
                end
                push!(cols_c, col)
            end
            note = length(cols_c) < length(cols) ? "dropped constant year dummies after deletion: " * join(setdiff(cols, cols_c), " ") : ""
            note = String(strip(join(filter(!isempty, [info.yref_note, note]), " | ")))
            try
                fit_and_record!(rows, "influence", spec, s, fr, cols_c, String(c), note)
            catch e
                push!(rows, empty_row("influence", mname, c, "failed", errstring(e), nrow(fr), length(unique(fr.iso3)),
                                      length(unique(fr.survey)), sample_hash(fr.id)))
            end
        end
    end
end

function constants_entry(prep, s::Dict{Symbol,Any})
    k = prep.constants
    return Dict{String,Any}(
        "rule" => k.rule,
        "n_basis" => k.n_basis,
        "n_surveys_in_set" => k.n_surveys,
        "n_rows_in_set" => k.n_rows,
        "n_roster_surveys" => prep.n_roster,
        "leave_sq" => s[:leave_sq_rule] == :U14 ? "raw leave^2 standardized (U14)" : "(standardized leave)^2, not restandardized",
        "status_carry_back" => prep.carried,
        "means" => k.means,
        "sds" => k.sds,
    )
end

function write_results(out_dir::String, rows::Vector)
    df = DataFrame([c => Any[] for c in RESULT_COLS]...)
    for r in rows
        push!(df, [r[c] for c in RESULT_COLS])
    end
    CSV.write(joinpath(out_dir, "results.csv"), df; missingstring = "")
    return nrow(df)
end

function write_session_info(out_dir::String, args, t_start, t_end)
    open(joinpath(out_dir, "session_info.txt"), "w") do io
        println(io, "manifest: P-7Q3 (neutral, version 1)")
        println(io, "script: run.jl")
        println(io, "command line: ", join(args, " "))
        println(io, "start: ", t_start, "  end: ", t_end, "  elapsed_s: ", round((t_end - t_start).value / 1000; digits = 1))
        println(io, "julia: ", VERSION)
        println(io, "os: ", Sys.KERNEL, " ", Sys.MACHINE, "  cpu_threads: ", Sys.CPU_THREADS, "  julia_threads: ", Threads.nthreads())
        println(io, "blas: ", BLAS.get_config())
        for (nm, mod) in [("MixedModels", MixedModels), ("GLM", GLM), ("StatsModels", StatsModels), ("DataFrames", DataFrames),
                          ("CSV", CSV), ("JSON3", JSON3), ("CategoricalArrays", CategoricalArrays), ("Distributions", Distributions)]
            println(io, nm, ": ", pkgversion(mod))
        end
        println(io, "stdlib: LinearAlgebra, Statistics, Random, SHA, Printf, Dates (SparseArrays accessed via MixedModels.SparseArrays)")
        println(io, "mixed-model routine (logit): fit(GeneralizedLinearMixedModel, ...; fast=false, nAGQ=1) -- Laplace, ML; optimizer NLopt LN_NEWUOA (MixedModels default)")
        println(io, "mixed-model routine (linear): fit(MixedModel, ...; REML=false) -- ML (U25: REML=true for M5)")
        println(io, "benchmark: GLM pooled fit; CR1 country-clustered sandwich SE with G/(G-1); normal two-sided p; M5 wild cluster bootstrap (Rademacher, null imposed, 999 reps, seed 20261028, Random.Xoshiro)")
        println(io, "patch: this script defines LinearAlgebra.mul!(::SparseMatrixCSC, ::Adjoint{<:ReMat{T,S}}, ::ReMat{T,P}) for S,P > 1, a method missing from MixedModels 5.9.1 (see IMPLEMENTATION_NOTES.md)")
        println(io, "weights: unweighted (manifest section 7); a weighted branch is not available with the specified mixed-model routines")
        println(io, "random-effects SDs are reported as |sigma| (MixedModels can return a negative sign on an independent-covariance diagonal)")
    end
end

# Returns (ordered run ids, influence model list). "influence" = all of M3-M8;
# "influence:M5" or "influence:M3+M5" restricts the influence refits to the listed models (testing aid).
function parse_run_ids(arg::String)
    ids = String.(strip.(split(arg, ",")))
    filter!(!isempty, ids)
    out = String[]
    dev_ids = [d[1] for d in DEVIATIONS]
    infl_models = String[]
    for id in ids
        if id == "all"
            push!(out, "ORIGIN"); append!(out, dev_ids)
        elseif startswith(id, "influence:")
            push!(out, "influence")
            for m in split(id[11:end], "+")
                String(m) in INFLUENCE_MODELS || error("influence model must be one of $(join(INFLUENCE_MODELS, ", ")): got $(m)")
                push!(infl_models, String(m))
            end
        elseif id == "influence"
            push!(out, "influence")
            append!(infl_models, INFLUENCE_MODELS)
        else
            push!(out, id)
        end
    end
    out = unique(out)
    infl_models = filter(m -> m in infl_models, INFLUENCE_MODELS)   # manifest order
    # manifest order: ORIGIN, deviations, influence
    order = Dict{String,Int}("ORIGIN" => 0)
    for (i, d) in enumerate(dev_ids); order[d] = i; end
    order["influence"] = length(dev_ids) + 1
    for id in out
        haskey(order, id) || error("unknown run id: $(id). Known: ORIGIN, $(join(dev_ids, ", ")), all, influence, influence:<model>")
    end
    return sort(out; by = id -> order[id]), infl_models
end

function main(args)
    length(args) == 3 || error("usage: julia run.jl <data_dir> <out_dir> <run_ids>")
    data_dir, out_dir, run_arg = args
    t_start = now()
    mkpath(out_dir)
    run_ids, infl_models = parse_run_ids(run_arg)
    @info "run ids: $(join(run_ids, ", "))" * ("influence" in run_ids ? " (influence models: $(join(infl_models, ", ")))" : "")
    raw = CSV.read(joinpath(data_dir, "gem_extract.csv"), DataFrame; missingstring = ["", "NA"])
    cy = CSV.read(joinpath(data_dir, "country_year_inputs.csv"), DataFrame; missingstring = ["", "NA"])
    @info "read gem_extract: $(nrow(raw)) rows; country_year_inputs: $(nrow(cy)) rows"
    rows = Any[]
    constants = Dict{String,Any}()
    origin_prep = nothing
    for run_id in run_ids
        if run_id == "ORIGIN"
            s = origin_settings()
            prep = prepare_run(raw, cy, s)
            origin_prep = prep
            constants["ORIGIN"] = constants_entry(prep, s)
            run_models!(rows, "ORIGIN", ALL_MODELS, s, prep)
        elseif run_id == "influence"
            s = origin_settings()
            prep = origin_prep === nothing ? prepare_run(raw, cy, s) : origin_prep
            constants["influence"] = merge(constants_entry(prep, s),
                                           Dict("note" => "origin constants and centering means from the full origin sample",
                                                "models" => infl_models))
            run_influence!(rows, s, prep, infl_models)
        else
            dev = DEVIATIONS[findfirst(d -> d[1] == run_id, DEVIATIONS)]
            s = merge(origin_settings(), dev[2])
            try
                prep = prepare_run(raw, cy, s)
                constants[run_id] = constants_entry(prep, s)
                run_models!(rows, run_id, dev[3], s, prep)
            catch e
                for m in dev[3]
                    push!(rows, empty_row(run_id, m, "", "failed", "run preparation: " * errstring(e), missing, missing, missing, missing))
                end
                @info "$(run_id) FAILED in preparation: $(errstring(e))"
            end
        end
        # write after every run so partial output survives an interruption
        write_results(out_dir, rows)
        open(joinpath(out_dir, "constants.json"), "w") do io
            JSON3.pretty(io, JSON3.write(constants))
        end
    end
    n = write_results(out_dir, rows)
    open(joinpath(out_dir, "constants.json"), "w") do io
        JSON3.pretty(io, JSON3.write(constants))
    end
    t_end = now()
    write_session_info(out_dir, args, t_start, t_end)
    @info "done: $(n) result rows written to $(joinpath(out_dir, "results.csv")) in $(round((t_end - t_start).value / 1000; digits = 1))s"
end

if abspath(PROGRAM_FILE) == @__FILE__
    main(ARGS)
end
