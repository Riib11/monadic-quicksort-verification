module Relation.Equality.PropBlind where

import Function
import Language.Haskell.Liquid.ProofCombinators

-- TODO: experimental
-- {-
-- ## Blind inferences

-- Since a proof term refined by a propositional equality predicate can be
-- converted to and from a witness, we can write versions of the inference rules
-- above that only use refinement logic and ignore witnesses. By not keeping track
-- of (trivial) witnesses, these inferences are "blind".
-- -}

{-
## Definition
-}

{-@
measure eqprop :: a -> a -> Bool
@-}

-- {-@
-- type EqualProp X Y = {_:Proof | eqprop X Y}
-- @-}

{-@
type EqualProp a X Y = {v:a | eqprop X Y && v = Y}
@-}

{-@ assume
reflexivity :: x:a -> EqualProp a {x} {x}
@-}
reflexivity :: a -> a
reflexivity x = x

{-@ assume
extensionality :: f:(a -> b) -> g:(a -> b) -> (x:a -> EqualProp b {f x} {g x}) -> EqualProp (a -> b) {f} {g}
@-}
extensionality :: (a -> b) -> (a -> b) -> (a -> b) -> (a -> b)
extensionality _ g _ = g

{-@ assume
substitutability :: x:a -> {y:a | eqprop x y} -> f:(a -> b) -> EqualProp b {f x} {f y}
@-}
substitutability :: a -> a -> (a -> b) -> b
substitutability _ y f = f y

{-
## Concreteness
-}

{-@
class EqSMT a where
  eqSMT :: x:a -> y:a -> {b:Bool | ((x = y) => b) && (b => (x = y))}
@-}
class EqSMT a where
  eqSMT :: a -> a -> Bool

{-@
class Concreteness a where
  concreteness :: x:a -> {y:a | eqprop x y} -> {x = y}
@-}
class Concreteness a where
  concreteness :: a -> a -> Proof

instance EqSMT a => Concreteness a where
  concreteness x y = concreteness_EqSMT x y

{-@ assume
concreteness_EqSMT :: EqSMT a => x:a -> {y:a | eqprop x y} -> {x = y}
@-}
concreteness_EqSMT :: EqSMT a => a -> a -> Proof
concreteness_EqSMT _ _ = ()

{-
## Properties
-}

{-@
retractability :: f:(a -> b) -> {g:(a -> b) | eqprop f g} -> x:a -> EqualProp b {f x} {g x}
@-}
retractability :: (a -> b) -> (a -> b) -> a -> b
retractability f g x =
  substitutability f g (given x)
    ? given x f
    ? given x g

{-@
class Symmetry a where
  symmetry :: x:a -> {y:a | eqprop x y} -> EqualProp a {y} {x}
@-}
class Symmetry a where
  symmetry :: a -> a -> a

-- instance

-- {-
-- OLD
-- -}

-- {-@
-- fromSMT' :: x:a -> y:a -> {_:Proof | x = y} -> {_:Proof | eqprop x y}
-- @-}
-- fromSMT' :: a -> a -> Proof -> Proof
-- fromSMT' x y e_x_y = fromWitness x y $ fromSMT x y e_x_y

-- {-@
-- extensionality' :: f:(a -> b) -> g:(a -> b) -> (x:a -> {_:Proof | eqprop (f x) (g x)}) -> {_:Proof | eqprop f g}
-- @-}
-- extensionality' :: (a -> b) -> (a -> b) -> (a -> Proof) -> Proof
-- extensionality' f g ep_fx_gx = fromWitness f g $ extensionality f g $ \x -> toWitness (f x) (g x) (ep_fx_gx x) ? f x ? g x

