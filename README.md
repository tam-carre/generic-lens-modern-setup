# The modern lens setup

After learning lens essentials, I set out to find the ideal lens setup to deal
with the Haskell record namespacing issue.

One very modern setup as of 2022 is combining `generic-lens`, `DuplicateRecordFields`, `OverloadedRecordDot` and `NoFieldSelectors`.

Here is an exploration of how to use it, what it accomplishes, and what it
doesn't. This guide is appropriate for beginners who are looking to use lenses for the
first time.

This is a followup to the 2017 gist [*Working around Haskell's namespace problem for
records*](https://gist.github.com/mtesseract/1b69087b0aeeb6ddd7023ff05f7b7e68)
which uses Template Haskell and `makeFields/makeFieldsNoPrefix`.

## Feature comparison

Here is a comparison of the TH solution detailed in the [2017 gist](https://gist.github.com/mtesseract/1b69087b0aeeb6ddd7023ff05f7b7e68).

|   | generic-lens | TH |
| - | - | - |
| Optics benefits |✔️ |✔️ |
| Duplicate fields |✔️ |⚠️ (requires centralizing lens declarations)|
| Decentralized optic definitions |✔️ |✔️ |
| Unnamespaced record field names |✔️ |⚠️ (possible with custom TH functions and namespaced lenses) |
| Unnamespaced lenses |⛔ (lenses start with #) |⚠️ (possible but clutter global namespace) |
| Whitespace-free style allowed |⛔ |✔️ |
| Safe multi-constructor record types |✔️ |✔️ |

If you want to know more about what a criterion means, check out [What is
the perfect optics setup?](./What_is_the_perfect_optics_setup.md).

It's possible to mix and mash: use `generic-lens` by default but use TH for safe multi-constructor record types.

## Usage

`generic-lens` must be installed as a dependency as well as `lens`.
`OverloadedRecordDot` is available since GHC 9.2.0, while `NoFieldSelectors`
requires GHC 9.2.1.

This repo demonstrates the bare minimum needed to use this setup. Check out:

- [src/UserGroup.hs](./src/UserGroup.hs) to create record fields/lenses with duplicate record fields (e.g. `User { name :: String }` and `Group { name :: String }`)
- [src/LensDemo.hs](./src/LensDemo.hs) for usage demonstration
- [src/Dog.hs](./src/Dog.hs) exists to demonstrate that duplicate record fields may be used regardless of whether datatypes with duplicate fields or their lenses live in the same module, as well as `NoFieldSelectors` allowing an `id` field.

Or you can read on this section for a more step-by-step walkthrough.

## Data type and lens declarations

Here's the minimum required to create data types and their lenses:

```hs
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
```

You can use duplicate fields globally; it doesn't matter where the data types are declared. For example, here's a separate module also using the `name` field name. We'll also use `NoFieldSelectors` this time to not pollute the top-level namespace and hence allow field names such as `id`.

```hs
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
```

## Setters

First, here's the minimum required to create data types with duplicate fields:

```hs
{-# LANGUAGE DuplicateRecordFields #-}

import Dog (Dog (..))
import UserGroup (User (..), Address (..), Group (..))

myDog :: Dog
myDog = Dog { id = 0, name = "Max" }

me :: User
me = User { uid = 0, name = "Tam", address = myAddress }

myAddress :: Address
myAddress = Address { street = "Abbey Road", city = "London" }

myGroup :: Group
myGroup = Group { gid = 0, name = "Haskellers" }
```

Note that you need to turn on `DuplicateRecordFields` and import the data type
constructors (e.g. `Dog (..)`).

Here's the minimum required to update fields using `generic-lens`:

```hs
{-# LANGUAGE OverloadedLabels #-}

import UserGroup (User (User), Address (Address))
import Control.Lens ((&), (.~), set)
import Data.Generics.Labels ()

me :: User
me = User "Tam" 0 (Address "Abbey Road" "London")

meWithNewName1, meWithNewName2 :: User
meWithNewName1 = set #name "Quattro" me
meWithNewName2 = me & #name .~ "Quattro"
```

We demonstrate operator-style using `.~` as well as function-style using `set`.
Enabling `OverloadedLabels` and importing `Data.Generics.Labels ()` are the two
key parts.

Turning on `DuplicateRecordFields`, it is also possible to use the same label
for different record types, regardless of their provenance:

```hs
{-# LANGUAGE OverloadedLabels #-}
{-# LANGUAGE DuplicateRecordFields #-}

import Dog (Dog (Dog, name))
import UserGroup (Group (Group))
import Control.Lens ((&), (.~))
import Data.Generics.Labels ()

myDog :: Dog
myDog = Dog "Ein" 0

myGroup :: Group
myGroup = Group "Haskellers" 0

myDogWithNewName1, myDogWithNewName2 :: Dog
myDogWithNewName1 = myDog & #name .~ "Ein"

myGroupWithNewName1 :: Group
myGroupWithNewName1 = myGroup & #name .~ "Haskellers 2.0"
```

Update by regular record update syntax is also possible by importing the record fields you use:

```hs
import Dog (Dog (name))

myDogWithNewName2 :: Dog
myDogWithNewName2 = myDog { name = "Ein" }
```

However, this raises a deprecation notice:

```
The record update myDog {name = "Ein"} with type Dog is ambiguous.
This will not be supported by -XDuplicateRecordFields in future releases of GHC. (typecheck -Wambiguous-fields)
```

Updating nested record fields looks like this (demonstrating function-style and
operator-style again):

```hs
meWithNewCity1, meWithNewCity2 :: User
meWithNewCity1 = set (#address . #city) "Yokohama" me
meWithNewCity2 = me & #address . #city .~ "Yokohama"
```

Compare with regular record syntax:

```hs
meWithNewCity3 = me { address = (address me) { city = "Yokohama" } }
```

Once `OverloadedRecordUpdate` is stable and released, we will be able to use this
syntax:

```hs
meWithNewCity4 = me { address.city = "Yokohama" }
```

## Mappers

Applying a function on a record field is where lenses start to really show their
worth:

```hs
meWithUppercasedStreet1, meWithUppercasedStreet2 :: User
meWithUppercasedStreet1 = over (#address . #street) (map toUpper) me
meWithUppercasedStreet2 = me & #address . #street %~ map toUpper
```

Even when data is not nested, the readability gains are considerable. Compare with record syntax style:

```hs
meWithUppercasedStreet3 = me { address = (address me) { city = map toUpper . city $ address me } }
```

## Before we get to getters, a note on whitespace-free style

One downside of using OverloadedLabels is that labels must be surrounded by
whitespace, meaning that this OOP-like syntax used in the ecosystem is not
supported:

```hs
me^.address.street
me & address.street .~ "New Value"
```

Regardless, this style would look weird due to the `#`s. Speaking of the `#`s,
while it is unfortunate that we cannot use lenses un-namespaced (e.g. `name`
instead of `#name`), there exists no solution which allows for lenses to be
un-namespaced without polluting the top-level declaration namespace (e.g.
having an `id` lens that is not ambiguous with `Prelude.id`). I consider
therefore OverloadedLabels to be the best current compromise.

The same whitespace limitation is shared with `OverloadedRecordDot` which requires that `.` be surrounded by whitespace. Therefore, I suggest always enabling `OverloadedRecordDot` when using `generic-lens`. Here's what that looks like:

## Getters

Basic usage:

```hs
myName1, myName2, myName3 :: String
myName1 = view #name me -- function style
myName2 = me ^. #name   -- operator style
myName3 = me.name       -- OverloadedRecordDot style
```

Passing a getter as a function parameter:

```hs
maybeMyStreet1, maybeMyStreet2, maybeMyStreet3 :: Maybe String
maybeMyStreet1 = Just me <&> view (#address . #street)
maybeMyStreet2 = Just me <&> (^. #address . #street)
maybeMyStreet3 = Just me <&> (.address.street)
```

This style is also possible but uses the raw record fields and hence requires
`FieldSelectors` which I don't recommend:

```
maybeMyStreet4 = Just me <&> (street . address)
```

## Sum types and safe multiconstructor record types

When using lenses and `NoFieldSelectors`, you can safely create this kind of
data type:

```hs
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
```

`options` and `buttonData` would normally be unsafe accessor functions
(`buttonData (InteractionChatInput 0 [])` would compile, but crash), but
optics derived from this type are completely safe:

```hs
{-# LANGUAGE TypeApplications #-}
{-# LANGUAGE DataKinds #-}

import Control.Lens ((^?), preview, _2)

myInteraction :: Interaction
myInteraction = InteractionButton 0 "This is a button"

myButtonData1, myButtonData2 :: Maybe String
myButtonData1 = preview (_Ctor @"InteractionButton" . _2) myInteraction
myButtonData2 = myInteraction ^? _Ctor @"InteractionButton" . _2
```

You must first use the prism `_Ctor`, which checks that `myInteraction` is an
`InteractionButton`. When consuming a prism with `^?` or `preview`, a `Maybe` is
returned. note that because `_Ctor` focuses *a tuple of the data constructor's
parameters* instead of a record, `buttonData` is then focused with `_2` rather
than `#buttonData`.

Note: it is slightly terser with `makeFields` TH variants, which allow `myInteraction ^? buttonData` of type `Maybe String`.

## Conclusion

This concludes this overview of using `generic-lens` alongside `DuplicateRecordFields`, `OverloadedRecordDot` and `NoFieldSelectors`. I believe it to be the current best optics setup to handle Haskell's record field namespace issue.

If you are a beginner who still feels confused on how to use lenses, I recommend
[this SPJ talk](https://www.youtube.com/watch?v=k-QwBL9Dia0) for a gentle
introduction to lenses' underlying insights, and [these exercises by William
Yao](https://williamyaoh.com/posts/2019-04-25-lens-exercises.html) to solidify
basic knowledge and become ready to actually use lenses.
