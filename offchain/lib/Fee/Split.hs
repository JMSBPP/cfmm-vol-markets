-- |
-- The fee splitter's arithmetic core: exact over pips, and admissible by the PROVER'S OWN TEST.
--
-- WHAT THIS MODULE DECIDES
-- ------------------------
-- A pool fee @f@ and a target @delta*@ arrive; a pair of leg fees @(phi_X, phi_M)@ has to come
-- back. Two constraints decide the pair. The LEVEL constraint is
-- @(1 - phi_X)(1 - phi_M) = 1 - f@, which this module carries as 'compose_scaled' in exact
-- 'Integer' arithmetic. The ADMISSIBILITY constraint is @volume_path.gms@'s own @ellTest@,
-- transcribed term for term as 'ellipse_test' -- not a closed form derived from it, and not the
-- arithmetic-mean reading that a plausible re-derivation produces.
--
-- Everything here is 'Integer' and total. There is no 53-bit floating value, no value from the
-- rational module of @base@, and no IO anywhere on this path. The one import is 'Data.Word', for
-- the seed field of 'FeeSplit'.
--
-- THE FOUR RULINGS THIS MODULE IS, AND WHAT BUMPING 'splitter_version' MEANS
-- --------------------------------------------------------------------------
-- 1. ROUND AND REPORT. 'nearest_partner' picks the integer nearest the exact solution and the
--    realized composition and its residual are RECORDED FIELDS, not discarded. Exact-or-refuse was
--    rejected on a measurement rather than on taste: it refuses every canonical Uniswap tier, since
--    @f@ = 100, 500, 3000 and 10000 pips each admit ZERO exact integer-pip pairs (see
--    'exact_pairs_for').
-- 2. The band is restricted to @phi_M > phi_X@. 'exact_pairs_for' is deliberately NOT restricted --
--    see its own haddock.
-- 3. Ties round UP, stated in 'nearest_partner' rather than left to a rounding mode.
-- 4. Admissibility is @ellTest@ itself.
--
-- 'splitter_version' names that SET. Widening any of the four bumps the string, which ORPHANS the
-- keys computed under the old one rather than silently reinterpreting them.
--
-- WHO IS AUTHORITATIVE FOR THE PAIR, AND THE HALF OF SC-1 THAT IS STILL OPEN
-- --------------------------------------------------------------------------
-- ROADMAP SC-1 rules that the DERIVED PIPS -- not @f@ -- are what reach the key, so this module is
-- authoritative for @(phi_X, phi_M)@ in v6.0. Phase 27 reads the same pair back off chain and the
-- two must then be reconciled; 'compose_scaled' records the one arithmetic reason they will
-- disagree by construction.
--
-- STATED AS A GAP RATHER THAN AS A CLAIM: the other half of SC-1 -- that the derived pips actually
-- REACH the key -- has NO implementing task in this phase. No plan of phase 26 touches
-- @Store.Key@, @Store.RunLog@ or the key scheme, and phase 25, which built the key, executed
-- BEFORE this module existed and therefore cannot import it. What this phase asserts is the ARGV
-- half. The store half is open work, and it is written here rather than asserted anywhere.
--
-- @fs_seed@ and 'splitter_version' are a NAMED CARRY-FORWARD, not a settled debt. @ROADMAP.md@
-- (measured at lines 1304-1305 of the file as it stands today) says: \"The @splitter_version@ is a
-- Phase 26 product; @key_scheme@ (Phase 23) is what makes adding it later non-destructive.\" That
-- is the whole warrant for the two fields landing here with no consumer: adding them to a key
-- preimage later is additive because the scheme column orphans rather than corrupts. Nothing in
-- phase 25 reads them today.
module Fee.Split
  ( -- * The unit
    pips_denominator
  , fee_in_domain
    -- * The level constraint
  , compose_scaled
  , residual_scaled
  , nearest_partner
  , exact_pairs_for
    -- * The prover's admissibility test
  , ellipse_test
  , is_admissible
  , min_admissible_dstar
    -- * The band, the mixer, and the seeded pick
  , admissible_band
  , mix64
  , pick_from_band
    -- * The split itself
  , split_for
    -- * The result, and why one was refused
  , FeeSplit (..)
  , SplitRefusal (..)
  , refusal_message
  , refusal_boundary
  , splitter_version
  ) where

-- The seed field's type. Nothing here resolves it from anywhere: the seed ARRIVES as an argument
-- and @Driver.Seed@ stays the only resolver, so this module cannot turn a typo'd seed into a drawn
-- one by looking somewhere else for it.
import Data.Word (Word32)
-- The mixer's three primitives, and the second and last import this module has. Everything else
-- below is arithmetic over values it was handed.
import Data.Bits ((.&.), shiftR, xor)

-- ---------------------------------------------------------------------------------------------
-- The unit
-- ---------------------------------------------------------------------------------------------

-- | Hundredths of a basis point. One whole pip is @1000000@ scaled units.
--
-- This is @volume_path.gms@'s @PIPS@, Uniswap v4's @ProtocolFeeLibrary.PIPS_DENOMINATOR@ (vendored
-- at @lib\/\/v4-core\/src\/libraries\/ProtocolFeeLibrary.sol@, spelled @1_000_000@ there) and the
-- Algebra @FEE_DENOMINATOR@. It is ALSO a component of the content key's preimage -- KEY-05, built
-- in phase 25, which states the same constant in @Store.Key@.
--
-- Two modules therefore spell this number, and that is a drift risk rather than a duplication:
-- @Store.Key@ cannot import this module (it was written first) and this module imports nothing.
-- The suite asserts the two are equal, so the drift is caught by a check rather than by a reader.
pips_denominator :: Integer
pips_denominator = 1000000

