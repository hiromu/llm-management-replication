suppressMessages(library(data.table))
setwd("/private/var/folders/7q/9m3zdcp550d685wgsq9kvf6r0000gn/T/role_im_yDw0Vg")
res <- fread("tests/_synthetic_out/results.csv")
ok <- res[status == "ok"]
bad <- ok[!(pseudo_r2 > 0 & pseudo_r2 < 1 & ll <= ll0) | is.na(pseudo_r2), .(model_id, n, ll, ll0, pseudo_r2, converged)][!duplicated(model_id)]
print(bad)
print(ok[, .(ll = ll[1], ll0 = ll0[1], r2 = pseudo_r2[1], n = n[1]), by = model_id][order(r2)][1:5])
print(str(ok[1:2]))
