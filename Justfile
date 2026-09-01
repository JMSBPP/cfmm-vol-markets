
plank file:
    plank build {{file}} \
      --dep v3=lib/plankified-univ3/plank/lib/ \
      --dep std=lib/plank-monorepo/std/ \
      --dep lib=src/lib \
      --dep types=src/types \
      --dep interfaces=src/interfaces \
      --backend sona
