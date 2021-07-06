{-# LANGUAGE BlockArguments #-}
{-@ LIQUID "--ple"        @-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE IncoherentInstances #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}

{-@ LIQUID "--ple"         @-}
{-@ LIQUID "--fast"        @-}

module Readers where

import Data.Refined.Unit
import Function hiding (compose)
import Language.Haskell.Liquid.ProofCombinators
import Language.Haskell.TH.Ppr
import Language.Haskell.TH.Syntax
import Relation.Equality.Prop
import Relation.Equality.Prop.EDSL
import Prelude hiding (fmap, id, pure, (<$>), (<*>), (>>=))

type Reader a b = a -> b

{-@ reflect fmap @-}
fmap :: (a -> b) -> Reader r a -> Reader r b
fmap fab fra r = fab (fra r)

{-@ reflect id @-}
id :: a -> a
id x = x

{-@ reflect dollar @-}
dollar :: (a -> b) -> a -> b
dollar f v = f v

{-@ reflect on @-}
on :: a -> (a -> b) -> b
on v f = f v

{-@ reflect compose @-}
compose :: (b -> c) -> (a -> b) -> (a -> c)
compose g f x = g (f x)

functorLaw_identity :: Reflexivity a => EqualityProp (Reader r a -> Reader r a)
{-@ functorLaw_identity :: Reflexivity a -> EqualProp (Reader r a -> Reader r a) (fmap id) id @-}
functorLaw_identity =
  extensionality
    (fmap id)
    id
    ( \r ->
        extensionality
          (fmap id r)
          (id r)
          ( \a ->
              refl (fmap id r a)
                ? ( fmap id r a
                      =~= id (r a)
                      =~= id r a
                      *** QED
                  )
          )
    )

functorLaw_identity_macros :: (Equality a, Equality (Reader r a -> Reader r a)) => EqualityProp (Reader r a -> Reader r a)
{-@ functorLaw_identity_macros :: (Equality a, Equality (Reader r a -> Reader r a)) => EqualProp (Reader r a -> Reader r a) (fmap id) id @-}
functorLaw_identity_macros =
  [eqp| fmap id %== id
          %by %extend r
          %by %extend a
          %by %smt
          %by id (r a)
  |]

functorLaw_composition :: Reflexivity c => (a -> b) -> (b -> c) -> EqualityProp (Reader r a -> Reader r c)
{-@ functorLaw_composition :: Reflexivity c => f:(a -> b) -> g:(b -> c) ->
      EqualProp (Reader r a -> Reader r c) (fmap (compose g f)) (compose (fmap g) (fmap f)) @-}
functorLaw_composition f g =
  extensionality
    (fmap (compose g f))
    (compose (fmap g) (fmap f))
    ( \rdr ->
        extensionality
          (fmap (compose g f) rdr)
          ((compose (fmap g) (fmap f)) rdr)
          ( \r ->
              refl
                (fmap (compose g f) rdr r)
                ? ( fmap (compose g f) rdr r
                      =~= (compose g f) (rdr r)
                      =~= g (f (rdr r))
                      =~= g (((fmap f) rdr) r)
                      =~= fmap g ((fmap f) rdr) r
                      =~= (compose (fmap g) (fmap f)) rdr r
                      *** QED
                  )
          )
    )

functorLaw_composition_macros :: (Equality c, Equality (Reader r a -> Reader r c)) => (a -> b) -> (b -> c) -> EqualityProp (Reader r a -> Reader r c)
{-@ functorLaw_composition_macros :: (Equality c, Equality (Reader r a -> Reader r c)) => f:(a -> b) -> g:(b -> c) ->
      EqualProp (Reader r a -> Reader r c) (fmap (compose g f)) (compose (fmap g) (fmap f)) @-}
functorLaw_composition_macros f g =
  [eqp| fmap (compose g f) %== compose (fmap g) (fmap f)
          %by %extend rdr
          %by %extend r
          %by %smt
          %by (compose g f) (rdr r)
            ? g (((fmap f) rdr) r)
            ? fmap g ((fmap f) rdr) r
  |]

{-@ reflect pure @-}
pure :: a -> Reader r a
pure a _r = a

{-@ reflect ap @-}
ap :: Reader r (a -> b) -> Reader r a -> Reader r b
ap frab fra r = frab r (fra r)

applicativeLaw_identity :: (Reflexivity a, Transitivity a) => Reader r a -> EqualityProp (Reader r a)
{-@ applicativeLaw_identity :: (Reflexivity a, Transitivity a) => v:Reader r a ->
      EqualProp (Reader r a) (ap (pure id) v) v @-}
applicativeLaw_identity v =
  extensionality
    (ap (pure id) v)
    v
    ( \r ->
        trans
          (ap (pure id) v r)
          ((pure id) r (v r))
          (v r)
          (refl (ap (pure id) v r))
          ( trans
              ((pure id) r (v r))
              (id (v r))
              (v r)
              (refl ((pure id) r (v r)))
              (refl (id (v r)))
          )
    )

applicativeLaw_identity_macros :: (Equality (Reader r a), Equality a) => Reader r a -> EqualityProp (Reader r a)
{-@ applicativeLaw_identity_macros :: (Equality (Reader r a), Equality a) => v:Reader r a ->
      EqualProp (Reader r a) (ap (pure id) v) v @-}
applicativeLaw_identity_macros v =
  (extensionality (ap (pure id) v) v) \r ->
    [eqp| ap (pure id) v r
      %== (pure id) r (v r)
      %== id (v r)
      %== v r
    |]

applicativeLaw_homomorphism :: (Reflexivity b, Transitivity b) => (a -> b) -> a -> EqualityProp (Reader r b)
{-@ applicativeLaw_homomorphism :: (Reflexivity b, Transitivity b) => f:(a->b) -> v:a ->
      EqualProp (Reader r b) (ap (pure f) (pure v)) (pure (f v)) @-}
applicativeLaw_homomorphism f v =
  extensionality
    (ap (pure f) (pure v))
    (pure (f v))
    ( \r ->
        trans
          (ap (pure f) (pure v) r)
          (pure f r (pure v r))
          (pure (f v) r)
          (refl (ap (pure f) (pure v) r))
          ( trans
              (pure f r (pure v r))
              (pure f r v)
              (pure (f v) r)
              (refl (pure f r (pure v r)))
              ( trans
                  (pure f r v)
                  (f v)
                  (pure (f v) r)
                  (refl (pure f r v))
                  (refl (f v))
              )
          )
    )

applicativeLaw_interchange :: (Reflexivity b, Transitivity b) => Reader r (a -> b) -> a -> EqualityProp (Reader r b)
{-@ applicativeLaw_interchange :: (Reflexivity b, Transitivity b) => u:(Reader r (a -> b)) -> y:a ->
      EqualProp (Reader r b) (ap u (pure y)) (ap (pure (on y)) u) @-}
applicativeLaw_interchange u y =
  extensionality
    (ap u (pure y))
    (ap (pure (on y)) u)
    ( \r ->
        trans
          (ap u (pure y) r)
          (u r (pure y r))
          (ap (pure (on y)) u r)
          (refl (ap u (pure y) r))
          ( trans
              (u r (pure y r))
              (u r y)
              (ap (pure (on y)) u r)
              (refl (u r (pure y r)))
              ( trans
                  (u r y)
                  ((on y) (u r))
                  (ap (pure (on y)) u r)
                  (refl (u r y))
                  ( trans
                      ((on y) (u r))
                      ((pure (on y)) r (u r))
                      (ap (pure (on y)) u r)
                      (refl ((on y) (u r)))
                      (refl ((pure (on y)) r (u r)))
                  )
              )
          )
    )

--- WHEW this one takes a long time
applicativeLaw_composition ::
  (Reflexivity c, Transitivity c) =>
  Reader r (b -> c) ->
  Reader r (a -> b) ->
  Reader r a ->
  EqualityProp (Reader r c)
{-@ applicativeLaw_composition :: (Reflexivity c, Transitivity c) =>
      u:(Reader r (b -> c)) -> v:(Reader r (a -> b)) -> w:(Reader r a) ->
      EqualProp (Reader r c) (ap (ap (ap (pure compose) u) v) w) (ap u (ap v w)) @-}
applicativeLaw_composition u v w =
  extensionality
    (ap (ap (ap (pure compose) u) v) w)
    (ap u (ap v w))
    ( \r ->
        trans
          (ap (ap (ap (pure compose) u) v) w r)
          ((ap (ap (pure compose) u) v) r (w r))
          (ap u (ap v w) r)
          (refl (ap (ap (ap (pure compose) u) v) w r))
          ( trans
              ((ap (ap (pure compose) u) v) r (w r))
              ((ap (pure compose) u) r (v r) (w r))
              (ap u (ap v w) r)
              (refl ((ap (ap (pure compose) u) v) r (w r)))
              ( trans
                  ((ap (pure compose) u) r (v r) (w r))
                  ((pure compose) r (u r) (v r) (w r))
                  (ap u (ap v w) r)
                  (refl ((ap (pure compose) u) r (v r) (w r)))
                  ( trans
                      ((pure compose) r (u r) (v r) (w r)) -- skipped ((\_r -> compose) r (u r) (v r) (w r))
                      (compose (u r) (v r) (w r))
                      (ap u (ap v w) r)
                      (refl ((pure compose) r (u r) (v r) (w r)))
                      ( trans
                          (compose (u r) (v r) (w r))
                          ((u r) ((v r) (w r)))
                          (ap u (ap v w) r)
                          (refl (compose (u r) (v r) (w r)))
                          ( trans
                              ((u r) ((v r) (w r)))
                              (u r (v r (w r)))
                              (ap u (ap v w) r)
                              (refl ((u r) ((v r) (w r))))
                              ( trans
                                  (u r (v r (w r)))
                                  (u r (ap v w r))
                                  (ap u (ap v w) r)
                                  (refl (u r (v r (w r))))
                                  (refl (u r (ap v w r)))
                              )
                          )
                      )
                  )
              )
          )
    )

applicativeLaw_homomorphism_macros :: (Equality (Reader r b), Equality b) => (a -> b) -> a -> EqualityProp (Reader r b)
{-@ applicativeLaw_homomorphism_macros :: (Equality (Reader r b), Equality b) => f:(a->b) -> v:a ->
      EqualProp (Reader r b) (ap (pure f) (pure v)) (pure (f v)) @-}
applicativeLaw_homomorphism_macros f v =
  extensionality (ap (pure f) (pure v)) (pure (f v)) \r ->
    [eqp| ap (pure f) (pure v) r
      %== pure f r (pure v r)
      %== pure f r v
      %== pure (f v) r
    |]

applicativeLaw_interchange_macros :: Equality b => Reader r (a -> b) -> a -> EqualityProp (Reader r b)
{-@ applicativeLaw_interchange_macros :: Equality b => u:(Reader r (a -> b)) -> y:a ->
      EqualProp (Reader r b) (ap u (pure y)) (ap (pure (on y)) u) @-}
applicativeLaw_interchange_macros u y =
  extensionality (ap u (pure y)) (ap (pure (on y)) u) \r ->
    [eqp| ap u (pure y) r
      %== u r (pure y r)
      %== u r y
      %== (on y) (u r)
      %== (pure (on y)) r (u r)
      %== ap (pure (on y)) u r
    |]

ap_fmap :: (Reflexivity b, Transitivity b) => (a -> b) -> Reader r a -> EqualityProp (Reader r b)
{-@ ap_fmap :: f:(a -> b) -> a:(Reader r a) -> EqualProp (Reader r b) (fmap f a) (ap (pure f) a) @-}
ap_fmap f a =
  extensionality
    (fmap f a)
    (ap (pure f) a)
    ( \r ->
        trans
          (fmap f a r)
          (f (a r))
          (ap (pure f) a r)
          (refl (fmap f a r))
          ( trans
              (f (a r))
              ((pure f) r (a r))
              (ap (pure f) a r)
              (refl (f (a r)))
              (refl ((pure f) r (a r)))
          )
    )

{-@ reflect bind @-}
bind :: Reader r a -> (a -> Reader r b) -> Reader r b
bind fra farb = \r -> farb (fra r) r

monadLaw_leftIdentity :: (Reflexivity b, Transitivity b) => a -> (a -> Reader r b) -> EqualityProp (Reader r b)
{-@ monadLaw_leftIdentity :: Reflexivity b => a:a -> f:(a -> Reader r b) ->
      EqualProp (Reader r b) (bind (pure a) f) (f a)
@-}
monadLaw_leftIdentity a f =
  extensionality
    (bind (pure a) f)
    (f a)
    ( \r ->
        trans
          (bind (pure a) f r)
          (f (pure a r) r)
          (f a r)
          (refl (bind (pure a) f r))
          (refl (f (pure a r) r))
    )

monadLaw_leftIdentity' :: (Reflexivity b, Transitivity b) => a -> (a -> Reader r b) -> EqualityProp (Reader r b)
{-@ monadLaw_leftIdentity' :: Reflexivity b => a:a -> f:(a -> Reader r b) ->
      EqualProp (Reader r b) (bind (pure a) f) (f a)
@-}
monadLaw_leftIdentity' a f =
  extensionality
    (bind (pure a) f)
    (f a)
    ( \r ->
        refl (bind (pure a) f r)
          ? (bind (pure a) f r =~= f (pure a r) r *** QED)
    )

monadLaw_rightIdentity :: Reflexivity a => (Reader r a) -> EqualityProp (Reader r a)
{-@ monadLaw_rightIdentity :: Reflexivity a => m:(Reader r a) -> EqualProp (Reader r a) (bind m pure) m @-}
monadLaw_rightIdentity m =
  extensionality
    (bind m pure)
    m
    ( \r ->
        refl (bind m pure r)
          ? ( (bind m pure r)
                =~= pure (m r) r
                *** QED
            )
    )

{-@ reflect kleisli @-}
kleisli :: (a -> Reader r b) -> (b -> Reader r c) -> a -> Reader r c
kleisli f g x = bind (f x) g

monadLaw_associativity ::
  (Reflexivity c, Transitivity c) => (Reader r a) -> (a -> Reader r b) -> (b -> Reader r c) -> EqualityProp (Reader r c)
{-@ monadLaw_associativity :: (Reflexivity c, Transitivity c) =>
      m:(Reader r a) -> f:(a -> Reader r b) -> g:(b -> Reader r c) ->
      EqualProp (Reader r c) (bind (bind m f) g) (bind m (kleisli f g))
@-}
monadLaw_associativity m f g =
  extensionality
    (bind (bind m f) g)
    (bind m (kleisli f g))
    ( \r ->
        let el = bind (bind m f) g r
            eml = g (bind m f r) r
            em = (bind (f (m r)) g) r
            emr = kleisli f g (m r) r
            er = bind m (kleisli f g) r
         in trans
              el
              em
              er
              (trans el eml em (refl el) (refl eml))
              (trans em emr er (refl em) (refl emr))
    )
