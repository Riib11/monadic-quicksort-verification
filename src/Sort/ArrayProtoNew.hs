{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}

{-@ LIQUID "--compile-spec" @-}

module Sort.ArrayProtoNew where

import Data.Refined.Bool
import Data.Refined.List
import Data.Refined.Natural
import Data.Refined.Tuple
import Data.Refined.Unit
import Data.Text (Text, unpack)
import Function
import Language.Haskell.Liquid.Equational
import Language.Haskell.TH.Ppr (pprint)
import Language.Haskell.TH.Syntax
import NeatInterpolation (text)
import Placeholder.M
import Relation.Equality.Prop
import Relation.Equality.Prop.EDSL
import Relation.Equality.Prop.Reasoning
import Sort.Array
import Sort.List
import Prelude hiding (Monad, all, foldl, length, pure, read, readList, seq, (*), (+), (++), (>>), (>>=))

--
-- iqsort_spec_step1
--

{-@ reflect iqsort_spec_step1_aux @-}
iqsort_spec_step1_aux :: Natural -> Int -> List Int -> M Unit
iqsort_spec_step1_aux i p xs =
  writeList i (Cons p xs)
    >> ipartl p (S i) (Z, Z, length xs) >>= \(ny, nz) ->
      swap i (i + ny)
        >> iqsort i ny
        >> iqsort (S (i + ny)) nz

-- by definition of iqsort
{-@
iqsort_spec_step1 ::
  i:Natural -> p:Int -> xs:List Int ->
  RefinesPlus (Unit)
    {iqsort_spec_aux1 i (Cons p xs)}
    {iqsort_spec_step1_aux i p xs}
@-}
iqsort_spec_step1 :: Natural -> Int -> List Int -> EqualityProp (M Unit)
iqsort_spec_step1 i p xs =
  (refinesplus_reflexivity (iqsort_spec_aux1 i (Cons p xs)))
    [eqpropchain|
        iqsort_spec_aux1 i (Cons p xs)

      %==
        writeList i (Cons p xs) >>
        iqsort i (length (Cons p xs))

      %==
        writeList i (Cons p xs) >>
        ( read i >>= 
          iqsort_aux1 i (lenth (Cons p xs))
        )

      %==
        writeList i (Cons p xs) >>
        ( read i >>= 
          iqsort_aux1 i (lenth (Cons p xs))
        )

      %==
        writeList i (Cons p xs) >>
        ipartl p (S i) (Z, Z, length xs) >>= \(ny, nz) ->
          swap i (i + ny) >>
          iqsort i ny >>
          iqsort (S (i + ny)) nz

      -- TODO

        -- %by %rewrite iqsort i (length (Cons p xs))
        --          %to ipartl p (S i) (Z, Z, length xs) >>= \(ny, nz) -> swap i (i + ny) >> iqsort i ny >> iqsort (S (i + ny)) nz

      %==
        iqsort_spec_step1_aux i p xs
    |]

--
-- iqsort_spec_step2
--

{-@ reflect iqsort_spec_step2_aux @-}
iqsort_spec_step2_aux :: Natural -> Int -> List Int -> M Unit
iqsort_spec_step2_aux i p xs =
  partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
    -- BEGIN: [ref 13]
    writeList i (Cons p ys)
      >> swap i (i + length ys)
      -- END: [ref 13]
      >> writeList (S (i + length (ys ++ Cons p Nil))) zs
      >> iqsort i (length ys)
      >> iqsort (S (i + length ys)) (length zs)

-- uses: iqsort_spec_lemma1, iqsort_spec_lemma2 [ref 13]
-- desc. This is what the typical quicksort algorithm does: swapping the pivot
-- with the last element of `ys`, and [ref 13] says that it is valid because
-- that is one of the many permutations of `ys`. With [ref 13] and [ref 10], the
-- specification can be refined to:
{-@
iqsort_spec_step2 ::
  i:Natural -> p:Int -> xs:List Int ->
  RefinesPlus (Unit)
    {iqsort_spec_step1_aux i p xs}
    {iqsort_spec_step2_aux i p xs}
@-}
iqsort_spec_step2 :: Natural -> Int -> List Int -> EqualityProp (M ())
iqsort_spec_step2 i p xs = undefined -- TODO

--
-- iqsort_spec_step3
--

