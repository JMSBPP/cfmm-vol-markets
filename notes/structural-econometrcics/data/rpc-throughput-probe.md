# RPC throughput probe — Phase 10 Wave-2 (plan 10-03)

Answers RESEARCH Open Question 3 (can `mainnet.base.org` sustain the bulk
archive read?). This is the SIZING probe; the bulk read itself is 10-06.

| metric | value |
|---|---|
| endpoint | `https://mainnet.base.org` |
| PROBE_CALLS | 200 |
| PROBE_OK_COUNT | 200 |
| PROBE_ERROR_COUNT | 0 |
| PROBE_429_COUNT | 0 |
| PROBE_ELAPSED_S | 27.630 |
| PROBE_CALLS_PER_S | 7.239 |
| PROJECTED_BULK_MINUTES (15k calls) | 34.54 |

`PROBE_CALLS_PER_S` is the post-backoff effective rate: `rpcPost` retries
transient 429s internally, so a 429 that eventually succeeded is counted OK.
`PROJECTED_BULK_MINUTES` uses the RESEARCH 15,000-call (daily-sized) figure;
the HOURLY re-scope makes the bulk read larger — see the plan SUMMARY for the
hourly-adjusted projection 10-06 must budget against.
