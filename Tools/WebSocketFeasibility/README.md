# Native WebSocket feasibility tool

Non-shipping, explicitly opt-in #165 experiment. No NetworkKit dependency/import, public SDK API, automatic CI, external service or production transport decision. Native clients communicate only with a native fixture bound to IPv4 loopback. Do not use this synchronous semaphore-based harness as an application client implementation.

## Run

Requires the existing Xcode 26.3 / Swift 6.2 toolchain on macOS 15+.

```sh
swift build --package-path Tools/WebSocketFeasibility -Xswiftc -warnings-as-errors
python3 Tools/WebSocketFeasibility/run.py --output /private/tmp/networkkit-websocket-new-attempt
```

The runner refuses to overwrite an output directory and does not build or rerun automatically. It executes exactly eight fresh connections per candidate, sequentially. Each subprocess has a 20-second harness bound and its process group is terminated if that bound expires. Application-level open waits are 10 seconds and individual receive/send/close waits are bounded. Results preserve failures and source/log hashes; raw logs stay in the private output directory.

Cases: text then binary with one 250ms pause before the second receive; binary payloads 65535/65536/65537 bytes against a 65536-byte setting; pending receive cancellation; immediate repeated stop; native normal peer close; TCP-accepted handshake withheld. One in-flight send/receive, one connection at a time. No arbitrary payload sizes or CLI scenarios are accepted. No custom WebSocket framing or TLS implementation.

## Interpretation

The final report is [F5_NATIVE_FEASIBILITY_REPORT](../../docs/planning/F5_NATIVE_FEASIBILITY_REPORT.md). Exact byte success, normal close, terminal state and fixture cancellation are observed. A receive failure alone does not diagnose every native error cause. The withheld case checks a harness wait and accepted TCP connection, not a library timeout implementation.

`time -l` maximum RSS includes the whole native process/framework/fixture, not SDK allocations or a process limit. Eight distinct scenarios are not statistical repetitions or a long-session test. Terminal callback observation does not prove every native allocation has been released.

No WSS/trust/redirect verification, production auth provider, hostile frame injection, controlled fragmentation, abrupt peer-loss test, real server semantics, repeated state-race proof, async consumer adapter or mobile/physical execution is delivered. The fixture's optional peer-cancel branch is not an executed scenario or a TCP reset guarantee. Watch WebSocket is deferred; HTTP support/#132 unchanged. #29 remains a publication barrier. Any further runtime expansion requires review of the approved finite scope.

## Separate #168 experiment

This page describes only the original #165 executable. The separately authorized handshake/public-WSS probe has its own [security instructions and budget boundaries](SECURITY_README.md); it does not rerun or expand #165's recorded cases.
