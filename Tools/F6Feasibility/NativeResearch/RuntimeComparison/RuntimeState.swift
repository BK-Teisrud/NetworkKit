import Foundation

/// Shared admission controls; no alternative framing or payload conversion.
func runtimePure(_ id: String) throws -> ResearchReport {
    if let mapped = ["V01":"R01","V02":"R02","V03":"R03","V04":"R04"][id] {
        let original = try datagramPure(mapped)
        return ResearchReport(id:id,status:original.status,observations:original.observations)
    }
    let gate = StartupCoordinator(); let replies = StartupWitness()
    let token = gate.register(context:gate.context) { replies.reply($0) }!
    if id == "V05" {
        gate.nativeReady(alpn:researchALPN)
        try assertion(gate.snapshot.handoffs == 0 && !gate.admitData(),"ready-not-trust-proof")
        gate.evaluated(token,valid:true)
        try assertion(gate.snapshot.handoffs == 1 && gate.admitData() && replies.state.withLock { $0.trueReplies == 1 },"trust-ALPN-admission")
    } else if id == "V06" {
        gate.terminate(.cancelled); gate.evaluated(token,valid:true); gate.nativeReady(alpn:researchALPN)
        try assertion(gate.result.resolutionCount == 1 && gate.snapshot.handoffs == 0 && !gate.admitData() && replies.state.withLock { $0.replies == 1 && $0.trueReplies == 0 },"late-terminal-revival")
    } else { throw ProbeFailure.failed("pure-runtime-id") }
    gate.terminate(.cancelled)
    return ResearchReport(id:id,observations:["evidence":"actual shared admission/state, fixed input"])
}
