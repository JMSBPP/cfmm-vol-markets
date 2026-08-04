-- |
-- The driver's randomness, made REPRODUCIBLE and RECORDABLE.
--
-- == THE GAP THIS CLOSES
--
-- Until 22-05 @offchain\/app\/Main.hs@ called @System.Random.MWC.createSystemRandom@: seeded from
-- the operating system, never recorded, and therefore unreplayable. A finished run could not say
-- which price path it had taken, so SC-5's reproducibility requirement was satisfied for the RIG
-- and not for the RUN. Everything here exists to make the run's stream a value that can be printed,
-- committed and handed back to the program.
--
-- == WHY A @Word32@ AND NOT mwc-random's OWN @Seed@
--
-- @System.Random.MWC.Seed@ derives @(Eq, Show, Typeable)@ and has NO @Read@ instance, so a shown
-- @Seed@ cannot be parsed back — it round-trips in one direction only, which is the useless one. A
-- single decimal 'Word32' is short enough to read off a terminal, type into an environment variable
-- and paste into a summary, and it round-trips through @show@\/@reads@ exactly.
--
-- The cost is stated plainly: a 'Word32' addresses 2^32 streams, not mwc-random's full 256-word
-- state. That is the right trade for a driver whose purpose is replaying a five-step demo path, and
-- it is the trade @initialize@ is designed for.
--
-- == WHAT REPLAYS AND WHAT DOES NOT
--
-- The seed replays the TICK PATH. It does not replay absolute chain timestamps: the driver's
-- @t_0@ is @chain_head + stride@ and @anvil --timestamp@ fixes the chain's ORIGIN, not its RATE
-- (22-03 measured the head at @1700000027@ over a deploy whose genesis was @1700000000@). A
-- from-scratch rig therefore gives a different @t_0@ and the schedule replays in SHAPE only —
-- @t_k - t_0 = k * stride@. 'Driver.Capture' records @t0@ for exactly this reason, so every offline
-- check is written against the run's own origin instead of a constant.
module Driver.Seed
  ( -- * The environment contract
    seed_env_var
    -- * Resolution
  , resolve_seed
  , gen_from_seed
  ) where

import Data.Char (isDigit, isSpace)
import Data.List (dropWhileEnd, intercalate)
import qualified Data.Vector.Unboxed as V
import Data.Word (Word32)
import System.Environment (lookupEnv)
import System.Random.MWC (GenIO, createSystemRandom, initialize, uniform)

-- | The one variable that controls the run's randomness. Named here rather than spelled at each
-- call site so a check cannot drift from the implementation it checks.
seed_env_var :: String
seed_env_var = "RIG_SEED"

-- | The run's seed, and a one-line provenance note describing where it came from.
--
-- Three outcomes, and the third is the one that matters:
--
--   * @RIG_SEED@ holds a decimal 'Word32' — it is used verbatim and reported as SUPPLIED.
--   * @RIG_SEED@ is unset — one is DRAWN from the system entropy source and the note says so, so
--     the caller knows it must print and record the value before doing anything else.
--   * @RIG_SEED@ holds anything else — this FAILS, loudly, naming the variable and the expected
--     form. It does NOT fall back to a drawn seed. A typo'd seed that silently becomes a random one
--     produces a run the operator believes is a replay and is not, and nothing downstream can
--     detect that: the artifact would record the drawn value and look perfectly consistent.
--
-- The message shape follows 'Rig.Manifest': name the variable, name the expected form, and say what
-- to do instead.
resolve_seed :: IO (Word32, String)
resolve_seed = do
  raw <- lookupEnv seed_env_var
  case raw of
    Nothing -> do
      -- Drawn through createSystemRandom + one `uniform`, rather than through createSystemSeed +
      -- fromSeed: the first word of a saved Seed is an implementation detail of the state vector,
      -- while a uniform Word32 is exactly the thing `initialize` consumes.
      gen <- createSystemRandom
      drawn <- uniform gen
      pure
        ( drawn
        , seed_env_var ++ " was unset, so the seed " ++ show drawn ++ " was DRAWN. Record it:"
            ++ " re-run this path with " ++ seed_env_var ++ "=" ++ show drawn
        )
    Just given ->
      case parse_seed (trim given) of
        Just w  -> pure (w, "seed " ++ show w ++ " supplied via " ++ seed_env_var)
        Nothing -> fail (malformed_message given)

-- | A generator seeded from a 'Word32'.
--
-- @initialize@ expands the single word into mwc-random's full state deterministically, so two calls
-- with the same argument in any two processes yield the same stream.
gen_from_seed :: Word32 -> IO GenIO
gen_from_seed w = initialize (V.singleton w)

-- ---------------------------------------------------------------------------------------------
-- Parsing
-- ---------------------------------------------------------------------------------------------

-- | A single decimal 'Word32'. No sign, no @0x@, no leading @+@: anything that is not exactly that
-- is a mistake worth stopping for, and accepting a wider grammar here would only widen the set of
-- values whose meaning has to be guessed later.
parse_seed :: String -> Maybe Word32
parse_seed s
  | null s          = Nothing
  | not (all isDigit s) = Nothing
  | otherwise =
      case reads s :: [(Integer, String)] of
        [(n, "")] | n >= 0 && n <= toInteger (maxBound :: Word32) -> Just (fromInteger n)
        _ -> Nothing

malformed_message :: String -> String
malformed_message given =
  intercalate "\n"
    [ "Driver.Seed: " ++ seed_env_var ++ " is set but is not a seed."
    , "  value    : " ++ show given
    , "  expected : a single decimal Word32 in [0, " ++ show (maxBound :: Word32) ++ "]"
    , "  This does NOT fall back to a drawn seed. A malformed seed that silently became a random"
    , "  one would produce a run the operator believes is a replay and is not -- and the artifact"
    , "  would record the drawn value, so nothing downstream could tell."
    , "  Unset " ++ seed_env_var ++ " to draw one (it will be printed), or supply a decimal value."
    ]

trim :: String -> String
trim = dropWhileEnd isSpace . dropWhile isSpace
