# Execution sandbox tests (2026-10-27)

- checks/nonet.sb `(deny network*)`, used for the B and C frozen runs: DNS lookups blocked (curl example.com, rc 6); direct-IP HTTPS blocked; R url() blocked; R PSOCK cluster cannot start.
- checks/nonet_localhost.sb, used for the A frozen run because A's influence loop uses an R socket cluster: deny network*, then allow bind/inbound on localhost and outbound to localhost only. DNS blocked (rc 6), direct-IP HTTPS to 1.1.1.1 blocked (rc 7), local PSOCK cluster works.
- An earlier draft that also allowed `network* (local ip "localhost:*")` let direct-IP traffic through. It was rejected and never used for a run.
