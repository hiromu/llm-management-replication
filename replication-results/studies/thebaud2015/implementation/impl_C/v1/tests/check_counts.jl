# Independent recomputation of the ORIGIN sample counts straight from the raw codes
# (does not use any function from run.jl). Compares with results.csv of a given out_dir.
using CSV, DataFrames, Statistics
dir = "/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_dc4ded12"
out = ARGS[1]
raw = CSV.read(joinpath(dir, "synthetic/gem_extract.csv"), DataFrame)
cy = CSV.read(joinpath(dir, "synthetic/country_year_inputs.csv"), DataFrame)
res = CSV.read(joinpath(out, "results.csv"), DataFrame)

roster = Dict("AUS"=>2002:2006, "AUT"=>[2005,2007], "BEL"=>2001:2008, "CAN"=>[2001,2002,2003,2006], "CZE"=>[2006],
    "DNK"=>2001:2008, "FIN"=>2001:2008, "FRA"=>2002:2008, "DEU"=>[2001:2006..., 2008], "GRC"=>2003:2008, "ISL"=>2002:2008,
    "IRL"=>2001:2008, "ITA"=>[2001:2003..., 2005:2008...], "JPN"=>2001:2008, "NLD"=>2002:2008, "NZL"=>[2001,2003,2004,2005],
    "NOR"=>[2002:2006..., 2008], "POL"=>[2001,2002,2004], "PRT"=>[2001,2004,2007], "ESP"=>2002:2008, "SWE"=>2001:2007,
    "CHE"=>[2002,2003,2005,2007], "GBR"=>2001:2008, "USA"=>2001:2008)
println("roster size: ", sum(length(v) for v in values(roster)))
inroster = [haskey(roster, String(c)) && (y in roster[String(c)]) for (c, y) in zip(raw.iso3, raw.GEM_YR)]
present = unique(raw[inroster, [:iso3, :GEM_YR]])
println("roster surveys present in gem_extract: ", nrow(present))

# survey-level completeness (raw): leave lag 1, childcare_interp, pt_common_employees_women, gdp, unemp, epl, wmgr, fert, status
cyidx = Dict((String(cy.iso3[i]), cy.year[i]) => i for i in 1:nrow(cy))
function svy_complete(c, y)
    haskey(cyidx, (c, y - 1)) || return false
    haskey(cyidx, (c, y)) || return false
    r = cy[cyidx[(c, y)], :]
    for col in [:childcare_interp, :pt_common_employees_women, :gdp_index_undp, :unemployment_rate, :epl_overall, :women_managers_pct, :fertility_rate]
        ismissing(r[col]) && return false
    end
    ismissing(cy[cyidx[(c, y - 1)], :leave_fte_weeks]) && return false
    return true
end
# status availability: NBSTATUS in {0,1,100} any respondent of (c,y); else carry back from earliest later year
nb = [(!ismissing(v) && (v == 0 || v == 1 || v == 100)) for v in raw.NBSTATUS]
has = Set((String(c), y) for (c, y) in zip(raw.iso3[nb], raw.GEM_YR[nb]))
function status_ok(c, y)
    (c, y) in has && return true
    any(((c, yy) in has) for yy in (y + 1):2008)
end
svyok = Dict((String(c), y) => (svy_complete(String(c), y) && status_ok(String(c), y)) for (c, y) in zip(present.iso3, present.GEM_YR))
println("roster surveys present with complete survey-level vars: ", count(values(svyok)))