-- | The pool fees this splitter is defined on: @1 <= f < 'pips_denominator'@.
--
-- THIS IS A TOTALITY GUARD, NOT A STYLE CHOICE, AND THE FALSIFYING INPUT IS A PRODUCTION VALUE.
-- The band a caller enumerates runs @x@ over @[1 .. f-1]@ and hands each to 'nearest_partner',
-- which divides by @'pips_denominator' - x@. For any @f@ greater than @1000000@ that enumeration
-- REACHES @x = 1000000@ and the division is by zero -- an exception, not a refusal, so no
-- 'SplitRefusal' could carry it.
--
-- Uniswap v4 emits exactly such a fee. @LPFeeLibrary.sol:15@ declares
-- @DYNAMIC_FEE_FLAG@ = 8388608 (written there in hexadecimal; decimal here because this file must
-- carry no hexadecimal literal), and @PoolKey.sol:16@ says that if the highest bit of
-- @PoolKey.fee@ is 1 the pool has a dynamic fee and the field \"must be exactly equal\" to that
-- flag. This repository's own DynamicFeeHook track produces that class of pool, so 8388608 arrives
-- as a POOL FEE FIELD and is not an 8388608-pip fee. Values strictly between @1000000@ and the
-- flag are quieter and worse: they divide cleanly and return legs above 100%.
--
-- The upper bound is one tighter than v4's own @isValid@, which admits @f = MAX_LP_FEE = 1000000@
-- (a 100% fee). At @f = 1000000@ the only partner of any @x@ is @m = 1000000@ -- a whole-input fee
-- on one leg -- which is not a leg fee in @[1, 999999]@, so the splitter has nothing to return and
-- the fee is out of ITS domain while remaining valid on chain. Said here because the two bounds
-- look identical and are not.
--
-- The consuming refusal is 'FeeOutOfDomain', raised as the FIRST step of a split -- ahead of any
-- band enumeration, and ordered so that it does not preempt the specific equal-fee diagnosis for
-- an in-domain fee.
fee_in_domain :: Integer -> Bool
fee_in_domain f = 1 <= f && f < pips_denominator

-- ---------------------------------------------------------------------------------------------
-- The level constraint
-- ---------------------------------------------------------------------------------------------

-- | @'compose_scaled' x m@ is @'pips_denominator' * f'@, where @f'@ is the fee the pair
-- @(x, m)@ ACTUALLY composes to when the two are charged in series.
--
-- Two fees in series keep @(1 - x\/D)(1 - m\/D)@ of the input, so the composed fee is
-- @1 - (1 - x\/D)(1 - m\/D)@, which is @(D(x+m) - xm) \/ D@. The value returned here is that,
-- multiplied through by @D@, so it is EXACT: no division happens and nothing rounds.
--
-- > compose_scaled 500 6000 == 6497000000
--
-- and the provenance of that number is independent of this function:
-- @999500 * 994000 = 993503000000 = 1000000 * 993503@, so the pair keeps 99.3503% and composes to
-- 6497 pips exactly. Deleting the @- x*m@ term -- the additive misreading -- gives @6500000000@
-- instead, which is the fixture's fee wrong by 3 pips.
--
-- Equality with @D * f@ holds if and only if @D@ divides @x*m@, which is true of 4.935% of @f@ in
-- @[1, 20000]@ (MEASURED: 987 of 20000) and of NONE of 100, 500, 3000 or 10000. That measurement
-- is what ruled out exact-or-refuse.
--
-- THE CHAIN FLOORS THE PRODUCT TERM AND THIS FUNCTION DOES NOT. v4 computes the same composition
-- in @ProtocolFeeLibrary.calculateSwapFee@ as @x + m - (x*m \/ 1000000)@ under EVM @div@, which
-- truncates. The realized on-chain fee is therefore HIGH by @frac(x*m \/ D)@ -- up to a whole pip,
-- and ALWAYS in the same direction. That is a second, independent discrepancy from this module's
-- own nearest-rounding residual, which is at most half a pip and signed either way. Phase 27's
-- reconciliation compares the composition of the pair it read back against the pool fee; without
-- this sentence that comparison reads the floor term as a splitter bug.
compose_scaled :: Integer -> Integer -> Integer
compose_scaled x m = pips_denominator * (x + m) - x * m

-- | How far a pair misses the requested fee, in units of @'pips_denominator' * pips@.
--
-- One WHOLE pip is therefore @1000000@ of these units, which is what makes the one-pip alarm a
-- comparison against 'pips_denominator' itself rather than against a scale factor written twice.
--
-- THE HEADROOM IS 2x, AND THE OTHER FIGURE IS A BAND MINIMUM. Nearest rounding gives
-- @residual = (D - x) * (m - m_exact)@ with @|m - m_exact| <= 1\/2@, so
-- @|residual_scaled| <= (D - x) \/ 2 < D \/ 2@. MEASURED over the whole @phi_M > phi_X@ band at
-- @delta* = 490000@, the largest absolute residual is 2464 at @f = 100@, 61824 at @f = 500@,
-- 499671 at @f = 3000@, 499240 at @f = 6497@ and 499527 at @f = 10000@. So an arbitrary band
-- member sits at up to 0.4997 pip and the alarm has TWO times headroom, not a thousand. The
-- thousand-fold figure some earlier notes carry is the band MINIMUM (the best member, 8 units at
-- @f = 3000@), and quoting it as the headroom describes the luckiest pair in the band as though it
-- were the typical one.
residual_scaled :: Integer -> Integer -> Integer -> Integer
residual_scaled f x m = compose_scaled x m - pips_denominator * f

