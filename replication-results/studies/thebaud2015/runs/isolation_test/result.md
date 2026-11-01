# Network isolation test (before empirical execution)

Profile: runs/isolation_test/nonet.sb (macOS sandbox-exec; allow default, deny network except local unix sockets).
- curl to https://www.oecd.org inside the sandbox: connection refused (blocked).
- Rscript readLines from https://cloud.r-project.org: "cannot open the connection" (blocked); lme4 loads.
- Julia download from https://julialang.org: blocked; MixedModels loads.
File-system isolation is not enforced by this profile: the numerical process can read files outside its run directory. Disclosed as a limitation.
2026-10-27T15:51:28Z
