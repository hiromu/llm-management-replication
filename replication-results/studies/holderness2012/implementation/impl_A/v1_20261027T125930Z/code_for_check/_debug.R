suppressMessages(library(data.table))
setwd("/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_im_yDw0Vg")
source("run.R"); source("tests/synthetic_data.R")
inputs <- make_synthetic_inputs(8000)
grid <- fromJSON("grid.json", simplifyVector = FALSE); spec <- grid$specs[[1]]
S <- build_spec_data(inputs, spec$params)
defs <- model_defs("T4", spec$params)
m2 <- defs[["T4_sameness_cap_simple"]]
ef <- estimation_frame(model_frame(S, "cap", "incl_self"), m2)
fit <- fit_model(ef$mf, m2)
cat("mine: ll", fit$ll, "iter", fit$iter, "conv", fit$converged, "dropped", fit$dropped_rank, "\n")
D2 <- build_design(ef$mf, m2$vars, m2$inter)
g2 <- glm(ef$mf$survival ~ D2$X[, -1] + factor(ef$mf$camp), family = binomial(link = "probit"), control = glm.control(maxit = 200, epsilon = 1e-12))
cat("glm: ll", as.numeric(logLik(g2)), "iter", g2$iter, "conv", g2$converged, "\n")
cf <- coef(g2); cat("n coef mine", length(fit$coef), "glm", length(cf), "NA in glm", sum(is.na(cf)), "\n")
d <- fit$coef - cf; print(head(sort(abs(d), decreasing = TRUE), 5))
print(cbind(mine = head(fit$coef, 6), glm = head(cf, 6)))
# check survival constant camps
print(ef$mf[, .(n = .N, s = mean(survival)), by = camp][order(s)][1:5])
# camp models: 7o
m <- defs[["T4_steepness_camp_full"]]
mf <- model_frame(S, "camp", "incl_self")
fitc <- fit_model(mf, m)
D <- build_design(mf, m$vars, m$inter)
g <- glm(mf$survival ~ D$X[, -1], family = binomial(link = "probit"), control = glm.control(maxit = 200, epsilon = 1e-12))
cat("camp full: mine ll", fitc$ll, "glm ll", as.numeric(logLik(g)), "dropped", fitc$dropped_rank, "\n")
cf <- coef(g); names(cf) <- sub("^D\\$X\\[, -1\\]", "", names(cf))
common <- intersect(names(fitc$coef), names(cf)); cat("max diff common:", max(abs(fitc$coef[common] - cf[common])), " glm NA:", names(cf)[is.na(cf)], "\n")
