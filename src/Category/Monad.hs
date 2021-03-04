module Category.Monad where

import Function
import Language.Haskell.Liquid.ProofCombinators
import Relation.Equality.Prop
import Prelude hiding (Monad, pure, seq)

{-
# Monad
-}

{-
## Data
-}

{-@
data Monad m = Monad
  { pure :: forall a. a -> m a,
    bind :: forall a b. m a -> (a -> m b) -> m b,
    identityLeft ::
      forall a b.
      (y:b -> EqualProp b {y} {y}) ->
      x:a ->
      k:(a -> m b) ->
      EqualProp (m b) {bind (pure x) k} {k x},
    identityRight ::
      forall a.
      (x:a -> EqualProp a {x} {x}) ->
      m:m a ->
      EqualProp (m a) {bind m pure} {m},
    associativity ::
      forall a b c.
      (x:c -> EqualProp c {x} {x}) ->
      (x:c -> y:c -> z:c -> EqualProp c {x} {y} -> EqualProp c {y} {z} -> EqualProp c {x} {z}) ->
      m:m a ->
      k1:(a -> m b) ->
      k2:(b -> m c) ->
      EqualProp (m c) {bind (bind m k1) k2} {bind m (\x:a -> bind (k1 x) k2)}
  }
@-}
data Monad m = Monad
  { pure :: forall a. a -> m a,
    bind :: forall a b. m a -> (a -> m b) -> m b,
    identityLeft ::
      forall a b.
      (b -> EqualityProp b) ->
      a ->
      (a -> m b) ->
      EqualityProp (m b),
    identityRight ::
      forall a.
      (a -> EqualityProp a) ->
      m a ->
      EqualityProp (m a),
    associativity ::
      forall a b c.
      (c -> EqualityProp c) ->
      (c -> c -> c -> EqualityProp c -> EqualityProp c -> EqualityProp c) ->
      m a ->
      (a -> m b) ->
      (b -> m c) ->
      EqualityProp (m c)
  }

{-
## Utilities
-}

{-@ reflect kleisli @-}
kleisli :: Monad m -> (a -> m b) -> (b -> m c) -> (a -> m c)
kleisli mnd k1 k2 x = bind mnd (k1 x) k2

{-@ reflect join @-}
join :: Monad m -> m (m a) -> m a
join mnd mm = bind mnd mm identity

{-@ reflect seq @-}
seq :: Monad m -> m a -> m b -> m b
seq mnd ma mb = bind mnd ma (\_ -> mb)

{-@ reflect map @-}
map :: Monad m -> (a -> b) -> (m a -> m b)
map mnd f m = bind mnd m (\x -> pure mnd (f x))

{-@ reflect map2 @-}
map2 :: Monad m -> (a -> b -> c) -> (m a -> m b -> m c)
map2 mnd f ma mb = bind mnd ma (\x -> bind mnd mb (\y -> pure mnd (f x y)))