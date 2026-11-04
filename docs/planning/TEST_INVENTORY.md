# Test declaration inventory — TLS-01

Current candidate note: [I30 verification](I30_DOWNLOAD_VERIFICATION.md) passes 267 local Mac declarations in 32 suites. DownloadTests has 21 declarations / 55 expanded cases; a separate normal-import compatibility test checks public function signatures. Production source is unchanged from accepted I29. Required candidate PR/main and simulator/platform execution remain pending; older snapshots below are retained.

Snapshot: 2026-10-27, TLS-01 candidate based on `dcf0a1b57c43ea5d96e06ee1d328e2d3d86a1a76`. This source index contains 218 `@Test` function declarations, including two macOS-only child-process tests and one macOS-only native TLS test; other selected runtime destinations retain 215 declarations. Parameterized cases are not additional function declarations. Runtime results must come from execution, not this count. See [contract evidence ledger](TEST_EVIDENCE.md) for coverage and limitations. Refresh this snapshot when the suite changes; historical run counts remain dated evidence.

## AuthenticationTests.swift

[Source](../../Tests/NetworkKitTests/Client/AuthenticationTests.swift) — 15 declarations.

- `bothInputsReceiveMinimalContextAndHeaders`
- `credentialConflictsAreNeverSilentlyOverwritten`
- `providerFieldsCannotBypassValidation`
- `httpNeverInvokesProvider`
- `additionalOriginsNeverInheritProviderOrDefaults`
- `optOutSkipsOnlyProviderAndRetainsExplicitPrecedence`
- `providerFailuresAreSafeAndNeverReachTransport`
- `providerSharesCancellationBudgetAndJoinedCleanup`
- `concurrentAccountsUseIndependentBindingsAndRequestIdentifiers`
- `cancellingOneAccountLeavesOtherProviderWorkAlive`
- `responsesDoNotRefreshOrReplay`
- `authDescriptionsExcludeAccountEnvironmentAndCredentials`
- `preCancelledCallNeverInvokesProvider`
- `invalidRequestsNeverInvokeProvider`
- `redirectCannotMoveProviderCredentialsToAnotherOrigin`

## ClientLifecycleTests.swift

[Source](../../Tests/NetworkKitTests/Client/ClientLifecycleTests.swift) — 11 declarations.

- `shutdownWithoutActiveWorkIsIdempotent`
- `closingRejectsBothInputsBeforeReadingOptionsAndJoinsCleanup`
- `concurrentShutdownRetainsCleanupOwnership`
- `shutdownWaitsForTransportFinalization`
- `admissionRemembersShutdownBeforeOperationBinding`
- `firstTimeoutOrShutdownCauseIsPreserved`
- `selectedCompletionSurvivesShutdown`
- `concurrentClientCallsKeepSnapshotsAndCodecsIndependent`
- `failedCallsReleaseAdmissionBeforeShutdown`
- `ownedSessionIsClosedAfterItsOperationsJoin`
- `borrowedSessionKeepsAnotherClientsActiveWorkAlive`

## ConfigurationTests.swift

[Source](../../Tests/NetworkKitTests/Client/ConfigurationTests.swift) — 8 declarations.

- `defaultsAndIndependentOverrides`
- `invalidLimits`
- `positiveFiniteLimits`
- `concurrentSnapshotsAreIndependent`
- `descriptionsExcludeConfigurationSecrets`
- `scriptedTransportWithoutNetworking`
- `monotonicDeadlineWithoutWaiting`
- `productionClockCancellation`

## DiagnosticsTests.swift

[Source](../../Tests/NetworkKitTests/Client/DiagnosticsTests.swift) — 13 declarations.

- `canariesInEveryBoundaryStayOutOfEventsAndErrorDescriptions`
- `onlyExactAllowlistedMethodNamesAreRetained`
- `enablingAndDisablingPreservesResultsAndRequests`
- `loggingDoesNotReadEndpointPropertiesOrDescriptionsAgain`
- `rejectedAdmissionAndPreCancellationEmitOneSafeEvent`
- `eventWaitsForJoinedCleanupAndIncludesItsDuration`
- `sinkLatencyCannotRewriteSelectedResultOrMeasuredDuration`
- `cancellationCategoriesFollowTheSelectedCause`
- `firstCancellationCauseSurvivesTheLaterCause`
- `selectedCompletionSurvivesLateCancellation`
- `timeoutsRemainCategorizedWithoutPendingDiagnosticsWork`
- `concurrentAccountsProduceOnlyIndependentSanitizedTerminalEvents`
- `unknownErrorsAreClassifiedWithoutFormattingThem`

