{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}

{-@ LIQUID "--compile-spec" @-}

module Placeholder.M where

-- import qualified Control.Refined.Monad as Monad
-- import qualified Control.Refined.Monad.Array as Array
-- import qualified Control.Refined.Monad.Plus as Plus

import Data.Refined.List
import Data.Refined.Natural
import Data.Refined.Unit
import Function
import Language.Haskell.Liquid.ProofCombinators
import Language.Haskell.TH
import Language.Haskell.TH.Syntax
import Relation.Equality.Prop
import Relation.Equality.Prop.EDSL
import Prelude hiding (Monad, length, pure, read, readList, seq, (+), (++), (>>), (>>=))

{-
# Synonyms
-}

{-@ reflect leq @-}
leq :: Int -> Int -> Bool
leq x y = x <= y

{-@ reflect geq @-}
geq :: Int -> Int -> Bool
geq x y = y <= x

{-
# M
-}

-- instances: Monad M, Plus M, Array M Int
data M :: * -> * where
  Pure :: a -> M a
  Bind :: M a -> (a -> M b) -> M b
  Epsilon :: M a
  Plus :: M a -> M a -> M a
  Read :: Natural -> M Int
  Write :: Natural -> Int -> M ()

-- TODO
-- interpretM :: Monad m -> Plus m -> Array m a -> m a -> m a
-- interpretM _ pls ary _m = undefined

{-
## Monad interface
-}

-- monad methods

{-@ reflect pure @-}
pure :: a -> M a
pure = Pure

{-@ reflect bind @-}
bind :: M a -> (a -> M b) -> M b
bind = Bind

{-@ infixl 1 >>= @-}
infixl 1 >>=

{-@ reflect >>= @-}
(>>=) :: M a -> (a -> M b) -> M b
(>>=) = Bind

-- monad functions

{-@ reflect seq @-}
seq :: M a -> M b -> M b
seq ma mb = ma >>= constant mb

{-@ infixl 1 >> @-}
infixl 1 >>

{-@ reflect >> @-}
(>>) :: M a -> M b -> M b
(>>) = seq

{-@ reflect kleisli @-}
kleisli :: (a -> M b) -> (b -> M c) -> (a -> M c)
kleisli k1 k2 x = k1 x >>= k2

{-@ infixr 1 >=> @-}
infixr 1 >=>

{-@ reflect >=> @-}
(>=>) :: (a -> M b) -> (b -> M c) -> (a -> M c)
(>=>) = kleisli

{-@ reflect join @-}
join :: M (M a) -> M a
join mm = mm >>= identity

{-@ reflect liftM @-}
liftM :: (a -> b) -> (M a -> M b)
liftM f m = m >>= \x -> pure (f x)

{-@ reflect liftM2 @-}
liftM2 :: (a -> b -> c) -> (M a -> M b -> M c)
liftM2 f ma mb = ma >>= \x -> mb >>= \y -> pure (f x y)

{-@ reflect second @-}
second :: (b -> M c) -> (a, b) -> M (a, c)
second k (x, y) = k y >>= \y' -> pure (x, y')

-- monad laws

{-@
assume
bind_identity_left :: x:a -> k:(a -> M b) -> EqualProp (M b) {pure x >>= k} {k x}
@-}
bind_identity_left :: a -> (a -> M b) -> EqualityProp (M b)
bind_identity_left _ _ = trivialProp

{-@
assume
bind_identity_right :: m:M a -> EqualProp (M a) {m >>= pure} {m}
@-}
bind_identity_right :: M a -> EqualityProp (M a)
bind_identity_right _ = trivialProp

{-@
assume
bind_associativity :: m:M a -> k1:(a -> M b) -> k2:(b -> M c) -> EqualProp (M c) {(m >>= k1) >>= k2} {m >>= (k1 >=> k2)}
@-}
bind_associativity :: M a -> (a -> M b) -> (b -> M c) -> EqualityProp (M c)
bind_associativity _ _ _ = trivialProp

-- monad lemmas

{-@
seq_associativity ::
  Equality (M c) => ma:M a -> mb:M b -> mc:M c -> EqualProp (M c) {(ma >> mb) >> mc} {ma >> mb >> mc}
@-}
seq_associativity ::
  Equality (M c) => M a -> M b -> M c -> EqualityProp (M c)
