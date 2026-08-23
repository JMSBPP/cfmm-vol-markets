-- | THE ONE PLACE THE CHAIN'S ADDRESS IS DECIDED.
--
-- CHAIN-06 says "nine sites, one rule". MEASURED at 27-01, by @git grep@ over @offchain\/@ for
-- the variable name or the default authority: __TEN__ files, not nine. The tenth is
-- @offchain\/spec\/types.md@, a pasted RPC transcript, and it is listed in 'endpoint_sites' as a
-- 'Transcript' rather than argued away -- see 'SiteKind' for the ruling and what it costs.
--
-- == WHAT WAS ACTUALLY WRONG BEFORE THIS MODULE
--
-- Not "the rule was implemented N times". MEASURED at 27-01: the rule was implemented __ZERO__
-- times. The only occurrence of the variable name anywhere under @offchain\/@ was a COMMENT in
-- @offchain\/rig\/deploy-rig.sh@ explaining that the deploy scripts scrub it. Every one of the
-- nine executable sites wrote the default authority out as a literal and read no environment at
-- all, so @ETH_RPC_URL=...:9545@ was accepted by the shell, ignored by every consumer, and the
-- run went to 8545. There was no drift between N copies to reconcile; there was one hardcoded
-- constant, nine times.
--
-- == WHY THE PRODUCER IS IN THE SAME MANIFEST AS THE CONSUMERS
--
-- CHAIN-07's own words: /a consumer-only resolver does NOT retire the requirement/. A resolver
-- that only the readers honour leaves @deploy-rig.sh@ free to start anvil on 8545 while the reads
-- attach to 9545 -- the endpoint is then agreed among everyone who cannot start a chain, which is
-- the precise divergence issue #29 was opened to prevent. So the script that OWNS anvil is a site
-- here, with its own 'SiteKind', and the census that reads this manifest asserts it derives the
-- host and the port it starts on from the same value the readers resolve.
--
-- == WHY THE SHELL HALF IS A SECOND FILE AND NOT A THIRD, FOURTH AND FIFTH COPY
--
-- Three of the ten sites are @bash@ and cannot import this module. The alternatives were: spell
-- @${ETH_RPC_URL:-...}@ inline in each of the three (four statements of the default, three of them
-- unchecked), or write the shell half ONCE in 'shell_resolver' and have the three source it. The
-- second is what shipped. It leaves the default authority written down in exactly TWO places, in
-- two languages, and the census asserts they are byte-equal -- the move this repository already
-- makes for the pip denominator, where @Fee.Split@ and @Store.Key@ each name it and a check
-- asserts the two agree. A duplication that a check compares is a checked agreement; a
-- duplication that nothing compares is the defect.
--
-- == WHY THE ALIAS COULD NOT BE THE MECHANISM
--
-- @deploy-rig.sh@ used to reach the chain through foundry's @--rpc-url local@, resolved by
-- @foundry.toml:59@ to @local = \"http:\/\/127.0.0.1:8545\"@. That is a THIRD statement of the
-- default -- and @foundry.toml@ is outside this workstream's territory, so it cannot be made to
-- honour the variable. Binding the producer through the alias would therefore have pinned it to
-- 8545 by construction no matter what the resolver returned. The producer now passes the resolved
-- URL to @forge@ and @cast@ directly and the alias is unused by the rig.
--
-- == WHAT THIS MODULE DOES NOT DO
--
-- It does not reach the chain, open a socket, or validate that anything is listening. It returns a
-- 'String'. Whether that authority answers is the caller's measurement, and every consumer already
-- reports its own RPC failure.
module Chain.Endpoint
  ( SiteKind (..)
  , EndpointSite (..)
  , endpoint_env_var
  , default_endpoint
  , endpoint_from
  , resolve_endpoint
  , shell_resolver
  , shell_default_var
  , producer_binding_tokens
  , chain_id_assertion_token
  , broadcast_token
  , endpoint_sites
  , site_paths
  , endpoint_census_terms
  , chain_reaching_terms
  , endpoint_authority
  ) where

import Data.List (stripPrefix, tails)
import System.Environment (lookupEnv)

