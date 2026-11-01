# Cross-check of the ORIGIN M3 fit: compare the manifest estimator (fast=false) with the
# fast=true path and with the objective evaluated at alternative theta values.
include("/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_dc4ded12/run.jl")
dir = "/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_dc4ded12"
raw = CSV.read(joinpath(dir, "synthetic/gem_extract.csv"), DataFrame; missingstring = ["", "NA"])
cy = CSV.read(joinpath(dir, "synthetic/country_year_inputs.csv"), DataFrame; missingstring = ["", "NA"])
s0 = origin_settings(); p0 = prepare_run(raw, cy, s0)
for mname in ["M1", "M3"]
    spec = MODELS[mname]
    sub = model_sample(p0.dd, spec, s0, p0.masks)
    f, cols, info = prepare_frame(sub, spec, s0)
    fml = build_formula(cols, s0)
    t1 = @elapsed m_fast = fit(GeneralizedLinearMixedModel, fml, f, Bernoulli(), LogitLink(); fast = true, nAGQ = 1, progress = false)
    println(mname, " fast=true : ", round(t1, digits = 1), "s deviance=", round(deviance(m_fast), digits = 4), " theta=", round.(m_fast.θ, digits = 4), " ret=", m_fast.optsum.returnvalue)
    t2 = @elapsed m_slow = fit(GeneralizedLinearMixedModel, fml, f, Bernoulli(), LogitLink(); fast = false, nAGQ = 1, progress = false)
    println(mname, " fast=false: ", round(t2, digits = 1), "s deviance=", round(deviance(m_slow), digits = 4), " theta=", round.(m_slow.θ, digits = 4), " ret=", m_slow.optsum.returnvalue, " feval=", m_slow.optsum.feval)
    i = findfirst(==("female_x_childcare"), coefnames(m_slow))
    if i !== nothing
        println("   female:childcare fast=true ", round(coef(m_fast)[i], digits = 4), " fast=false ", round(coef(m_slow)[i], digits = 4))
    end
    j = findfirst(==("female"), coefnames(m_slow))
    println("   female fast=true ", round(coef(m_fast)[j], digits = 4), " fast=false ", round(coef(m_slow)[j], digits = 4))
    # objective of the fast=false model at the fast=true theta/beta (both are Laplace deviances)
    println("   max |beta_fast - beta_slow| = ", round(maximum(abs.(coef(m_fast) .- coef(m_slow))), digits = 4))
end