-- | The integer @m@ nearest the exact partner of @x@ under the level constraint, TIES ROUND UP.
--
-- Solving @D(x+m) - xm = D f@ for @m@ gives @m = D(f - x) \/ (D - x)@ exactly over the rationals.
-- This computes the nearest integer to it with 'divMod' and the tie rule @2*r >= (D - x)@ -- never
-- with a division into a fractional type, never with a rounding mode inherited from a library, and
-- never through a 53-bit floating value. The rule is written down because SC-1 requires the
-- rounding rule pinned IN WRITING: a half-unit tie is a genuine choice, and a splitter that
-- changed its mind about it would move every key it produced without changing anything a reader
-- would notice.
--
-- PARTIAL, ON PURPOSE, WITH THE GUARD NAMED. The divisor is @D - x@, so @x = 1000000@ divides by
-- zero. The caller enumerates @x@ over @[1 .. f-1]@, which reaches that value for every
-- @f > 1000000@, and v4's dynamic-fee sentinel 8388608 is such an @f@. 'fee_in_domain' is the
-- guard, and it belongs to the SPLIT, ahead of the band, rather than here: a total
-- 'nearest_partner' would have to invent a value for a pair that does not exist and hand it
-- onwards, which is how an absent subject acquires a plausible answer.
nearest_partner :: Integer -> Integer -> Integer
nearest_partner f x =
  let divisor    = pips_denominator - x
      (quotient, remainder) = (pips_denominator * (f - x)) `divMod` divisor
  in if 2 * remainder >= divisor then quotient + 1 else quotient

-- | Every integer-pip pair composing to @f@ EXACTLY, in BOTH orientations.
--
-- With @a = D - x@ and @b = D - m@ the level constraint is exactly @a * b = D * (D - f)@, so the
-- pairs are the divisor pairs of @n = D * (D - f)@ whose factors both land in @[1, D-1]@. That
-- bounds @a@ to the OPEN window @(D - f, D)@, which is @f - 1@ candidates rather than a search
-- over all of @n@'s divisors.
--
-- DELIBERATELY UNRESTRICTED IN ORIENTATION. The band this module's caller enumerates keeps only
-- @phi_M > phi_X@, and this function does not: it returns @(500,6000)@ AND @(6000,500)@. That is
-- what makes its census a statement about the LEVEL CONSTRAINT rather than about the band's
-- convention, and it is why the count below is 2 rather than 1.
--
-- The census, MEASURED:
--
-- > length (exact_pairs_for 100)   == 0
-- > length (exact_pairs_for 500)   == 0
-- > length (exact_pairs_for 3000)  == 0
-- > length (exact_pairs_for 10000) == 0
-- > length (exact_pairs_for 6497)  == 2      -- (500,6000) and (6000,500)
--
-- Four canonical Uniswap tiers admit NO exact split at all. That measurement, not a preference,
-- is why this module rounds and reports.
exact_pairs_for :: Integer -> [(Integer, Integer)]
exact_pairs_for f =
  [ (pips_denominator - a, pips_denominator - n `div` a)
  | a <- [pips_denominator - f + 1 .. pips_denominator - 1]
  , n `mod` a == 0
  , let b = n `div` a
  , 1 <= b && b <= pips_denominator - 1
  ]
  where
    n = pips_denominator * (pips_denominator - f)

-- ---------------------------------------------------------------------------------------------
-- The prover's admissibility test
-- ---------------------------------------------------------------------------------------------

