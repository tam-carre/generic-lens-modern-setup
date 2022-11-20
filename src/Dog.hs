{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE NoFieldSelectors #-}

module Dog (Dog (..)) where

import GHC.Generics (Generic)

data Dog
  = Dog
    { name :: String
    , id :: Int
    }
  deriving (Generic)
