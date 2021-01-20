module VIdentity where

import Function
import Language.Haskell.Liquid.ProofCombinators
import Relation
import VFunctor
import VMonad

-- Data. The identity functor trivially wraps a type with its single
-- constructor.
{-@
data VIdentity a = VIdentity a
@-}
data VIdentity a = VIdentity a

{-@ reflect vmapF_VIdentity @-}
vmapF_VIdentity ::
  forall a b. (a -> b) -> (VIdentity a -> VIdentity b)
vmapF_VIdentity f (VIdentity x) = VIdentity (f x)

-- TODO: prove
-- {-@ automatic-instances vmapF_vid_VIdentity @-}
{-@
assume vmapF_vid_VIdentity :: forall a. x:VIdentity a ->
  {vmapF_VIdentity vid x = vid x}
@-}
vmapF_vid_VIdentity :: forall a. VIdentity a -> Proof
vmapF_vid_VIdentity _ = ()

-- TODO: prove that VIdentity is a VFunctor
-- -- TODO: why does vmapF_vid_VIdentity need to be qualified?
-- {-@ reflect iFunctor_VIdentity @-}
-- iFunctor_VIdentity :: VFunctor VIdentity
-- iFunctor_VIdentity =
--   VFunctor {vmapF = vmapF_VIdentity, vmapF_vid = VIdentity.vmapF_vid_VIdentity}

-- {-@ reflect vlift_VIdentity @-}
-- vlift_VIdentity :: forall a. a -> VIdentity a
-- vlift_VIdentity = VIdentity

-- {-@ reflect vbind_VIdentity @-}
-- vbind_VIdentity ::
--   forall a b. VIdentity a -> (a -> VIdentity b) -> VIdentity b
-- vbind_VIdentity (VIdentity x) k = k x

-- {-@
-- vbind_correct_VIdentity :: forall a b . m:VIdentity a -> f:(a -> b) ->
--   {vbind_VIdentity m (vcomp vlift_VIdentity f) = vmapF iFunctor_VIdentity f m}
-- @-}
-- vbind_correct_VIdentity ::
--   forall a b. VIdentity a -> (a -> b) -> Proof
-- vbind_correct_VIdentity _ _ = ()

-- {-@
-- vbind_identity_VIdentity :: forall a . m:VIdentity a ->
--   {vbind_VIdentity m vlift_VIdentity = m}
-- @-}
-- vbind_identity_VIdentity :: forall a. VIdentity a -> Proof
-- vbind_identity_VIdentity _ = ()

-- {-@
-- vbind_vlift_VIdentity :: forall a b . k:(a -> VIdentity b) -> x:a ->
--   {vbind_VIdentity (vlift_VIdentity x) k = k x}
-- @-}
-- vbind_vlift_VIdentity :: forall a b. (a -> VIdentity b) -> a -> Proof
-- vbind_vlift_VIdentity _ _ = ()

-- {-@
-- vbind_vbind_VIdentity :: forall a b c . m:VIdentity a -> k1:(a -> VIdentity b) -> k2:(b -> VIdentity c) ->
--   {vbind_VIdentity (vbind_VIdentity m k1) k2 = vbind_VIdentity m (raw_kleisli vbind_VIdentity k1 k2)}
-- @-}
-- vbind_vbind_VIdentity ::
--   forall a b c.
--   VIdentity a ->
--   (a -> VIdentity b) ->
--   (b -> VIdentity c) ->
--   Proof
-- vbind_vbind_VIdentity _ _ _ = ()

-- {-@ reflect iMonad_VIdentity @-}
-- iMonad_VIdentity :: VMonad VIdentity
-- iMonad_VIdentity =
--   VMonad
--     { iFunctor = iFunctor_VIdentity,
--       vbind = vbind_VIdentity,
--       vlift = vlift_VIdentity,
--       vbind_correct = vbind_correct_VIdentity,
--       vbind_identity = vbind_identity_VIdentity,
--       vbind_vlift = vbind_vlift_VIdentity,
--       vbind_vbind = vbind_vbind_VIdentity
--     }
