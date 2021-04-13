module Data.Refined.Bool where

import Prelude hiding (not)

{-@ reflect not @-}
not :: Bool -> Bool
not True = False
not False = True

{-@ reflect branch @-}
branch :: Bool -> a -> a -> a
branch True a1 _ = a1
branch False _ a2 = a2
