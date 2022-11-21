{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE OverloadedRecordDot #-}
{-# LANGUAGE DuplicateRecordFields #-}
{-# LANGUAGE NoFieldSelectors #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DataKinds #-}

module LensDemo where

import Dog (Dog (..))
import UserGroup (User (..), Address (..), Group (..))

import Control.Lens ((^.), (&), (.~), (%~), (^?), view, set, over, preview, _2)
import Data.Char (toUpper)
import Data.Functor ((<&>))
import Data.Generics.Labels () -- necessary to use lenses as #labels
import GHC.Generics (Generic)
import Data.Generics.Sum (AsConstructor(_Ctor))

-- DUMMY DATA

-- Record creation is very clean since we didn't need to prefix the field names with _ or dog
myDog :: Dog
myDog = Dog { id = 0, name = "Max" }

me :: User
me = User { uid = 0, name = "Tam", address = myAddress }

myAddress :: Address
myAddress = Address { street = "Abbey Road", city = "London" }

myGroup :: Group
myGroup = Group { gid = 0, name = "Haskellers" }


-- SETTERS

meWithNewName1, meWithNewName2 :: User
meWithNewName1 = set #name "Quattro" me
meWithNewName2 = me & #name .~ "Quattro"

-- No problem using #name for different data types;
-- DuplicateRecordFields is only needed within modules that
-- declare data types with duplicate record fields, so it is
-- not required in this module if using lenses.

myDogWithNewName1, myDogWithNewName2 :: Dog
myDogWithNewName1 = myDog & #name .~ "Ein"

-- A record update without lenses is possible with DuplicateRecordFields
-- enabled in the field performing the record update; however it raises
-- a deprecation warning
-- ```
-- The record update myDog {name = "Ein"} with type Dog is ambiguous.
-- This will not be supported by -XDuplicateRecordFields in future releases of GHC. (typecheck -Wambiguous-fields)
-- ```
myDogWithNewName2 = myDog { name = "Ein" }

myGroupWithNewName1 :: Group
myGroupWithNewName1 = myGroup & #name .~ "Haskellers 2.0"

-- Nested field update
meWithNewCity1, meWithNewCity2 :: User
meWithNewCity1 = set (#address . #city) "Yokohama" me
meWithNewCity2 = me & #address . #city .~ "Yokohama"

-- Reminder: without lenses, this would suck:
-- meWithNewCity3 = me { address = (address me) { city = "Yokohama" } }

-- Eventually we'll be able to do this with OverloadedRecordUpdate, but not yet:
-- meWithNewCity4 = me { address.city = "Yokohama" }


-- MAPPERS

meWithUppercasedStreet1, meWithUppercasedStreet2 :: User
meWithUppercasedStreet1 = over (#address . #street) (map toUpper) me
meWithUppercasedStreet2 = me & #address . #street %~ map toUpper

-- Reminder: without lenses, this would suck big time:
-- meWithUppercasedStreet' =
--   me { address = (address me) { city = map toUpper . city $ address me } }


{- Unfortunately, overloaded labels (`#fieldname`) must be surrounded by spaces.
  meWithNewCity' = me & #address.#city .~ "Rome" -- ERROR (ambiguous with (.#))

  Therefore, when using OverloadedLabels it is never possible to use
  whitespace-free lens composition e.g the following styles cannot be used:
  - record^.lens1.lens2
  - record & lens1.lens2 .~ val

  It is therefore recommended to always use OverloadedRecordDot, since
  the only drawback of enabling it is it also makes whitespace-free
  composition impossible.

  We will see in this next section how to use OverlodedRecordDot
-}


-- GETTERS

myName1, myName2, myName3 :: String
myName1 = view #name me
myName2 = me ^. #name
myName3 = me.name

-- OverloadedRecordDot accessor function syntax
maybeMyStreet1, maybeMyStreet2, maybeMyStreet3, maybeMyStreet4 :: Maybe String
maybeMyStreet1 = Just me <&> view (#address . #street)
maybeMyStreet2 = Just me <&> (^. #address . #street)
maybeMyStreet3 = Just me <&> (.address.street)
-- Discouraged: requires FieldSelectors in declaring file
maybeMyStreet4 = Just me <&> (street . address)


-- NAMESPACE POLLUTION

-- We've already seen that records may contain duplicate field names,
-- whether in the same module or in different modules. You can go further
-- and prevent record field names from polluting the top level function
-- namespace by enabling NoFieldSelectors in the file where
-- the data type is declared. For example, because Dog.hs has NoFieldSelectors
-- enabled, both of those expressions can be used in this file with
-- no ambiguity error:

myDogId :: Int
myDogId = myDog.id

-- Note how this evaluates to a Dog, not an Int
myDog' :: Dog
myDog' = id myDog


-- SAFE MULTI-CONSTRUCTOR RECORD TYPES

-- With NoFieldSelectors enabled, this is safe because
-- partial functions `options` and `buttonData` are not created
data Interaction
  = InteractionChatInput
    { id :: Int
    , options :: [String]
    }
  | InteractionButton
    { id :: Int
    , buttonData :: String
    }
  deriving (Generic)

myInteraction :: Interaction
myInteraction = InteractionButton 0 "This is a button"

myButtonData1, myButtonData2 :: Maybe String
myButtonData1 = preview (_Ctor @"InteractionButton" . _2) myInteraction
myButtonData2 = myInteraction ^? #_InteractionButton . _2
