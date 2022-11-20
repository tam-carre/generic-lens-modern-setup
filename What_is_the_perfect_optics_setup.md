# What is the perfect optics setup?

### 1. Terse nested record updates and other optics benefits

There are many benefits to optics, and I am not familiar with nearly all of
them. One of the biggest and most common optics wins, though, must be applying
functions to record fields. Here is an example:

```hs
-- No lens
userWithLastNameUppercased = user { lastname = Text.toUpper $ lastname user } }

-- Lens (with operators)
userWithLastNameUppercased = user & #lastname %~ Text.toUpper

-- Lens (no operators)
userWithLastNameUppercased = over #lastname Text.toUpper user
```

This gets more obvious with even just one level of nesting:
```hs
userWithCountryUppercased = user { address = (address user) { country = Text.toUpper . country $ address user } }
userWithCountryUppercased = user & #address . #country %~ Text.toUpper
userWithCountryUppercased = over (#address . #country) Text.toUpper user
```

### 2. Duplicate field names

When working with varied and complex data, the namespacing problem in Haskell can severely affect code readability. Here's what I mean:

```hs
-- Bad
myCityName = cityName (addressCity (personAddress me))
myDogName  = dogName myDog

-- Good
myCityName = name (city (address me))
myDogName  = name myDog
```

Ideally, we should also be able to name record fields the same as top-level
functions, e.g. (infamously) `id`.

### 2. Optics defined in the same file as the data types

The [original gist](https://gist.github.com/mtesseract/1b69087b0aeeb6ddd7023ff05f7b7e68)
proposes a Template Haskell solution with which you must create all lenses
in the same file. This ends up adding much complexity juggling additional files
you otherwise would not have to. You end up forced to extract out data type declarations out
of `Module` into `Module.Types` (or `Types.Module`) modules to avoid circular dependencies.

**Ideally, optics should be created in the same file as the data type they are for.**

[A package exists ostensibly addressing this problem with the original gist](https://github.com/intolerable/shared-fields), but it is unmaintained and I am not sure what it would take to make it work with newer versions of GHC.

### 3. Un-namespaced raw record fields

Template-Haskell solutions for lens generation rely on record fields being
namespaced with the data type name. For example `personName` instead of `name`, generating a `name` lens. Or `_name`, generating also a `name` lens. However, you still need to deal with those ugly namespaced field names if you want to construct records:

```hs
Dog
  { _name = "Max"
  , _age = 10
  }
```

"Nameless" record construction is still possible but not always readable:

```hs
Dog "Max" 10
```

This lens-only syntax exists but is unsafe as you can forget to initialize
a field and it will compile:

```hs
Dog {}
  & name .~ "Max"
  & age .~ 10
```

Another place where you might deal with the ugly record names is using
RecordWildCards or NamedFieldPuns:

```hs
{-# LANGUAGE RecordWildCards #-}

printDogName (Dog {..}) = putStrLn ("Dog's name is " ++ _name)

mkDog firstname lastname =
  let _name = firstname ++ " " ++ lastname
      _age  = 0
  in Dog {..}

{-# LANGUAGE NamedFieldPuns #-}

printDogAge (Dog { _age }) = putStrLn ("Dog's age is " ++ _age)
```

### 4. Allow for un-namespaced lenses

I want to be able to use lenses like `name` rather than `Lens.name`, `L.name`, `nameL`, or `#name`.

However, this should ideally not pollute the global namespace, e.g. I can both have a lens named `id` as well as the Prelude `id` function.

### 5. Allow for whitespace-free lens composition

A common lens code style is as follows:

```hs
myCityName = me^.address.city.name

meWithUppercasedCityName = me & address.city.name %~ Text.toUpper
```

I would like this style to be allowed in an ideal lens setup.

### 6. Allow for safe multi-constructor record types

One lesser-known win of using lenses is that, combined
with NoFieldSelectors, you can safely define the following datatype:

```hs
data Interaction
  = InteractionChatInput
    { _id :: Int
    , _options :: [Option]
    }
  | InteractionButton
    { _id :: Int
    , _buttonData :: Text
    }

makeFieldsNoPrefix ''Interaction
```

Without `NoFieldSelectors`, `_options` and `_buttonData` would be partial
functions, e.g. `_buttonData (InteractionChatInput 0 [])` would compile, but
crash.

Lens TH functions as well as generic-lens, however, create `options` and `buttonData` as prisms,
allowing for safe access to those fields.