{-@ reflect iqsort_spec_step3_aux @-}
iqsort_spec_step3_aux :: Natural -> Int -> List Int -> M ()
iqsort_spec_step3_aux i p xs =
  partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
    permute ys >>= \ys' ->
      writeList i (ys' ++ Cons p Nil ++ zs)
        >> iqsort i (length ys)
        >> iqsort (S (i + length ys)) (length zs)

-- [ref 13]
-- uses: iqsort_spec_lemma1 [ref 10], ipartl_spec_lemma3 [ref 11]
-- desc: Now that we have introduced `partl'`, the next goal is to embed
-- `ipartl`. The status of the array before the two calls to `iqsort` is given
-- by `writeList i (ys' ++ [p] ++ zs)`. That is, `ys' ++ [p] ++ zs` is stored in
-- the array from index `i`, where `ys'` is a permutation of `ys`. The
-- postcondition of `ipartl`, according to the specification [ref 10], ends up
-- with `ys` and `zs` stored consecutively. To connect the two conditions, we
-- use a lemma that is dual to [ref 11]:
{-@
iqsort_spec_step3 ::
  i:Natural -> p:Int -> xs:List Int ->
  RefinesPlus (Unit)
    {iqsort_spec_step2_aux i p xs}
    {iqsort_spec_step3_aux i p xs}
@-}
iqsort_spec_step3 :: Natural -> Int -> List Int -> EqualityProp (M ())
iqsort_spec_step3 i p xs = undefined -- TODO

--
-- iqsort_spec_step4
--

-- uses: [ref 9] and [ref 12] (recursively) and divide_and_conquer
-- desc: For this to work, we introduced two `perm` to permute both partitions
-- generated by partition. We can do so because `perm >=> perm = perm` and thus
-- `perm >=> slowsort = slowsort`. The term `perm zs` was combined with
-- `partition p`, yielding `partl' p`, while `perm ys` will be needed later. We
-- also needed [ref 9] to split `writeList i (ys' ++ [x] ++ zs')` into two
-- parts. Assuming that [ref 12] has been met for lists shorter than `xs`, two
-- subexpressions are folded back to `iqsort`.
{-@
iqsort_spec_step4 ::
  i:Natural -> p:Int -> xs:List Int ->
  RefinesPlus (Unit)
    {iqsort_spec_step3_aux i p xs}
    {iqsort_spec_aux2 i (Cons p xs)}
@-}
iqsort_spec_step4 :: Natural -> Int -> List Int -> EqualityProp (M Unit)
iqsort_spec_step4 i p xs = undefined -- TODO

--
-- iqsort_spec
--

-- {-@ reflect iqsort_spec_aux1 @-}
-- iqsort_spec_aux1 :: Natural -> List Int -> M ()
-- iqsort_spec_aux1 i xs = writeList i xs >> iqsort i (length xs)

-- {-@ reflect iqsort_spec_aux2 @-}
-- iqsort_spec_aux2 :: Natural -> List Int -> M ()
-- iqsort_spec_aux2 i xs = slowsort xs >>= writeList i

{-@
iqsort_spec ::
  (Equality (M Unit)) =>
  i:Natural -> xs:List Int ->
  RefinesPlus (Unit)
    {iqsort_spec_aux1 i xs}
    {iqsort_spec_aux2 i xs}
@-}
iqsort_spec :: (Equality (M Unit)) => Natural -> List Int -> EqualityProp (M Unit)
iqsort_spec i Nil = undefined -- TODO
iqsort_spec i (Cons p xs) =
  (refinesplus_transitivity aux1 aux2 aux5)
    step1
    ( (refinesplus_transitivity aux2 aux3 aux5)
        step2
        ( (refinesplus_transitivity aux3 aux4 aux5)
            step3
            step4
        )
    )
  where
    aux1 = iqsort_spec_aux1 i (Cons p xs)
    step1 = iqsort_spec_step1 i p xs
    aux2 = iqsort_spec_step1_aux i p xs
    step2 = iqsort_spec_step2 i p xs
    aux3 = iqsort_spec_step2_aux i p xs
    step3 = iqsort_spec_step3 i p xs
    aux4 = iqsort_spec_step3_aux i p xs
    step4 = iqsort_spec_step4 i p xs
    aux5 = iqsort_spec_aux2 i (Cons p xs)