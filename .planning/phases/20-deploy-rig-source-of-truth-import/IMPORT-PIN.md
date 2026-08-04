# Phase 20 Import Pin

Source ref: `origin/develop` @ `2039f2783598866a337115df4a265a75e8842e82`
Ref subject: `Merge pull request #18 from JMSBPP/feat/plank`
Imported: 2026-08-02T16:03:40Z
Path list: `offchain/rig/import-paths.txt` (37 paths)
Re-pinned: Phase 22 (plan 22-01), 2026-08-02T16:03:40Z — supersedes ref `9f5ccba92ddf89d80efe81bae1dcd1d0a1c10e2d` (PR #15). This file stays THE pin file: `offchain/rig/verify-import.sh`'s `PIN=` constant is unchanged on purpose, so there is exactly one source of truth for this fact.
Removed as superseded: `src/lib/TickUtils.plk` (now `src/types/pricing/TickUtils.plk`)

Content-identity to this ref is the SC-1 acceptance test, re-checkable at any time with
`offchain/rig/verify-import.sh`. Files are IMPORTED, never re-typed, and never edited on
this branch (`src/`, `foundry-scripts/` belong to the plank workstream — CLAUDE.md).

The digest rows below were generated mechanically from `git show <ref>:<path> | sha256sum`;
no digest in this file was transcribed by hand.

| sha256 | path |
|--------|------|
| `911a9a3214918de92fa512dffcff5ee781ac72ec9ca962eaacf69b387752aefa` | `foundry-scripts/deploy/PlankDeployBase.s.sol` |
| `e4a6ab881a2f7d9893186baaaff309f8f3d846d471348deff31cdf582f4d163c` | `foundry-scripts/deploy/DeployVolOrderManagerMod.s.sol` |
| `a776fce6013385fd5703b9d011540559d476a2f1e5c069ab32202126f9f7a84b` | `foundry-scripts/deploy/DeployRealizedVolatilityMod.s.sol` |
| `cf951bbab5325f7fd21dc91d31f2c40619bd813ceca6b7b6667856a7dd9f497d` | `foundry-scripts/deploy/DeployDynamicFeeMod.s.sol` |
| `f282e0942d0f013e04541957d74245bcd932bb3cbdb4f8628812bea219082fa0` | `foundry-scripts/deploy/DeployDynamicFeeHook.s.sol` |
| `fba060b988086e3c81d150fefd9e43e1bcbf0ec1b5041917fd8cff8efcbb75e1` | `foundry-scripts/deploy/InitSwappableRig.s.sol` |
| `02c803039db0bd97d4ad12e98c5bb34d4055eb91026288b35de05cd83d81b00d` | `.planning/rpc-api-volorder-v2-HANDOFF.md` |
| `b9f8a1198f39d2bcca28025941ca290feb67e6becccec83eed897a6e1cd259ea` | `notes/DATA_CONTRACT.md` |
| `5628b982423e0183bbdd3aa9d0469627524fae1ba98b52435c09ed7beb4f0104` | `notes/UNITS_AND_SCALES.md` |
| `5907e8d5111364ba55f346417f03303d1cb381f3fded7b9134ccd6e08b721519` | `src/interfaces/pos_spec/VolOrderManagerInterface.plk` |
| `191564aabd871f1ca2f44a147b428a2a72c26c2e4f45f58db32e6170a33037f9` | `src/interfaces/market_state_measurements/RealizedVolatilityInterface.plk` |
| `d565bf521e21ccab3533e487e5f5ae88d61ea4c5d4ed8f0a67c7a099d59cbc51` | `src/interfaces/premium/DynamicFeeInterface.plk` |
| `a54b53485900f62373c92a52f066c26cd208a85011c21b8e581755314d269cdb` | `src/interfaces/protocol_integrations/DynamicFeeHookInterface.plk` |
| `2283fe3791a6ee66fe2e0ede83895e90dad71c6926f72eeebf8ab657a37b1616` | `src/interfaces/protocol_integrations/IMarketStateSocket.plk` |
| `b99d6b80a857dab90bd69891b3b87b18307d8bed8e5369404e08f729c28485c5` | `src/interfaces/exposure/VegaAccountInterface.plk` |
| `27d2fd992cf9ec20ad458c13e31a9cdf729bd3b3e782e828abf67fe33a8dd64a` | `src/lib/events/VolEventsLib.plk` |
| `12665adc7bf6624f3719a8f7dd8d368f60c95b98440386620f2047715d4505e1` | `src/lib/market_state_measurements/RealizedVolatilityLib.plk` |
| `90d9ffa465c94415bddedc6fed1b69900d1f3760c47d93ee60bb0e41e364d561` | `src/lib/market_state_measurements/RealizedVolatilityStateLib.plk` |
| `ee4644e0f2d2f8c62b8e30b6cb9be80a9ef5e81a389b5b82b89bfe7be3478df5` | `src/lib/pos_spec/VolOrderValidationLib.plk` |
| `b767d8bfd5bc5df6d786f12da2ba3a84dd7c22a67de9dd7e7bf1ee5b167e93c3` | `src/lib/pos_spec/TickVolatilityLib.plk` |
| `53ce00e2a2b31f0fee993125b81e893ae0c3b604c8fbca82d83fcf59b827c2be` | `src/lib/premium/AdaptiveFee.plk` |
| `7689960ca16be52ae72099a1b596472950d4a46f9b6c0f8b1b6535fb4ed9b787` | `src/lib/protocol_integrations/CallbackRealizedVolatilityLib.plk` |
| `6e53516aea413d75af01e43d076410b7775141f958ad4f415b2ee2c4a924d435` | `src/modules/market_state_measurements/RealizedVolatilityMod.plk` |
| `d9d4e228da9f96d96d40d526f851bcc5f10b3c54e4a3bb04e286fba66caa5c42` | `src/modules/pos_spec/VolOrderManagerMod.plk` |
| `94c54e7ca8cc08c0f78d8e14a4e377fd213c5a7aec25b721327beaa3f2424a15` | `src/modules/premium/DynamicFeeMod.plk` |
| `8113f14c5cf11e0cdc9d6b50df650fac7c71e97f63121f243fcc4f1541fa5297` | `src/modules/protocol_integrations/DynamicFeeHook.plk` |
| `40b6906eb78741395e2eb3918785e6f6f3c25d70c7c557af95be4ce3529644e3` | `src/types/Numerics.plk` |
| `992193d6df86ff252201b34491814efaabfa7475f339be5cbd526a37b7028f55` | `src/types/StorageIndex.plk` |
| `d9c783325bcbd2a8920aab6cea5aa5551d83bdcc93179eb2a7807c5aee82a683` | `src/types/TimeWindow.plk` |
| `f6e6edf581dca39b2364c9160e11f0a1f3e51be6cd56c7986b21bdb0c99085d0` | `src/types/market_state_measurements/Timepoint.plk` |
| `be951ae0f17cb05f37ccfb31e7f7bae20569dc4ee9d9b8d2e8c891b597469842` | `src/types/pos_spec/SpreadTickAssimetry.plk` |
| `db9ab0346de0ccf595602fcc2fbc01b2667649ad72983afae7c5727a95cef934` | `src/types/pos_spec/TickVolatility.plk` |
| `cc881dcddaa89972640f007fc258ad90f0bb6629c313ea8ee5acbd9047db6485` | `src/types/pos_spec/VegaTarget.plk` |
| `cf2cd6bf2eceacd8c32100009f69d84b67c99fb2bb64cddba678a6d98dd968cb` | `src/types/pos_spec/VolOrder.plk` |
| `e33ca9b21f97129c8ffd43f7aeb7f13e89e80e68da93813f6f87bbe77e89f454` | `src/types/pos_spec/VolRangeWidth.plk` |
| `6060b654bc75ada234c6ef4fa991a2e9bfc0e464ae6656cb648aaef77a5832f7` | `src/types/premium/AlgebraFeeConfiguration.plk` |
| `8ea460d3d34dd8b090070bebd0b38771008477278684a4cae82d764359ff3a24` | `src/types/pricing/TickUtils.plk` |