seq_associativity ma mb mc =
  [eqpropchain|
      (ma >> mb) >> mc 
    %==
      (ma >>= constant mb) >> mc
    %==
      (ma >>= constant mb) >>= constant mc
        %by undefined %-- TODO: smt crash: invalid qualiied identifier, sort mismatch
    %==
      ma >>= (constant mb >=> constant mc)
        %by bind_associativity ma (constant mb) (constant mc)
    %==
      ma >>= (\x -> (constant mb x >>= constant mc))
    %==
      ma >>= (\x -> (mb >>= constant mc))
        %by %rewrite (\x -> (constant mb x >>= constant mc)) 
                 %to (\x -> (mb >>= constant mc))
        %by %extend x
        %by %reflexivity
    %==
      ma >>= constant (mb >>= constant mc)
        %by %rewrite \x -> (mb >>= constant mc)
                 %to constant (mb >>= constant mc)
        %by %extend x 
        %by %reflexivity
    %==
      ma >> (mb >>= constant mc)
    %==
      ma >> mb >> mc 
  |]

-- TODO: other monad lemmas

{-
## Plus interface
-}

-- plus methods

{-@ reflect epsilon @-}
epsilon :: M a
epsilon = Epsilon

{-@ reflect plus @-}
plus :: M a -> M a -> M a
plus = Plus

{-@ infixl 3 <+> @-}
infixl 3 <+>

{-@ reflect <+> @-}
(<+>) :: M a -> M a -> M a
(<+>) = plus

-- plus functions

{-@ reflect plusF @-}
plusF :: (a -> M b) -> (a -> M b) -> (a -> M b)
plusF k1 k2 x = k1 x <+> k2 x

{-@ reflect guard @-}
guard :: Bool -> M ()
guard b = if b then pure () else epsilon

{-@ reflect guardBy @-}
guardBy :: (a -> Bool) -> a -> M a
guardBy p x = guard (p x) >> pure x

-- plus laws

{-@
assume
plus_identity_left :: m:M a -> EqualProp (M a) {epsilon <+> m} {m}
@-}
plus_identity_left :: M a -> EqualityProp (M a)
plus_identity_left _ = trivialProp

{-@
assume
plus_distributivity_left :: m1:M a -> m2:M a -> k:(a -> M b) -> EqualProp (M b) {(m1 <+> m2) >>= k} {(m1 >>= k) <+> (m2 >>= k)}
@-}
plus_distributivity_left :: M a -> M a -> (a -> M b) -> EqualityProp (M b)
plus_distributivity_left _ _ _ = trivialProp

{-@ reflect plus_distributivity_right_aux @-}
plus_distributivity_right_aux :: (a -> M b) -> (a -> M b) -> a -> M b
plus_distributivity_right_aux k1 k2 x = k1 x <+> k2 x

{-@
assume
plus_distributivity_right :: m:M a -> k1:(a -> M b) -> k2:(a -> M b) -> EqualProp (M b) {m >>= plus_distributivity_right_aux k1 k2} {(m >>= k1) <+> (m >>= k2)}
@-}
plus_distributivity_right :: M a -> (a -> M b) -> (a -> M b) -> EqualityProp (M b)
plus_distributivity_right _ _ _ = trivialProp

{-@
assume
bind_zero_left :: k:(a -> M b) -> EqualProp (M b) {epsilon >>= k} {epsilon}
@-}
bind_zero_left :: (a -> M b) -> EqualityProp (M b)
bind_zero_left _ = trivialProp

{-@
assume
bind_zero_right :: m:M a -> EqualProp (M b) {m >> epsilon} {epsilon}
@-}
bind_zero_right :: M a -> EqualityProp (M b)
bind_zero_right _ = trivialProp

-- plus lemmas

{-@
type RefinesPlus a M1 M2 = EqualProp (M a) {plus M1 M2} {M2}
@-}

{-@
type RefinesPlusF a b K1 K2 = x:a -> EqualProp (M b) {plus (K1 x) (K2 x)} {K2 x}
@-}

