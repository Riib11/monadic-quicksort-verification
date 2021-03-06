module Function where

import Language.Haskell.Liquid.ProofCombinators
import Prelude hiding (flip, map)

--
-- utilities
--

{-@ reflect apply @-}
apply :: (a -> b) -> (a -> b)
apply f = f

{-@ reflect given @-}
given :: a -> (a -> b) -> b
given x f = f x

{-@ reflect map @-}
map :: (a -> b) -> ([a] -> [b])
map f [] = []
map f (x : xs) = f x : map f xs

{-@ reflect flip @-}
flip :: (a -> b -> c) -> (b -> a -> c)
flip f y x = f x y

{-@ reflect constant @-}
constant :: a -> b -> a
constant x _ = x

{-@ reflect diagonalize @-}
diagonalize :: (a -> a -> a) -> (a -> a)
diagonalize f x = f x x

{-@ reflect identity @-}
identity :: a -> a
identity x = x

{-@ reflect compose @-}
compose :: (b -> c) -> (a -> b) -> (a -> c)
compose f g x = f (g x)

--
-- lemmas
--

{-
{-@
apply_if :: f:(a -> b) -> b:Bool -> a1:a -> a2:a -> {_:Proof | f (if b then a1 else a2) = if b then f a1 else f a2}
@-}
apply_if :: (a -> b) -> Bool -> a -> a -> Proof
apply_if = undefined
-}