age = [(!ismissing(a) && a != 99 && a != 999 && 18 < a < 55) for a in raw.GEMAGE]
emp = [(!ismissing(w) && (w == 1 || w == 2)) for w in raw.GEMWORK]
fem = [(!ismissing(v) && (v == 1 || v == 2)) for v in raw.GEMSEX]
educ = [(!ismissing(v) && v in (0, 111, 1212, 1316, 1720)) for v in raw.GEMEDUC]
act = [(!ismissing(a) && !ismissing(o) && ((a == 1 || o == 1) || (a == 0 && o == 0))) for (a, o) in zip(raw.SUBOANWT, raw.OWNMGE)]
svy = [get(svyok, (String(c), y), false) for (c, y) in zip(raw.iso3, raw.GEM_YR)]
s123 = inroster .& age .& emp
s1 = s123 .& fem .& educ .& act .& svy
println("S1 (M2/M3/R1) n = ", count(s1), "  surveys = ", nrow(unique(raw[s1, [:iso3, :GEM_YR]])), "  countries = ", length(unique(raw.iso3[s1])))
println("S1 M1 (no survey vars) n = ", count(s123 .& fem .& educ .& act))
# R2: steps 1,2 + complete activity, female, age, postsecondary, not_employed (employed non-missing) + survey vars w/o fert (same completeness here)
empdef = [(!ismissing(w) && w in (1, 2, 3, 4, 5, 6)) for w in raw.GEMWORK]
println("R2 n = ", count(inroster .& age .& fem .& educ .& act .& empdef .& svy))
# R3
scrok(v) = !ismissing(v) && (v == 0 || v == 1 || v == 100)
r3 = s1 .& scrok.(raw.SUSKILL) .& scrok.(raw.FEARFAIL) .& scrok.(raw.KNOWENT)
println("R3 n = ", count(r3))
# S2
owner = [(!ismissing(o) && o == 1) for o in raw.OWNMGE]
sole = [(!ismissing(v) && (v == 1 || v == 2)) for v in raw.OMOWN]
bage = [(!ismissing(w) && 1990 <= w <= y && (y - w) > 0) for (w, y) in zip(raw.OMWAGEYR, raw.GEM_YR)]
base2 = s123 .& owner .& fem .& educ .& sole .& bage .& svy
planb = [(!ismissing(v) && v in (1, 2, 3, 4, 6)) for v in raw.OMREASON]
sz = [(!ismissing(v) && 0 <= v <= 999998) for v in raw.OMNOWJOB]
gr = sz .& [(!ismissing(v) && 0 <= v <= 999998) for v in raw.OMYR5JOB]
np = [(!ismissing(v) && v in (1, 2, 3)) for v in raw.OMNEWCST]
nt = [(!ismissing(v) && v in (1, 2, 3)) for v in raw.OMNEWT_5]
y78 = [2002 <= y <= 2008 for y in raw.GEM_YR]
y58 = [2005 <= y <= 2008 for y in raw.GEM_YR]
println("M4 n = ", count(base2 .& planb), "  M5 n = ", count(base2 .& sz), "  M6 n = ", count(base2 .& gr),
        "  M7 n = ", count(base2 .& np .& y78), "  M8 n = ", count(base2 .& nt .& y58), " M8 countries = ", length(unique(raw.iso3[base2 .& nt .& y58])))
println("--- results.csv ORIGIN counts:")
r = unique(res[res.run_id .== "ORIGIN", [:model, :status, :n_obs, :n_countries, :n_surveys]])
show(stdout, r; allrows = true); println()
# Standardization constants recomputed over S1 surveys
s1svy = unique(raw[s1, [:iso3, :GEM_YR]])
leave = [cy[cyidx[(String(c), y - 1)], :leave_fte_weeks] for (c, y) in zip(s1svy.iso3, s1svy.GEM_YR)]
println("leave mean/sd over S1 surveys: ", mean(leave), " ", std(leave))
statusv = Float64[]
for (c, y) in zip(s1svy.iso3, s1svy.GEM_YR)
    c = String(c)
    yy = y
    while !((c, yy) in has); yy += 1; end
    sel = (String.(raw.iso3) .== c) .& (raw.GEM_YR .== yy) .& nb
    push!(statusv, mean([v == 0 ? 0.0 : 1.0 for v in raw.NBSTATUS[sel]]))
end
println("status mean/sd over S1 surveys: ", mean(statusv), " ", std(statusv))
