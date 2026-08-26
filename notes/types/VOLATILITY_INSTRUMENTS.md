

| Mathematics           | Type-theoretic object | Example in your protocol   |
| --------------------- | --------------------- | -------------------------- |
| Set                   | Type                  | `Tick`, `Price`, `FeeRate` |
| Element               | Value                 | `tick = 120`               |
| Function              | Pure function         | `priceOfTick`              |
| Relation              | Predicate             | `InRange`                  |
| Product               | Struct                | `Position`                 |
| Coproduct             | Enum                  | `Swap \| Mint \| Burn`     |
| Monoid                | Trait                 | Fee accumulation           |
| Group                 | Trait                 | Hazard aggregation         |
| Ring                  | Trait                 | Fixed-point arithmetic     |
| Field                 | Trait                 | Off-chain analytics        |
| Vector space          | Typeclass             | Portfolio                  |
| Linear map            | Operator type         | Derivative                 |
| Bilinear form         | Operator type         | Covariance                 |
| Integral              | Fold                  | Fee accumulator            |
| Differential equation | State transition      | Dynamic fee controller     |
| Category              | Module graph          | Protocol architecture      |


