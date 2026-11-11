-- Progress mirrors TimeSpacing.md: set + intro (elim / (=) not yet).
-- Carrier: U8 = Bits8 (EVM u8 width; Cast Nat Bits8 wraps mod 256).
module TimeSpacing

import Data.So

------------------------------------------------------------------------
-- Carrier: u8 ≅ Bits8
------------------------------------------------------------------------

public export
U8 : Type
U8 = Bits8

public export
toU8 : Nat -> U8
toU8 = cast

public export
fromU8 : U8 -> Nat
fromU8 = cast

------------------------------------------------------------------------
-- TimeSpacing ← dt̄ := { dt ∈ u8 | 1 ≤ dt ≤ 10 }
------------------------------------------------------------------------

public export
inTimeSpacing : U8 -> Bool
inTimeSpacing dt =
  let n = fromU8 dt
  in n >= 1 && n <= 10

public export
TimeSpacing : Type
TimeSpacing = (dt : U8 ** So (inTimeSpacing dt))

------------------------------------------------------------------------
-- intro :: u8 → TimeSpacing + ⊥
------------------------------------------------------------------------

public export
intro : U8 -> Maybe TimeSpacing
intro dt with (inTimeSpacing dt) proof eq
  intro dt | True  = Just (dt ** eqToSo eq)
  intro dt | False = Nothing
