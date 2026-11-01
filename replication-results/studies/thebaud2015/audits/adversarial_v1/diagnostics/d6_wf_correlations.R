## POST-HOC diagnostic: survey-level correlations among the three work-family indicators
## over the origin M3 survey set, compared with article footnote 10 (r = .22, -.30, -.25).
source("audits/adversarial_v1/diagnostics/load_impl.R")
s <- origin_settings(); prep <- prepare_run(inputs, s)
m3 <- build_sample(prep$d, "M3", s)
sv <- unique(m3[, .(survey, iso3)])
sv <- merge(sv, prep$survey_table[, .(survey, leave, childcare, parttime)], by = "survey")
r <- data.table(pair = c("leave-childcare", "leave-parttime", "childcare-parttime"),
                ours = c(cor(sv$leave, sv$childcare), cor(sv$leave, sv$parttime), cor(sv$childcare, sv$parttime)),
                published_fn10 = c(.22, -.30, -.25), n_surveys = nrow(sv))
print(r); fwrite(r, "audits/adversarial_v1/diagnostics/d6_wf_correlations.csv")