-- | The variable, written down ONCE.
--
-- Named here rather than spelled at each @lookupEnv@ for the reason @Store.Config@ and
-- @Gams.Config@ name theirs: the constant is what a census can compare against, and a variable
-- that is spelled at its use sites is a variable a rename can leave half-honoured.
endpoint_env_var :: String
endpoint_env_var = "ETH_RPC_URL"

-- | The authority every site falls back to, written down ONCE on the Haskell side.
--
-- This is the ONE place in the Haskell tree where this literal may appear, and the census asserts
-- exactly that: every other site names 'resolve_endpoint' instead. 'shell_resolver' holds the
-- other permitted copy, and the two are asserted byte-equal.
default_endpoint :: String
default_endpoint = "http://127.0.0.1:8545"

-- | @ETH_RPC_URL@ if it is set AND NON-EMPTY, else 'default_endpoint'.
--
-- == THE NON-EMPTY HALF IS NOT DEFENSIVE PROGRAMMING
--
-- @lookupEnv@ returns @Just ""@ for an exported-but-empty variable, and the obvious
-- @fromMaybe default_endpoint \<$\> lookupEnv ...@ therefore resolves an empty export to the
-- EMPTY STRING. This repository has measured what that costs six separate times, always in the
-- same shape: an empty value flows onward, is compared against another empty value, @\"\" == \"\"@
-- is true, and the run exits 0 having verified nothing. @deploy-rig.sh@ carries the narrative for
-- the closest instance -- an empty @import-ref.txt@ wrote an empty @generatedFrom@ into the
-- manifest and every downstream freshness check then compared one empty string to another.
--
-- Here the empty value would not even be silently wrong: @HttpProvider \"\"@ is a request to an
-- empty authority. But an operator who ran @export ETH_RPC_URL=@ and got a connection error would
-- be told the chain refused, when what happened is that this function agreed to an address nobody
-- asked for. An empty export means "I did not supply one", and this returns the default.
--
-- No trimming, and that is a decision rather than an omission: @\" \"@ is not empty, and a
-- resolver that silently repaired whitespace would be quietly interpreting an operator's input.
-- A value with a space in it reaches the provider and the provider says so.
--
-- == WHY THE RULE IS A SEPARATE, PURE FUNCTION
--
-- Not style. MEASURED at 27-01, and it is a small trap with a large consequence:
-- @System.Environment.setEnv k \"\"@ does NOT export an empty variable -- base's implementation
-- routes an empty value to @unsetEnv@, so the very next @lookupEnv k@ returns @Nothing@. Observed
-- directly:
--
-- > setEnv "PROBE_VAR" ""  >> lookupEnv "PROBE_VAR"   ==>  Nothing
-- > setEnv "PROBE_VAR" "x" >> lookupEnv "PROBE_VAR"   ==>  Just "x"
--
-- A shell can do what @setEnv@ will not (@export VAR=@ leaves the variable PRESENT and empty, and
-- @printenv VAR@ exits 0 on it), so the state is entirely reachable in production and entirely
-- unreachable from an in-process test that sets the variable. A check written against the
-- environment therefore exercises the UNSET path twice while reporting on the empty one -- an
-- assertion that passes because its subject is absent, which is this milestone's standing defect
-- and would have been that defect INSIDE the guard against it. 27-01 wrote that check first and
-- MEASURED it green against a deliberately unguarded resolver.
--
-- 'endpoint_from' is the rule as a total function of exactly what @lookupEnv@ returns, so
-- @Just \"\"@ can be handed to it directly. 'resolve_endpoint' is the wiring, and the suite still
-- drives the wiring through the environment for the two states a process CAN set.
endpoint_from :: Maybe String -> String
endpoint_from (Just value) | not (null value) = value
endpoint_from _                               = default_endpoint

resolve_endpoint :: IO String
resolve_endpoint = endpoint_from <$> lookupEnv endpoint_env_var

-- | The shell half of the SAME resolver, sourced by every @bash@ site.
--
-- A path rather than a body, because @bash@ cannot import a Haskell module and a Haskell module
-- must not try to be a shell library. What binds the two is the census: that file states the
-- default once, and the check asserts the literal it states is byte-equal to 'default_endpoint'.
shell_resolver :: FilePath
shell_resolver = "offchain/rig/endpoint.sh"