-- | @volume_path.gms@ lines 100-108, TRANSCRIBED, multiplied through by @D^6@.
--
-- The model's own four lines are
--
-- > phiBar  = 1 - (1-phiX)*(1-phiM);
-- > dphi    = phiM - phiX;
-- > ellTest = (sqr(phiBar) + sqr(dphi))*sqr(dStar) - (phiX+phiM)*phiBar*dStar + phiX*phiM;
-- > abort$(ellTest > 0) 'target outside the admissible ellipse';
--
-- With @Pn = D(x+m) - xm@ (which is @D^2 * phiBar@) and @d@ the target in pips, multiplying
-- through by @D^6@ clears every denominator and leaves
--
-- > E = Pn^2 d^2  +  D^2 (m-x)^2 d^2  -  D^2 (x+m) Pn d  +  D^4 x m
--
-- so @E = D^6 * ellTest@ in SIGN and in VALUE. That identity was verified on 20000 random triples
-- at research time and is re-asserted in the suite against an independently hand-built numerator.
-- Admissible is @E <= 0@, matching the model's abort condition exactly.
--
-- WHAT phiBar AND dphi ARE, AND WHAT THE PLAUSIBLE MISREADING COSTS. @phiBar@ is the COMPOSED fee
-- and @dphi@ is the FULL gap. Reading them instead as the arithmetic MEAN of the two fees and as
-- the ellipse SEMI-axis produces a test that is exactly two times too large: at the fixture fees
-- its roots are @[0.165517, 1.000000]@ against the prover's @[0.082803, 0.500000]@, it disagrees
-- with the prover on 36 of 70 near-boundary points, and it falsely refuses 82713 pips of
-- admissible @delta*@. The prover's form independently reproduces @VOLUME_PATH.md@ section 1.1's
-- ceiling of one half as its upper root; the misreading gives one. The corollary the misreading
-- carries about a minimum leg ratio is stated, and refuted, in the suite check that pins these
-- values -- it is not stated here, because this file is scanned for the name of the operation that
-- sentence would have to spell.
--
-- Pinned, exactly:
--
-- > ellipse_test 500 6000 490000 == -295056739100000000000000000000
-- > ellipse_test 500 6000 82803  == 4991723980281000000000000        -- refused, one pip below
-- > ellipse_test 500 6000 82804  == -25238725702256000000000000      -- admitted, the boundary
-- > ellipse_test 500 6000 0      == 3000000000000000000000000000000
--
-- The last one generalises: @ellipse_test x m 0 = D^4 * x * m@, which is strictly positive for
-- any two nonzero fees. So @delta* = 0@ is refused BY THE ELLIPSE, with no separate bound -- which
-- is what closes @Gams.Argv@'s live hole admitting @txlVolumeRate = 0@.
ellipse_test :: Integer -> Integer -> Integer -> Integer
ellipse_test x m d =
  pn * pn * d * d
    + d2 * (m - x) * (m - x) * d * d
    - d2 * (x + m) * pn * d
    + d2 * d2 * x * m
  where
    pn = pips_denominator * (x + m) - x * m
    d2 = pips_denominator * pips_denominator

-- | The prover's verdict, as a 'Bool'. Nothing else decides admissibility in this codebase.
is_admissible :: Integer -> Integer -> Integer -> Bool
is_admissible x m d = ellipse_test x m d <= 0

-- | The least integer @delta*@ in @[0, 'pips_denominator' - 1]@ this pair admits, if any.
--
-- @E@ is a quadratic in @d@ with leading coefficient @A = Pn^2 + D^2 (m-x)^2 > 0@, so it is convex
-- and its admissible set is the closed real interval between its two roots, centred on the vertex
-- @v = -B \/ 2A@. Bisection is valid on any interval @[0, hi]@ whose right end is ADMISSIBLE:
-- @hi <= r2@ then holds, so the integers in @[0, hi]@ that satisfy the predicate are exactly those
-- at or above @ceil(r1)@ -- a monotone step, which is what bisection needs. No linear scan and no
-- root through a floating value.
--
-- THE OBVIOUS CHOICE OF @hi@ IS WRONG, AND THE COUNTEREXAMPLE IS PINNED. Taking @hi = floor(v)@
-- returns 'Nothing' whenever @ceil(r1) > floor(v)@ even though an admissible integer exists just
-- above the vertex. MEASURED: at @x = 99, m = 101@ the real vertex is @499974.996...@, so
-- @floor(v) = 499974@ and @ellipse_test 99 101 499974 = 27201107960480676 > 0@ -- that rule reports
-- no admissible target. But @ellipse_test 99 101 499975 = -12498937537499375 <= 0@, so the true
-- answer is @Just 499975@, confirmed by exhaustive scan over the whole range.
--
-- Both @floor(v)@ and @floor(v) + 1@ are therefore tried, and trying BOTH is not belt-and-braces:
-- either alone is wrong. If an admissible integer @k@ exists then either @k <= floor(v)@, which
-- forces @floor(v)@ itself into the root interval, or @k >= floor(v) + 1@, which forces
-- @floor(v) + 1@ into it. So if neither candidate is admissible, none is, and 'Nothing' is a fact
-- rather than a failure to look.
--
-- Pinned:
--
-- > min_admissible_dstar 500  6000 == Just 82804
-- > min_admissible_dstar 100  900  == Just 109769
-- > min_admissible_dstar 1000 3000 == Just 300361
-- > min_admissible_dstar 50   9950 == Just 5026
-- > min_admissible_dstar 700  800  == Just 495953
-- > min_admissible_dstar 99   101  == Just 499975
-- > min_admissible_dstar 3000 3000 == Nothing
--
-- The last row is @VOLUME_PATH.md@ section 1.2 as a machine-checked fact, and it is STRICTLY
-- STRONGER than that section's prose. At equal fees the discriminant vanishes: the quadratic has a
-- DOUBLE root at @1 \/ (2 - phi) = 0.50075...@, which is not an integer number of pips, so NO
-- integer @delta*@ at all is admissible -- where the prose only says the root exceeds one half.
-- That is also why an equal-fee shock must be diagnosed by its own refusal before this test runs:
-- this one would refuse it for the right reason with the wrong message.
--
-- The degenerate @A = 0@ case is 'Nothing' for a reason rather than by clamping: @A@ vanishes only
-- when @Pn = 0@ and @m = x@ together, and @E@ is then the positive constant @D^4 x m@, admissible
-- nowhere. It cannot arise for fees in @[1, 999999]@, where @Pn > 0@ always.
min_admissible_dstar :: Integer -> Integer -> Maybe Integer
min_admissible_dstar x m
  | leading == 0 = Nothing
  | otherwise =
      case filter (is_admissible x m) [clamp (vertex + 1), clamp vertex] of
        []       -> Nothing
        (hi : _) -> Just (bisect 0 hi)
  where
    pn      = pips_denominator * (x + m) - x * m
    d2      = pips_denominator * pips_denominator
    leading = pn * pn + d2 * (m - x) * (m - x)
    vertex  = (d2 * (x + m) * pn) `div` (2 * leading)
    clamp v = max 0 (min (pips_denominator - 1) v)
    bisect lo hi
      | lo >= hi  = lo
      | otherwise =
          let mid = (lo + hi) `div` 2
          in if is_admissible x m mid then bisect lo mid else bisect (mid + 1) hi

