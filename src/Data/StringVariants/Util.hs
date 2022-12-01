{-# LANGUAGE TypeOperators #-}

module Data.StringVariants.Util (useNat, usePositiveNat, textIsWhitespace, textHasNoMeaningfulContent) where

import Data.Proxy
import GHC.TypeLits (KnownNat, OrderingI (..), SomeNat (..), cmpNat, someNatVal, type (<=))
import Prelude
import Data.Text (Text)
import qualified Data.Text as T
import Data.Char (isSpace, isControl)

textIsWhitespace :: Text -> Bool
textIsWhitespace = T.all isSpace

textHasNoMeaningfulContent :: Text -> Bool
textHasNoMeaningfulContent = T.all (\c -> isSpace c || isControl c)

useNat :: Integer -> (forall n proxy. KnownNat n => proxy n -> x) -> x
useNat n f = case someNatVal n of
  Nothing -> error (show n ++ " isn't a valid Nat")
  Just (SomeNat p) -> f p

-- | If the integer is >= 1, evaluate the function with the proof of that. Otherwise, return the default value
usePositiveNat :: Integer -> a -> (forall n proxy. (KnownNat n, 1 <= n) => proxy n -> a) -> a
usePositiveNat n a f = case someNatVal n of
  Nothing -> a
  Just (SomeNat p) -> case cmpNat (Proxy @1) p of
    EQI -> f p
    LTI -> f p
    GTI -> a