## DocumentationExamplesTests.swift

[Source](../../Tests/NetworkKitTests/Compatibility/DocumentationExamplesTests.swift) — 4 declarations.

- `typedGuideDecodesValueAndMetadata`
- `formatGuideHandlesBytesTextEmptyAndExplicitStatus`
- `ownershipGuideConstructsAndClosesBothProfiles`
- `authAndErrorGuideUsesPublicBoundariesWithoutNetworking`

## EndpointURLTests.swift

[Source](../../Tests/NetworkKitTests/HTTP/EndpointURLTests.swift) — 15 declarations.

- `typedEndpointAndBasePath`
- `reservedAndUnicodeSegmentsAreData`
- `queryOrderingRepetitionsAndOptionalValues`
- `invalidSegments`
- `asciiEscapingAndControlValidation`
- `invalidBaseURLs`
- `relativeURLWithFoundationBaseIsRejected`
- `snapshotsKeepTheirOwnPathAndQuery`
- `existingEscapesStayEncodedOnce`
- `safeDescriptionsAndErrors`
- `validSameOriginRequestPreservesURL`
- `invalidRequestsUseSameValidation`
- `missingURLAndInvalidBaseAreRejected`
- `unicodeHostAndEffectivePorts`
- `typedURLPassesRawValidation`

## F1AcceptanceTests.swift

[Source](../../Tests/NetworkKitTests/Compatibility/F1AcceptanceTests.swift) — 6 declarations.

- `typedAndRawPOSTHaveRequestAndResponseParity`
- `encodingFailureDoesNotSendOrPoisonClient`
- `HTTPFailurePrecedesDecoderWithoutRetry`
- `invalidUTF8IsDecodingFailureForBothInputs`
- `extraRawOriginDropsDefaultsAndDeniedOriginDoesNotSend`
- `loopbackCredentialsFailBeforeTransport`

## FixtureProcessTests.swift

[Source](../../Tests/NetworkKitTests/Support/FixtureProcessTests.swift) — 2 macOS-only declarations; no placeholder executions on other platforms.

- `missingReadinessFailsAndStopsTheChild`
- `childIgnoringTerminationIsForceStoppedWithinTheBound`

## HTTPPipelineTests.swift

[Source](../../Tests/NetworkKitTests/HTTP/HTTPPipelineTests.swift) — 12 declarations.

- `jsonThroughSession`
- `dataTextAndEmptyThroughSession`
- `statusPrecedesDecodingAndExplicitPolicyWorks`
- `invalidJSONAndContentTypeRemainStructured`
- `transportErrorsAreSanitizedAndNeverRetried`
- `systemTimeoutAndUnexplainedCancellationAreDistinct`
- `securityRejectsBeforeTransport`
- `preCancelledCallsDoNotSend`
- `constructorsRejectInsecureBaseAndIncompatibleSession`
- `sessionFailureUsesSharedNormalization`
- `nonHTTPResponseIsRejectedAfterTransport`
- `preparedHeadersAndTimeoutReachTransport`

## NetworkKitTests.swift

[Source](../../Tests/NetworkKitTests/HTTP/NetworkKitTests.swift) — 21 declarations.

- `standardMethodsAndCaseSensitivity`
- `tokenAlphabetIsASCIIOnly`
- `invalidMethodsFailWithoutEchoingInput`
- `customMethodsDoNotAppearInDescriptions`
- `caseInsensitiveLookupPreservesOpaqueValues`
- `equalDuplicatesCollapseButConflictsFail`
- `invalidNamesAreRejected`
- `controlsAreRejectedExceptHorizontalTab`
- `opaqueValuesAreNotUnicodeNormalized`
- `lookupRejectsUnicodeAliasesAndMalformedNames`
- `snapshotsDoNotChangeWithInputOrExportedDictionary`
- `descriptionsDoNotExposeNamesOrValues`
- `everyValidStatusHasTheExpectedDefaultClassification`
- `invalidStatusesAreRejected`
- `valuesAndMetadataRemainAvailableWithoutImplicitDecoding`
- `payloadSnapshotsAndDescriptionsDoNotLeak`
- `publicValuesCanCrossTaskBoundaries`
- `transportIdentityPreservesCodeWithoutUnderlyingUserInfo`
- `httpErrorsRetainExplicitMetadataButDescriptionsAreSanitized`
- `categoriesRemainDistinctAndAllDescriptionsAreSafe`
- `cancellationRemainsASeparateSwiftError`

## NetworkSecurityTests.swift

[Source](../../Tests/NetworkKitTests/Policies/NetworkSecurityTests.swift) — 21 declarations.

