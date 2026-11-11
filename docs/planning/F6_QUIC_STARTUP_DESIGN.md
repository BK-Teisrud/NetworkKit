# F6 QUIC logical startup design and verification preparation

Prepared for #179/#90 in the same draft PR #177 after the owner's approval of the [adapter review](F6_QUIC_ADAPTER_REVIEW.md) at 084525a. Planning only: no new code, compiler, network or fixture authorization. Public Swift declarations and final F6 contract remain unapproved.

## Ownership and admission

Use one internal startup coordinator for one native group, its trust handlers and one monotonic startup budget. Candidate states are preparing, admitted and terminal. A single serialized decision owns the first terminal/result outcome; native callbacks submit observations rather than directly returning a usable connection. No lock is held while invoking a native verification completion, cancelling a group, resuming a caller or executing app/provider code.

| Observation | Decision |
| --- | --- |
| Caller already cancelled before admission | CancellationError; no native work admitted |
| Local trust evaluator actually rejects | Seal startup with redacted trust rejection; respond to the pending verify callback once and cancel group |
| Generic native failure | Seal with sanitized transport error; no certificate/ALPN diagnosis inferred |
| Startup deadline expires | Seal with startup timeout; cancel native work and reject pending verification handlers |
| Native ready signal | Record readiness only; no caller/data admission yet |
| Verified trust proof and negotiated ALPN in requested set, native transport ready, budget open | Commit one connection handoff |
| Observed negotiated ALPN outside requested set | Seal with ALPN policy rejection; no app data handoff |
| Late callback after terminal/close | Reject/suppress safely; cannot admit or revive startup |

Required trust evidence must belong to this immutable connection/security context. A boolean from a different group/session/account cannot authorize the connection. Missing or inaccessible trust/ALPN metadata is a failed/unproved admission condition, not presumed success. TLS resumption may change native callback behavior: define and verify admissible context-bound trust evidence before any implementation claims, rather than require a fresh callback count or accept missing trust blindly. No key/session export, global trust store or hidden new connection is selected.

Apple SecProtocolOptions.h explicitly permits one or more verification callbacks per connection. Each verification handler has its own once-only completion registration. Logical termination drains outstanding handlers with refusal. Late provider/evaluation work may continue cooperatively but cannot answer an already completed handler or publish a connection. A failure winner cannot be overwritten by a later native ready callback. For handoff versus simultaneous cancellation, the coordinator's serialized admission point defines ownership; review that boundary explicitly in tests. Closing after successful handoff belongs to the connection's own lifecycle. The connection retains the verification-handler owner after handoff: a later rejection closes that connection and answers its callback once, without returning a second startup result. Never leave a post-handoff verification callback unanswered.

Do not promise peer close acknowledgement, interruption of all OS trust work or physical resource drain when logical startup ends. Never inspect raw error strings to determine security categories; use explicit local policy decisions or typed native error information with justified mapping.

## Verification inputs to specify before executable scope

These are acceptance inputs for future preparation, not permission to run them. A later execution manifest must fix counts, build/source scope, fixture material, peer isolation, deadlines and cleanup before code/kicking off tests.

- Already-cancelled startup admits no native/provider work.
- Positive trust plus expected ALPN admits exactly once; readiness alone does not.
- Local rejection races a native ready callback: no connection/data admission and one caller result.
- Deadline/cancellation drains a pending trust handler once; late acceptance cannot revive it.
- Observed mismatched/missing ALPN is never admitted, independently of the native error domain.
- Generic native failure and absent callbacks remain transport error/timeout; no fabricated security diagnosis.
- A resumed-context case must prove its trust binding or remain blocked; no inferred trust from callback absence.
- Controlled native trusted/untrusted/wrong-ALPN inputs share a valid positive control, verify bounded outcomes and no rejected connection/data handoff, and preserve the actual native witness separately.

The former Q06/Q07 failed native-error probes stay unchanged. New coordinator acceptance tests must have distinct identifiers and expectations. A timeout on its own does not prove the intended security scenario was exercised. A deterministic test is not native execution evidence.

## Remaining research split and dependencies

Startup ownership/error verification can be prepared independently of empty datagram delivery. The unresolved Q04/Q05 contract still requires a demonstrated native empty-message path and complete mixed-mode isolation, or an explicit later owner disposition. No marker-byte wrapper, stream substitution, new dependency, OS-floor change or silent empty-message removal is adopted.

Before another executable investigation identify an actual changed adapter hypothesis, including how metadata/readiness and resumed trust are obtained. Do not spend a new run merely to rediscover absent callbacks. Keep #179 open until all selected criteria and integrated PR/main are accepted. #90 continues independent security/platform/discovery/multicast/P2P planning; #29/#132 publication barriers remain.