-- ---------------------------------------------------------------------------------------------
-- The band, the mixer, and the seeded pick
-- ---------------------------------------------------------------------------------------------

-- | Every pair that composes to @f@ under the rounding rule AND is admissible at @delta*@,
-- ASCENDING IN @phi_X@.
--
-- THE ORDER IS LOAD-BEARING AND IS NOT A PRESENTATION CHOICE. 'pick_from_band' selects by INDEX,
-- so the index a seed resolves to is only reproducible if the list it indexes is. @x@ runs
-- @[1 .. f-1]@ in increasing order and nothing is sorted afterwards, so the position of a member is
-- a function of @f@ and @delta*@ alone. A band that came back in the order a set iterator happened
-- to yield would replay a DIFFERENT pair from the same seed, and nothing in the recorded split
-- would have changed.
--
-- @m > x@ IS LOCKED DECISION 3 (@rho > 1@), not a tie-break. @VOLUME_PATH.md@ section 2's two legs
-- are asymmetric -- the numeraire leg and the other one are different quantities in the model -- and
-- the fixture's own orientation is @(500, 6000)@. Keeping both orientations would put @(x, m)@ and
-- @(m, x)@ in the band as separate members with identical composed fees, which doubles the band and
-- makes the seeded index mean half as much. 'exact_pairs_for' is DELIBERATELY unrestricted and
-- therefore counts BOTH orientations; that is why its census at @f = 6497@ is 2 and not 1, and the
-- two functions are not measuring the same thing.
--
-- PARTIAL EXACTLY WHERE 'nearest_partner' IS, AND THE GUARD IS ELSEWHERE. The enumeration reaches
-- @x = 1000000@ for every @f > 1000000@, and 'nearest_partner' divides by @1000000 - x@ there. That
-- is an exception rather than a refusal, so 'split_for' tests 'fee_in_domain' BEFORE it ever calls
-- this function. Calling this one directly on a fee outside the domain is the caller's error and it
-- is not defended against here, because a defence here would have to invent a band for a fee that
-- has none.
--
-- The sizes, MEASURED, at @delta* = 490000@:
--
-- > length (admissible_band 100   490000) == 44
-- > length (admissible_band 500   490000) == 224
-- > length (admissible_band 3000  490000) == 1344
-- > length (admissible_band 6497  490000) == 2900
-- > length (admissible_band 10000 490000) == 4447
--
-- and the two degenerate inputs the seed's evidence depends on:
--
-- > admissible_band 3000 500 == [(1, 2999)]     -- a SINGLETON
-- > admissible_band 3000 200 == []              -- EMPTY
--
-- A PLANNING CORRECTION, MEASURED HERE. @26-RESEARCH.md@ guard 20 and @26-VALIDATION.md@ both name
-- @f = 3000, delta* = 1000@ as the empty-band input, and @26-03-PLAN.md@'s table calls its size 4.
-- Neither is right for this function:
--
-- > admissible_band 3000 1000 == [(1, 2999), (2, 2998)]   -- size 2
--
-- The 4 is the count WITHOUT the @m > x@ restriction -- @(1,2999)@, @(2,2998)@, @(2998,2)@ and
-- @(2999,1)@ -- so it describes a band this function does not return. The empty input is
-- @delta* = 200@ and the singleton is @delta* = 500@.
admissible_band :: Integer -> Integer -> [(Integer, Integer)]
admissible_band f dstar =
  [ (x, m)
  | x <- [1 .. f - 1]
  , let m = nearest_partner f x
  , m > x
  , is_admissible x m dstar
  ]

-- | The splitmix64 finalizer, in exact 'Integer' arithmetic with every intermediate masked to 64
-- bits.
--
-- WHY A HAND-ROLLED, DOCUMENTED MIXER RATHER THAN A LIBRARY GENERATOR. @fs_seed@ is what a run log
-- replays a split FROM. A generator whose stream is an implementation detail of a package would
-- move under a version bump -- silently, and without changing a single stored byte -- and every
-- split ever recorded would then resolve to a different pair while still looking internally
-- consistent. That is the same failure the driver's seed contract names: a value the operator
-- believes is a replay and is not, with nothing downstream able to tell. So the stream is written
-- down here, in five lines, with its constants in DECIMAL. Bumping any of them is a
-- 'splitter_version' change.
--
-- The constants, named rather than spelled inline, are the published finalizer's: the 64-bit mask
-- @18446744073709551615@, the golden-ratio addend @11400714819323198485@, and the two multipliers
-- @13787848793156543929@ and @10723151780598845931@, with shifts 30, 27 and 31. They are decimal
-- because this file must carry no hexadecimal literal -- the repository scans for exactly that --
-- and decimal is the same value, not a weaker statement of it.
--
-- Total on every 'Integer'. A negative argument is masked into the same 64-bit window as a positive
-- one, so there is no input on which this diverges or throws; in practice the only caller passes a
-- 'Word32'.
mix64 :: Integer -> Integer
mix64 seed = z3 `xor` (z3 `shiftR` 31)
  where
    z0 = (seed + golden_ratio_addend) .&. word64_mask
    z1 = ((z0 `xor` (z0 `shiftR` 30)) * mixer_multiplier_one) .&. word64_mask
    z2 = ((z1 `xor` (z1 `shiftR` 27)) * mixer_multiplier_two) .&. word64_mask
    z3 = z2