- `originNormalizationAndSafeDescriptions`
- `HTTPIsDeniedByDefault`
- `explicitLoopbackPermission`
- `loopbackLookalikesAndNoncanonicalAddressesFail`
- `HTTPDoesNotAcceptCredentialOrCustomHeaders`
- `HTTPMetadataAndTypedRawParity`
- `explicitExtraRawOriginDropsAllClientDefaultHeaders`
- `approvedRedirectsAndEffectivePorts`
- `unsafeRedirectsAreRefusedEvenWithExtraOriginPermission`
- `mutatingAndNonSelectedMethodsAreNeverReplayed`
- `HEADPreservesMethodAndRejectsBodyOrChangedMethod`
- `sixthHopAndLoopsBecomeStructuredErrors`
- `trustUsesSystemAndOtherChallengesNeverSupplyCredentials`
- `challengeCallbacksDiscardEvenProposedCredentials`
- `deniedInitialDestinationsNeverReachDataOperation`
- `redirectCallbackRejectsBeforeExecutorCanFollow`
- `loopFailurePropagatesThroughAdapter`
- `loopbackTransportDisablesAutomaticHandlingAndRejectsAppStores`
- `additionalPermissionDoesNotAuthorizeInsecureRemoteOrigin`
- `additionalRawOriginCannotInheritAnAppManagedCookieStore`
- `credentialStoresAndSessionGlobalHeadersAreRejected`

## OperationBudgetTests.swift

[Source](../../Tests/NetworkKitTests/Client/OperationBudgetTests.swift) — 16 declarations.

- `defaultBudgetExpiresAndJoinsBothChildren`
- `callOverridesClientLimits`
- `clientLimitsOverrideLibraryDefaults`
- `preCancelledCallerDoesNotStartTransport`
- `cancellationDuringIOStopsAndJoinsWork`
- `cancellationIsScopedToOneCall`
- `encodingTimeCannotSendAfterExpiration`
- `optionsAndSchedulingTimeBelongToBudget`
- `decodingTimeCannotProduceLateSuccess`
- `futureSuspendingHookIsInsideOperationBudget`
- `systemTimeoutIsDistinctFromTotalTimeout`
- `firstRecordedInterruptionSurvivesCleanupRace`
- `selectedCompletionSurvivesCancellationWhileWatchdogJoins`
- `extremePositiveBudgetsDoNotOverflowOrLeaveSleepers`
- `longBudgetContinuesAcrossBoundedSleeps`
- `borrowedSessionStopsOnlyThisOperation`

## PublicResponseAPITests.swift

[Source](../../Tests/NetworkKitTests/HTTP/PublicResponseAPITests.swift) — 8 declarations.

- `externalConsumerSelectsBorrowedStorageProfile`
- `externalConsumerReceivesOnlySanitizedDiagnostics`
- `externalConsumerCanConfigureAuthenticationProvider`
- `externalConsumerCanShutdownThroughClientBoundary`
- `systemTimeoutRetainsOnlySafeTransportIdentity`
- `externalConsumerCanInjectAndExecuteClientBoundary`
- `externalConsumerCanBorrowCompatibleSession`
- `externalConsumerCanSelectTypedAndRawStrategies`

## RedirectIntegrationTests.swift

[Source](../../Tests/NetworkKitTests/Policies/RedirectIntegrationTests.swift) — 3 declarations.

- `deniedRedirectDestinationIsNotContacted`
- `terminalRedirectFailureCancelsOnlyItsUnderlyingTask`
- `sameOriginRedirectsHaveABoundedLifetime`

## RequestEncodingTests.swift

[Source](../../Tests/NetworkKitTests/HTTP/RequestEncodingTests.swift) — 20 declarations.

- `defaultEndpointHasNoBodyOrInventedContentType`
- `dataAndEmptyDataAreExplicitBodies`
- `textUsesExactUTF8`
- `jsonDefaultsAndNull`
- `jsonOptionsUseNativeStrategies`
- `jsonFloatAndOutputFormatting`
- `explicitHeadersAndContentTypeWinWithoutChangingBytes`
- `methodsArePreserved`
- `normalizedCustomMethodIsNotSilentlyChanged`
- `bodylessMethodsRejectBodies`
- `encodingFailureIsSanitizedAndDoesNotPoisonNextCall`
- `encodingCancellationIsNotOrdinaryFailure`
- `concurrentEncodersHaveIndependentStrategiesAndPayloads`
- `descriptionsExcludePayloadAndFormattingValues`
- `rawBodyHeadersAndCallPrecedence`
- `rawExplicitContentTypeAndNoBody`
- `rawStreamsAndMalformedMethodsFailLocally`
- `managedHeadersAreRejected`
- `rawHeadersUseExistingValidation`
- `foundationDiscardedCRLFIsNotReintroduced`

