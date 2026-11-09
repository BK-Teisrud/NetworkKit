import Foundation
import Network

func modelCase(_ id: String) async throws -> ResearchReport {
    let n = Int(id.dropFirst()) ?? 0
    switch id.first {
    case "B":
        let b = BrowserModel()
        switch n {
        case 1: try assertion(b.records.isEmpty && b.revision == 0,"empty-ready")
        case 2: try b.update(["a"]); let key = try b.endpoint("a"); try b.update(["a"],txtBytes:1); let updated = try b.endpoint("a"); try assertion(updated == key,"tracked-id")
        case 3: try b.update(["a"]); try b.update([]); try rejected { _ = try b.endpoint("a") }
        case 4: try b.update(["a"]); b.transferred = true; b.stop(); try rejected { _ = try b.endpoint("a") }; try assertion(b.transferred,"transferred-ownership")
        case 5: try b.wait(after:0); try rejected { try b.wait(after:0) }
        case 6: try b.wait(after:0); try assertion(b.waiter,"waiting"); try b.update(["a"]); try assertion(!b.waiter && b.revision == 1,"new-revision")
        case 7: try rejected { try b.wait(after:1) }
        case 8: try rejected { try b.update(["a","b","c"]) }; try assertion(b.stopped && b.records.isEmpty,"overlimit-terminal")
        case 9: try rejected { try b.update(["a"],txtBytes:9) }; try assertion(b.stopped,"txt-terminal")
        case 10: b.revision = .max; try rejected { try b.update([]) }; try assertion(b.stopped && b.revision == .max,"revision-wrap")
        default: throw ProbeFailure.failed("model-id")
        }
    case "L":
        let registry = LeaseRegistry(); let first = try registry.reserve()
        switch n {
        case 1: try registry.handoff(first); try rejected { _ = try registry.reserve() }; try assertion(registry.state.withLock { $0.active.count == 1 },"total-cap")
        case 2: registry.release(first); registry.release(first); try assertion(registry.state.withLock { $0.releases == 1 && $0.rearms == 1 },"double-credit")
        case 3: try registry.handoff(first); registry.stop(); try rejected { try registry.handoff(first) }; try assertion(registry.state.withLock { $0.active.contains(first) },"handoff-commit")
        case 4: registry.release(first); try assertion(registry.state.withLock { $0.active.isEmpty && $0.pending.isEmpty },"deadline-lease")
        case 5: registry.stop(); registry.release(first); try assertion(registry.state.withLock { $0.rearms == 0 },"stopped-rearm")
        case 6:
            final class Wrapper { let lease: Lease; init(_ lease: Lease) { self.lease = lease } }
            var wrapper: Wrapper? = Wrapper(Lease(registry,first)); weak let weakWrapper = wrapper
            wrapper = nil; try assertion(weakWrapper == nil && registry.state.withLock { $0.active.isEmpty },"model-registry-cycle")
        default: throw ProbeFailure.failed("model-id")
        }
    case "M":
        var model = DatagramModel()
        switch n {
        case 1: model.push(Data()); try assertion(model.take()?.0 == Data(),"zero-is-data")
        case 2: model.push(Data(repeating:1,count:9)); try assertion(model.queue.isEmpty && model.dropped == 1,"observed-oversize")
        case 3: try assertion(model.dropped == 0,"no-callback-no-count")
        case 4: model.push(Data([1])); model.push(Data([2])); let result = model.take(); try assertion(result?.0 == Data([1]) && result?.1 == 1,"drop-newest")
        case 5: model.push(Data([1])); model.push(Data([2])); _ = model.take(); try assertion(model.dropped == 0 && model.queue.isEmpty,"dequeue-reset")
        case 6: model.dropped = .max; model.push(Data(repeating:1,count:9)); try assertion(model.dropped == .max && model.saturated,"saturate")
        default: throw ProbeFailure.failed("model-id")
        }
    case "Q":
        var model = QUICModel()
        switch n {
        case 1: try rejected { try model.operation(role:"receiveOnly",send:true) }; try assertion(model.sideEffects == 0,"direction-side-effect")
        case 2: try model.stream(1,pending:true); try model.stream(2); try rejected { try model.stream(3) }; try assertion(model.active.count == 2 && model.pending.count == 1,"stream-cap")
        case 3: try model.stream(1); try model.stream(2); let waits = Array(model.waiters.values); model.close(); try assertion(waits.allSatisfy { $0.resolutionCount == 1 } && model.active.isEmpty,"children-terminal")
        case 4: try model.stream(1); try model.stream(2); model.closeStream(1); try assertion(model.active == [2] && model.waiters[2]?.resolutionCount == 0,"sibling-model")
        case 5: try model.datagram(); try rejected { try model.datagram() }; try assertion(model.datagramFlow,"one-flow")
        case 6: let caller = 8, negotiated = 6, bytes = 7; try rejected { try assertion(bytes <= min(caller,negotiated),"size") }
        case 7: let alpn = ""; try rejected { try assertion(!alpn.isEmpty && alpn.utf8.allSatisfy { (33...126).contains($0) },"alpn") }
        case 8: try model.send(); try rejected { try model.send() }; try assertion(model.senderBusy,"no-extra-waiter")
        default: throw ProbeFailure.failed("model-id")
        }
    default: throw ProbeFailure.failed("model-id")
    }
    return ResearchReport(id:id,observations:["evidence":"pure policy model, not native/permission proof"])
}

