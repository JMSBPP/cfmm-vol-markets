- Include reactive callback on sys
- Verify callback calldata is correct
1. Refactor TickRealizedVariance test to have the Differential test structure
2. Import the Algebra oracle and integrate it on the test
3. Integrate TickRealizedVariance on the Observer
4. GREEN TickRealizedVarianceTest
5. Create entry point for Input volatility
6. Refactor exposure to acccoung for vegaNotional
7. Draft test for optionClearingHouse/Panoptic__Premium == targetVariancePremium


[solves 194](https://github.com/JMSBPP/cfmm-vol-markets/issues/194) 
