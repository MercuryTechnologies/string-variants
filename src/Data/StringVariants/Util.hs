module Data.StringVariants.Util (natOfLength, useNat, textIsWhitespace, textHasNoMeaningfulContent) where
import GHC.TypeLits (KnownNat, Nat, SomeNat (..), someNatVal)
import Prelude
import Data.Text (Text)
import qualified Data.Text as T
import Data.Char (isSpace, isControl)

textIsWhitespace :: Text -> Bool
textIsWhitespace = T.all isSpace

textHasNoMeaningfulContent :: Text -> Bool
textHasNoMeaningfulContent = T.all (\c -> isSpace c || isControl c)


natOfLength :: proxy (n :: Nat) -> f (other n) -> f (other n)
natOfLength _ = id

useNat :: Integer -> (forall n proxy. KnownNat n => proxy n -> x) -> x
useNat n f = case someNatVal n of
  Nothing -> error (show n ++ " isn't a valid Nat")
  Just (SomeNat p) -> f p

