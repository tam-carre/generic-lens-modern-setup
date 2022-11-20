{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DuplicateRecordFields #-}

module UserGroup (User (..), Address (..), Group (..)) where

import GHC.Generics (Generic)

data User
  = User
    { name :: String
    , uid :: Int
    , address :: Address
    }
  deriving (Generic)

data Address
  = Address
    { street :: String
    , city :: String
    }
  deriving (Generic)

data Group =
  Group
    { name :: String
    , gid :: Int
    }
  deriving (Generic)