-- | @2^64 - 1@, in decimal.
word64_mask :: Integer
word64_mask = 18446744073709551615

-- | @floor(2^64 \/ phi)@, the finalizer's addend, in decimal.
golden_ratio_addend :: Integer
golden_ratio_addend = 11400714819323198485

-- | The finalizer's first multiplier, in decimal.
mixer_multiplier_one :: Integer
mixer_multiplier_one = 13787848793156543929

-- | The finalizer's second multiplier, in decimal.
mixer_multiplier_two :: Integer
mixer_multiplier_two = 10723151780598845931

-- | The band member a seed selects: a PURE function of @(seed, band)@ and of nothing else.
--
-- That purity is the whole of FEE-04's Tier-A standing. Nothing here reads a clock, an environment
-- variable or an entropy source, so the same @(seed, band)@ gives the same member in any process on
-- any host, and a check can assert it without a rig.
--
-- 'Nothing' EXACTLY when the band is empty, which is what lets 'split_for' treat the emptiness test
-- and the pick as one test rather than two that could disagree.
--
-- The indexing operator is partial and the guard is the @mod@ immediately above it: @size@ is
-- strictly positive on the branch that indexes, so the index lies in @[0, size-1]@ and the operator
-- cannot be reached out of range. Said here because a partial operator with its guard three lines
-- away is how a total-looking function acquires an unreachable-until-it-is-not branch.
pick_from_band :: Word32 -> [(Integer, Integer)] -> Maybe (Integer, Integer)
pick_from_band seed band
  | null band = Nothing
  | otherwise = Just (band !! fromInteger (mix64 (toInteger seed) `mod` size))
  where
    size = toInteger (length band)

-- ---------------------------------------------------------------------------------------------
-- The result, and why one was refused
-- ---------------------------------------------------------------------------------------------

-- | A split that was made, with everything that was rounded away RECORDED rather than discarded.
--
-- One constructor and record syntax, so every selector is total. The realized composition and the
-- residual are first-class fields because ruling 1 is round-AND-REPORT: a splitter that returned
-- only the pair would make the half-pip it moved unobservable downstream, and Phase 27's
-- reconciliation against the chain needs both the residual and the floor term named in
-- 'compose_scaled' to tell a rounding difference from a bug.
--
-- Construction is a later plan's work. The record lands here so its consumers are written against
-- a fixed interface rather than against one that grows underneath them.
data FeeSplit = FeeSplit
  { fs_pool_fee_pips   :: !Integer
    -- ^ the requested pool fee @f@, in pips
  , fs_dstar_pips      :: !Integer
    -- ^ the requested target @delta*@, in pips
  , fs_phi_x_pips      :: !Integer
    -- ^ the numeraire leg, in pips
  , fs_phi_m_pips      :: !Integer
    -- ^ the other leg, in pips; always strictly greater than 'fs_phi_x_pips' under ruling 2
  , fs_realized_scaled :: !Integer
    -- ^ @'compose_scaled' phi_x phi_m@: what the pair ACTUALLY composes to, times
    --   'pips_denominator'
  , fs_residual_scaled :: !Integer
    -- ^ @'residual_scaled' f phi_x phi_m@: the signed miss, in the same scaled units
  , fs_is_exact        :: !Bool
    -- ^ whether 'fs_residual_scaled' is zero. False for every canonical Uniswap tier
  , fs_ellipse_e       :: !Integer
    -- ^ @'ellipse_test' phi_x phi_m delta*@, the prover's own quantity, recorded not just signed
  , fs_boundary_pips   :: !Integer
    -- ^ the least admissible @delta*@ for this pair
  , fs_band_size       :: !Int
    -- ^ how many admissible pairs the choice was made from; 1 makes the seed vacuous
  , fs_seed            :: !Word32
    -- ^ the seed that selected this member of the band
  , fs_splitter_version :: !String
    -- ^ 'splitter_version' as it stood when this split was made
  } deriving (Eq, Show)

-- | Why a split was refused. POSITIONAL constructors, deliberately: a multi-constructor record
-- would give partial selectors, which GHC 9.10's @-Wincomplete-record-selectors@ reports and
-- @-Wall@ is a gate here.
--
-- Every constructor names its subject AND its number, in the same voice @Gams.Argv.in_range@ uses,
-- so an operator reading a refusal learns which quantity was wrong rather than that one of them
-- was.
data SplitRefusal
  = FeeOutOfDomain Integer
    -- ^ the pool fee, which is outside @[1, 'pips_denominator' - 1]@. See 'fee_in_domain': this is
    --   the FIRST thing a split checks, because the band enumeration below it divides by zero on
    --   such a fee rather than refusing it.
  | EqualFees Integer
    -- ^ the value both legs carry
  | OutsideEllipse Integer Integer Integer Integer (Maybe Integer)
    -- ^ @phi_x@, @phi_m@, the requested @delta*@, the exact @E@, and the least admissible
    --   @delta*@ if one exists. The last is 'Maybe' because 'min_admissible_dstar' is: at equal
    --   fees there is genuinely no boundary to report.
  | EmptyBand Integer Integer Int
    -- ^ the pool fee, the requested @delta*@, and the size of the band that came back (zero)
  | ResidualTooLarge Integer Integer Integer Integer
    -- ^ the pool fee, @phi_x@, @phi_m@, and the residual that exceeded one whole pip
  | NoBoundaryForAnAdmissiblePair Integer Integer Integer
    -- ^ @phi_x@, @phi_m@ and the @delta*@ they were ADMITTED at. This is an INTERNAL
    --   INCONSISTENCY, not an input error: the pair reached 'split_for' through
    --   'admissible_band', so 'is_admissible' said yes at this target, and
    --   'min_admissible_dstar' then reported that the pair admits no target at all. Those two
    --   statements cannot both be true. It exists as a refusal rather than as a defaulted
    --   boundary because a default here is exactly the shape RC-M4 found: the bisection that
    --   returns 'Nothing' on an admissible pair is a real bug this module already had once, and a
    --   @0@ or a @fromMaybe@ in its place would have shipped a legal split carrying a boundary
    --   nobody measured.
  deriving (Eq, Show)

