# Code-path harness: includes run.jl (main is guarded), prepares every deviation run and
# reports sample sizes / constants, and fits only cheap stage-2 models under selected branches.
include("/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_dc4ded12/run.jl")
dir = "/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_dc4ded12"
raw = CSV.read(joinpath(dir, "synthetic/gem_extract.csv"), DataFrame; missingstring = ["", "NA"])
cy = CSV.read(joinpath(dir, "synthetic/country_year_inputs.csv"), DataFrame; missingstring = ["", "NA"])

s0 = origin_settings()
p0 = prepare_run(raw, cy, s0)
println("ORIGIN: roster=", p0.n_roster, " M3-set surveys=", p0.constants.n_surveys, " carried=", length(p0.carried))
for mname in ALL_MODELS
    spec = MODELS[mname]
    sub = model_sample(p0.dd, spec, s0, p0.masks)
    f, cols, info = prepare_frame(sub, spec, s0)
    println("  ", mname, " n=", nrow(sub), " surveys=", length(unique(sub.survey)), " cols=", length(cols), " yref=", info.yearref, " ", info.yref_note)
end
println()
for (id, chg, models) in DEVIATIONS
    s = merge(origin_settings(), chg)
    p = prepare_run(raw, cy, s)
    parts = String[]
    for mname in models
        spec = MODELS[mname]
        sub = model_sample(p.dd, spec, s, p.masks)
        f, cols, info = prepare_frame(sub, spec, s)
        push!(parts, "$(mname):n=$(nrow(sub)),svy=$(length(unique(sub.survey))),cols=$(length(cols))" * (info.yref_note == "" ? "" : ",yref=$(info.yearref)"))
    end
    k = p.constants
    println(id, " ", chg, " roster=", p.n_roster, " set=", k.n_surveys, "/", k.n_basis, " leave(m,sd)=(", round(k.means["leave"], digits = 3), ",", round(k.sds["leave"], digits = 3),
            ") status=(", round(k.means["status"], digits = 4), ",", round(k.sds["status"], digits = 4), ")",
            haskey(k.means, "leave_sq_raw") ? " leave_sq_raw=($(round(k.means["leave_sq_raw"], digits=1)),$(round(k.sds["leave_sq_raw"], digits=1)))" : "",
            " carried=", length(p.carried))
    println("    ", join(parts, "  "))
end
println()
# Sanity: standardized variables have mean 0 / sd 1 over the M3 set of surveys (origin)
m3 = model_sample(p0.dd, MODELS["M3"], s0, p0.masks)
svy = unique(m3[:, [:iso3, :year, SURVEY_VARS...]], [:iso3, :year])
for v in SURVEY_VARS
    println("  z-check ", v, " mean=", round(mean(svy[!, v]), digits = 10), " sd=", round(std(svy[!, v]), digits = 10))
end
println("  leave_sq == leave^2: ", all(isapprox.(m3.leave_sq, m3.leave .^ 2)))
# U15 country rule: standardized country means have mean 0 / sd 1
s15 = merge(origin_settings(), Dict{Symbol,Any}(:std_rule => :country)); p15 = prepare_run(raw, cy, s15)
m3_15 = model_sample(p15.dd, MODELS["M3"], s15, p15.masks)
svy15 = unique(m3_15[:, [:iso3, :year, :leave]], [:iso3, :year])
cm = combine(groupby(svy15, :iso3), :leave => mean => :leave)
println("  U15 country-mean leave: mean=", round(mean(cm.leave), digits = 10), " sd=", round(std(cm.leave), digits = 10), " n=", nrow(cm))
# U16 individual rule
s16 = merge(origin_settings(), Dict{Symbol,Any}(:std_rule => :individual)); p16 = prepare_run(raw, cy, s16)
m3_16 = model_sample(p16.dd, MODELS["M3"], s16, p16.masks)
println("  U16 row-level leave: mean=", round(mean(m3_16.leave), digits = 10), " sd=", round(std(m3_16.leave), digits = 10))
# U14
s14 = merge(origin_settings(), Dict{Symbol,Any}(:leave_sq_rule => :U14)); p14 = prepare_run(raw, cy, s14)
m3_14 = model_sample(p14.dd, MODELS["M3"], s14, p14.masks)
svy14 = unique(m3_14[:, [:iso3, :year, :leave_sq]], [:iso3, :year])
println("  U14 leave_sq over surveys: mean=", round(mean(svy14.leave_sq), digits = 10), " sd=", round(std(svy14.leave_sq), digits = 10))
println()
# Cheap fits under selected branches (stage-2 models only) to exercise code paths
rows = Any[]
for (id, mname) in [("U20", "M4"), ("U20", "M5"), ("N01", "M4"), ("U05", "M5"), ("U07", "M6"), ("U24", "M7"), ("U11", "M8"), ("U22", "M5"), ("U15", "M5"), ("U16", "M5"), ("U14", "M5"), ("U01", "M5"), ("U02", "M5"), ("U17", "M5"), ("U18", "M5"), ("U19", "M5"), ("U12", "M5"), ("U13", "M5"), ("U08", "M5"), ("U09", "M4"), ("U10", "M4"), ("U23", "M6")]
    chg = DEVIATIONS[findfirst(d -> d[1] == id, DEVIATIONS)][2]
    s = merge(origin_settings(), chg)
    p = prepare_run(raw, cy, s)
    run_models!(rows, id, [mname], s, p)
end
df = DataFrame([c => Any[] for c in RESULT_COLS]...)
for r in rows; push!(df, [r[c] for c in RESULT_COLS]); end
summ = unique(select(df, :run_id, :model, :status, :n_obs, :n_countries, :n_surveys, :converged, :singular, :sd_country_intercept, :sd_survey_female))
show(stdout, summ; allrows = true)
println()
println("U20 M4 terms: ", join(df[(df.run_id .== "U20") .& (df.model .== "M4"), :term], " "))
println("N01 M4 terms: ", join(df[(df.run_id .== "N01") .& (df.model .== "M4"), :term], " "), " | error col: ", first(df[(df.run_id .== "N01") .& (df.model .== "M4"), :error]))
# Failure path: force an error by fitting an impossible model (constant outcome)
spec = MODELS["M4"]; sub = model_sample(p0.dd, spec, s0, p0.masks); f, cols, info = prepare_frame(sub, spec, s0)
f.y .= 1.0
rows2 = Any[]
fit_and_record!(rows2, "TEST", spec, s0, f, cols, "", "")
println("forced-failure row: status=", rows2[1]["status"], " error=", first(string(rows2[1]["error"]), 120))
