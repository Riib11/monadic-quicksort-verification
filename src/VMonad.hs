module VMonad where

import           Liquid.ProofCombinators
import           VFunctor
import           Function
import           VUnit


-- Data Class. A monad is a TODO.
{-@
data VMonad m = VMonad
  { iFunctor :: VFunctor m
  , vlift :: forall a . a -> m a
  , vbind :: forall a b . m a -> (a -> m b) -> m b
  , vbind_correct :: forall a b . m:m a -> f:(a -> b) ->
      {vbind m (vcomp vlift f) = vmap iFunctor f m}
  , vbind_identity :: forall a . m:m a ->
      {vbind m vlift = m}
  , vbind_vlift :: forall a b . k:(a -> m b) -> x:a ->
      {vbind (vlift x) k = k x}
  , vbind_vbind :: forall a b c . m:m a -> k1:(a -> m b) -> k2:(b -> m c) ->
      {vbind (vbind m k1) k2 = vbind m (raw_kleisli vbind k1 k2)}
  }
@-}
data VMonad m = VMonad
  { iFunctor :: VFunctor m
  , vlift :: forall a . a -> m a
  , vbind :: forall a b . m a -> (a -> m b) -> m b
  , vbind_correct :: forall a b . m a -> (a -> b) -> Proof
  , vbind_identity :: forall a . m a -> Proof
  , vbind_vlift :: forall a b . (a -> m b) -> a -> Proof
  , vbind_vbind :: forall a b c . m a -> (a -> m b) -> (b -> m c) -> Proof
  }


-- Function.
{-@ reflect raw_kleisli @-}
raw_kleisli
  :: forall m a b c
   . (forall a b . m a -> (a -> m b) -> m b) -- vbind
  -> (a -> m b)
  -> (b -> m c)
  -> (a -> m c)
raw_kleisli raw_vbind f g x = raw_vbind (f x) g


-- Function.
{-@ reflect kleisli @-}
kleisli
  :: forall m a b c
   . VMonad m
  -> (a -> m b)
  -> (b -> m c)
  -> (a -> m c)
kleisli iMonad = raw_kleisli (vbind iMonad)


-- Lemma. Function.
{-@ reflect vseq @-}
vseq :: forall m a b . VMonad m -> m a -> m b -> m b
vseq iMonad m1 m2 = (vbind iMonad) m1 (vconst m2)


-- Term.
{-@ reflect vseq_epsilon @-}
vseq_epsilon :: forall m . VMonad m -> m VUnit
vseq_epsilon iMonad = vlift iMonad vunit


-- Lemma.
{-@
vseq_identity_left :: forall m . iMonad:VMonad m -> m:m VUnit ->
  {IsIdentityLeft (vseq iMonad) (vseq_epsilon iMonad) m}
@-}
vseq_identity_left :: forall m . VMonad m -> m VUnit -> Proof
vseq_identity_left iMonad m =
  vseq_ vseq_epsilon_ m
    ==. vbind_ (vlift_ vunit) (vconst m)
    ==. vconst m vunit
    ?   vbind_vlift_ (vconst m) vunit
    ==. m
    *** QED
 where
  vseq_         = vseq iMonad
  vseq_epsilon_ = vseq_epsilon iMonad
  vbind_        = vbind iMonad
  vlift_        = vlift iMonad
  vbind_vlift_  = vbind_vlift iMonad


-- Lemma
{-@
assume vseq_identity_right :: forall m a . iMonad:VMonad m -> m:m VUnit ->
  {IsIdentityRight (vseq iMonad) (vseq_epsilon iMonad) m}
@-}
vseq_identity_right :: forall m a . VMonad m -> m VUnit -> Proof
vseq_identity_right iMonad m = ()
 --  vseq_ m vseq_epsilon_
 --    ==. vbind_ m (vconst vseq_epsilon_)
 --    ==. vbind_ m (vconst (vlift_ vunit))
 --    ==. vbind_ m (\() -> vlift_ ())
 --    ==. vbind_ m vlift_
 --    ==. m
 --    ?   vbind_identity_ m
 --    *** QED
 -- where
 --  vseq_           = vseq iMonad
 --  vseq_epsilon_   = vseq_epsilon iMonad
 --  vbind_          = vbind iMonad
 --  vlift_          = vlift iMonad
 --  vbind_identity_ = vbind_identity iMonad


-- Lemma.
{-@
assume vseq_identity :: forall m a . iMonad:VMonad m -> m:m VUnit ->
  {IsIdentity (vseq iMonad) (vseq_epsilon iMonad) m}
@-}
vseq_identity :: forall m a . VMonad m -> m VUnit -> Proof
vseq_identity iMonad m =
  let _ = vseq_identity_left iMonad m
      _ = vseq_identity_right iMonad m
  in  ()


-- Function.
{-@ reflect vliftF @-}
vliftF :: forall m a b . VMonad m -> (a -> b) -> m a -> m b
vliftF iMonad f m = vbind' m (\x -> vlift' (f x))
 where
  vlift' = vlift iMonad
  vbind' = vbind iMonad


-- Function.
{-@ reflect vliftF2 @-}
vliftF2
  :: forall m a b c . VMonad m -> (a -> b -> c) -> m a -> m b -> m c
vliftF2 iMonad f ma mb = vbind'
  ma
  (\x -> vbind' mb (\y -> vlift' (f x y)))
 where
  vlift' = vlift iMonad
  vbind' = vbind iMonad


-- Predicate. Commutativity for monads.
{-@ predicate IsMCommutative IMON M1 M2 F =
      vliftF2 IMON F M1 M2 = vliftF2 IMON (vflip F) M2 M1 @-}