## ResponseDecodingTests.swift

[Source](../../Tests/NetworkKitTests/HTTP/ResponseDecodingTests.swift) — 19 declarations.

- `jsonAndMetadata`
- `acceptedJSONMediaTypes`
- `missingContentTypeIsAllowed`
- `rejectsIncorrectOrAmbiguousJSONMediaType`
- `statusWinsOverCodingAndContentType`
- `malformedOrEmptyJSONFails`
- `explicitEmpty204AndHEADSemantics`
- `dataIsUnchangedAndDoesNotImposeContentType`
- `textUsesStrictUTF8`
- `textWithoutContentTypeAndInvalidBytes`
- `unsupportedOrInvalidTextDeclarationFails`
- `rejectsNonHTTPAndInvalidStatus`
- `customDecoderFailuresAreSanitized`
- `appleDecoderOptionsAndDefaultValues`
- `typedAndRawStrategiesShareStatusRules`
- `parallelDecodersDoNotShareStrategyOrPayload`
- `cancellationBeforeAndAfterSynchronousDecoding`
- `defaultsAndBoundaries`
- `rejectsEmptyOrInvalidPolicies`

## SessionTransportTests.swift

[Source](../../Tests/NetworkKitTests/Transport/SessionTransportTests.swift) — 14 declarations.

- `strictConfigurationDisablesAutomaticStorage`
- `ownedSessionIsReusedAndSnapshotsItsConfiguration`
- `injectedSessionSurvivesAdapterCleanupAndDeinit`
- `defaultStoredSessionsRequireExplicitAppManagedPolicy`
- `externalDelegateIsRejectedEvenWithAppManagedStorage`
- `strictInjectionRejectsEachIncompatibleSetting`
- `concurrentCallsOnOneSessionRemainIndependent`
- `streamsAreRejectedBeforeTransport`
- `cancellationAtEntryDoesNotStartRequest`
- `externalInvalidationStopsAnActiveBorrowedOperation`
- `invalidResourceLimitsAndOwnedStoresAreRejected`
- `strictRequestCopyPreventsCookieAndCacheOverrides`
- `backgroundConfigurationRejectedWhereAvailable`
- `resourceLimitRemainsSeparateFromRequestedTotalBudget`

## StorageIntegrationTests.swift

[Source](../../Tests/NetworkKitTests/Policies/StorageIntegrationTests.swift) — 8 declarations.

- `strictProfileDoesNotRetainOrSendCookies`
- `strictProfileCannotServeAnAutomaticHTTPCacheEntry`
- `ownedStrictProfileNeverSuppliesBasicChallengeCredentials`
- `publicProfilesRejectCredentialsGlobalHeadersDelegatesAndBackgrounds`
- `appManagedActiveStoresCannotRunOverLoopbackHTTP`
- `appManagedCookiesCannotFollowAdditionalRawOriginPermission`
- `additionalRawOriginWithoutCookiesCannotUseAppCachePolicy`
- `appManagedCookieCacheProfileRequiresExplicitPublicSelection`


## PrivacyManifestTests.swift

[Source](../../Tests/NetworkKitTests/Compatibility/PrivacyManifestTests.swift) — 1 declaration.

- `bundledManifestMatchesReviewedSDKPractices`

## NativeTLSTests.swift

[Source](../../Tests/NetworkKitTests/Transport/NativeTLSTests.swift) — 1 macOS-only declaration.

- `untrustedCertificateIsRejectedThroughBothPublicInputs`

## DownloadTests.swift — I29 addition

[Source](../../Tests/NetworkKitTests/Downloads/DownloadTests.swift) — 11 declarations covering successful/empty app ownership, invalid limits/requests before auth, rejected statuses without retry, actual file size, preserve/inspect/remove errors, original deadline discard, cancellation/cleanup precedence, exclusive target collisions, native-return adoption order and shutdown/join. See the I29 report for actual local results and unproved native boundaries.

## I30 verification addition

[DownloadTests](../../Tests/NetworkKitTests/Downloads/DownloadTests.swift) now has 21 declarations / 55 expanded cases. [DocumentationExamplesTests](../../Tests/NetworkKitTests/Compatibility/DocumentationExamplesTests.swift) adds a regular-import public compatibility declaration. I30 adds 11 declarations in total; actual source-hashed results, negative controls and unproved native boundaries are in [the I30 report](I30_DOWNLOAD_VERIFICATION.md).