-- -- TODO: why does `ep_x_y` not work in place of `undefined`?
-- {-@
-- substitutability' :: forall a b. x:a -> y:a -> f:(a -> b) -> {_:Proof | eqprop x y} -> {_:Proof | eqprop (f x) (f y)}
-- @-}
-- substitutability' :: forall a b. a -> a -> (a -> b) -> Proof -> Proof
-- substitutability' x y f ep_x_y =
--   ( (fromWitness (f x) (f y))
--       ( (substitutability x y f (toWitness x y undefined))
--           ? (f x)
--           ? (f y)
--       )
--   )
--     ? f x
--     ? f y

-- {-@
-- concreteness' :: Concreteness a => x:a -> y:a -> {_:Proof | eqprop x y} -> {_:Proof | x = y}
-- @-}
-- concreteness' :: Concreteness a => a -> a -> Proof -> Proof
-- concreteness' x y ep_x_y = concreteness x y (toWitness x y ep_x_y)

-- {-@
-- retractability' :: Retractability a b => f:(a -> b) -> g:(a -> b) -> {_:Proof | eqprop f g} -> (x:a -> {_:Proof | eqprop (f x) (g x)})
-- @-}
-- retractability' :: Retractability a b => (a -> b) -> (a -> b) -> Proof -> (a -> Proof)
-- retractability' f g ep_f_g x = fromWitness (f x) (g x) $ retractability f g (toWitness f g ep_f_g) x

-- {-@
-- reflexivity' :: Reflexivity a => x:a -> {_:Proof | eqprop x x}
-- @-}
-- reflexivity' :: Reflexivity a => a -> Proof
-- reflexivity' x = fromWitness x x $ reflexivity x

-- {-@
-- symmetry' :: Symmetry a => x:a -> y:a -> {_:Proof | eqprop x y} -> {_:Proof | eqprop y x}
-- @-}
-- symmetry' :: Symmetry a => a -> a -> Proof -> Proof
-- symmetry' x y ep_x_y = fromWitness y x $ symmetry x y (toWitness x y ep_x_y)

-- {-@
-- transitivity' :: Transitivity a => x:a -> y:a -> z:a -> {_:Proof | eqprop x y} -> {_:Proof | eqprop y z} -> {_:Proof | eqprop x z}
-- @-}
-- transitivity' :: Transitivity a => a -> a -> a -> Proof -> Proof -> Proof
-- transitivity' x y z ep_x_y ep_y_z = fromWitness x z $ transitivity x y z (toWitness x y ep_x_y) (toWitness y z ep_y_z)

-- {-
-- ## Utilities
-- -}

-- infixl 3 =~=

-- {-@
-- (=~=) :: Equality a => x:a -> {y:a | eqprop x y} -> {z:a | eqprop x z && eqprop z y}
-- @-}
-- (=~=) :: Equality a => a -> a -> a
-- _ =~= y = y `withProof` toWitness (reflexivity y)

-- -- TODO: reduntant with (?)
-- -- infixl 4 ?~

-- -- {-@
-- -- (?~) :: forall a b <p :: a -> Bool, q :: b -> Bool>. a<p> -> b<q> -> a<p>
-- -- @-}
-- -- (?~) :: a -> b -> a
-- -- x ?~ wit = x `withProof` wit

-- -- examples

-- {-@
-- test1 :: Equality a => x:a -> EqualProp a {x} {x}
-- @-}
-- test1 :: Equality a => a -> EqualityProp a
-- test1 x =
--   toWitness x x $
--     x
--       === x ? reflexivity x
--       *** QED

-- -- TODO: fail
-- {-@ fail test2 @-}
-- {-@
-- test2 :: Equality a => x:a -> y:a -> z:a -> EqualProp a {x} {y} -> EqualProp a {y} {z} -> EqualProp a {x} {z}
-- @-}
-- test2 :: Equality a => a -> a -> a -> EqualityProp a -> EqualityProp a -> EqualityProp a
-- test2 x y z ep_x_y ep_y_z =
--   toWitness x z $
--     x
--       =~= y ? ep_x_y
--       =~= z ? ep_y_z
--       *** QED
