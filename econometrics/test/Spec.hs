-- | Test entry point for @stack test econometrics:test:unit@.
--
-- For now this proves the hspec harness runs and that the frozen sandwich-SE
-- golden fixture is internally consistent (dimensions line up; SE = sqrt diag V).
-- The actual @Model.SandwichSE@ implementation is built and checked against this
-- fixture in plan 09-08.
module Main (main) where

import Test.Hspec
import qualified Golden.SandwichFixture as F
import qualified Panel.BuildSpec
import qualified Panel.VarianceSpec
import qualified Model.UpsilonSpec
import qualified Model.NLSSpec
import qualified Model.SandwichSpec
import qualified Tests.SpecificationSpec
import qualified AlternativesSpec

-- | Diagonal of a square matrix given as a list of rows.
diagonal :: [[Double]] -> [Double]
diagonal rows = [ (rows !! i) !! i | i <- [0 .. length rows - 1] ]

main :: IO ()
main = hspec $ do
  Panel.BuildSpec.spec
  Panel.VarianceSpec.spec
  Model.UpsilonSpec.spec
  Model.NLSSpec.spec
  Model.SandwichSpec.spec
  Tests.SpecificationSpec.spec
  AlternativesSpec.spec
  describe "sandwich golden fixture" $ do
    it "has matching obs counts across J rows, residuals, and clusters" $ do
      length F.toyJacobianRows `shouldBe` 3
      length F.toyResiduals    `shouldBe` length F.toyJacobianRows
      length F.toyClusters     `shouldBe` length F.toyJacobianRows

    it "every Jacobian row is a 3-parameter gradient" $
      map length F.toyJacobianRows `shouldBe` [3, 3, 3]

    it "expectedV is 3x3" $ do
      length F.expectedV `shouldBe` 3
      map length F.expectedV `shouldBe` [3, 3, 3]

    it "expectedSE equals sqrt of the diagonal of expectedV" $
      F.expectedSE `shouldBe` map sqrt (diagonal F.expectedV)