func printReport(_ value: ResearchReport) {
    if let bytes = try? JSONEncoder().encode(value) { FileHandle.standardOutput.write(bytes + Data([10])) }
}
func failedReport(_ id: String, _ error: any Error) -> ResearchReport {
    ResearchReport(id:id,status:"fail",observations:["error":String(describing:error)])
}
@main struct ResearchMain {
    static func main() async {
        let args = CommandLine.arguments
        guard args.count >= 3 else { printReport(failedReport("none",ProbeFailure.failed("explicit-mode-id"))); exit(1) }
        let fixture = ProcessInfo.processInfo.environment["F6_RESEARCH_FIXTURE"].map { URL(fileURLWithPath:$0) }
        if args[1] == "--pure" {
            do { printReport(try await modelCase(args[2])) } catch { printReport(failedReport(args[2],error)); exit(1) }
            return
        }
        if args[1] == "--local-batch", let fixture {
            var observedInterface: NWInterface?
            while let line = readLine() {
                let id = line.trimmingCharacters(in:.whitespacesAndNewlines)
                if id == "quit" { return }
                do {
                    let report: ResearchReport
                    if id.hasPrefix("N"), (1...6).contains(Int(id.dropFirst()) ?? 0) {
                        let result = try await tcpCase(id,observedInterface:observedInterface); observedInterface = result.1; report = result.0
                    } else if id.hasPrefix("Q"), (1...9).contains(Int(id.dropFirst()) ?? 0) { report = try await quicCase(id,root:fixture) }
                    else { throw ProbeFailure.failed("explicit-local-id") }
                    printReport(report)
                } catch { printReport(failedReport(id,error)) }
            }
            return
        }
        if args[1] == "--peer", args[2] == "Q10", let fixture {
            do {
                let peer = try QUICListenerPeer(root:fixture); defer { peer.close() }
                let port = try await peer.start(); printReport(ResearchReport(id:"Q10-ready",observations:["port":String(port)]))
                let group = try await peer.take(); let flow = try await group.incoming()
                let input = try await flow.read(4); try assertion(input == Data("q10\n".utf8),"independent-input")
                try await flow.send(input)
                printReport(ResearchReport(id:"Q10-peer",observations:["peerTransportGroups":String(peer.groups.withLock { $0.count }),"echoBytes":String(input.count)]))
                try await Task.sleep(for:.seconds(0.3))
            } catch { printReport(failedReport("Q10-peer",error)); exit(1) }
            return
        }
        printReport(failedReport(args[2],ProbeFailure.failed("mode"))); exit(1)
    }
}
