module Relation.Equality.Prop where

import Data.Refined.Constant
import Data.Refined.Unit
import Data.Void
import Function
import Language.Haskell.Liquid.ProofCombinators

{-
# Extra definitions to port old code
-}

infixl 3 =~=

(=~=) :: a -> a -> a
_ =~= y = y




-- Hacks with Abstract Refinement to preserve domains 
eqSMT' :: a -> a -> EqualityProp a -> EqualityProp a 
{-@ ignore eqSMT' @-}
{-@ assume eqSMT' :: forall <p :: a -> Bool>.
       x:a<p> -> y:a<p> ->
      EqualProp (a) {x} {y} ->
      EqualProp (a<p>) {x} {y}
@-}
eqSMT' _ _ p = p 


{-@ ignore deqFun @-}
{-@ deqFun :: forall<p :: a -> b -> Bool>. f:(a -> b) -> g:(a -> b)
          -> (x:a -> EqualProp b<p x> {f x} {g x}) -> EqualProp (y:a -> b<p y>) {f} {g}  @-}
deqFun :: (a -> b) -> (a -> b) -> (a -> EqualityProp b) -> EqualityProp (a -> b)
deqFun = extensionality

{-
# END OF Extra definitions to port old code
-}


{-
# Propositional Equality
-}

{-
## Definition
-}

{-@
measure eqprop :: a -> a -> Bool
@-}

data EqualityProp a = EqualityProp

{-@
type EqualProp a X Y = {w:EqualityProp a | eqprop X Y}
@-}

-- NV suggests to keep the below 
{-@
type PEq a X Y = {w:EqualityProp a | eqprop X Y}
@-}




{-@
type NEqualProp a X Y = EqualProp a {X} {Y} -> Void
@-}

assumedProp :: EqualityProp a
assumedProp = EqualityProp

{-
### Axioms
-}

{- 
{-@ assume
reflexivity :: x:a -> EqualProp a {x} {x}
@-}
reflexivity :: a -> EqualityProp a
reflexivity x = EqualityProp
-}


{-@ assume
baseEq :: AEq a => x:a -> y:a -> {v:() | bbEq x y } -> EqualProp a {x} {x}
@-}
baseEq :: a -> a -> () -> EqualityProp a
baseEq _ _ _ = EqualityProp




{-@ assume
extensionality :: f:(a -> b) -> g:(a -> b) -> (x:a -> EqualProp b {f x} {g x}) -> EqualProp (a -> b) {f} {g}
@-}
extensionality :: (a -> b) -> (a -> b) -> (a -> EqualityProp b) -> EqualityProp (a -> b)
extensionality f g pf = EqualityProp

{-@ assume
substitutability :: f:(a -> b) -> x:a -> y:a -> EqualProp a {x} {y} -> EqualProp b {f x} {f y}
@-}
substitutability :: (a -> b) -> a -> a -> EqualityProp a -> EqualityProp b
substitutability f x y pf = EqualityProp


{-@ eqRTCtx :: x:a -> y:a -> EqualProp a {x} {y} -> f:(a -> b) -> EqualProp b {f x} {f y} @-}
eqRTCtx :: a -> a -> EqualityProp a -> (a -> b) -> EqualityProp b
eqRTCtx x y p f = substitutability f x y p 
{-
### Witnesses
-}

{-@ assume
toWitness :: x:a -> y:a -> {_:t | eqprop x y} -> EqualProp a {x} {y}
@-}
toWitness :: a -> a -> t -> EqualityProp a
toWitness x y pf = EqualityProp

{-@
fromWitness :: x:a -> y:a -> EqualProp a {x} {y} -> {_:Proof | eqprop x y}
@-}
fromWitness :: a -> a -> EqualityProp a -> Proof
fromWitness x y pf = trivial

{-
## Properties
-}

{-
### Equality

Combines together the equality properties:
- reflexivity (axiom)
- symmetry
- transitivity
- substitutability
-}

-- TODO: parsing error when I tried to use type synonym
{-@
class Equality a where
  symmetry :: x:a -> y:a -> {_:EqualityProp a | eqprop x y} -> {_:EqualityProp a | eqprop y x}
  transitivity :: x:a -> y:a -> z:a -> EqualProp a {x} {y} -> EqualProp a {y} {z} -> {_:EqualityProp a | eqprop x z} 
  reflexivity  :: x:a -> EqualProp a {x} {x}
@-}
class Equality a where
  symmetry :: a -> a -> EqualityProp a -> EqualityProp a
  transitivity :: a -> a -> a -> EqualityProp a -> EqualityProp a -> EqualityProp a
  reflexivity  :: a -> EqualityProp a 

{-
### SMT Equality
-}

{-@
class EqSMT a where
  eqSMT :: x:a -> y:a -> {b:Bool | ((x = y) => b) && (b => (x = y))}
@-}
class EqSMT a where
  eqSMT :: a -> a -> Bool

instance Eq a => EqSMT a where
  eqSMT = (==)

{-
### Concreteness
-}

{-@
class Concreteness a where
  concreteness :: x:a -> y:a -> EqualProp a {x} {y} -> {_:Proof | x = y}
@-}
class Concreteness a where
  concreteness :: a -> a -> EqualityProp a -> Proof

instance EqSMT a => Concreteness a where
  concreteness x y pf = concreteness_EqSMT x y pf

-- ! why....
{-@ type MyProof = () @-}

{-@ assume
concreteness_EqSMT :: EqSMT a => x:a -> y:a -> EqualProp a {x} {y} -> {_:MyProof | x = y}
@-}
concreteness_EqSMT :: EqSMT a => a -> a -> EqualityProp a -> Proof
concreteness_EqSMT _ _ _ = ()

{-
### Retractability
-}

class Reflexivity a where 
  refl :: a -> EqualityProp a 


{-@
class Reflexivity a where 
  refl :: x:a -> PEq a {x} {x}
@-}

{-@
class Retractability a b where
  retractability :: f:(a -> b) -> g:(a -> b) -> EqualProp (a -> b) {f} {g} -> (x:a -> EqualProp b {f x} {g x})
@-}
class Retractability a b where
  retractability :: (a -> b) -> (a -> b) -> EqualityProp (a -> b) -> (a -> EqualityProp b)

instance Retractability a b where
  retractability f g efg x =
    substitutability (given x) f g efg
      ? (given x (f)) -- instantiate `f x`
      ? (given x (g)) -- instantiate `g x`

{-
### Symmetry'
-}

{-@
class Symmetry a where
  symm :: x:a -> y:a -> EqualProp a {x} {y} -> EqualProp a {y} {x}
@-}
class Symmetry a where
  symm :: a -> a -> EqualityProp a -> EqualityProp a

instance (Concreteness a, Reflexivity a) => Symmetry a where
  symm x y exy =
    refl x ? concreteness x y exy

instance (Symmetry b) => Symmetry (a -> b) where
  symm f g efg =
    let efxgx x = substitutability (given x) f g efg ? (given x f) ? (given x g)
        egxfx x = symm (f x) (g x) (efxgx x)
     in extensionality g f egxfx

{-
### Transitivity'
-}

{-@
class Transitivity a where
  trans :: x:a -> y:a -> z:a -> EqualProp a {x} {y} -> EqualProp a {y} {z} -> EqualProp a {x} {z}
@-}
class Transitivity a where
  trans :: a -> a -> a -> EqualityProp a -> EqualityProp a -> EqualityProp a

instance (Concreteness a, Reflexivity a) => Transitivity a where
  trans x y z exy eyz =
    refl x
      ? concreteness x y exy
      ? concreteness y z eyz

instance (Transitivity b, Retractability a b) => Transitivity (a -> b) where
  trans f g h efg egh =
    let es_fx_gx = retractability f g efg
        es_gx_hx = retractability g h egh
        es_fx_hx x = trans (f x) (g x) (h x) (es_fx_gx x) (es_gx_hx x)
     in extensionality f h es_fx_hx

{-
## Lemmas
-}

{-@
alphaEquivalency :: Equality b => f:(a -> b) -> EqualProp (a -> b) {f} {apply (\x:a -> f x)}
@-}
alphaEquivalency :: Equality b => (a -> b) -> EqualityProp (a -> b)
alphaEquivalency f =
  extensionality f (apply (\x -> f x)) $ \y ->
    reflexivity (f y) ? apply (\x -> f x) y

{-@
etaEquivalency :: Equality b => x:a -> y:b -> EqualProp b {y} {apply (\_:a -> y) x}
@-}
etaEquivalency :: Equality b => a -> b -> EqualityProp b
etaEquivalency x y =
  reflexivity y ? apply (\_ -> y) x

{-
## Basic instances
-}

instance Equality Bool where
  symmetry = undefined
  transitivity = undefined
  reflexivity = undefined 

instance Equality Int where
  symmetry = undefined
  transitivity = undefined
  reflexivity = undefined 

instance Equality () where
  symmetry = undefined
  transitivity = undefined
  reflexivity = undefined 




---------------------------------------------------------------------------------------------------------------------------------------
-- | Axiomatized Equality -------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------------------------------


class AEq a where
  bEq :: a -> a -> Bool
  reflP :: a -> ()
  symmP :: a -> a -> ()
  transP :: a -> a -> a -> ()
  smtP   :: a -> a -> () -> () 


{-@ measure bbEq :: a -> a -> Bool @-}
{-@ class AEq a where
     bEq    :: x:a -> y:a -> {v:Bool | v <=> bbEq x y }
     reflP  :: x:a -> {bbEq x x}
     symmP  :: x:a -> y:a -> { bbEq x y => bbEq y x }
     transP :: x:a -> y:a -> z:a -> { ( bbEq x y && bbEq y z) => bbEq x z }
     smtP   :: x:a -> y:a -> {v:() | bbEq x y} -> {x = y}
@-}

instance Reflexivity Integer where 
  refl x = baseEq x x (reflP x)

instance AEq Integer where
  bEq = bEqInteger
  reflP x = const () (bEqInteger x x)
  symmP x y = () `const` (bEqInteger x y)
  transP x y _ = () `const` (bEqInteger x y)
  smtP x y _ = () `const` (bEqInteger x y)

instance AEq Bool where
  bEq = bEqBool
  reflP x = const () (bEqBool x x)
  symmP x y = () `const` (bEqBool x y)
  transP x y _ = () `const` (bEqBool x y)
  smtP x y _ = () `const` (bEqBool x y)

{-@ assume bEqInteger :: x:Integer -> y:Integer -> {v:Bool | (v <=> bbEq x y) && (v <=> x = y)} @-}
bEqInteger :: Integer -> Integer -> Bool
bEqInteger x y = x == y

{-@ assume bEqBool :: x:Bool -> y:Bool -> {v:Bool | (v <=> bbEq x y) && (v <=> x = y)} @-}
bEqBool :: Bool -> Bool -> Bool
bEqBool x y = x == y