{-@
refinesplus_reflexivity :: Equality (M a) => m:M a -> RefinesPlus a {m} {m}
@-}
refinesplus_reflexivity :: Equality (M a) => M a -> EqualityProp (M a)
refinesplus_reflexivity m =
  [eqpropchain|
      m <+> m
    %==
      m 
        %by undefined 
        %-- TODO: not sure...
  |]

-- TODO: other lemmas about RefinesPlus

{-
## Array interface
-}

-- array methods

{-@ reflect read @-}
read :: Natural -> M Int
read = Read

{-@ reflect write @-}
write :: Natural -> Int -> M ()
write = Write

-- array methods

-- TODO

{-@ reflect readList @-}
readList :: Natural -> Natural -> M (List Int)
readList i Z = pure Nil
readList i (S n) = liftM2 Cons (read i) (readList (S i) n)

{-@ reflect writeList @-}
writeList :: Natural -> List Int -> M ()
writeList i Nil = pure it
writeList i (Cons x xs) = write i x >> writeList (S i) xs

{-@ reflect writeListToLength @-}
writeListToLength :: Natural -> List Int -> M Natural
writeListToLength i xs = writeList i xs >> pure (length xs)

{-@ reflect writeListToLength2 @-}
writeListToLength2 :: Natural -> (List Int, List Int) -> M (Natural, Natural)
writeListToLength2 i (xs, ys) = writeList i (xs ++ ys) >> pure (length xs, length ys)

{-@ reflect writeListToLength3 @-}
writeListToLength3 :: Natural -> (List Int, List Int, List Int) -> M (Natural, Natural, Natural)
writeListToLength3 i (xs, ys, zs) = writeList i (xs ++ ys ++ zs) >> pure (length xs, length ys, length zs)

{-@ reflect swap @-}
swap :: Natural -> Natural -> M ()
swap i j = read i >>= \x -> read j >>= \y -> write i y >> write j x

-- array laws

{-@
assume
bind_read_write :: i:Natural -> EqualProp (m ()) {read i >>= write i} {pure it}
@-}
bind_read_write :: Natural -> EqualityProp (m ())
bind_read_write _ = trivialProp

{-@
assume
seq_write_read :: i:Natural -> x:Int -> EqualProp (m Int) {write i x >> read i} {write i x >> pure x}
@-}
seq_write_read :: Natural -> Int -> EqualityProp (m Int)
seq_write_read _ _ = trivialProp

{-@
assume
seq_write_write :: i:Natural -> x:Int -> y:Int -> EqualProp (m Unit) {write i x >> write i y} {write i y}
@-}
seq_write_write :: Natural -> Int -> Int -> EqualityProp (m Unit)
seq_write_write _ _ _ = trivialProp

{-@
assume
liftM_read :: i:Natural -> f:(Int -> Int -> Int) -> EqualProp (M Int) {liftM2 f (read i) (read i)} {liftM (diagonalize f) (read i)}
@-}
liftM_read :: Natural -> (Int -> Int -> Int) -> EqualityProp (M Int)
liftM_read _ _ = trivialProp

{-@
assume
seq_commutativity_write :: i:Natural -> j:{j:Natural | i /= j} -> x:Int -> y:Int -> EqualProp (M Unit) {write i x >> write j y} {write j y >> write i x}
@-}
seq_commutativity_write :: Natural -> Natural -> Int -> Int -> EqualityProp (M ())
seq_commutativity_write _ _ _ _ = trivialProp

{-@
assume
seq_associativity_write :: i:Natural -> j:{j:Natural | i /= j} -> x:Int -> y:Int -> EqualProp (m Unit) {(read i >> pure it) >> write j x} {write j x >> (read i >> pure it)}
@-}
seq_associativity_write :: Natural -> Natural -> Int -> Int -> EqualityProp (m Unit)
seq_associativity_write _ _ _ _ = trivialProp

-- array lemmas

{-@
writeList_append :: i:Natural -> xs:List Int -> ys:List Int -> EqualProp (M Unit) {writeList i (append xs ys)} {writeList i xs >> writeList (add i (length xs)) ys}
@-}
writeList_append :: Natural -> List Int -> List Int -> EqualityProp (M ())
writeList_append = undefined -- TODO: migrate proof from Control.Monad.Array