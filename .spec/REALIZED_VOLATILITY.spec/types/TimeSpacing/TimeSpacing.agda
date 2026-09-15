-- Progress mirrors TimeSpacing.md: set + intro (elim / (=) not yet).
-- Carrier: U8 = Fin 256 (EVM u8 width via Data.Nat.DivMod._mod_).
module TimeSpacing where

open import Data.Bool       using (Bool; true; false; if_then_else_; _∧_)
open import Data.Fin        using (Fin; toℕ)
open import Data.Maybe      using (Maybe; just; nothing)
open import Data.Nat        using (ℕ; _≤ᵇ_)
open import Data.Nat.DivMod using (_mod_)
open import Data.Product    using (Σ; _,_)
open import Data.Unit       using (⊤; tt)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; sym)

------------------------------------------------------------------------
-- Carrier: u8 ≅ Fin 256 (truncate Nat like EVM low-byte)
------------------------------------------------------------------------

U8 : Set
U8 = Fin 256

toU8 : ℕ → U8
toU8 n = n mod 256

fromU8 : U8 → ℕ
fromU8 = toℕ

------------------------------------------------------------------------
-- TimeSpacing ← dt̄ := { dt ∈ u8 | 1 ≤ dt ≤ 10 }
------------------------------------------------------------------------

T : Bool → Set
T true  = ⊤
T false = ⊥
  where
  data ⊥ : Set where

subst : ∀ {A : Set} (P : A → Set) {x y : A} → x ≡ y → P x → P y
subst P refl p = p

inTimeSpacing : U8 → Bool
inTimeSpacing dt = (1 ≤ᵇ fromU8 dt) ∧ (fromU8 dt ≤ᵇ 10)

TimeSpacing : Set
TimeSpacing = Σ U8 (λ dt → T (inTimeSpacing dt))

------------------------------------------------------------------------
-- intro :: u8 → TimeSpacing + ⊥
------------------------------------------------------------------------

intro : U8 → Maybe TimeSpacing
intro dt with inTimeSpacing dt in eq
... | false = nothing
... | true  = just (dt , subst T (sym eq) tt)