-- | The operator-facing sentence for a refusal. Total: one arm per constructor.
refusal_message :: SplitRefusal -> String
refusal_message refusal =
  case refusal of
    FeeOutOfDomain f ->
      "pool fee " ++ show f ++ " is outside the splitter's domain, which is 1 .. "
        ++ show (pips_denominator - 1) ++ " pips. A fee at or above " ++ show pips_denominator
        ++ " has no partner in that range, and the band enumeration DIVIDES BY ZERO on it rather"
        ++ " than refusing it, which is why this is checked first. If the value is "
        ++ show dynamic_fee_flag_value
        ++ " it is Uniswap v4's DYNAMIC_FEE_FLAG sentinel arriving in PoolKey.fee, NOT a fee of "
        ++ show dynamic_fee_flag_value ++ " pips: resolve the live fee from the hook and split"
        ++ " that."
    EqualFees value ->
      "both legs carry " ++ show value ++ " pips, and they must DIFFER. VOLUME_PATH.md section 1.2:"
        ++ " equal fees on the two legs are infeasible for EVERY target. Measured here rather than"
        ++ " argued: at equal fees the admissibility quadratic has a double root at"
        ++ " 1/(2-phi), which is not an integer number of pips, so no integer target is admissible"
        ++ " at all."
    OutsideEllipse phi_x phi_m dstar e boundary ->
      "the pair (" ++ show phi_x ++ ", " ++ show phi_m ++ ") pips does not admit the target "
        ++ show dstar ++ " pips: the prover's own ellTest is " ++ show e
        ++ " scaled units, and it must be at or below zero. "
        ++ case boundary of
             Just b  -> "The least admissible target for this pair is " ++ show b ++ " pips."
             Nothing -> "This pair admits NO integer target at all, so no boundary can be named."
    EmptyBand f dstar size ->
      "no admissible pair composes to " ++ show f ++ " pips at target " ++ show dstar
        ++ " pips: the band came back with " ++ show size
        ++ " members. Widening the band is a splitter_version change, not a retry."
    ResidualTooLarge f phi_x phi_m residual ->
      "the pair (" ++ show phi_x ++ ", " ++ show phi_m ++ ") pips composes to a fee that misses "
        ++ show f ++ " pips by " ++ show residual ++ " scaled units, which is at or beyond one"
        ++ " whole pip (" ++ show pips_denominator ++ "). Nearest rounding bounds this below half"
        ++ " a pip, so a value here means the rounding rule changed."
    NoBoundaryForAnAdmissiblePair phi_x phi_m dstar ->
      "the pair (" ++ show phi_x ++ ", " ++ show phi_m ++ ") pips was ADMITTED at target "
        ++ show dstar ++ " pips by is_admissible, and min_admissible_dstar then reported that it"
        ++ " admits NO integer target at all. Those two cannot both be true, so this is an"
        ++ " inconsistency INSIDE the splitter and not a fact about the input. It is reported"
        ++ " rather than defaulted: a boundary invented here would travel into a recorded split as"
        ++ " a measurement nobody made."

-- | The boundary a refusal carries, when it carries one. Total.
refusal_boundary :: SplitRefusal -> Maybe Integer
refusal_boundary refusal =
  case refusal of
    OutsideEllipse _ _ _ _ boundary -> boundary
    _                               -> Nothing

-- | v4's dynamic-fee sentinel, in DECIMAL. Named once so the refusal above can spell it without
-- this file carrying a hexadecimal literal, which the repository's own literal purge scans for.
dynamic_fee_flag_value :: Integer
dynamic_fee_flag_value = 8388608

-- | The ruling SET this splitter implements, as a string that keys alongside its output.
--
-- Round-and-report; the band restricted to @phi_M > phi_X@; nearest with ties UP; admissibility by
-- the prover's own @ellTest@. Widening any one of the four bumps this string. That is the whole
-- point of it: keys computed under \"fee-split-1\" become ORPHANS under the next version rather
-- than silently meaning something else, which is the property the key scheme column was built to
-- give.
splitter_version :: String
splitter_version = "fee-split-1"

-- ---------------------------------------------------------------------------------------------
-- The split
-- ---------------------------------------------------------------------------------------------