-- | The name of the shell variable 'shell_resolver' states the default in.
--
-- Held here so the suite can find that line without spelling anything itself, and WRITTEN OUT
-- rather than derived: 24-04 MEASURED that referring to a name through a constant makes both sides
-- of a comparison follow a rename together, leaving the whole suite green under it, while a
-- written-out name reddens. A rename in the shell file therefore fails
-- @the_producer_and_the_consumers_bind_one_endpoint@ rather than silently ending the comparison.
shell_default_var :: String
shell_default_var = "ETH_RPC_URL_DEFAULT"

-- | The producer's two obligations under CHAIN-07, as the tokens that witness them.
--
-- @--host@ and @--port@ are what make the chain @deploy-rig.sh@ STARTS the chain every reader
-- RESOLVES. They are worth asserting precisely because omitting them is survivable: anvil's own
-- defaults are the same authority the resolver defaults to, so with the variable unset a rig with
-- no flags at all behaves identically -- and diverges for every other value.
producer_binding_tokens :: [String]
producer_binding_tokens = ["--host", "--port"]

-- | The assertion that must precede the first broadcast, and the token that marks a broadcast.
--
-- Two strings rather than one check, because 26-03 measured what happens when an ordering claim is
-- expressed only as a position: a later refactor moved the lines and the gate was structurally
-- voided while staying green. Existence and order are asserted separately, so DELETING the
-- assertion reddens even when nothing has moved.
chain_id_assertion_token :: String
chain_id_assertion_token = "cast chain-id"

broadcast_token :: String
broadcast_token = "--broadcast"

-- | What kind of thing a site is, and therefore which half of the rule applies to it.
--
-- The kind is not decoration -- it is what stops the census from being either vacuous or wrong.
-- Applying "must name the resolver" to the transcript would fail a document that is evidence, and
-- applying "must not hold the literal" to the resolver itself would fail the one file that is
-- supposed to hold it. A single undifferentiated list has to be relaxed on its first run, and a
-- rule relaxed on its first run is a rule nobody enforces afterwards.
data SiteKind
  = HaskellResolver
    -- ^ This module. Holds the literal; must be the only Haskell file that does.
  | ShellResolver
    -- ^ 'shell_resolver'. Holds the literal too, and its copy is asserted equal to this one's.
  | HaskellConsumer
    -- ^ Builds a @Provider@. Must obtain the authority from 'resolve_endpoint' and hold no
    -- literal.
  | ShellConsumer
    -- ^ Reads the chain from @bash@. Must source 'shell_resolver' and hold no literal.
  | ShellProducer
    -- ^ STARTS the chain. Must source 'shell_resolver' and bind the host AND the port it starts
    -- anvil on from the resolved value -- the half CHAIN-07 says a consumer-only resolver leaves
    -- open.
  | Transcript
    -- ^ Prose, documentation, or a recorded RPC session. Reads nothing and starts nothing.
    --
    -- Two members, and both are here DELIBERATELY. Neither is a consumer and the resolver rule
    -- does not apply to either, but both are inside the census grep's blast radius, and a file
    -- inside a grep's radius that the grep's list does not know about is how a scan gets narrowed
    -- on the day it first fires. Twenty-five instances of prose caught by a pattern are on record
    -- on this branch, and the answer every time was to move or declare the prose, never to relax
    -- the pattern. So both are DECLARED, and what is asserted about them is exactly what is true:
    -- they exist, and they are known.
  | Census
    -- ^ @offchain\/test\/Main.hs@: the suite that asserts this manifest.
    --
    -- It is a site because it NAMES the resolver -- it has to, in order to check it -- and a
    -- census whose own observer is outside its scope has a hole exactly where the observer is.
    -- What is asserted about it is the opposite of every other kind: it must name the resolver and
    -- must name NONE of 'chain_reaching_terms', which is @offchain\/rig\/README.md@'s standing
    -- claim that @cabal test@ opens no socket, made executable. That claim was prose with a
    -- hand-run grep beside it until 27-01; MEASURED at 27-01 before anything was written, all
    -- three of its tokens were 0, so what shipped is a guard around a property that already held
    -- rather than a repair.
  deriving (Eq, Show)

