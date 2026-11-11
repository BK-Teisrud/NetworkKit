# Isolated F6 native research

Non-shipping experiment for #179; not imported by NetworkKit. See [scope](../../../docs/planning/F6_NATIVE_RESEARCH_SCOPE.md) and [results](../../../docs/planning/F6_NATIVE_RESEARCH_RESULTS_2026-11-09.md).

The approved runtime is closed: 8/8 compiler commands, 30/40 pure invocations, 19/25 transport sessions and 2/2 fixture pairs consumed. QUIC gaps remain. These tools and unused reserves are not standing permission to rerun or reset a ledger. No production API, dependency or trust-store change is introduced.

Use only explicitly authorized controller actions; no default network execution. Per-invocation hashes in the evidence distinguish corrected source versions. Further compiled corrections require a new reviewed execution scope.

The separately approved [QUIC correction](../../../docs/planning/F6_QUIC_CORRECTION_RESULTS_2026-11-09.md) is also closed: 3/4 compiler commands, 4/8 offline oracle controls, 16/16 local sessions, 2/2 pairs. Its fixed-path run_quic_correction.py ledger is independent of the original runtime and refuses execution after closure. Final-source changes do not retroactively validate build-2 observations.

The separately approved [completion investigation](../../../docs/planning/F6_QUIC_COMPLETION_RESULTS_2026-11-09.md) is closed: 3/6 Mac builds, 6/12 oracle controls, 19/32 local sessions, 2/2 fixture pairs. Eight positive controls match final Swift sources; Q04/Q06/Q07 failed and Q05 was prerequisite-blocked. run_quic_completion.py uses a separate fixed-path closed ledger. Unused quota is not permission to reopen it.

The [startup-only experiment](../../../docs/planning/F6_QUIC_STARTUP_RESULTS_2026-11-09.md) is closed: 4/4 builds (two failed/two passed), 12/20 Swift controls, 7/18 local sessions, 2/2 fixture pairs. Six latest native controls pass; Q04/Q05 remain unresolved. run_startup.py owns a separate fixed-path closed ledger. Its private native callback slot uses explicitly reviewed experiment-only unchecked-state ownership, not a general Sendable native wrapper.

The [direct datagram comparison](../../../docs/planning/F6_QUIC_DATAGRAM_ROUTE_RESULTS_2026-11-10.md) is closed: 1/4 builds, 4/8 Swift controls, 3/16 sessions, 2/2 pairs. D01–D03 failed complete empty delivery; G01/G02 were prerequisite-blocked. run_datagram_routes.py uses its own closed fixed-path ledger. No remaining budget is standing execution authority.

The [runtime comparison](../../../docs/planning/F6_QUIC_RUNTIME_COMPARISON_RESULTS_2026-11-11.md) is closed before tests: 1/6 legacy compiler commands, 0/12 Swift inputs, 0/24 sessions, 0/2 fixture pairs, one timed-out simulator boot. Temporary simulator deletion/absence verified. RuntimeComparison/run_runtime.py refuses reopening; modern probe was not implemented or compiled.
