-- | FROZEN golden fixture for the cluster-robust (CR0) sandwich standard errors.
--
-- This module hard-codes a tiny 2-cluster, 3-observation toy panel together with
-- the covariance matrix and standard errors computed BY HAND below. Plan 09-08
-- implements @Model.SandwichSE@ and must reproduce 'expectedV' / 'expectedSE'
-- from ('toyJacobianRows', 'toyResiduals', 'toyClusters') to 1e-9. This file only
-- freezes the truth and proves the harness runs; it contains no estimator code.
--
-- ===========================================================================
--  CR0 cluster-robust sandwich (no finite-sample correction):
--
--    V = (J^T J)^{-1} [ sum_g s_g s_g^T ] (J^T J)^{-1}
--
--  where g indexes tokenId clusters, J_it is the row-gradient d f / d theta at
--  observation (i,t), v_it the residual, and the per-cluster score sum is
--    s_g = sum_{it in g} J_it * v_it   (a length-3 vector).
--
--  Toy panel (theta = [b0, u0, k], so every gradient row has 3 entries):
--
--    obs   cluster   J row (row-gradient)   residual v
--    ---   -------   -------------------    ----------
--     1      "A"       [ 1,  1,  0 ]            2
--     2      "A"       [ 1, -1,  0 ]            1
--     3      "B"       [ 0,  0,  2 ]            3
--
--  The J columns are mutually orthogonal, so the "bread" is diagonal:
--
--    J^T J = diag( 1^2+1^2+0 , 1^2+1^2+0 , 0+0+2^2 ) = diag(2, 2, 4)
--    (J^T J)^{-1}                                     = diag(1/2, 1/2, 1/4) =: A
--
--  Per-cluster score sums:
--
--    s_A = [1,1,0]*2 + [1,-1,0]*1 = [2,2,0] + [1,-1,0] = [3, 1, 0]
--    s_B = [0,0,2]*3                                    = [0, 0, 6]
--
--  Meat  M = s_A s_A^T + s_B s_B^T :
--
--    s_A s_A^T = [[9,3,0],[3,1,0],[0,0,0]]
--    s_B s_B^T = [[0,0,0],[0,0,0],[0,0,36]]
--    M         = [[9,3,0],[3,1,0],[0,0,36]]
--
--  Sandwich  V = A M A.  A is diagonal, so V_ij = A_ii * M_ij * A_jj with
--  A_11 = A_22 = 1/2, A_33 = 1/4:
--
--    V_11 = (1/2)(9)(1/2)  = 9/4  = 2.25
--    V_12 = (1/2)(3)(1/2)  = 3/4  = 0.75      (= V_21)
--    V_22 = (1/2)(1)(1/2)  = 1/4  = 0.25
--    V_13 = (1/2)(0)(1/4)  = 0                (= V_31)
--    V_23 = (1/2)(0)(1/4)  = 0                (= V_32)
--    V_33 = (1/4)(36)(1/4) = 36/16 = 9/4 = 2.25
--
--    V  = [[2.25, 0.75, 0   ],
--          [0.75, 0.25, 0   ],
--          [0   , 0   , 2.25]]
--
--  Standard errors = sqrt of the diagonal:
--
--    SE = [ sqrt 2.25, sqrt 0.25, sqrt 2.25 ] = [1.5, 0.5, 1.5]
-- ===========================================================================
module Golden.SandwichFixture
  ( toyJacobianRows
  , toyResiduals
  , toyClusters
  , expectedV
  , expectedSE
  ) where

import Data.Text (Text)

-- | Row-gradients d f / d theta = [ d/d b0, d/d u0, d/d k ], one row per obs.
toyJacobianRows :: [[Double]]
toyJacobianRows =
  [ [ 1,  1, 0 ]
  , [ 1, -1, 0 ]
  , [ 0,  0, 2 ]
  ]

-- | Residual v_it, one per observation.
toyResiduals :: [Double]
toyResiduals = [2, 1, 3]

-- | tokenId cluster label per observation (cluster "A" has 2 obs, "B" has 1).
toyClusters :: [Text]
toyClusters = ["A", "A", "B"]

-- | Hand-computed 3x3 CR0 cluster-robust covariance V (see header derivation).
expectedV :: [[Double]]
expectedV =
  [ [ 2.25, 0.75, 0.00 ]
  , [ 0.75, 0.25, 0.00 ]
  , [ 0.00, 0.00, 2.25 ]
  ]

-- | Standard errors = sqrt of the diagonal of 'expectedV'.
expectedSE :: [Double]
expectedSE = [1.5, 0.5, 1.5]