-- | One site: where it is, what it is, and why it is that.
data EndpointSite = EndpointSite
  { site_path :: FilePath
  , site_kind :: SiteKind
  , site_note :: String
  }

-- | The authority alone -- 'default_endpoint' without its scheme.
--
-- COMPUTED, never spelled a second time. It is what a "does this file hardcode the default?" scan
-- has to look for, and the scan runs from @offchain\/test\/Main.hs@, which must not contain the
-- literal: @offchain\/rig\/README.md@ records that @grep -cE \'cast call|HttpProvider|8545\'@ over
-- that file is 0, and a check that spelled its own subject would be the thing that broke the
-- property it asserts. Deriving it here means the suite names nothing and a change to
-- 'default_endpoint' carries the scan with it.
-- The scheme is stripped with 'stripPrefix' over 'tails' rather than a hand-rolled search: a
-- three-line substring scan written here would be a fourth implementation of something base
-- already has, and this repository has a standing note about not hand-rolling what a boot package
-- supplies. Falls back to the whole string if there is no scheme, so the scan degrades to
-- searching for MORE than it needs rather than for nothing.
endpoint_authority :: String
endpoint_authority =
  case [rest | tail_ <- tails default_endpoint, Just rest <- [stripPrefix "://" tail_]] of
    (rest : _) -> rest
    []         -> default_endpoint

-- | HOW A FILE IS RECOGNISED AS TOUCHING THE ENDPOINT AT ALL.
--
-- This list is the whole difference between a census that closes and one that reports the fix as a
-- regression, and 27-01 MEASURED both. The plan's census pattern was "names the variable OR the
-- default authority", which is what found the original ten. Run again AFTER the consumers were
-- rewired it found EIGHT: five of the six Haskell consumers no longer name either token, because
-- naming 'resolve_endpoint' instead is exactly what the fix is. A census on that pattern would
-- have reported the five correctly-fixed files as missing.
--
-- 'chain_reaching_terms' is the second correction and it is the one that found a site nobody had.
-- CHAIN-06 lists nine and @offchain\/rig\/verify-rig.sh@ is not among them -- because it reached
-- the chain through foundry's @--rpc-url local@ ALIAS, so it named neither token and no pattern
-- built from them could see it, while making fourteen @cast@ calls against a live rig. A pattern
-- that matches "names the variable" does not mean "reaches a chain". These two terms mean the
-- second thing, and they are what closes the census over files that reach a chain by any route.
--
-- Matched as FIXED STRINGS, not as a regular expression: the authority is full of dots, and an
-- unescaped @.@ is a wildcard that would match a host nobody wrote.
endpoint_census_terms :: [String]
endpoint_census_terms = [endpoint_env_var, endpoint_authority, "resolve_endpoint", shell_resolver]
                          ++ chain_reaching_terms

-- | The two shapes of REACHING a chain, one per language.
--
-- Held here rather than in the suite so the suite can scan for them without containing them.
--
-- == WHY @cast call@ IS NOT A THIRD TERM, MEASURED
--
-- It was, for one run. @offchain\/rig\/README.md@'s chain-independence claim is a hand-run
-- @grep -cE@ that names it, so the first draft inherited it -- and it MATCHED
-- @offchain\/lib\/CheatSwap\/Encoding.hs@, whose haddock says the calldata is built by shelling to
-- @cast calldata@. That call reaches nothing: it formats an ABI payload locally, like @cast sig@
-- and @cast keccak@, and no endpoint is involved. The term matched because @cast call@ is a PREFIX
-- of @cast calldata@ -- the same shape 26-03 measured when a naming assertion passed on a longer
-- wrong value because @\"828040\"@ contains @\"82804\"@. The README's grep carries the same defect
-- and has simply never met a file that says @cast calldata@.
--
-- Dropping it loses nothing, because it was neither necessary nor sufficient. A @cast@ invocation
-- that reaches a chain MUST name an endpoint flag, and every one in @verify-rig.sh@ and both
-- capture scripts does; the local ones never do. @--rpc-url@ is the anchored form of the question,
-- and @cast call@ was a lookalike for it.
chain_reaching_terms :: [String]
chain_reaching_terms = ["--rpc-url", "HttpProvider"]

