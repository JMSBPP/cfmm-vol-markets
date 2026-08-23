-- |
-- GAMS-06's first half: the child's environment, AS DATA.
--
-- The whitelist is a value in this module rather than a shell incantation at the call site, so the
-- suite can assert what will be handed to @execve@ without spawning anything, and so the
-- invocation layer has exactly one place to get it wrong.
--
-- WHAT WAS MEASURED, ON THIS MACHINE, ON 2026-08-16
-- -------------------------------------------------
-- The real prover was driven under four environment configurations against the same shock, and the
-- artifact's sha256 was compared each time:
--
-- >  the ambient developer shell                                                    golden
-- >  env -i PATH=<gamsdir>:/usr/bin HOME=<home> LC_ALL=C                            golden
-- >  env -i PATH=<gamsdir>:/usr/bin LC_ALL=C          (no HOME at all)              golden
-- >  env -i PATH=/usr/bin LC_ALL=C GAMSTHREADS=8 GDXCOMPRESS=1
-- >         LC_NUMERIC=de_DE.UTF-8 GAMSDIR=/nonexistent, absolute binary path        golden
--
-- So a three-variable whitelist reproduces the bytes; so does a two-variable one; and four hostile
-- ambient variables changed nothing at all. @PATH@ is kept at a single system directory because
-- the binary is invoked by ABSOLUTE path, which removes the @PATH@-shadow surface rather than
-- policing it.
--
-- THE HONEST LIMIT, STATED HERE SO NOBODY LATER INVENTS A VARIABLE THAT MATTERS
-- ----------------------------------------------------------------------------
-- NO ambient variable and NO configuration file was found on this machine that changes the
-- artifact's bytes, and @locale -a@ offers only @C@, @C.utf8@, @en_US.utf8@ and @POSIX@ -- there is
-- NO comma-decimal locale installed, so a locale-driven byte difference is not observable here at
-- all. An explicit command-line parameter also beat a @gamsconfig.yaml@ placed in the run
-- directory.
--
-- The consequence is a correction of record, not a gap to paper over. GAMS-06's
-- /"a run inheriting the environment is OBSERVED to differ"/ CANNOT be discharged against artifact
-- bytes on this machine: the only way to make such a check pass would be to invent a variable that
-- matters, or to let it pass because its subject is absent. It IS cleanly dischargeable against
-- the CHILD'S OWN ENVIRONMENT VECTOR -- spawn a probe through the same invocation function twice,
-- once with this whitelist and once inheriting, and assert the inherited one carries a variable
-- this list excludes. That is plan 24-04's subject, and it is the honest one: a whitelist that
-- silently fell back to inheritance is exactly what it catches, while a byte comparison would
-- report success either way.
--
-- @LC_ALL@ IS PINNED ANYWAY, AND THAT IS NOT A CONTRADICTION
-- ----------------------------------------------------------
-- Nothing measurable here depends on it TODAY, on a host with no comma-decimal locale installed.
-- The pin costs one pair and removes the decimal separator from the set of things that could ever
-- differ between two machines whose bytes are supposed to be comparable. An unpinned separator is
-- not a hazard this repository has observed; it is one it declines to leave open on a path whose
-- entire purpose is byte reproducibility.
module Gams.Env
  ( -- * The whitelist
    whitelist_keys
  , whitelist_for
  , forbidden_key_prefixes
    -- * Checking a candidate environment
  , validate_env
  , EnvError (..)
  ) where

import Data.List (isPrefixOf, sort)

-- | The keys the child is given, sorted, and nothing else.
whitelist_keys :: [String]
whitelist_keys = ["HOME", "LC_ALL", "PATH"]

-- | The environment vector, given the resolved HOME.
--
-- HOME comes from the CALLER because it is the one whitelisted value that is a property of the
-- machine rather than a decision of this module; the two that are decisions are written here.
-- MEASURED: the bytes are golden with HOME present and with HOME absent, so it is carried for the
-- benefit of anything the solver invokes, not because the artifact depends on it.
whitelist_for :: FilePath -> [(String, String)]
whitelist_for home =
  [ ("HOME", home)
  , ("LC_ALL", "C")
  , ("PATH", "/usr/bin")
  ]

-- | The prefixes no key in a whitelisted environment may carry.
--
-- Every one of these was MEASURED inert against the artifact's bytes, and every one of them is
-- excluded anyway: @GAMSTHREADS@ selects a thread count, @GDXCOMPRESS@ selects a container
-- encoding, and the two locale variables select a decimal separator. Inert TODAY, on this host, at
-- this toolchain version is a measurement -- it is not a property of the interface, and the
-- interface is what an environment vector commits to.
forbidden_key_prefixes :: [String]
forbidden_key_prefixes = ["GAMS", "GDX", "CONOPT", "LC_NUMERIC", "LANG"]

-- | Why a candidate environment is not the whitelist.
--
-- Each constructor names its subject, because \"the environment is wrong\" tells an operator
-- nothing about which of three pairs to look at.
data EnvError
  = KeySetDiffers [String] [String]
    -- ^ the keys that are present and should not be; the keys that are absent and should be
  | ForbiddenKey String String
    -- ^ the key, and the prefix that forbids it
  | WrongValue String String String
    -- ^ the key, the value it carried, the value required
  deriving (Eq, Show)

-- | The whole check, in BOTH directions.
--
-- A one-directional rule -- \"no forbidden key is present\" -- is satisfied by an EMPTY
-- environment, which is the shape of every guard this project has caught passing because its
-- subject was absent. So the key SET is asserted both ways before anything else is looked at, and
-- only then are the two pinned values compared.
validate_env :: [(String, String)] -> Either EnvError ()
validate_env pairs = do
  let present = sort (map fst pairs)
      extra   = [k | k <- present, k `notElem` whitelist_keys]
      missing = [k | k <- whitelist_keys, k `notElem` present]
  _ <- if null extra && null missing
         then Right ()
         else Left (KeySetDiffers extra missing)
  _ <- mapM_ forbidden present
  value_is "LC_ALL" "C"
  where
    forbidden key =
      case [p | p <- forbidden_key_prefixes, p `isPrefixOf` key] of
        (p : _) -> Left (ForbiddenKey key p)
        []      -> Right ()

    value_is key wanted =
      case [v | (k, v) <- pairs, k == key] of
        (v : _) | v == wanted -> Right ()
                | otherwise   -> Left (WrongValue key v wanted)
        []                    -> Left (KeySetDiffers [] [key])
