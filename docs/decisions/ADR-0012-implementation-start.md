# ADR-0012: Begin the approved HTTP-core implementation

Date: 2026-10-20. Status: Accepted through the owner's instruction to continue.
Gate: [START-00 / #41](https://github.com/BK-Teisrud/NetworkKit/issues/41). First task: [I01 / #42](https://github.com/BK-Teisrud/NetworkKit/issues/42).

## Owner instruction and context

After the conversation explicitly identified implementation authorization as the next step, the owner instructed the assistant to execute the work and ask when input is needed, and supplied an Xcode-created default NetworkKit package.

Translated from Norwegian: “Let us do this together. We will continue as we did yesterday. You execute and ask if you need anything. I have already created a Swift package called NetworkKit in the folder. It is empty and only has the default Xcode setup.”

This instruction is treated in context as authorization to begin the previously approved HTTP core, starting with the package baseline. It is not a quotation of an approval phrase the owner did not use. The original statement remains in the conversation.

## Decision and scope

Close #41 explicitly after recording the instruction. Continue one bounded task and PR at a time within existing contracts. The owner's starter package is adapted rather than discarded: repository-root manifest, package NetworkKit, product/target/import NetworkKit, one library module and one test target, Swift tools 6.2, Swift 6 mode, and OS minimums 17/14/10/17. A root manifest supports ordinary Swift Package Manager consumption of the repository.

Remove the empty Xcode example test. Building the test target and compiling a separate importing consumer are smoke checks, not passed behavioral tests. The library remains without HTTP behavior at I01; real contract tests accompany I02 and subsequent implementation. No workflows are introduced until I06.

## Continuing restrictions

Existing scope, rights, concurrency, security, platforms, and cost decisions remain in force. New scope, paid services, access changes, and release publication require separate decisions. Missing minimum-OS evidence still blocks release. Norwegian conversation and English repository content remain unchanged.

ADR-0009 remains the historical record of planning-only approval on 2026-10-19. This later decision supersedes its implementation hold from 2026-10-20; it does not alter the earlier approval or claim completed product functionality.