-- | THE MANIFEST. Twenty entries.
--
-- Ten were MEASURED at 27-01 by the pattern CHAIN-06's own wording implies, which reported nine:
--
-- > git grep -l -e 'ETH_RPC_URL' -e '127\.0\.0\.1:8545' -- offchain | wc -l
-- > 10
--
-- and the same command over the whole tracked tree printed 34, the other 24 being planning
-- documents, historical @docs\/superpowers\/@ plans, @foundry.toml@, a workflow and a Solidity
-- test -- none of them under this workstream's territory and none of them a consumer. The census
-- is therefore scoped to @offchain\/@, and that scope is asserted rather than assumed: the check
-- that reads this list enumerates every file under @offchain\/@ with NO extension filter, so a new
-- site of any type is named on the day it lands.
--
-- The remaining five are the two resolvers, the suite, and TWO FILES THE MEASURED PATTERN COULD
-- NOT SEE -- see 'endpoint_census_terms' for how each was found. @verify-rig.sh@ in particular is
-- a real eleventh consumer that CHAIN-06's list of nine does not contain.
--
-- BOTH DIRECTIONS, and the second one is the one that matters. A list compared only against what
-- the tree holds still passes when the tree grows past it; a list compared only against itself
-- passes when a file it names is deleted. 23-03 measured the cost of the first shape -- a storage
-- module sat unlisted for two commits with nothing red.
endpoint_sites :: [EndpointSite]
endpoint_sites =
  [ EndpointSite "offchain/lib/Chain/Endpoint.hs" HaskellResolver
      "This module. States the variable and the default once each, for the whole Haskell tree."
  , EndpointSite "offchain/rig/endpoint.sh" ShellResolver
      "The shell half. States the default once for the three bash sites, and splits the resolved\
      \ URL into the host and port the producer needs. Its copy of the default is asserted\
      \ byte-equal to this module's."
  , EndpointSite "offchain/lib/PriceSetter/Rpc.hs" HaskellConsumer
      "write_price_and_report builds the Provider it runs the slot0 cheat through."
  , EndpointSite "offchain/lib/VolOrder/Rpc.hs" HaskellConsumer
      "create_order_and_report builds the Provider the order transaction is sent through."
  , EndpointSite "offchain/lib/StochasticOrderGen/Rpc.hs" HaskellConsumer
      "run_order_gen_and_report builds the Provider the batched orders are sent through."
  , EndpointSite "offchain/lib/StochasticPriceGen/Rpc.hs" HaskellConsumer
      "run_price_gen_and_report builds the Provider the simulated path is written through."
  , EndpointSite "offchain/app/Main.hs" HaskellConsumer
      "The demo driver. One Provider for the whole run, resolved before the capture is armed so a\
      \ resolution failure cannot leave a half-written artifact."
  , EndpointSite "offchain/app/CheatSwapProof.hs" HaskellConsumer
      "The cheat-swap capture. Its provider was a top-level pure value; it is now an IO action,\
      \ because a resolver that runs before main does is a resolver the environment cannot reach."
  , EndpointSite "offchain/rig/capture-batch-return.sh" ShellConsumer
      "Captures the empty-batch return shape with cast against a standing rig."
  , EndpointSite "offchain/rig/capture-cheat-swap-proof.sh" ShellConsumer
      "Captures the cheat-swap proof with cast against a standing rig."
  , EndpointSite "offchain/app/ChainReadConformance.hs" HaskellConsumer
      "27-02. CHAIN-02's observational half: reads the pool pinned at a block, changes the state,\
      \ and reads again both ways. It is also the ONLY thing that executes Chain.Read's wiring --\
      \ read_pool_field, read_raw_word_token and block_param are unreachable from cabal test by\
      \ construction, and an unexercised surface is this package's advertised-and-dead shape."
  , EndpointSite "offchain/rig/capture-chain-read.sh" ShellConsumer
      "27-02. Owns the preconditions, the artifact preservation and the self-checks around the\
      \ executable above. Its cast calls are the liveness probe and the chainId assertion, and it\
      \ FAILS rather than skipping when nothing answers."
  , EndpointSite "offchain/rig/chain-read-conformance.json" Transcript
      "27-02's committed artifact, and the THIRD member of this kind. It is not a consumer: it is\
      \ a recorded RPC session, and the resolver rule does not apply to it. It is DECLARED for the\
      \ reason spec/types.md and rig/README.md are -- its provenance note NAMES the shell resolver\
      \ (to say that the endpoint is deliberately not recorded), which puts it inside this census's\
      \ blast radius, and a file inside the radius that this list does not know about is how a scan\
      \ gets narrowed on the day it first fires. MEASURED at 27-02: it fired on this file's first\
      \ run, and the answer is the twenty-seventh instance of the same one -- declare the prose,\
      \ never relax the pattern."
  , EndpointSite "offchain/lib/Loop/Chain.hs" HaskellConsumer
      "28-02. THE ONLY module in the loop layer that names the transport: it builds a\
      \ Loop.Poll.ChainSource -- a record of five actions -- out of a resolved endpoint and the\
      \ three addresses the Shock filter needs. Everything else under offchain/lib/Loop/ takes\
      \ that record as an argument and is therefore drivable with no node, which is the whole\
      \ reason LOOP-01's restart proof can exist: the check supplies the source, so the check is\
      \ what the chain did while the loop was down."
  , EndpointSite "offchain/rig/capture-loop.sh" ShellConsumer
      "28-05. LOOP-01..05's LIVE half, and the only capture in this directory that HAS NEVER BEEN\
      \ RUN. It stands a fresh rig up, drives one Shock, runs the loop with --once and records the\
      \ watermark either side, every ledger row, the published fixture's digest and the observed\
      \ exit code. It cannot execute today and it refuses by NUMBER rather than skipping: there is\
      \ no deployable emitter of Shock (CHAIN-01, issue #26) and the publication directory is on\
      \ neither tree (LOOP-04, issues #24 and #25). Its artifact,\
      \ offchain/rig/loop-conformance.json, is deliberately ABSENT and the suite asserts that\
      \ absence -- the only form in which \"this evidence does not exist yet\" can itself be\
      \ evidence."
  , EndpointSite "offchain/rig/verify-rig.sh" ShellConsumer
      "SC-2. THE SITE CHAIN-06's LIST OF NINE DOES NOT CONTAIN: fourteen cast calls against a live\
      \ rig, reached through foundry's --rpc-url local alias, so it named neither the variable nor\
      \ the authority and the pattern that found the other nine could not see it."
  , EndpointSite "offchain/rig/deploy-rig.sh" ShellProducer
      "The PRODUCER. Owns anvil: kills the stale listener on the resolved port, starts the chain\
      \ on the resolved host and port, and passes the resolved URL to every forge and cast\
      \ invocation. CHAIN-07 is the half that a consumer-only resolver leaves open."
  , EndpointSite "offchain/spec/types.md" Transcript
      "A pasted RPC transcript kept as evidence. Reads nothing, starts nothing, and is listed so\
      \ the census over offchain/ is CLOSED rather than quietly narrowed around it."
  , EndpointSite "offchain/rig/README.md" Transcript
      "Operator documentation. It names the alias in the commands it tells an operator to run, so\
      \ the census sees it; it executes nothing itself."
  , EndpointSite "offchain/LOOP.md" Transcript
      "The loop's operator manual. It states ETH_RPC_URL and its default in the environment table\
      \ it tells an operator to set, so the census sees it; it executes nothing itself. It was the\
      \ thirty-first instance of prose caught by the pattern, and the first caught by the develop\
      \ gate rather than locally: it was committed after the suite's last run. Declared, as the\
      \ thirty before it were."
  , EndpointSite "offchain/test/Main.hs" Census
      "The suite. Names the resolver in order to assert about it, and is asserted to name none of\
      \ chain_reaching_terms -- README.md's claim that cabal test opens no socket, made\
      \ executable."
  ]

-- | The manifest's paths, in the order it declares them.
site_paths :: [FilePath]
site_paths = map site_path endpoint_sites
