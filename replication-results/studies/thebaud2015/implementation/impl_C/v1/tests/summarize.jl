using CSV, DataFrames, JSON3
out = ARGS[1]
res = CSV.read(joinpath(out, "results.csv"), DataFrame)
truth = JSON3.read(read("/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_dc4ded12/synthetic/synthetic_truth.json", String))
println("rows: ", nrow(res), "  runs: ", join(unique(res.run_id), ","))
println("status counts: ", combine(groupby(res, [:run_id, :status]), nrow => :rows))
println("fits per run/model (unique sample rows): ")
u = unique(res[:, [:run_id, :model, :deleted_country, :status, :n_obs, :n_countries, :n_surveys, :converged, :singular]])
show(stdout, combine(groupby(u, [:run_id, :model]), nrow => :fits, :status => (x -> count(==("ok"), x)) => :ok, :converged => (x -> count(y -> y === true, x)) => :converged, :singular => (x -> count(y -> y === true, x)) => :singular); allrows = true); println()
m3 = res[(res.run_id .== "ORIGIN") .& (res.model .== "M3"), :]
println("\nORIGIN M3 vs truth:")
for (t, key) in [("(Intercept)", "b0"), ("female", "female"), ("childcare", "childcare"), ("female:leave", "female:leave"), ("female:childcare", "female:childcare"), ("female:parttime", "female:parttime")]
    r = m3[m3.term .== t, :]
    println("  ", rpad(t, 18), " est=", round(r.estimate[1], digits = 3), " se=", round(r.se[1], digits = 3), " truth=", truth[key], "  |est-truth|/se=", round(abs(r.estimate[1] - truth[key]) / r.se[1], digits = 2),
            "  bench_se=", round(r.bench_se[1], digits = 3), " p=", round(r.p[1], digits = 4), " bench_p=", round(r.bench_p[1], digits = 4))
end
println("  sd_country_intercept=", round(m3.sd_country_intercept[1], digits = 3), " (truth ", truth["sd_country"], ")  sd_country_female=", round(m3.sd_country_female[1], digits = 3), " (truth ", truth["sd_country_female"], ")")
println("  sd_survey_intercept=", round(m3.sd_survey_intercept[1], digits = 3), " (truth ", truth["sd_survey"], ")  sd_survey_female=", round(m3.sd_survey_female[1], digits = 3), " (truth ", truth["sd_survey_female"], ")")
println("  loglik=", m3.loglik[1], " aic=", m3.aic[1], " converged=", m3.converged[1], " singular=", m3.singular[1])
println("  terms: ", join(m3.term, " "))
println("  hash: ", m3.sample_hash[1])
for mn in ["M1", "M2", "R1", "R2", "R3", "M4", "M6", "M7", "M8"]
    r = res[(res.run_id .== "ORIGIN") .& (res.model .== mn), :]
    nrow(r) == 0 && continue
    f = r[r.term .== "female", :]
    println("  ", mn, ": female est=", round(f.estimate[1], digits = 3), " se=", round(f.se[1], digits = 3), " n=", f.n_obs[1], " terms=", nrow(r), " sd_c_int=", round(r.sd_country_intercept[1], digits = 3), " sd_s_int=", round(r.sd_survey_intercept[1], digits = 3), " ll=", round(r.loglik[1], digits = 2))
end
m5 = res[(res.run_id .== "ORIGIN") .& (res.model .== "M5"), :]
println("\nORIGIN M5 wild p: ", [(t, round(m5[m5.term .== t, :wild_p][1], digits = 3), round(m5[m5.term .== t, :bench_p][1], digits = 3)) for t in ["female:leave", "female:leave_sq", "female:childcare", "female:parttime"]])
for run in ["U09", "U23", "U25"]
    r = res[res.run_id .== run, :]
    nrow(r) == 0 && continue
    println(run, " ", r.model[1], ": n=", r.n_obs[1], " status=", r.status[1], " ll=", r.loglik[1], " aic=", r.aic[1], " routine=", first(string(r.routine[1]), 60))
end
inf = res[res.run_id .== "influence", :]
if nrow(inf) > 0
    ui = unique(inf[:, [:model, :deleted_country, :status, :n_obs, :n_countries, :n_surveys]])
    println("\ninfluence: ", nrow(ui), " refits; countries deleted: ", join(ui.deleted_country, " "), "; status ok: ", count(==("ok"), ui.status))
    println("  n_countries all 23: ", all(ui.n_countries .== 23), "  n_obs range: ", extrema(ui.n_obs))
    fc = inf[inf.term .== "female:childcare", :]
    println("  female:childcare across deletions: min=", round(minimum(fc.estimate), digits = 3), " max=", round(maximum(fc.estimate), digits = 3), " wild_p range=", extrema(fc.wild_p))
end
println("\nconstants.json keys: ", keys(JSON3.read(read(joinpath(out, "constants.json"), String))))