-- | @(seed, pool fee in pips, delta* in pips)@ to a fully populated 'FeeSplit', or to the named
-- reason there is none.
--
-- FIVE STEPS, AND THE ORDER OF THE FIRST TWO IS THE WHOLE DESIGN.
--
-- 1. __The domain of @f@, FIRST.__ @unless (fee_in_domain f)@, this is 'FeeOutOfDomain'. It is
--    ahead of the band because the band ENUMERATES @x@ over @[1 .. f-1]@ and hands each to
--    'nearest_partner', which divides by @1000000 - x@: for any @f > 1000000@ that reaches
--    @x = 1000000@ and raises an EXCEPTION, which no 'Either' can carry. The falsifying input is a
--    production value, not a hypothetical --
--
--    > split_for 0 8388608 490000 == Left (FeeOutOfDomain 8388608)
--
--    and 8388608 is Uniswap v4's @DYNAMIC_FEE_FLAG@ arriving in @PoolKey.fee@ (see
--    'fee_in_domain'), which this repository's own dynamic-fee hook track produces. It is NOT a fee
--    of 8388608 pips.
--
--    THIS STEP DOES NOT PREEMPT THE EQUAL-FEE DIAGNOSIS, and that is deliberate. It tests @f@ --
--    the POOL fee -- and says nothing about the two legs. An in-domain request with equal legs
--    never reaches this function as a pair at all: the legs are what this function DERIVES.
--    @Gams.Argv.render_argv@ is where a caller-supplied pair is diagnosed, and there the
--    equal-fee refusal runs before the ellipse for exactly the same reason this step runs before
--    the band -- the more specific diagnosis must not be swallowed by a more general one that
--    happens to refuse the same input.
--
-- 2. __The band, and the pick, as ONE test.__ 'pick_from_band' answers 'Nothing' exactly when the
--    band is empty, so there is no second emptiness test that could disagree with it and no
--    unreachable branch needing an invented message. The refusal carries the size the band
--    actually came back with, which is @0@ on this path by construction -- and if it ever printed
--    anything else, that number is itself the diagnosis.
--
-- 3. __The residual alarm.__ @abs r >= 1000000@ is 'ResidualTooLarge'. Nearest rounding bounds
--    @|r|@ by @(D - x) \/ 2 < D \/ 2@, so this is a two-times headroom alarm on the ROUNDING RULE
--    rather than a tolerance: it can only fire if 'nearest_partner' stopped rounding to nearest.
--
-- 4. __The boundary.__ 'min_admissible_dstar' is 'Just' here because the pair came out of
--    'admissible_band' and is therefore admissible AT @dstar@. The impossible 'Nothing' is
--    'NoBoundaryForAnAdmissiblePair' -- a refusal, never a @fromMaybe@ default. RC-M4 is why: the
--    bisection specified for this module returned 'Nothing' on the admissible pair @(99, 101)@,
--    and under a default that split would have shipped with a boundary of zero and nothing red.
--
-- 5. __The record__, with everything that was rounded away kept.
--
-- THE TWO WAYS FEE-04 GOES VACUOUS, AND WHY @fs_band_size@ IS A FIELD. A test that runs one seed
-- twice is green under a selector that IGNORES the seed, and a test that runs eight seeds is green
-- under a band with ONE member -- every seed then resolves to index 0 and the recorded pair is the
-- same for a reason that has nothing to do with the mixer. The first is caught by comparing two
-- different seeds; the second cannot be caught from the outside at all, which is why the band size
-- is RECORDED in the result rather than inferred by whoever reads it. MEASURED:
-- @admissible_band 3000 500@ is the singleton @[(1, 2999)]@, so @split_for s 3000 500@ returns the
-- same pair for every @s@ in the universe, and the artifact says @fs_band_size = 1@ where a reader
-- can see it.
--
-- The four named results, pinned:
--
-- > split_for 0 3000 490000  -> (752, 2250)   residual   308000, band 1344, boundary 300912
-- > split_for 1 3000 490000  -> ( 66, 2934)   residual  -193644, band 1344, boundary  22486
-- > split_for 0 6497 490000  -> (1036, 5467)  residual   336188, band 2900, boundary 183150
-- > split_for 1 6497 490000  -> (2466, 4041)  residual    34894, band 2900, boundary 445955
--
-- > split_for 0 3000 200 == Left (EmptyBand 3000 200 0)
split_for :: Word32 -> Integer -> Integer -> Either SplitRefusal FeeSplit
split_for seed f dstar
  | not (fee_in_domain f) = Left (FeeOutOfDomain f)
  | otherwise =
      let band = admissible_band f dstar
      in case pick_from_band seed band of
           Nothing -> Left (EmptyBand f dstar (length band))
           Just (x, m) ->
             let r = residual_scaled f x m
             in if abs r >= pips_denominator
                  then Left (ResidualTooLarge f x m r)
                  else case min_admissible_dstar x m of
                         Nothing -> Left (NoBoundaryForAnAdmissiblePair x m dstar)
                         Just boundary ->
                           Right FeeSplit
                             { fs_pool_fee_pips    = f
                             , fs_dstar_pips       = dstar
                             , fs_phi_x_pips       = x
                             , fs_phi_m_pips       = m
                             , fs_realized_scaled  = compose_scaled x m
                             , fs_residual_scaled  = r
                             , fs_is_exact         = r == 0
                             , fs_ellipse_e        = ellipse_test x m dstar
                             , fs_boundary_pips    = boundary
                             , fs_band_size        = length band
                             , fs_seed             = seed
                             , fs_splitter_version = splitter_version
                             }
