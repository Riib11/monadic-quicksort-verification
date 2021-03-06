{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE TemplateHaskell #-}

{-@ LIQUID "--compile-spec" @-}

module Sort.ArrayProto where

import Data.Refined.Bool
import Data.Refined.List
import Data.Refined.Natural
import Data.Refined.Tuple
import Data.Refined.Unit
import Function
import Language.Haskell.Liquid.Equational
import Language.Haskell.TH.Syntax
import Placeholder.M
import Relation.Equality.Prop
import Relation.Equality.Prop.EDSL
import Relation.Equality.Prop.Reasoning
import Sort.List
import Prelude hiding (Monad, all, foldl, length, pure, read, readList, seq, (*), (+), (++), (>>), (>>=))

-- --
-- -- ## ipartl
-- --

-- {-@ reflect partl' @-}
-- partl' :: Int -> (List Int, List Int, List Int) -> M (List Int, List Int)
-- partl' p (ys, zs, Nil) = pure (ys, zs)
-- partl' p (ys, zs, Cons x xs) = dispatch x p (ys, zs, xs) >>= partl' p

-- {-@ reflect dispatch_aux1 @-}
-- dispatch_aux1 :: Int -> List Int -> List Int -> List Int -> M (List Int, List Int, List Int)
-- dispatch_aux1 x xs ys zs' = pure (ys ++ Cons x Nil, zs', xs)

-- {-@ reflect dispatch_aux2 @-}
-- dispatch_aux2 :: List Int -> List Int -> List Int -> M (List Int, List Int, List Int)
-- dispatch_aux2 xs ys zs' = pure (ys, zs', xs)

-- {-@ reflect dispatch @-}
-- dispatch :: Int -> Int -> (List Int, List Int, List Int) -> M (List Int, List Int, List Int)
-- dispatch x p (ys, zs, xs) =
--   if x <= p
--     then permute zs >>= dispatch_aux1 x xs ys
--     else permute (zs ++ Cons x Nil) >>= dispatch_aux2 xs ys

-- {-@ reflect dispatch_preserves_length_append_ys_zs_aux @-}
-- dispatch_preserves_length_append_ys_zs_aux :: (List Int, List Int, List Int) -> M Natural
-- dispatch_preserves_length_append_ys_zs_aux (ys', zs', xs) =
--   pure (length (append ys' zs'))

-- {-@
-- dispatch_preserves_length_append_ys_zs ::
--   Equality (M Natural) =>
--   x:Int -> p:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   EqualProp (M Natural)
--     {bind (dispatch x p (ys, zs, xs)) dispatch_preserves_length_append_ys_zs_aux}
--     {pure (length (append ys zs))}
-- @-}
-- dispatch_preserves_length_append_ys_zs :: Equality (M Natural) => Int -> Int -> List Int -> List Int -> List Int -> EqualityProp (M Natural)
-- dispatch_preserves_length_append_ys_zs x p xs ys zs =
--   [eqpropchain|
--             bind (dispatch x p (ys, zs, xs)) dispatch_preserves_length_append_ys_zs_aux
--         %==
--             pure (length (append ys zs))
--     |]

-- {-@
-- assume
-- dispatch_commutativity_seq_bind ::
--   Equality (M a) =>
--   i:Natural -> xs:List Int -> x:Int -> p:Int -> ys_zs_xs:(List Int, List Int, List Int) -> k:((List Int, List Int, List Int) -> M a) ->
--   EqualProp (M a)
--     {bind (seq (writeList (S i) xs) (dispatch x p ys_zs_xs)) k}
--     {bind (dispatch x p ys_zs_xs) (seqk (writeList i xs) k)}
-- @-}
-- dispatch_commutativity_seq_bind :: Equality (M a) => Natural -> List Int -> Int -> Int -> (List Int, List Int, List Int) -> ((List Int, List Int, List Int) -> M a) -> EqualityProp (M a)
-- dispatch_commutativity_seq_bind i xs x p ys_zs_xs k =
--   [eqpropchain|
--       bind (seq (writeList (S i) xs) (dispatch x p ys_zs_xs)) k
--     %==
--       bind (dispatch x p ys_zs_xs) (seqk (writeList i xs) k)
--   |]

-- -- final derivation of `ipartl`
-- {-@ reflect ipartl @-}
-- ipartl :: Int -> Natural -> (Natural, Natural, Natural) -> M (Natural, Natural)
-- ipartl p i (ny, nz, Z) = pure (ny, nz)
-- ipartl p i (ny, nz, S k) =
--   read (i + ny + nz) >>= ipartl_aux p i ny nz k

-- {-@ reflect ipartl_aux @-}
-- ipartl_aux :: Int -> Natural -> Natural -> Natural -> Natural -> Int -> M (Natural, Natural)
-- ipartl_aux p i ny nz k x' =
--   if x' <= p
--     then
--       swap (i + ny) (i + ny + nz)
--         >> ipartl p i (S ny, nz, k)
--     else ipartl p i (ny, S nz, k)

-- --
-- -- ### ipartl spec lemmas
-- --

-- --
-- -- #### ipartl spec lemma 1
-- --

-- {-@
-- ipartl_spec_lemma1_step1 ::
--   Equality (M (Natural, Natural)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step3_aux2 p i x xs ys zs}
--     {bind (pure (append zs (Cons x Nil))) (ipartl_spec_step4_aux2_aux p i xs ys)}
-- @-}
-- ipartl_spec_lemma1_step1 :: Equality (M (Natural, Natural)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_lemma1_step1 p i x xs ys zs =
--   refinesplus_equalprop
--     (ipartl_spec_step3_aux2 p i x xs ys zs)
--     (bind (pure (append zs (Cons x Nil))) (ipartl_spec_step4_aux2_aux p i xs ys))
--     [eqpropchain|
--       ipartl_spec_step3_aux2 p i x xs ys zs

--     %==
--       writeList i (ys ++ zs ++ Cons x Nil) >>
--         ipartl p i (length ys, S (length zs), length xs)

--         %by %reflexivity

--     %==
--       writeList i (ys ++ zs ++ Cons x Nil) >>
--         ipartl p i (length ys, length (zs ++ Cons x Nil), length xs)

--         %by %rewrite S (length zs)
--                  %to length (zs ++ Cons x Nil)
--         %by %smt
--         %by length_snoc zs x

--     %==
--       ( \zs' ->
--           writeList i (ys ++ zs') >>
--             ipartl p i (length ys, length zs', length xs)
--       ) (zs ++ Cons x Nil)

--         %by %symmetry
--         %by %reflexivity

--     %==
--       pure (zs ++ Cons x Nil) >>= \zs' ->
--         writeList i (ys ++ zs') >>
--           ipartl p i (length ys, length zs', length xs)

--         %by %symmetry
--         %by pure_bind (zs ++ Cons x Nil) (\zs' -> writeList i (ys ++ zs') >> ipartl p i (length ys, length zs', length xs))

--     %==
--       pure (zs ++ Cons x Nil) >>=
--         ipartl_spec_step4_aux2_aux p i xs ys

--         %by %rewrite \zs' -> writeList i (ys ++ zs') >> ipartl p i (length ys, length zs', length xs)
--                  %to ipartl_spec_step4_aux2_aux p i xs ys
--         %by %extend zs'
--         %by %symmetry
--         %by %reflexivity

--     %==
--       pure (append zs (Cons x Nil)) >>=
--         ipartl_spec_step4_aux2_aux p i xs ys

--       %by %rewrite zs ++ Cons x Nil
--            %to append zs (Cons x Nil)
--       %by %reflexivity

--     %==
--       bind (pure (append zs (Cons x Nil)))
--         (ipartl_spec_step4_aux2_aux p i xs ys)

--         %by %reflexivity
--   |]

-- {-@
-- ipartl_spec_lemma1_step2 ::
--   (Equality (M (List Int, List Int)), Equality (M (Natural, Natural)), Equality (M (List Int)), Equality (List Int)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {bind (pure (append zs (Cons x Nil))) (ipartl_spec_step4_aux2_aux p i xs ys)}
--     {bind (permute (append zs (Cons x Nil))) (ipartl_spec_step4_aux2_aux p i xs ys)}
-- @-}
-- ipartl_spec_lemma1_step2 :: (Equality (M (List Int, List Int)), Equality (M (Natural, Natural)), Equality (M (List Int)), Equality (List Int)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_lemma1_step2 p i x xs ys zs = refinesplus_substitutability f a b f_morphism pf
--   where
--     f m = bind m (ipartl_spec_step4_aux2_aux p i xs ys)
--     a = pure (append zs (Cons x Nil))
--     b = permute (append zs (Cons x Nil))
--     f_morphism a b = reflexivity (f a <+> f b)
--     pf = pure_refines_permute (append zs (Cons x Nil))

-- {-@
-- ipartl_spec_lemma1_step3 ::
--   (Equality (M (Natural, Natural)), Eq (List Int)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {bind (permute (append zs (Cons x Nil))) (ipartl_spec_step4_aux2_aux p i xs ys)}
--     {ipartl_spec_step4_aux2 p i x xs ys zs}
-- @-}
-- ipartl_spec_lemma1_step3 :: (Equality (M (Natural, Natural)), Eq (List Int)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_lemma1_step3 p i x xs ys zs =
--   refinesplus_equalprop
--     (bind (permute (append zs (Cons x Nil))) (ipartl_spec_step4_aux2_aux p i xs ys))
--     (ipartl_spec_step4_aux2 p i x xs ys zs)
--     [eqpropchain|
--       bind (permute (append zs (Cons x Nil))) (ipartl_spec_step4_aux2_aux p i xs ys)

--     %==
--       permute (append zs (Cons x Nil)) >>= ipartl_spec_step4_aux2_aux p i xs ys

--     %==
--       permute (zs ++ Cons x Nil) >>= ipartl_spec_step4_aux2_aux p i xs ys

--         %by %rewrite append zs (Cons x Nil)
--                  %to zs ++ Cons x Nil
--         %by %symmetry
--         %by %reflexivity

--     %==
--       ipartl_spec_step4_aux2 p i x xs ys zs
--         %by %symmetry
--         %by %reflexivity
--   |]

-- {-@
-- ipartl_spec_lemma1 ::
--   (Equality (M (List Int, List Int)), Equality (M (Natural, Natural)), Equality (M (List Int)), Equality (List Int)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step3_aux2 p i x xs ys zs}
--     {ipartl_spec_step4_aux2 p i x xs ys zs}
-- @-}
-- ipartl_spec_lemma1 :: (Equality (M (List Int, List Int)), Equality (M (Natural, Natural)), Equality (M (List Int)), Equality (List Int)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_lemma1 p i x xs ys zs =
--   (refinesplus_transitivity aux1 aux2 aux4)
--     step1
--     ( (refinesplus_transitivity aux2 aux3 aux4)
--         step2
--         step3
--     )
--   where
--     aux1 = ipartl_spec_step3_aux2 p i x xs ys zs
--     step1 = ipartl_spec_lemma1_step1 p i x xs ys zs
--     aux2 = bind (pure (append zs (Cons x Nil))) (ipartl_spec_step4_aux2_aux p i xs ys)
--     step2 = ipartl_spec_lemma1_step2 p i x xs ys zs
--     aux3 = bind (permute (append zs (Cons x Nil))) (ipartl_spec_step4_aux2_aux p i xs ys)
--     step3 = ipartl_spec_lemma1_step2 p i x xs ys zs
--     aux4 = ipartl_spec_step4_aux2 p i x xs ys zs

-- --
-- -- #### ipartl spec lemma 2
-- --

-- {-@ reflect ipartl_spec_lemma2_step1_aux1 @-}
-- ipartl_spec_lemma2_step1_aux1 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_lemma2_step1_aux1 p i x xs ys zs' =
--   writeList (i + length ys) (Cons x Nil ++ zs')
--     >> ipartl p i (S (length ys), length zs', length xs)

-- {-@
-- ipartl_spec_lemma2_step1 ::
--   (Equality (M (Natural, Natural)), Equality (M Unit)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step3_aux1 p i x xs ys zs}
--     {seq (seq (seq (writeList i ys) (writeList (add i (length ys)) (append zs (Cons x Nil)))) (swap (add i (length ys)) (add i (add (length ys) (length zs))))) (ipartl p i (S (length ys), length zs, length xs))}
-- @-}
-- ipartl_spec_lemma2_step1 :: (Equality (M (Natural, Natural)), Equality (M Unit)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_lemma2_step1 p i x xs ys zs =
--   -- !LH slow
--   [eqpropchain|
--       ipartl_spec_step3_aux1 p i x xs ys zs

--     %==
--       writeList i (ys ++ zs ++ Cons x Nil) >>
--         swap (i + length ys) (i + length ys + length zs) >>
--           ipartl p i (S (length ys), length zs, length xs)

--         %by %reflexivity

--     %==
--       writeList i (ys ++ zs ++ Cons x Nil) >>
--         swap (i + length ys) (add i (add (length ys) (length zs))) >>
--           ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite i + length ys + length zs
--                  %to add i (add (length ys) (length zs))
--         %by %reflexivity

--     %==
--       writeList i (ys ++ zs ++ Cons x Nil) >>
--         swap (add i (length ys)) (add i (add (length ys) (length zs))) >>
--           ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite i + length ys
--                  %to add i (length ys)
--         %by %reflexivity

--     %==
--       writeList i (ys ++ append zs (Cons x Nil)) >>
--         swap (add i (length ys)) (add i (add (length ys) (length zs))) >>
--           ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite ys ++ zs ++ Cons x Nil
--                  %to ys ++ append zs (Cons x Nil)
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         writeList (add i (length ys)) (append zs (Cons x Nil)) >>
--           swap (add i (length ys)) (add i (add (length ys) (length zs))) >>
--             ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite writeList i (ys ++ append zs (Cons x Nil))
--                  %to writeList i ys >> writeList (add i (length ys)) (append zs (Cons x Nil))
--         %by writeList_append i ys (append zs (Cons x Nil))

--     %==
--       seq (writeList i ys)
--           (writeList (add i (length ys)) (append zs (Cons x Nil))) >>
--         swap (add i (length ys)) (add i (add (length ys) (length zs))) >>
--           ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite writeList i ys >> writeList (add i (length ys)) (append zs (Cons x Nil))
--                  %to writeList i ys >> writeList (add i (length ys)) (append zs (Cons x Nil))
--         %by %reflexivity

--     %==
--       seq (seq (writeList i ys)
--                (writeList (add i (length ys)) (append zs (Cons x Nil))))
--           (swap (add i (length ys)) (add i (add (length ys) (length zs)))) >>
--         ipartl p i (S (length ys), length zs, length xs)

--       %by %rewrite seq (writeList i ys) (writeList (add i (length ys)) (append zs (Cons x Nil))) >> swap (add i (length ys)) (add i (add (length ys) (length zs)))
--                %to seq (seq (writeList i ys) (writeList (add i (length ys)) (append zs (Cons x Nil)))) (swap (add i (length ys)) (add i (add (length ys) (length zs))))
--       %by %reflexivity

--     %==
--       seq (seq (seq (writeList i ys)
--                     (writeList (add i (length ys)) (append zs (Cons x Nil))))
--                (swap (add i (length ys)) (add i (add (length ys) (length zs)))))
--           (ipartl p i (S (length ys), length zs, length xs))

--         %by %reflexivity
--   |]

-- {-@
-- ipartl_spec_lemma2_step2 ::
--   (Equality (() -> M ()), Equality (() -> M (Natural, Natural)), Equality (List Int -> M (Natural, Natural)), Equality (M (Natural, Natural)), Equality (M Unit)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {seq (seq (seq (writeList i ys) (writeList (add i (length ys)) (append zs (Cons x Nil)))) (swap (add i (length ys)) (add i (add (length ys) (length zs))))) (ipartl p i (S (length ys), length zs, length xs))}
--     {bind (seq (writeList i ys) (permute zs)) (ipartl_spec_lemma2_step1_aux1 p i x xs ys)}
-- @-}
-- ipartl_spec_lemma2_step2 :: (Equality (() -> M ()), Equality (() -> M (Natural, Natural)), Equality (List Int -> M (Natural, Natural)), Equality (M (Natural, Natural)), Equality (M Unit)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_lemma2_step2 p i x xs ys zs =
--   -- !LH slow
--   [eqpropchain|
--       seq (seq (seq
--       (writeList i ys)
--         (writeList (add i (length ys)) (append zs (Cons x Nil))))
--           (swap (add i (length ys)) (add i (add (length ys) (length zs)))))
--             (ipartl p i (S (length ys), length zs, length xs))

--     %==
--       (seq (seq
--       (writeList i ys)
--         (writeList (add i (length ys)) (append zs (Cons x Nil))))
--           (swap (add i (length ys)) (add i (add (length ys) (length zs))))) >>
--             (ipartl p i (S (length ys), length zs, length xs))

--     %==
--       (seq
--       (writeList i ys)
--         (writeList (add i (length ys)) (append zs (Cons x Nil)))) >>
--           swap (add i (length ys)) (add i (add (length ys) (length zs))) >>
--             ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite (seq (seq (writeList i ys) (writeList (add i (length ys)) (append zs (Cons x Nil)))) (swap (add i (length ys)) (add i (add (length ys) (length zs)))))
--                  %to (seq (writeList i ys) (writeList (add i (length ys)) (append zs (Cons x Nil)))) >> swap (add i (length ys)) (add i (add (length ys) (length zs)))
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         writeList (add i (length ys)) (append zs (Cons x Nil)) >>
--           swap (add i (length ys)) (add i (add (length ys) (length zs))) >>
--             ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite (seq (writeList i ys) (writeList (add i (length ys)) (append zs (Cons x Nil))))
--                  %to writeList i ys >> writeList (add i (length ys)) (append zs (Cons x Nil))
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         writeList (add i (length ys)) (append zs (Cons x Nil)) >>
--           swap (add i (length ys)) (add i (add (length ys) (length zs))) >>
--             ipartl p i (S (length ys), length zs, length xs)

--     %==
--       writeList i ys >>
--         writeList (i + length ys) (append zs (Cons x Nil)) >>
--           swap (add i (length ys)) (add i (add (length ys) (length zs))) >>
--             ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite add i (length ys)
--                  %to i + length ys
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         writeList (i + length ys) (zs ++ Cons x Nil) >>
--           swap (i + length ys) (add i (add (length ys) (length zs))) >>
--             ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite append zs (Cons x Nil)
--                  %to zs ++ Cons x Nil
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         writeList (i + length ys) (zs ++ Cons x Nil) >>
--           swap (i + length ys) (i + length ys + length zs) >>
--             ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite add i (add (length ys) (length zs))
--                  %to i + length ys + length zs
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         ( writeList (i + length ys) (zs ++ Cons x Nil) >>
--             swap (i + length ys) (i + length ys + length zs)
--         ) >>
--             ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite writeList i ys >> writeList (i + length ys) (zs ++ Cons x Nil) >> swap (i + length ys) (i + length ys + length zs)
--                  %to writeList i ys >> (writeList (i + length ys) (zs ++ Cons x Nil) >> swap (i + length ys) (i + length ys + length zs))
--         %by seq_associativity (writeList i ys) (writeList (i + length ys) (zs ++ Cons x Nil)) (swap (i + length ys) (i + length ys + length zs))

--     %==
--       writeList i ys >>
--         ipartl_spec_lemma3_aux1 (i + length ys) x zs >>
--           ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite writeList (i + length ys) (zs ++ Cons x Nil) >> swap (i + length ys) (i + length ys + length zs)
--                  %to ipartl_spec_lemma3_aux1 (i + length ys) x zs
--         %by %symmetry
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         ipartl_spec_lemma3_aux2 (i + length ys) x zs >>
--           ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite ipartl_spec_lemma3_aux1 (i + length ys) x zs
--                  %to ipartl_spec_lemma3_aux2 (i + length ys) x zs
--         %by ipartl_spec_lemma3 (i + length ys) x zs

--     %==
--       writeList i ys >>
--         ( permute zs >>=
--             ipartl_spec_lemma3_aux2_aux (i + length ys) x
--         ) >>
--             ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite ipartl_spec_lemma3_aux2 (i + length ys) x zs
--                  %to permute zs >>= ipartl_spec_lemma3_aux2_aux (i + length ys) x
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         permute zs >>=
--           ipartl_spec_lemma3_aux2_aux (i + length ys) x >>
--             ipartl p i (S (length ys), length zs, length xs)

--         %by %rewrite writeList i ys >> (permute zs >>= ipartl_spec_lemma3_aux2_aux (i + length ys) x)
--                  %to writeList i ys >> permute zs >>= ipartl_spec_lemma3_aux2_aux (i + length ys) x
--         %by %symmetry
--         %by seq_bind_associativity
--               (writeList i ys)
--               (permute zs)
--               (ipartl_spec_lemma3_aux2_aux (i + length ys) x)

--     %==
--       ( ( writeList i ys >>
--             permute zs
--         ) >>=
--           ipartl_spec_lemma3_aux2_aux (i + length ys) x
--       ) >>
--         (\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs)

--         %by %rewrite ipartl p i (S (length ys), length zs, length xs)
--                  %to (\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs)
--         %by %symmetry
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         ( permute zs >>=
--             ipartl_spec_lemma3_aux2_aux (i + length ys) x >>
--               (\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs)
--         )

--       %by seq_bind_seq_associativity
--             (writeList i ys)
--             (permute zs)
--             (ipartl_spec_lemma3_aux2_aux (i + length ys) x)
--             ((\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs))

--     %==
--       writeList i ys >>
--         ( permute zs >>=
--             ( kseq
--                 (ipartl_spec_lemma3_aux2_aux (i + length ys) x)
--                 ((\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs))
--             )
--         )

--         %by %rewrite permute zs >>= ipartl_spec_lemma3_aux2_aux (i + length ys) x >> (\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs)
--                  %to permute zs >>= kseq (ipartl_spec_lemma3_aux2_aux (i + length ys) x) ((\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs))
--         %by bind_seq_associativity
--               (permute zs)
--               (ipartl_spec_lemma3_aux2_aux (i + length ys) x)
--               ((\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs))

--     %==
--       writeList i ys >>
--         ( permute zs >>=
--             bind_seq_associativity_with_permute_preserved_length_aux
--               (ipartl_spec_lemma3_aux2_aux (i + length ys) x)
--               (\nz -> ipartl p i (S (length ys), nz, length xs))
--         )

--         %by %rewrite permute zs >>= kseq (ipartl_spec_lemma3_aux2_aux (i + length ys) x) ((\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs))
--                  %to bind (permute zs) (bind_seq_associativity_with_permute_preserved_length_aux (ipartl_spec_lemma3_aux2_aux (i + length ys) x) (\nz -> ipartl p i (S (length ys), nz, length xs)))
--         %by bind_seq_associativity_with_permute_preserved_length
--               zs
--               (ipartl_spec_lemma3_aux2_aux (i + length ys) x)
--               (\nz -> ipartl p i (S (length ys), nz, length xs))

--     %==
--       writeList i ys >>
--         permute zs >>=
--           bind_seq_associativity_with_permute_preserved_length_aux
--             (ipartl_spec_lemma3_aux2_aux (i + length ys) x)
--             (\nz -> ipartl p i (S (length ys), nz, length xs))

--         %by %symmetry
--         %by seq_bind_associativity
--               (writeList i ys)
--               (permute zs)
--               (bind_seq_associativity_with_permute_preserved_length_aux (ipartl_spec_lemma3_aux2_aux (i + length ys) x) (\nz -> ipartl p i (S (length ys), nz, length xs)))

--     %==
--       writeList i ys >>
--         permute zs >>= \zs' ->
--           ipartl_spec_lemma3_aux2_aux (i + length ys) x zs' >>
--             (\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs')

--         %by %rewrite bind_seq_associativity_with_permute_preserved_length_aux (ipartl_spec_lemma3_aux2_aux (i + length ys) x) (\nz -> ipartl p i (S (length ys), nz, length xs))
--                  %to \zs' -> ipartl_spec_lemma3_aux2_aux (i + length ys) x zs' >> (\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs')
--         %by %extend zs'
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         permute zs >>= \zs' ->
--           ipartl_spec_lemma3_aux2_aux (i + length ys) x zs' >>
--             ipartl p i (S (length ys), length zs', length xs)

--         %by %rewrite \zs' -> ipartl_spec_lemma3_aux2_aux (i + length ys) x zs' >> (\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs')
--                  %to \zs' -> ipartl_spec_lemma3_aux2_aux (i + length ys) x zs' >> ipartl p i (S (length ys), length zs', length xs)
--         %by %extend zs'
--         %by %rewrite (\nz -> ipartl p i (S (length ys), nz, length xs)) (length zs')
--                  %to ipartl p i (S (length ys), length zs', length xs)
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         permute zs >>= \zs' ->
--           writeList (i + length ys) (Cons x Nil ++ zs') >>
--             ipartl p i (S (length ys), length zs', length xs)

--         %by %rewrite \zs' -> ipartl_spec_lemma3_aux2_aux (i + length ys) x zs' >> ipartl p i (S (length ys), length zs', length xs)
--                  %to \zs' -> writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)
--         %by %extend zs'
--         %by %rewrite ipartl_spec_lemma3_aux2_aux (i + length ys) x zs'
--                  %to writeList (i + length ys) (Cons x Nil ++ zs')
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         permute zs >>=
--           ipartl_spec_lemma2_step1_aux1 p i x xs ys

--         %by %rewrite \zs' -> writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)
--                  %to ipartl_spec_lemma2_step1_aux1 p i x xs ys
--         %by %extend zs'
--         %by %symmetry
--         %by %reflexivity

--     %==
--       seq (writeList i ys) (permute zs) >>= ipartl_spec_lemma2_step1_aux1 p i x xs ys

--         %by %rewrite writeList i ys >> permute zs
--                  %to seq (writeList i ys) (permute zs)
--         %by %reflexivity

--     %==
--       bind (seq (writeList i ys) (permute zs)) (ipartl_spec_lemma2_step1_aux1 p i x xs ys)

--         %by %reflexivity
--   |]

-- {-@
-- ipartl_spec_lemma2_step3 ::
--   (Equality (M (Natural, Natural)), Equality (M Unit)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {bind (seq (writeList i ys) (permute zs)) (ipartl_spec_lemma2_step1_aux1 p i x xs ys)}
--     {ipartl_spec_step4_aux1 p i x xs ys zs}
-- @-}
-- ipartl_spec_lemma2_step3 :: (Equality (M (Natural, Natural)), Equality (M Unit)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_lemma2_step3 p i x xs ys zs =
--   [eqpropchain|
--       bind (seq
--       (writeList i ys)
--         (permute zs))
--           (ipartl_spec_lemma2_step1_aux1 p i x xs ys)

--     %==
--       seq
--       (writeList i ys)
--         (permute zs) >>=
--           ipartl_spec_lemma2_step1_aux1 p i x xs ys

--     %==
--       writeList i ys >>
--         permute zs >>=
--           ipartl_spec_lemma2_step1_aux1 p i x xs ys

--         %by %rewrite seq (writeList i ys) (permute zs)
--                  %to writeList i ys >> permute zs
--         %by %reflexivity

--     %==
--       writeList i ys >>
--         permute zs >>= \zs' ->
--           writeList (i + length ys) (Cons x Nil ++ zs') >>
--             ipartl p i (S (length ys), length zs', length xs)

--         %by %rewrite ipartl_spec_lemma2_step1_aux1 p i x xs ys
--                  %to \zs' -> writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)
--         %by %extend zs'
--         %by %reflexivity

--     %==
--       permute zs >>=
--         seqk
--           (writeList i ys)
--           (\zs' ->
--             writeList (i + length ys) (Cons x Nil ++ zs') >>
--               ipartl p i (S (length ys), length zs', length xs))

--         %by permute_commutativity_seq_bind
--               (writeList i ys)
--               zs
--               (\zs' -> writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs))

--     %==
--       permute zs >>= \zs' ->
--         writeList i ys >>
--           (\zs' ->
--             writeList (i + length ys) (Cons x Nil ++ zs') >>
--               ipartl p i (S (length ys), length zs', length xs))
--             zs'

--         %by %rewrite seqk (writeList i ys) (\zs' -> writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs))
--                  %to \zs' -> writeList i ys >> (\zs' -> writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)) zs'
--         %by %extend zs'
--         %by %reflexivity

--     %==
--       permute zs >>= \zs' ->
--         writeList i ys >>
--           ( writeList (i + length ys) (Cons x Nil ++ zs') >>
--               ipartl p i (S (length ys), length zs', length xs)
--           )

--         %by %rewrite \zs' -> writeList i ys >> (\zs' -> writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)) zs'
--                  %to \zs' -> writeList i ys >> (writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs))
--         %by %extend zs'
--         %by %rewrite (\zs' -> writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)) zs'
--                  %to writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)
--         %by %reflexivity

--     %==
--       permute zs >>= \zs' ->
--         writeList i ys >>
--           writeList (i + length ys) (Cons x Nil ++ zs') >>
--             ipartl p i (S (length ys), length zs', length xs)

--         %by %rewrite \zs' -> writeList i ys >> (writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs))
--                  %to \zs' -> writeList i ys >> writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)
--         %by %extend zs'
--         %by %symmetry
--         %by seq_associativity
--               (writeList i ys)
--               (writeList (i + length ys) (Cons x Nil ++ zs'))
--               (ipartl p i (S (length ys), length zs', length xs))

--     %==
--       permute zs >>= \zs' ->
--         writeList i (ys ++ Cons x Nil ++ zs') >>
--           ipartl p i (S (length ys), length zs', length xs)

--         %by %rewrite \zs' -> writeList i ys >> writeList (i + length ys) (Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)
--                  %to \zs' -> writeList i (ys ++ Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)
--         %by %extend zs'
--         %by %symmetry
--         %by %rewrite writeList i ys >> writeList (i + length ys) (Cons x Nil ++ zs')
--                  %to writeList i (ys ++ Cons x Nil ++ zs')
--         %by writeList_append i ys (Cons x Nil ++ zs')

--     %==
--       permute zs >>= ipartl_spec_step4_aux1_aux p i x xs ys

--         %by %rewrite \zs' -> writeList i (ys ++ Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)
--                  %to ipartl_spec_step4_aux1_aux p i x xs ys
--         %by %extend zs'
--         %by %symmetry
--         %by %reflexivity

--     %==
--       ipartl_spec_step4_aux1 p i x xs ys zs

--         %by %symmetry
--         %by %reflexivity
--   |]

-- {-@
-- ipartl_spec_lemma2 ::
--   (Equality (() -> M ()), Equality (() -> M (Natural, Natural)), Equality (List Int -> M (Natural, Natural)), Equality (M (Natural, Natural)), Equality (M Unit)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step3_aux1 p i x xs ys zs}
--     {ipartl_spec_step4_aux1 p i x xs ys zs}
-- @-}
-- ipartl_spec_lemma2 :: (Equality (() -> M ()), Equality (() -> M (Natural, Natural)), Equality (List Int -> M (Natural, Natural)), Equality (M (Natural, Natural)), Equality (M Unit)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_lemma2 p i x xs ys zs =
--   (refinesplus_transitivity aux1 aux2 aux4)
--     step1
--     ( (refinesplus_transitivity aux2 aux3 aux4)
--         step2
--         step3
--     )
--   where
--     aux1 = ipartl_spec_step3_aux1 p i x xs ys zs
--     step1 = ipartl_spec_lemma2_step1 p i x xs ys zs
--     aux2 = seq (seq (seq (writeList i ys) (writeList (add i (length ys)) (append zs (Cons x Nil)))) (swap (add i (length ys)) (add i (add (length ys) (length zs))))) (ipartl p i (S (length ys), length zs, length xs))
--     step2 = ipartl_spec_lemma2_step2 p i x xs ys zs
--     aux3 = bind (seq (writeList i ys) (permute zs)) (ipartl_spec_lemma2_step1_aux1 p i x xs ys)
--     step3 = ipartl_spec_lemma2_step3 p i x xs ys zs
--     aux4 = ipartl_spec_step4_aux1 p i x xs ys zs

-- --
-- -- #### ipartl spec lemma 3
-- --

-- {-@ reflect ipartl_spec_lemma3_aux1 @-}
-- ipartl_spec_lemma3_aux1 :: Natural -> Int -> List Int -> M ()
-- ipartl_spec_lemma3_aux1 i x zs =
--   writeList i (zs ++ Cons x Nil) >> swap i (i + length zs)

-- {-@ reflect ipartl_spec_lemma3_aux2 @-}
-- ipartl_spec_lemma3_aux2 :: Natural -> Int -> List Int -> M ()
-- ipartl_spec_lemma3_aux2 i x zs =
--   permute zs >>= ipartl_spec_lemma3_aux2_aux i x

-- {-@ reflect ipartl_spec_lemma3_aux2_aux @-}
-- ipartl_spec_lemma3_aux2_aux :: Natural -> Int -> List Int -> M ()
-- ipartl_spec_lemma3_aux2_aux i x zs' =
--   writeList i (Cons x Nil ++ zs')

-- {-@
-- ipartl_spec_lemma3_aux1_Nil ::
--   Equality (M Unit) =>
--   i:Natural -> x:Int ->
--   EqualProp (M Unit)
--     {ipartl_spec_lemma3_aux1 i x Nil}
--     {seq (write i x) (pure it)}
-- @-}
-- ipartl_spec_lemma3_aux1_Nil :: Equality (M Unit) => Natural -> Int -> EqualityProp (M Unit)
-- ipartl_spec_lemma3_aux1_Nil i x =
--   [eqpropchain|
--       ipartl_spec_lemma3_aux1 i x Nil

--     %==
--       writeList i (Nil ++ Cons x Nil) >> swap i (i + length Nil)

--     %==
--       writeList i (Nil ++ Cons x Nil) >> swap i i

--         %by %rewrite i + length Nil
--                  %to i
--         %by %reflexivity

--     %==
--       writeList i (Cons x Nil) >> swap i i

--         %by %rewrite Nil ++ Cons x Nil
--                  %to Cons x Nil
--         %by %smt
--         %by append_identity (Cons x Nil)

--     %==
--       (write i x >> writeList (S i) Nil) >> swap i i

--         %by %rewrite writeList i (Cons x Nil)
--                  %to write i x >> writeList (S i) Nil
--         %by %reflexivity

--     %==
--       (write i x >> pure it) >> swap i i

--         %by %rewrite writeList (S i) Nil
--                  %to pure it
--         %by %reflexivity

--     %==
--       (write i x >> pure it) >> pure it

--         %by %rewrite swap i i
--                  %to pure it
--         %by swap_id i

--     %==
--       write i x >> (pure it >> pure it)

--         %by seq_associativity (write i x) (pure it) (pure it)

--     %==
--       write i x >> pure it

--         %by %symmetry
--         %by seq_identity_left it (pure it)
--   |]

-- {-@
-- ipartl_spec_lemma3_aux2_Nil ::
--   Equality (M Unit) =>
--   i:Natural -> x:Int ->
--   EqualProp (M Unit)
--     {ipartl_spec_lemma3_aux2 i x Nil}
--     {seq (write i x) (pure it)}
-- @-}
-- ipartl_spec_lemma3_aux2_Nil :: Equality (M Unit) => Natural -> Int -> EqualityProp (M Unit)
-- ipartl_spec_lemma3_aux2_Nil i x =
--   [eqpropchain|
--       ipartl_spec_lemma3_aux2 i x Nil

--     %==
--       permute Nil >>= ipartl_spec_lemma3_aux2_aux i x

--     %==
--       pure Nil >>= ipartl_spec_lemma3_aux2_aux i x
--         %by %rewrite permute Nil
--                  %to pure Nil
--         %by %reflexivity

--     %==
--       ipartl_spec_lemma3_aux2_aux i x Nil

--         %by pure_bind Nil (ipartl_spec_lemma3_aux2_aux i x)

--     %==
--       writeList i (Cons x Nil ++ Nil)

--         %by %reflexivity

--     %==
--       writeList i (Cons x Nil)

--         %by %rewrite Cons x Nil ++ Nil
--                  %to Cons x Nil
--         %by %smt
--         %by append_identity (Cons x Nil)

--     %==
--       write i x >> writeList (S i) Nil

--         %by %reflexivity

--     %==
--       write i x >> pure it

--         %by %rewrite writeList (S i) Nil
--                  %to pure it
--         %by %reflexivity
--   |]

-- {-@ reflect ipartl_spec_lemma3_aux1_Cons_aux @-}
-- ipartl_spec_lemma3_aux1_Cons_aux :: Natural -> Int -> Int -> List Int -> M ()
-- ipartl_spec_lemma3_aux1_Cons_aux i x z zs =
--   write i z
--     >> writeList (S i) zs
--     >> write (i + length zs) x
--     >> swap i (S (i + length zs))

-- {-@
-- ipartl_spec_lemma3_aux1_Cons ::
--   Equality (M Unit) =>
--   i:Natural -> x:Int -> z:Int -> zs:List Int ->
--   EqualProp (M Unit)
--     {ipartl_spec_lemma3_aux1 i x (Cons z zs)}
--     {ipartl_spec_lemma3_aux1_Cons_aux i x z zs}
-- @-}
-- ipartl_spec_lemma3_aux1_Cons :: Equality (M Unit) => Natural -> Int -> Int -> List Int -> EqualityProp (M ())
-- ipartl_spec_lemma3_aux1_Cons i x z zs =
--   [eqpropchain|
--       ipartl_spec_lemma3_aux1 i x (Cons z zs)

--     %==
--       writeList i (Cons z zs ++ Cons x Nil) >> swap i (i + length (Cons z zs))

--         %by %reflexivity

--     %==
--       writeList i (Cons z zs ++ Cons x Nil) >> swap i (i + S (length zs))

--         %by %rewrite length (Cons z zs)
--                  %to S (length zs)
--         %by %reflexivity

--     %==
--       writeList i (Cons z zs ++ Cons x Nil) >> swap i (S (i + length zs))

--         %by %rewrite i + S (length zs)
--                  %to S (i + length zs)
--         %by %smt
--         %by add_S_right i (length zs)

--     %==
--       writeList i (Cons z (zs ++ Cons x Nil)) >> swap i (S (i + length zs))

--         %by %rewrite Cons z zs ++ Cons x Nil
--                  %to Cons z (zs ++ Cons x Nil)
--         %by %reflexivity

--     %==
--       write i z >> writeList (S i) (zs ++ Cons x Nil) >> swap i (S (i + length zs))

--         %by %rewrite writeList i (Cons z (zs ++ Cons x Nil))
--                  %to write i z >> writeList (S i) (zs ++ Cons x Nil)
--         %by %reflexivity

--     %==
--       (write i z >> (writeList (S i) zs >> writeList (i + length zs) (Cons x Nil))) >> swap i (S (i + length zs))

--         %by %rewrite writeList (S i) (zs ++ Cons x Nil)
--                  %to writeList (S i) zs >> writeList (i + length zs) (Cons x Nil)
--         %by writeList_append (S i) zs (Cons x Nil)

--     %==
--       (write i z >> (writeList (S i) zs >> (write (i + length zs) x >> writeList (S (i + length zs)) Nil))) >> swap i (S (i + length zs))

--         %by %rewrite writeList (i + length zs) (Cons x Nil)
--                  %to write (i + length zs) x >> writeList (S (i + length zs)) Nil
--         %by %reflexivity

--     %==
--       (write i z >> (writeList (S i) zs >> (write (i + length zs) x >> pure it))) >> swap i (S (i + length zs))

--         %by %rewrite writeList (S (i + length zs)) Nil
--                 %to pure it
--         %by %reflexivity

--     %==
--       write i z >> writeList (S i) zs >> (write (i + length zs) x >> pure it) >> swap i (S (i + length zs))

--         %by %rewrite write i z >> (writeList (S i) zs >> (write (i + length zs) x >> pure it))
--                  %to write i z >> writeList (S i) zs >> (write (i + length zs) x >> pure it)
--         %by %symmetry
--         %by seq_associativity
--               (write i z)
--               (writeList (S i) zs)
--               (write (i + length zs) x >> pure it)

--     %==
--       write i z >> writeList (S i) zs >> write (i + length zs) x >> pure it >> swap i (S (i + length zs))

--         %by %rewrite write i z >> writeList (S i) zs >> (write (i + length zs) x >> pure it)
--                  %to write i z >> writeList (S i) zs >> write (i + length zs) x >> pure it
--         %by %symmetry
--         %by seq_associativity
--               (write i z >> writeList (S i) zs)
--               (write (i + length zs) x)
--               (pure it)

--     %==
--       write i z >> writeList (S i) zs >> write (i + length zs) x >> (pure it >> swap i (S (i + length zs)))

--         %by seq_associativity
--               (write i z >> writeList (S i) zs >> write (i + length zs) x)
--               (pure it)
--               (swap i (S (i + length zs)))

--     %==
--       write i z >> writeList (S i) zs >> write (i + length zs) x >> swap i (S (i + length zs))

--         %by seq_identity_left it (swap i (S (i + length zs)))
--   |]

-- {-@ reflect ipartl_spec_lemma3_aux2_Cons_aux @-}
-- ipartl_spec_lemma3_aux2_Cons_aux :: Natural -> Int -> Int -> List Int -> M Unit
-- ipartl_spec_lemma3_aux2_Cons_aux i x z zs =
--   split zs
--     >>= permute_aux1 z
--     >>= ipartl_spec_lemma3_aux2_aux i x

-- {-@
-- ipartl_spec_lemma3_aux2_Cons ::
--   Equality (M Unit) =>
--   i:Natural -> x:Int -> z:Int -> zs:List Int ->
--   EqualProp (M Unit)
--     {ipartl_spec_lemma3_aux2 i x (Cons z zs)}
--     {ipartl_spec_lemma3_aux2_Cons_aux i x z zs}
-- @-}
-- ipartl_spec_lemma3_aux2_Cons :: Equality (M ()) => Natural -> Int -> Int -> List Int -> EqualityProp (M ())
-- ipartl_spec_lemma3_aux2_Cons i x z zs =
--   [eqpropchain|
--       ipartl_spec_lemma3_aux2 i x (Cons z zs)

--     %== -- defn ipartl_spec_lemma3_aux2
--       permute (Cons z zs) >>=
--         ipartl_spec_lemma3_aux2_aux i x

--         %by %reflexivity

--     %== -- defn permute
--       split zs >>=
--         permute_aux1 z >>=
--           ipartl_spec_lemma3_aux2_aux i x

--         %by %rewrite permute (Cons z zs)
--                  %to split zs >>= permute_aux1 z
--         %by %reflexivity

--     %== -- defn ipartl_spec_lemma3_aux2_Cons_aux
--       ipartl_spec_lemma3_aux2_Cons_aux i x z zs

--         %by %symmetry
--         %by %reflexivity
--   |]

-- -- [ref 11]
-- {-@
-- ipartl_spec_lemma3 ::
--   Equality (M Unit) =>
--   i:Natural ->
--   x:Int ->
--   zs:List Int ->
--   RefinesPlus (Unit)
--     {ipartl_spec_lemma3_aux1 i x zs}
--     {ipartl_spec_lemma3_aux2 i x zs}
-- @-}
-- ipartl_spec_lemma3 :: Equality (M ()) => Natural -> Int -> List Int -> EqualityProp (M ())
-- ipartl_spec_lemma3 i x Nil =
--   refinesplus_equalprop
--     (ipartl_spec_lemma3_aux1 i x Nil)
--     (ipartl_spec_lemma3_aux2 i x Nil)
--     [eqpropchain|
--         ipartl_spec_lemma3_aux1 i x Nil <+> ipartl_spec_lemma3_aux2 i x Nil
--       %==
--         ipartl_spec_lemma3_aux1 i x Nil <+> (write i x >> pure it)
--           %by %rewrite ipartl_spec_lemma3_aux2 i x Nil
--                   %to write i x >> pure it
--           %by ipartl_spec_lemma3_aux2_Nil i x
--       %==
--         (write i x >> pure it) <+> (write i x >> pure it)
--           %by %rewrite ipartl_spec_lemma3_aux1 i x Nil
--                   %to write i x >> pure it
--           %by ipartl_spec_lemma3_aux1_Nil i x
--       %==
--         write i x >> pure it
--           %by refinesplus_reflexivity (write i x >> pure it)
--       %==
--         ipartl_spec_lemma3_aux2 i x Nil
--           %by %symmetry
--         %by ipartl_spec_lemma3_aux2_Nil i x
--   |]
-- ipartl_spec_lemma3 i x (Cons z zs) =
--   [eqpropchain|
--       ipartl_spec_lemma3_aux1 i x (Cons z zs)

--     %==
--       ipartl_spec_lemma3_aux1_Cons_aux i x z zs

--     %==
--       write i z >>
--         writeList (S i) zs >>
--           write (i + length zs) x >>
--             swap i (S (i + length zs))

--     %==
--       split zs >>=
--         ( \(ys', zs') ->
--             liftM2 (\ys' zs' -> ys' ++ Cons z Nil ++ zs') (permute ys') (permute zs')
--         ) >>= \zs' ->
--           write i x >>
--             writeList (S i) zs'

--     %-- writeList_singleton i x

--     %==
--       split zs >>=
--         ( \(ys', zs') ->
--             liftM2 (\ys' zs' -> ys' ++ Cons z Nil ++ zs') (permute ys') (permute zs')
--         ) >>= \zs' ->
--           writeList i (Cons x Nil) >>
--             writeList (S i) zs'

--     %-- writeList_append i (Cons x Nil) zs'

--     %==

--       split zs >>=
--         ( \(ys', zs') ->
--             liftM2 (\ys' zs' -> ys' ++ Cons z Nil ++ zs') (permute ys') (permute zs')
--         ) >>= \zs' ->
--           writeList i (Cons x Nil ++ zs')

--     %==
--       split zs >>=
--         ( \(ys', zs') ->
--             liftM2 (permute_aux2 z) (permute ys') (permute zs')
--         ) >>= \zs' ->
--           writeList i (Cons x Nil ++ zs')

--     %==
--       split zs >>=
--         permute_aux1 z >>= \zs' ->
--           writeList i (Cons x Nil ++ zs')

--     %==
--       split zs >>=
--         permute_aux1 z >>=
--           ipartl_spec_lemma3_aux2_aux i x

--     %==
--       ipartl_spec_lemma3_aux2_Cons_aux i x z zs

--     %==
--       ipartl_spec_lemma3_aux2 i x (Cons z zs)
--   |]

-- --
-- -- ### ipartl spec
-- --

-- {-@ reflect ipartl_spec_aux1 @-}
-- ipartl_spec_aux1 :: Int -> Natural -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_aux1 p i xs ys zs =
--   writeList i (ys ++ zs ++ xs) >> ipartl p i (length ys, length zs, length xs)

-- {-@ reflect ipartl_spec_aux2 @-}
-- ipartl_spec_aux2 :: Int -> Natural -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_aux2 p i xs ys zs =
--   partl' p (ys, zs, xs) >>= writeListToLength2 i

-- -- step 1

-- {-@ reflect ipartl_spec_step1 @-}
-- ipartl_spec_step1 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step1 p i x xs ys zs =
--   ipartl_spec_aux1 p i (Cons x xs) ys zs

-- -- step 3

-- {-@ reflect ipartl_spec_step3 @-}
-- ipartl_spec_step3 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step3 p i x xs ys zs =
--   writeList (S (i + length ys + length zs)) xs
--     >> if x <= p
--       then ipartl_spec_step3_aux1 p i x xs ys zs
--       else ipartl_spec_step3_aux2 p i x xs ys zs

-- {-@ reflect ipartl_spec_step3_aux1 @-}
-- ipartl_spec_step3_aux1 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step3_aux1 p i x xs ys zs =
--   writeList i (ys ++ zs ++ Cons x Nil)
--     >> swap (i + length ys) (i + length ys + length zs)
--     >> ipartl p i (S (length ys), length zs, length xs)

-- {-@ reflect ipartl_spec_step3_aux2 @-}
-- ipartl_spec_step3_aux2 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step3_aux2 p i x xs ys zs =
--   writeList i (ys ++ zs ++ Cons x Nil)
--     >> ipartl p i (length ys, S (length zs), length xs)

-- -- step 3a

-- -- step3A is step3 with lemma1 applied
-- -- step4 is step3A with lemma2 applied
-- {-@ reflect ipartl_spec_step3A @-}
-- ipartl_spec_step3A :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step3A p i x xs ys zs =
--   writeList (S (i + length ys + length zs)) xs
--     >> if x <= p
--       then ipartl_spec_step3_aux1 p i x xs ys zs
--       else ipartl_spec_step4_aux2 p i x xs ys zs

-- -- step 4

-- {-@ reflect ipartl_spec_step4 @-}
-- ipartl_spec_step4 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step4 p i x xs ys zs =
--   writeList (S (i + length ys + length zs)) xs
--     >> if x <= p
--       then ipartl_spec_step4_aux1 p i x xs ys zs
--       else ipartl_spec_step4_aux2 p i x xs ys zs

-- {-@ reflect ipartl_spec_step4_aux1 @-}
-- ipartl_spec_step4_aux1 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step4_aux1 p i x xs ys zs =
--   permute zs >>= ipartl_spec_step4_aux1_aux p i x xs ys

-- {-@ reflect ipartl_spec_step4_aux1_aux @-}
-- ipartl_spec_step4_aux1_aux :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step4_aux1_aux p i x xs ys zs' =
--   writeList i (ys ++ Cons x Nil ++ zs')
--     >> ipartl p i (S (length ys), length zs', length xs)

-- {-@ reflect ipartl_spec_step4_aux2 @-}
-- ipartl_spec_step4_aux2 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step4_aux2 p i x xs ys zs =
--   permute (zs ++ Cons x Nil)
--     >>= ipartl_spec_step4_aux2_aux p i xs ys

-- {-@ reflect ipartl_spec_step4_aux2_aux @-}
-- ipartl_spec_step4_aux2_aux :: Int -> Natural -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step4_aux2_aux p i xs ys zs' =
--   writeList i (ys ++ zs')
--     >> ipartl p i (length ys, length zs', length xs)

-- -- step 5

-- {-@ reflect ipartl_spec_step5 @-}
-- ipartl_spec_step5 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step5 p i x xs ys zs =
--   writeList (S (i + length ys + length zs)) xs
--     >> dispatch x p (ys, zs, xs)
--       >>= ipartl_spec_step5_aux p i

-- {-@ reflect ipartl_spec_step5_aux @-}
-- ipartl_spec_step5_aux :: Int -> Natural -> (List Int, List Int, List Int) -> M (Natural, Natural)
-- ipartl_spec_step5_aux p i (ys', zs', xs) =
--   writeList i (ys' ++ zs')
--     >> ipartl p i (length ys', length zs', length xs)

-- -- step 6

-- {-@ reflect ipartl_spec_step6 @-}
-- ipartl_spec_step6 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step6 p i x xs ys zs =
--   dispatch x p (ys, zs, xs)
--     >>= ipartl_spec_step6_aux p i

-- {-@ reflect ipartl_spec_step6_aux @-}
-- ipartl_spec_step6_aux :: Int -> Natural -> (List Int, List Int, List Int) -> M (Natural, Natural)
-- ipartl_spec_step6_aux p i (ys', zs', xs) =
--   writeList i (ys' ++ zs')
--     >> writeList (i + length (ys' ++ zs')) xs
--     >> ipartl p i (length ys', length zs', length xs)

-- -- step 7

-- {-@ reflect ipartl_spec_step7 @-}
-- ipartl_spec_step7 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step7 p i x xs ys zs =
--   dispatch x p (ys, zs, xs)
--     >>= writeListToLength3 i
--     >>= ipartl p i

-- -- step 8

-- {-@ reflect ipartl_spec_step8 @-}
-- ipartl_spec_step8 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step8 p i x xs ys zs =
--   dispatch x p (ys, zs, xs)
--     >>= partl' p
--     >>= writeListToLength2 i

-- -- step 9

-- {-@ reflect ipartl_spec_step9 @-}
-- ipartl_spec_step9 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_step9 p i x xs ys zs = ipartl_spec_aux2 p i (Cons x xs) ys zs

-- {-@
-- ipartl_spec_steps1to3_lemma ::
--   (Equality (M Unit), Equality (M Int), Equality (M (Natural, Natural)), Equality Int) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   EqualProp (M Int)
--     {seq (writeList i (append ys (append zs (Cons x xs)))) (read (add (add i (length ys)) (length zs)))}
--     {seq (writeList i (append ys (append zs (Cons x xs)))) (pure x)}
-- @-}
-- ipartl_spec_steps1to3_lemma ::
--   (Equality (M Unit), Equality (M Int), Equality (M (Natural, Natural)), Equality Int) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M Int)
-- ipartl_spec_steps1to3_lemma p i x xs ys zs =
--   [eqpropchain|
--       seq (writeList i (append ys (append zs (Cons x xs)))) (read (add (add i (length ys)) (length zs)))

--     %== -- defn seq, defn append, defn add
--       writeList i (ys ++ zs ++ Cons x xs) >>
--         read (i + length ys + length zs)

--         %by %reflexivity

--     %== -- add_associativity
--       writeList i ((ys ++ zs) ++ Cons x xs) >>
--         read (i + (length ys + length zs))

--         %by %rewrite i + length ys + length zs
--                  %to i + (length ys + length zs)
--         %by %smt
--         %by add_associativity i (length ys) (length zs)

--     %== -- length_append
--       writeList i ((ys ++ zs) ++ Cons x xs) >>
--         read (i + length (ys ++ zs))

--         %by %rewrite length ys + length zs
--                  %to length (ys ++ zs)
--         %by %smt
--         %by length_append ys zs

--     %== -- writeList_append
--       writeList i (ys ++ zs) >>
--         writeList (i + length (ys ++ zs)) (Cons x xs) >>
--           read (i + length (ys ++ zs))

--         %by %rewrite writeList i ((ys ++ zs) ++ Cons x xs)
--                  %to writeList i (ys ++ zs) >> writeList (i + length (ys ++ zs)) (Cons x xs)
--         %by writeList_append i (ys ++ zs) (Cons x xs)

--     %== -- seq_associativity
--       writeList i (ys ++ zs) >>
--         ( writeList (i + length (ys ++ zs)) (Cons x xs) >>
--             read (i + length (ys ++ zs))
--         )

--         %by seq_associativity
--               (writeList i (ys ++ zs))
--               (writeList (i + length (ys ++ zs)) (Cons x xs))
--               (read (i + length (ys ++ zs)))

--     %== -- writeList_read (i + length (ys ++ zs))
--       writeList i (ys ++ zs) >>
--         ( writeList (i + length (ys ++ zs)) (Cons x xs) >>
--             pure x
--         )

--         %by %rewrite writeList (i + length (ys ++ zs)) (Cons x xs) >> read (i + length (ys ++ zs))
--                  %to writeList (i + length (ys ++ zs)) (Cons x xs) >> pure x
--         %by writeList_read (i + length (ys ++ zs)) x xs

--     %== -- seq_associativity
--       writeList i (ys ++ zs) >>
--         writeList (i + length (ys ++ zs)) (Cons x xs) >>
--           pure x

--         %by %symmetry
--         %by seq_associativity
--               (writeList i (ys ++ zs))
--               (writeList (i + length (ys ++ zs)) (Cons x xs))
--               (pure x)

--     %== -- writeList_append
--       writeList i (ys ++ zs ++ Cons x xs) >>
--         pure x

--         %by %rewrite writeList i (ys ++ zs) >> writeList (i + length (ys ++ zs)) (Cons x xs)
--                  %to writeList i (ys ++ zs ++ Cons x xs)
--         %by writeList_append i (ys ++ zs) (Cons x xs)

--     %== -- defn seq, defn append, defn add
--       seq (writeList i (append ys (append zs (Cons x xs)))) (pure x)

--         %by %reflexivity
--   |]

-- -- uses:
-- -- - `seq_write_read`
-- -- - defn of `writeList`
-- -- - distributivity of `if`
-- -- - [ref 9]
-- {-@
-- ipartl_spec_steps1to3 ::
--   (Equality (M Unit), Equality (M Int), Equality (M (Natural, Natural))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step1 p i x xs ys zs}
--     {ipartl_spec_step3 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps1to3 :: (Equality (M Unit), Equality (M Int), Equality (M (Natural, Natural))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps1to3 p i x xs ys zs =
--   (refinesplus_equalprop (ipartl_spec_step1 p i x xs ys zs) (ipartl_spec_step3 p i x xs ys zs))
--     [eqpropchain|
--         ipartl_spec_step1 p i x xs ys zs

--       %==
--         ipartl_spec_aux1 p i (Cons x xs) ys zs

--       %==
--         writeList i (ys ++ zs ++ Cons x xs)
--           >> ipartl p i (length ys, length zs, length (Cons x xs))

--       %==
--         writeList i (ys ++ zs ++ Cons x xs)
--           >> ipartl p i (length ys, length zs, S (length xs))

--           %by %rewrite length (Cons x xs)
--                    %to S (length xs)
--           %by %reflexivity

--       %==
--         writeList i (ys ++ zs ++ Cons x xs)
--           >> read (i + length ys + length zs)
--             >>= ipartl_aux p i (length ys) (length zs) (length xs)

--           %by %rewrite ipartl p i (length ys, length zs, S (length xs))
--                    %to read (i + length ys + length zs) >>= ipartl_aux p i (length ys) (length zs) (length xs)
--           %by %reflexivity

--       %==
--         writeList i (ys ++ zs ++ Cons x xs)
--           >> read (i + length ys + length zs)
--             >>= \x' -> if x' <= p
--               then
--                 swap (i + length ys) (i + length ys + length zs)
--                   >> ipartl p i (S (length ys), length ys, length xs)
--               else
--                 ipartl p i (length ys, S (length ys), length xs)

--           %by %rewrite ipartl_aux p i (length ys) (length zs) (length xs)
--                    %to \x' -> if x' <= p then swap (i + length ys) (i + length ys + length zs) >> ipartl p i (S (length ys), length ys, length xs) else ipartl p i (length ys, S (length ys), length xs)
--           %by %extend x'
--           %by %reflexivity

--       %==
--         writeList i (ys ++ zs ++ Cons x xs)
--           >> pure x
--             >>= \x' -> if x' <= p
--               then
--                 swap (i + length ys) (i + length ys + length zs)
--                   >> ipartl p i (S (length ys), length zs, length xs)
--               else
--                 ipartl p i (length ys, S (length zs), length xs)

--           %by %rewrite writeList i (ys ++ zs ++ Cons x xs) >> read (i + length ys + length zs)
--                    %to writeList i (ys ++ zs ++ Cons x xs) >> pure x
--           %by ipartl_spec_steps1to3_lemma p i x xs ys zs

--       %==
--         %-- ipartl_spec_step2
--         writeList i (ys ++ zs ++ Cons x xs) >>
--         if x <= p
--           then
--             swap (i + length ys) (i + length ys + length zs)
--               >> ipartl p i (S (length ys), length zs, length xs)
--           else
--             ipartl p i (length ys, S (length zs), length xs)

--           %by pure_bind x
--                 (\x' -> if x' <= p
--                     then
--                         swap (i + length ys) (i + length ys + length zs)
--                         >> ipartl p i (S (length ys), length zs, length xs)
--                     else
--                         ipartl p i (length ys, S (length zs), length xs))

--       %==
--         ipartl_spec_step3 p i x xs ys zs
--     |]

-- -- uses: ipartl_spec_lemma1, refinesplus_substitutability
-- {-@
-- ipartl_spec_steps3to3a ::
--   (Equality (M (List Int, List Int)), Equality (M (List Int)), Equality (M (Natural, Natural))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step3 p i x xs ys zs}
--     {ipartl_spec_step3A p i x xs ys zs}
-- @-}
-- ipartl_spec_steps3to3a :: (Equality (M (List Int, List Int)), Equality (M (List Int)), Equality (M (Natural, Natural))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps3to3a p i x xs ys zs = refinesplus_substitutability f a b f_morphism pf
--   where
--     f a' =
--       writeList (S (i + length ys + length zs)) xs
--         >> if x <= p
--           then
--             writeList i (ys ++ zs ++ Cons x Nil)
--               >> swap (i + length ys) (i + length ys + length zs)
--               >> ipartl p i (S (length ys), length zs, length xs)
--           else a'
--     a = ipartl_spec_step3_aux2 p i x xs ys zs
--     b = ipartl_spec_step4_aux2 p i x xs ys zs
--     f_morphism a b = reflexivity (f a <+> f b)
--     pf = ipartl_spec_lemma1 p i x xs ys zs

-- -- uses: ipartl_spec_lemma2, refinesplus_substitutability
-- {-@
-- ipartl_spec_steps3Ato4 ::
--   (Equality (() -> M ()), Equality (() -> M (Natural, Natural)), Equality (List Int -> M (Natural, Natural)), Equality (M (Natural, Natural)), Equality (M Unit)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step3A p i x xs ys zs}
--     {ipartl_spec_step4 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps3Ato4 :: (Equality (() -> M ()), Equality (() -> M (Natural, Natural)), Equality (List Int -> M (Natural, Natural)), Equality (M (Natural, Natural)), Equality (M Unit)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps3Ato4 p i x xs ys zs = refinesplus_substitutability f a b f_morphism pf
--   where
--     f a' =
--       writeList (S (i + length ys + length zs)) xs
--         >> if x <= p
--           then
--             a'
--               >> ipartl p i (S (length ys), length zs, length xs)
--           else ipartl_spec_step4_aux2 p i x xs ys zs
--     a = ipartl_spec_step3_aux1 p i x xs ys zs
--     b = ipartl_spec_step4_aux1 p i x xs ys zs
--     f_morphism a b = reflexivity (f a <+> f b)
--     pf = ipartl_spec_lemma2 p i x xs ys zs -- !LH reject

-- -- uses:
-- -- - `ipartl_spec_lemma1`,
-- -- - `ipartl_spec_lemma2`
-- {-@
-- ipartl_spec_steps3to4 ::
--   (Equality (M (List Int, List Int)), Equality (() -> M ()), Equality (() -> M (Natural, Natural)), Equality (() -> M (Natural, Natural)), Equality (List Int -> M (Natural, Natural)), Equality (M (List Int)), Equality (M (Natural, Natural)), Equality (M Unit)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step3 p i x xs ys zs}
--     {ipartl_spec_step4 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps3to4 :: (Equality (M (List Int, List Int)), Equality (() -> M ()), Equality (() -> M (Natural, Natural)), Equality (() -> M (Natural, Natural)), Equality (List Int -> M (Natural, Natural)), Equality (M (List Int)), Equality (M (Natural, Natural)), Equality (M Unit)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps3to4 p i x xs ys zs =
--   refinesplus_transitivity
--     (ipartl_spec_step3 p i x xs ys zs) -- 3
--     (ipartl_spec_step3A p i x xs ys zs) -- 3a
--     (ipartl_spec_step4 p i x xs ys zs) -- 4
--     -- 3 refines 3a
--     (ipartl_spec_steps3to3a p i x xs ys zs)
--     -- 3a refines 4
--     (ipartl_spec_steps3Ato4 p i x xs ys zs)

-- --
-- -- ## iqsort
-- --

-- --
-- -- ### lemmas
-- --

-- {-@
-- permute_kleisli_permute_lemma ::
--   Equality (M (List Int)) =>
--   xs:List Int ->
--   EqualProp (M (List Int)) {bind (permute xs) permute} {permute xs}
-- @-}
-- permute_kleisli_permute_lemma :: Equality (M (List Int)) => List Int -> EqualityProp (M (List Int))
-- permute_kleisli_permute_lemma Nil =
--   [eqpropchain|
--       bind (permute Nil) permute
--     %==
--       bind (pure Nil) permute
--         %by %rewrite permute Nil
--                  %to pure Nil
--         %by %reflexivity
--     %==
--       permute Nil
--         %by pure_bind_outfix Nil permute
--   |]
-- permute_kleisli_permute_lemma (Cons x xs) =
--   [eqpropchain|
--       bind (permute (Cons x xs)) permute
--     %==
--       bind
--         (split xs >>= \(ys, zs) -> liftM2 (\ys' zs' -> ys' ++ Cons x Nil ++ zs') (permute ys) (permute zs))
--         permute
--         %by %rewrite permute (Cons x xs)
--                  %to split xs >>= \(ys, zs) -> liftM2 (\ys' zs' -> ys' ++ Cons x Nil ++ zs') (permute ys) (permute zs)
--         %by %reflexivity
--     %==
--       bind
--         (split xs >>= \(ys, zs) -> permute ys >>= \ys' -> permute zs >>= \zs' -> pure (ys' ++ Cons x Nil ++ zs'))
--         permute
--           %by %rewrite \(ys, zs) -> liftM2 (\ys' zs' -> ys' ++ Cons x Nil ++ zs') (permute ys) (permute zs)
--                    %to \(ys, zs) -> permute ys >>= \ys' -> permute zs >>= \zs' -> pure (ys' ++ Cons x Nil ++ zs')
--           %by %extend (ys, zs)
--           %by %reflexivity
--     %==
--       bind
--         (split xs >>= \(ys, zs) -> permute ys >>= \ys' -> permute zs >>= \zs' -> pure (ys' ++ Cons x Nil ++ zs'))
--         permute
--     %==
--       permute (Cons x xs)
--         %by %reflexivity
--   |]

-- {-@
-- permute_kleisli_permute ::
--   (Equality (List Int -> M (List Int)), Equality (M (List Int))) =>
--   xs:List Int ->
--   EqualProp (M (List Int))
--     {kleisli permute permute xs}
--     {permute xs}
-- @-}
-- permute_kleisli_permute :: (Equality (List Int -> M (List Int)), Equality (M (List Int))) => List Int -> EqualityProp (M (List Int))
-- permute_kleisli_permute Nil =
--   [eqpropchain|
--       kleisli permute permute Nil
--     %==
--       permute Nil >>= permute
--     %==
--       pure Nil >>= permute
--         %by %rewrite permute Nil %to pure Nil
--         %by %reflexivity
--     %==
--       permute Nil
--         %by pure_bind Nil permute
--   |]
-- permute_kleisli_permute (Cons x xs) =
--   [eqpropchain|
--       kleisli permute permute (Cons x xs)
--     %==
--       permute (Cons x xs) >>= permute
--     %==
--       (split xs >>= permute_aux1 x) >>= permute
--         %by %rewrite permute (Cons x xs)
--                  %to split xs >>= permute_aux1 x
--         %by %reflexivity
--     %==
--       split xs >>= (permute_aux1 x >=> permute)
--         %by bind_associativity (split xs) (permute_aux1 x) permute
--     %==
--       split xs >>= ((\(ys, zs) -> liftM2 (permute_aux2 x) (permute ys) (permute zs)) >=> permute)
--         %by %rewrite permute_aux1 x
--                  %to \(ys, zs) -> liftM2 (permute_aux2 x) (permute ys) (permute zs)
--         %by %extend (ys, zs)
--         %by %reflexivity
--     %==
--       split xs >>= ((\(ys, zs) -> permute ys >>= \ys' -> permute zs >>= \zs' -> pure (permute_aux2 x ys' zs')) >=> permute)
--         %by %rewrite \(ys, zs) -> liftM2 (permute_aux2 x) (permute ys) (permute zs)
--                  %to \(ys, zs) -> permute ys >>= \ys' -> permute zs >>= \zs' -> pure (permute_aux2 x ys' zs')
--         %by %extend (ys, zs)
--         %by %reflexivity
--     %==
--       permute (Cons x xs)
--   |]

-- {-@
-- permute_kleisli_slowsort ::
--   (Equality (M (List Int)), Equality (List Int -> M (List Int))) =>
--   xs:List Int ->
--   EqualProp (M (List Int))
--     {kleisli permute slowsort xs}
--     {slowsort xs}
-- @-}
-- permute_kleisli_slowsort :: (Equality (M (List Int)), Equality (List Int -> M (List Int))) => List Int -> EqualityProp (M (List Int))
-- permute_kleisli_slowsort xs =
--   [eqpropchain|
--       kleisli permute slowsort xs

--     %==
--       kleisli permute (kleisli permute (guardBy sorted)) xs

--         %by %rewrite slowsort
--                  %to kleisli permute (guardBy sorted)
--         %by %extend ys
--         %by %reflexivity

--     %==
--       kleisli (kleisli permute permute) (guardBy sorted) xs

--         %by kleisli_associativity permute permute (guardBy sorted) xs

--     %==
--       kleisli permute (guardBy sorted) xs

--         %by %rewrite kleisli permute permute
--                  %to permute
--         %by %extend ys
--         %by permute_kleisli_permute ys

--     %==
--       slowsort xs
--   |]

-- --
-- -- #### lemma 1
-- --

-- {-@ reflect iqsort_spec_lemma1_aux @-}
-- iqsort_spec_lemma1_aux :: Int -> Natural -> List Int -> M ()
-- iqsort_spec_lemma1_aux p i xs =
--   partl' p (Nil, Nil, xs) >>= iqsort_spec_lemma1_aux_aux p i

-- {-@ reflect iqsort_spec_lemma1_aux_aux @-}
-- iqsort_spec_lemma1_aux_aux :: Int -> Natural -> (List Int, List Int) -> M ()
-- iqsort_spec_lemma1_aux_aux p i (ys, zs) =
--   permute ys >>= iqsort_spec_lemma1_aux_aux_aux p i ys zs

-- {-@ reflect iqsort_spec_lemma1_aux_aux_aux @-}
-- iqsort_spec_lemma1_aux_aux_aux :: Int -> Natural -> List Int -> List Int -> List Int -> M ()
-- iqsort_spec_lemma1_aux_aux_aux p i ys zs ys' =
--   writeList i (ys' ++ Cons p Nil ++ zs)
--     >> iqsort i (length ys)
--     >> iqsort (S (i + length ys)) (length zs)

-- -- !INSERT iqsort_spec_lemma1

-- --
-- -- #### lemma 2
-- --

-- {-@ reflect iqsort_spec_lemma2_aux1 @-}
-- iqsort_spec_lemma2_aux1 :: Int -> Natural -> List Int -> M ()
-- iqsort_spec_lemma2_aux1 p i ys = permute ys >>= iqsort_spec_lemma2_aux2 p i

-- {-@ reflect iqsort_spec_lemma2_aux2 @-}
-- iqsort_spec_lemma2_aux2 :: Int -> Natural -> List Int -> M ()
-- iqsort_spec_lemma2_aux2 p i ys' = writeList i (ys' ++ Cons p Nil)

-- -- !INSERT iqsort_spec_lemma2

-- --
-- -- #### lemma 3
-- --

-- {-@ reflect iqsort_spec_lemma3_aux @-}
-- iqsort_spec_lemma3_aux :: Int -> Natural -> List Int -> M ()
-- iqsort_spec_lemma3_aux p i xs =
--   writeList i (Cons p xs)
--     >> ipartl p (S i) (Z, Z, length xs)
--       >>= iqsort_spec_lemma3_aux_aux i

-- {-@ reflect iqsort_spec_lemma3_aux_aux @-}
-- iqsort_spec_lemma3_aux_aux :: Natural -> (Natural, Natural) -> M ()
-- iqsort_spec_lemma3_aux_aux i (ny, nz) =
--   swap i (i + ny)
--     >> iqsort i ny
--     >> iqsort (S (i + ny)) nz

-- -- !INSERT iqsort_spec_lemma3

-- --
-- -- #### lemma 4
-- --

-- -- !INSERT iqsort_spec_lemma3

-- --
-- -- #### iqsort
-- --

-- -- `iqsort i n` sorts the `n` elements in the array starting from index `i`.
-- -- TODO: need to prove termination?
-- {-@ lazy iqsort @-}
-- {-@ reflect iqsort @-}
-- iqsort :: Natural -> Natural -> M ()
-- iqsort i Z = pure ()
-- iqsort i (S n) = read i >>= iqsort_aux1 i n

-- {-@ lazy iqsort_aux1 @-}
-- {-@ reflect iqsort_aux1 @-}
-- iqsort_aux1 :: Natural -> Natural -> Int -> M ()
-- iqsort_aux1 i n p = ipartl p (S i) (Z, Z, n) >>= iqsort_aux2 i n

-- {-@ lazy iqsort_aux2 @-}
-- {-@ reflect iqsort_aux2 @-}
-- iqsort_aux2 :: Natural -> Natural -> (Natural, Natural) -> M ()
-- iqsort_aux2 i n (ny, nz) = swap i (i + ny) >> iqsort i ny >> iqsort (S (i + ny)) nz

-- --
-- -- ### iqsort spec
-- --

-- -- from [ref 12]
-- {-@ reflect iqsort_spec_aux1 @-}
-- iqsort_spec_aux1 :: Natural -> List Int -> M ()
-- iqsort_spec_aux1 i xs = writeList i xs >> iqsort i (length xs)

-- -- from [ref 12]
-- {-@ reflect iqsort_spec_aux2 @-}
-- iqsort_spec_aux2 :: Natural -> List Int -> M ()
-- iqsort_spec_aux2 i xs = slowsort xs >>= writeList i

-- {-@
-- iqsort_spec_aux1_Nil ::
--   (Equality (M Unit), Equality (M (List Int))) =>
--   i:Natural ->
--   EqualProp (M Unit) {iqsort_spec_aux1 i Nil} {pure it}
-- @-}
-- iqsort_spec_aux1_Nil :: (Equality (M ()), Equality (M (List Int))) => Natural -> EqualityProp (M ())
-- iqsort_spec_aux1_Nil i =
--   [eqpropchain|
--       iqsort_spec_aux1 i Nil
--     %==
--       writeList i Nil >> iqsort i (length Nil)
--     %==
--       writeList i Nil >> iqsort i Z
--         %by %rewrite length Nil %to Z
--         %by %reflexivity
--     %==
--       writeList i Nil >> pure ()
--         %by %rewrite iqsort i Z %to pure ()
--         %by %reflexivity
--     %==
--       pure it >> pure ()
--         %by %rewrite writeList i Nil %to pure it
--         %by %reflexivity
--     %==
--       pure ()
--         %by seq_identity_left it (pure ())
--     %==
--       pure it
--         %by %rewrite () %to it
--         %by %reflexivity
--   |]

-- {-@
-- iqsort_spec_aux2_Nil ::
--   (Equality (M Unit), Equality (M (List Int))) =>
--   i:Natural ->
--   EqualProp (M Unit) {iqsort_spec_aux2 i Nil} {pure it}
-- @-}
-- iqsort_spec_aux2_Nil :: (Equality (M ()), Equality (M (List Int))) => Natural -> EqualityProp (M ())
-- iqsort_spec_aux2_Nil i =
--   [eqpropchain|
--       iqsort_spec_aux2 i Nil
--     %==
--       slowsort Nil >>= writeList i
--     %==
--       (permute Nil >>= guardBy sorted) >>= writeList i
--         %by %rewrite slowsort Nil %to permute Nil >>= guardBy sorted
--         %by %reflexivity
--     %==
--       (pure Nil >>= guardBy sorted) >>= writeList i
--         %by %rewrite permute Nil %to pure Nil
--         %by %reflexivity
--     %==
--       guardBy sorted Nil >>= writeList i
--         %by %rewrite pure Nil >>= guardBy sorted %to guardBy sorted Nil
--         %by pure_bind Nil (guardBy sorted)
--     %==
--       (guard (sorted Nil) >> pure Nil) >>= writeList i
--         %by %rewrite guardBy sorted Nil %to guard (sorted Nil) >> pure Nil
--         %by %reflexivity
--     %==
--       (guard True >> pure Nil) >>= writeList i
--         %by %rewrite sorted Nil %to True
--         %by %reflexivity
--     %==
--       (pure () >> pure Nil) >>= writeList i
--         %by %rewrite guard True %to pure ()
--         %by %reflexivity
--     %==
--       pure Nil >>= writeList i
--         %by %rewrite pure () >> pure Nil %to pure Nil
--         %by seq_identity_left () (pure Nil)
--     %==
--       writeList i Nil
--         %by pure_bind Nil (writeList i)
--     %==
--       pure it
--   |]

-- {-@ reflect iqsort_spec_aux1_Cons_aux @-}
-- iqsort_spec_aux1_Cons_aux :: Int -> Natural -> List Int -> M ()
-- iqsort_spec_aux1_Cons_aux p i xs =
--   (write i p >> writeList (S i) xs)
--     >> (read i >>= iqsort_aux1 i n)
--   where
--     n = length xs

-- {-@
-- iqsort_spec_aux1_Cons ::
--   (Equality (M Unit), Equality (M (List Int))) =>
--   p:Int -> i:Natural -> xs:List Int ->
--   EqualProp (M Unit)
--     {iqsort_spec_aux1 i (Cons p xs)}
--     {iqsort_spec_aux1_Cons_aux p i xs}
-- @-}
-- iqsort_spec_aux1_Cons :: (Equality (M ()), Equality (M (List Int))) => Int -> Natural -> List Int -> EqualityProp (M ())
-- iqsort_spec_aux1_Cons p i xs =
--   [eqpropchain|
--       iqsort_spec_aux1 i (Cons p xs)
--     %==
--       writeList i (Cons p xs) >> iqsort i (length (Cons p xs))
--     %==
--       writeList i (Cons p xs) >> iqsort i (S (length xs))
--         %by %rewrite length (Cons p xs) %to S (length xs)
--         %by %reflexivity
--     %==
--       writeList i (Cons p xs) >> iqsort i (S n)
--         %by %rewrite length xs %to n
--         %by %reflexivity
--     %==
--       writeList i (Cons p xs) >> (read i >>= iqsort_aux1 i n)
--         %by %rewrite iqsort i (S n)
--                  %to read i >>= iqsort_aux1 i n
--         %by %reflexivity
--     %==
--       (write i p >> writeList (S i) xs) >> (read i >>= iqsort_aux1 i n)
--         %by %rewrite writeList i (Cons p xs)
--                  %to write i p >> writeList (S i) xs
--         %by %reflexivity
--     %==
--       iqsort_spec_aux1_Cons_aux p i xs
--         %by %symmetry
--         %by %reflexivity
--   |]
--   where
--     n = length xs

-- {-@ reflect iqsort_spec_aux2_Cons_aux @-}
-- iqsort_spec_aux2_Cons_aux :: Int -> Natural -> List Int -> M ()
-- iqsort_spec_aux2_Cons_aux p i xs =
--   split xs
--     >>= permute_aux1 p
--     >>= guardBy sorted
--     >>= writeList i

-- {-@
-- iqsort_spec_aux2_Cons ::
--   (Equality (M Unit), Equality (M (List Int))) =>
--   p:Int -> i:Natural -> xs:List Int ->
--   EqualProp (M Unit)
--     {iqsort_spec_aux2 i (Cons p xs)}
--     {iqsort_spec_aux2_Cons_aux p i xs}
-- @-}
-- iqsort_spec_aux2_Cons :: (Equality (M ()), Equality (M (List Int))) => Int -> Natural -> List Int -> EqualityProp (M ())
-- iqsort_spec_aux2_Cons p i xs =
--   [eqpropchain|
--       iqsort_spec_aux2 i (Cons p xs)
--     %==
--       slowsort (Cons p xs) >>= writeList i
--     %==
--       (permute (Cons p xs) >>= guardBy sorted) >>= writeList i
--         %by %rewrite slowsort (Cons p xs)
--                  %to permute (Cons p xs) >>= guardBy sorted
--         %by %reflexivity
--     %==
--       ((split xs >>= permute_aux1 p) >>= guardBy sorted) >>= writeList i
--         %by %rewrite permute (Cons p xs)
--                  %to split xs >>= permute_aux1 p
--         %by %reflexivity
--     %==
--       iqsort_spec_aux2_Cons_aux p i xs
--         %by %symmetry
--         %by %reflexivity
--   |]

-- --
-- -- ipartl_spec_steps4to7_lemma1
-- --

-- {-@ reflect ipartl_spec_steps4to7_lemma1_aux2 @-}
-- ipartl_spec_steps4to7_lemma1_aux2 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_steps4to7_lemma1_aux2 p i x xs ys zs =
--   permute zs
--     >>= dispatch_aux1 x xs ys
--     >>= ipartl_spec_steps4to7_lemma1_aux2_aux p i

-- {-@ reflect ipartl_spec_steps4to7_lemma1_aux2_aux @-}
-- ipartl_spec_steps4to7_lemma1_aux2_aux :: Int -> Natural -> (List Int, List Int, List Int) -> M (Natural, Natural)
-- ipartl_spec_steps4to7_lemma1_aux2_aux p i (ys', zs', xs) =
--   writeList i (ys' ++ zs')
--     >> ipartl p i (length ys', length zs', length xs)

-- {-@
-- ipartl_spec_steps4to7_lemma1 ::
--   (Equality (M (Natural, Natural)), Equality (M (List Int, List Int, List Int))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   EqualProp (M (Natural, Natural))
--     {ipartl_spec_step4_aux1 p i x xs ys zs}
--     {ipartl_spec_steps4to7_lemma1_aux2 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps4to7_lemma1 :: (Equality (M (Natural, Natural)), Equality (M (List Int, List Int, List Int))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps4to7_lemma1 p i x xs ys zs =
--   [eqpropchain|
--       ipartl_spec_step4_aux1 p i x xs ys zs

--     %==
--       permute zs >>=
--         ipartl_spec_step4_aux1_aux p i x xs ys

--         %by %reflexivity

--     %==
--       permute zs >>= \zs' ->
--         ipartl_spec_step4_aux1_aux p i x xs ys zs'

--         %by %rewrite ipartl_spec_step4_aux1_aux p i x xs ys
--                  %to \zs' -> ipartl_spec_step4_aux1_aux p i x xs ys zs'
--         %by %extend zs'
--         %by %symmetry
--         %by %reflexivity

--     %==
--       permute zs >>= \zs' ->
--         ipartl_spec_steps4to7_lemma1_lemma_aux2 p i x xs ys zs'

--         %by %rewrite \zs' -> ipartl_spec_step4_aux1_aux p i x xs ys zs'
--                  %to \zs' -> ipartl_spec_steps4to7_lemma1_lemma_aux2 p i x xs ys zs'
--         %by %extend zs'
--         %by ipartl_spec_steps4to7_lemma1_lemma p i x xs ys zs'

--     %==
--       permute zs >>= \zs' ->
--         dispatch_aux1 x xs ys zs' >>=
--           ipartl_spec_steps4to7_lemma1_aux2_aux p i

--       %by %rewrite \zs' -> ipartl_spec_steps4to7_lemma1_lemma_aux2 p i x xs ys zs'
--                %to \zs' -> dispatch_aux1 x xs ys zs' >>= ipartl_spec_steps4to7_lemma1_aux2_aux p i
--       %by %extend zs'
--       %by %reflexivity

--     %==
--       permute zs >>=
--         (dispatch_aux1 x xs ys >=>
--           ipartl_spec_steps4to7_lemma1_aux2_aux p i)

--       %by %rewrite \zs' -> dispatch_aux1 x xs ys zs' >>= ipartl_spec_steps4to7_lemma1_aux2_aux p i
--                %to dispatch_aux1 x xs ys >=> ipartl_spec_steps4to7_lemma1_aux2_aux p i
--       %by %extend zs'
--       %by %symmetry
--       %by %reflexivity

--     %==
--       permute zs >>=
--         dispatch_aux1 x xs ys >>=
--           ipartl_spec_steps4to7_lemma1_aux2_aux p i

--       %by %symmetry
--       %by bind_associativity (permute zs) (dispatch_aux1 x xs ys) (ipartl_spec_steps4to7_lemma1_aux2_aux p i)

--     %==
--       ipartl_spec_steps4to7_lemma1_aux2 p i x xs ys zs

--         %by %symmetry
--         %by %reflexivity
--   |]

-- {-@ reflect ipartl_spec_steps4to7_lemma1_lemma_aux2 @-}
-- ipartl_spec_steps4to7_lemma1_lemma_aux2 :: Int -> Natural -> Int -> List Int -> List Int -> List Int -> M (Natural, Natural)
-- ipartl_spec_steps4to7_lemma1_lemma_aux2 p i x xs ys zs' =
--   dispatch_aux1 x xs ys zs'
--     >>= ipartl_spec_steps4to7_lemma1_aux2_aux p i

-- {-@
-- ipartl_spec_steps4to7_lemma1_lemma ::
--   (Equality (M (Natural, Natural)), Equality (M (List Int, List Int, List Int))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs':List Int ->
--   EqualProp (M (Natural, Natural))
--     {ipartl_spec_step4_aux1_aux p i x xs ys zs'}
--     {ipartl_spec_steps4to7_lemma1_lemma_aux2 p i x xs ys zs'}
-- @-}
-- ipartl_spec_steps4to7_lemma1_lemma :: (Equality (M (Natural, Natural)), Equality (M (List Int, List Int, List Int))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps4to7_lemma1_lemma p i x xs ys zs' =
--   [eqpropchain|
--       ipartl_spec_step4_aux1_aux p i x xs ys zs'

--     %==
--       writeList i (ys ++ Cons x Nil ++ zs') >>
--         ipartl p i (S (length ys), length zs', length xs)

--     %==
--       writeList i (ys ++ Cons x Nil ++ zs') >>
--         ipartl p i (length (ys ++ Cons x Nil), length zs', length xs)

--       %by %rewrite S (length ys)
--                %to length (ys ++ Cons x Nil)
--       %by %symmetry
--       %by %smt
--       %by length_snoc ys x

--     %==
--       writeList i ((ys ++ Cons x Nil) ++ zs') >>
--         ipartl p i (length (ys ++ Cons x Nil), length zs', length xs)

--         %by %rewrite ys ++ Cons x Nil ++ zs'
--                  %to (ys ++ Cons x Nil) ++ zs'
--         %by %smt
--         %by append_associativity ys (Cons x Nil) zs'

--     %==
--       ( \(ys', zs', xs) ->
--             writeList i (ys' ++ zs') >>
--               ipartl p i (length ys', length zs', length xs))
--         (ys ++ Cons x Nil, zs', xs)

--         %by %symmetry
--         %by %reflexivity

--     %==
--       pure (ys ++ Cons x Nil, zs', xs) >>= \(ys', zs', xs) ->
--         writeList i (ys' ++ zs') >>
--           ipartl p i (length ys', length zs', length xs)

--         %by %symmetry
--         %by pure_bind (ys ++ Cons x Nil, zs', xs) (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs))

--     %==
--       dispatch_aux1 x xs ys zs' >>= \(ys', zs', xs) ->
--         writeList i (ys' ++ zs') >>
--           ipartl p i (length ys', length zs', length xs)

--         %by %rewrite pure (ys ++ Cons x Nil, zs', xs)
--                  %to dispatch_aux1 x xs ys zs'
--         %by %symmetry
--         %by %reflexivity

--     %==
--       dispatch_aux1 x xs ys zs' >>=
--         ipartl_spec_steps4to7_lemma1_aux2_aux p i

--         %by %rewrite \(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)
--                  %to ipartl_spec_steps4to7_lemma1_aux2_aux p i
--         %by %extend (ys', zs', xs)
--         %by %symmetry
--         %by %reflexivity

--     %==
--       ipartl_spec_steps4to7_lemma1_lemma_aux2 p i x xs ys zs'

--       %by %symmetry
--       %by %reflexivity
--   |]

-- --
-- -- ipartl_spec_steps4to5_lemma1
-- --

-- {-@
-- ipartl_spec_steps4to5_lemma1 ::
--   (Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs':List Int ->
--   EqualProp (M (Natural, Natural))
--     {ipartl_spec_step4_aux1_aux p i x xs ys zs'}
--     {kleisli (dispatch_aux1 x xs ys) (ipartl_spec_step5_aux p i) zs'}
-- @-}
-- ipartl_spec_steps4to5_lemma1 :: (Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps4to5_lemma1 p i x xs ys zs' =
--   [eqpropchain|
--       ipartl_spec_step4_aux1_aux p i x xs ys zs'

--     %==
--       writeList i (ys ++ Cons x Nil ++ zs') >> ipartl p i (S (length ys), length zs', length xs)

--         %by %reflexivity

--     %==
--       writeList i (ys ++ Cons x Nil ++ zs') >> ipartl p i (length (ys ++ Cons x Nil), length zs', length xs)

--         %by %rewrite S (length ys)
--                  %to length (ys ++ Cons x Nil)
--         %by %symmetry
--         %by %smt
--         %by length_snoc ys x

--     %==
--       writeList i ((ys ++ Cons x Nil) ++ zs') >> ipartl p i (length (ys ++ Cons x Nil), length zs', length xs)

--         %by %rewrite ys ++ Cons x Nil ++ zs'
--                  %to (ys ++ Cons x Nil) ++ zs'
--         %by %smt
--         %by append_associativity ys (Cons x Nil) zs'

--     %==
--       (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) (ys ++ Cons x Nil, zs', xs)

--         %by %symmetry
--         %by %reflexivity

--     %==
--       compose (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) (\zs' -> (ys ++ Cons x Nil, zs', xs)) zs'

--         %by %symmetry
--         %by %reflexivity

--     %==
--       kleisli (compose pure (\zs' -> (ys ++ Cons x Nil, zs', xs))) (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) zs'

--         %by %symmetry
--         %by pure_kleisli
--               (\zs' -> (ys ++ Cons x Nil, zs', xs))
--               (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs))
--               zs'

--     %==
--       kleisli (\zs' -> pure ((\zs' -> (ys ++ Cons x Nil, zs', xs)) zs')) (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) zs'

--         %by %rewrite compose pure (\zs' -> (ys ++ Cons x Nil, zs', xs))
--                  %to \zs' -> pure ((\zs' -> (ys ++ Cons x Nil, zs', xs)) zs')
--         %by %extend zs'
--         %by %reflexivity

--     %==
--       kleisli (\zs' -> pure ((\zs' -> (ys ++ Cons x Nil, zs', xs)) zs')) (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) zs'

--         %by %symmetry
--         %by %reflexivity

--     %==
--       kleisli (\zs' -> pure (ys ++ Cons x Nil, zs', xs)) (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) zs'

--         %by %rewrite \zs' -> pure ((\zs' -> (ys ++ Cons x Nil, zs', xs)) zs')
--                  %to \zs' -> pure (ys ++ Cons x Nil, zs', xs)
--         %by %extend zs'
--         %by %symmetry
--         %by %reflexivity

--     %==
--       kleisli (dispatch_aux1 x xs ys) (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) zs'

--         %by %rewrite \zs' -> pure (ys ++ Cons x Nil, zs', xs)
--                  %to dispatch_aux1 x xs ys
--         %by %extend zs'
--         %by %symmetry
--         %by %reflexivity

--     %==
--       kleisli (dispatch_aux1 x xs ys) (ipartl_spec_step5_aux p i) zs'

--         %by %rewrite \(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)
--                  %to ipartl_spec_step5_aux p i
--         %by %extend (ys', zs', xs)
--         %by %symmetry
--         %by %reflexivity
--   |]

-- --
-- -- ipartl_spec_steps4to5_lemma2
-- --

-- {-@
-- ipartl_spec_steps4to5_lemma2 ::
--   (Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs':List Int ->
--   EqualProp (M (Natural, Natural))
--     {ipartl_spec_step4_aux2_aux p i xs ys zs'}
--     {kleisli (dispatch_aux2 xs ys) (ipartl_spec_step5_aux p i) zs'}
-- @-}
-- ipartl_spec_steps4to5_lemma2 :: (Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps4to5_lemma2 p i x xs ys zs' =
--   [eqpropchain|
--       ipartl_spec_step4_aux2_aux p i xs ys zs'

--     %==
--       writeList i (ys ++ zs') >> ipartl p i (length ys, length zs', length xs)

--         %by %reflexivity

--     %==
--       ipartl_spec_step5_aux p i (ys, zs', xs)

--         %by %symmetry
--         %by %reflexivity

--     %==
--       pure (ys, zs', xs) >>= ipartl_spec_step5_aux p i

--         %by %symmetry
--         %by pure_bind (ys, zs', xs) (ipartl_spec_step5_aux p i)

--     %==
--       dispatch_aux2 xs ys zs' >>= ipartl_spec_step5_aux p i

--         %by %rewrite pure (ys, zs', xs)
--                  %to dispatch_aux2 xs ys zs'
--         %by %symmetry
--         %by %reflexivity

--     %==
--       kleisli (dispatch_aux2 xs ys) (ipartl_spec_step5_aux p i) zs'

--         %by %symmetry
--         %by %reflexivity
--   |]

-- --
-- -- ipartl_spec_steps4to5
-- --

-- {-@
-- ipartl_spec_steps4to5 ::
--   (Equality (() -> M (Natural, Natural)), Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   EqualProp (M (Natural, Natural))
--     {ipartl_spec_step4 p i x xs ys zs}
--     {ipartl_spec_step5 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps4to5 :: (Equality (() -> M (Natural, Natural)), Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps4to5 p i x xs ys zs =
--   [eqpropchain|
--       ipartl_spec_step4 p i x xs ys zs

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         if x <= p
--           then ipartl_spec_step4_aux1 p i x xs ys zs
--           else ipartl_spec_step4_aux2 p i x xs ys zs

--         %by %reflexivity

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         if x <= p
--           then permute zs >>= ipartl_spec_step4_aux1_aux p i x xs ys
--           else permute (zs ++ Cons x Nil) >>= ipartl_spec_step4_aux2_aux p i xs ys

--         %by %reflexivity

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         if x <= p
--           then permute zs >>= ipartl_spec_step4_aux1_aux p i x xs ys
--           else permute (zs ++ Cons x Nil) >>= ipartl_spec_step4_aux2_aux p i xs ys

--         %by %reflexivity

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         if x <= p
--           then permute zs >>= kleisli (dispatch_aux1 x xs ys) (ipartl_spec_step5_aux p i)
--           else permute (zs ++ Cons x Nil) >>= ipartl_spec_step4_aux2_aux p i xs ys

--         %by %rewrite ipartl_spec_step4_aux1_aux p i x xs ys
--                  %to kleisli (dispatch_aux1 x xs ys) (ipartl_spec_step5_aux p i)
--         %by %extend zs'
--         %by ipartl_spec_steps4to5_lemma1 p i x xs ys zs'

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         if x <= p
--           then permute zs >>= (dispatch_aux1 x xs ys >=> ipartl_spec_step5_aux p i)
--           else permute (zs ++ Cons x Nil) >>= ipartl_spec_step4_aux2_aux p i xs ys

--         %by %rewrite kleisli (dispatch_aux1 x xs ys) (ipartl_spec_step5_aux p i)
--                  %to dispatch_aux1 x xs ys >=> ipartl_spec_step5_aux p i
--         %by %extend zs'
--         %by %reflexivity

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         if x <= p
--           then permute zs >>= dispatch_aux1 x xs ys >>= ipartl_spec_step5_aux p i
--           else permute (zs ++ Cons x Nil) >>= ipartl_spec_step4_aux2_aux p i xs ys

--         %by %rewrite permute zs >>= (dispatch_aux1 x xs ys >=> ipartl_spec_step5_aux p i)
--                  %to permute zs >>= dispatch_aux1 x xs ys >>= ipartl_spec_step5_aux p i
--         %by %symmetry
--         %by bind_associativity (permute zs) (dispatch_aux1 x xs ys) (ipartl_spec_step5_aux p i)

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         if x <= p
--           then permute zs >>= dispatch_aux1 x xs ys >>= ipartl_spec_step5_aux p i
--           else permute (zs ++ Cons x Nil) >>= kleisli (dispatch_aux2 xs ys) (ipartl_spec_step5_aux p i)

--         %by %rewrite ipartl_spec_step4_aux2_aux p i xs ys
--                  %to kleisli (dispatch_aux2 xs ys) (ipartl_spec_step5_aux p i)
--         %by %extend zs'
--         %by ipartl_spec_steps4to5_lemma2 p i x xs ys zs'

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         if x <= p
--           then permute zs >>= dispatch_aux1 x xs ys >>= ipartl_spec_step5_aux p i
--           else permute (zs ++ Cons x Nil) >>= (dispatch_aux2 xs ys >=> ipartl_spec_step5_aux p i)

--         %by %rewrite kleisli (dispatch_aux2 xs ys) (ipartl_spec_step5_aux p i)
--                  %to dispatch_aux2 xs ys >=> ipartl_spec_step5_aux p i
--         %by %extend zs'
--         %by %reflexivity

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         if x <= p
--           then permute zs >>= dispatch_aux1 x xs ys >>= ipartl_spec_step5_aux p i
--           else permute (zs ++ Cons x Nil) >>= dispatch_aux2 xs ys >>= ipartl_spec_step5_aux p i

--         %by %rewrite permute (zs ++ Cons x Nil) >>= (dispatch_aux2 xs ys >=> ipartl_spec_step5_aux p i)
--                  %to permute (zs ++ Cons x Nil) >>= dispatch_aux2 xs ys >>= ipartl_spec_step5_aux p i
--         %by %symmetry
--         %by bind_associativity (permute (zs ++ Cons x Nil)) (dispatch_aux2 xs ys) (ipartl_spec_step5_aux p i)

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         ( if x <= p
--             then permute zs >>= dispatch_aux1 x xs ys
--             else permute (zs ++ Cons x Nil) >>= dispatch_aux2 xs ys
--         ) >>=
--           ipartl_spec_step5_aux p i

--         %by %symmetry
--         %by seq_if_bind
--               (writeList (S (i + length ys + length zs)) xs) (x <= p)
--               (permute zs >>= dispatch_aux1 x xs ys)
--               (permute (zs ++ Cons x Nil) >>= dispatch_aux2 xs ys)
--               (ipartl_spec_step5_aux p i)

--     %==
--       writeList (S (i + length ys + length zs)) xs >>
--         dispatch x p (ys, zs, xs) >>=
--           ipartl_spec_step5_aux p i

--       %by %rewrite if x <= p then permute zs >>= dispatch_aux1 x xs ys else permute (zs ++ Cons x Nil) >>= dispatch_aux2 xs ys
--                %to dispatch x p (ys, zs, xs)
--       %by %symmetry
--       %by %reflexivity

--     %==
--       ipartl_spec_step5 p i x xs ys zs
--         %by %symmetry
--         %by %reflexivity
--   |]

-- --
-- -- ipartl_spec_steps6to7_lemma
-- --

-- {-@
-- ipartl_spec_steps6to7_lemma ::
--   (Equality (() -> M (Natural, Natural)), Equality (List Int), Equality (M ()), Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) =>
--   p:Int -> i:Natural -> ys'_zs'_xs:(List Int, List Int, List Int) ->
--   EqualProp (M (Natural, Natural))
--     {ipartl_spec_step6_aux p i ys'_zs'_xs}
--     {kleisli (writeListToLength3 i) (ipartl p i) ys'_zs'_xs}
-- @-}
-- ipartl_spec_steps6to7_lemma :: (Equality (() -> M (Natural, Natural)), Equality (List Int), Equality (M ()), Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) => Int -> Natural -> (List Int, List Int, List Int) -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps6to7_lemma p i (ys', zs', xs) =
--   [eqpropchain|
--       ipartl_spec_step6_aux p i (ys', zs', xs)

--     %==
--       writeList i (ys' ++ zs') >>
--         writeList (i + length (ys' ++ zs')) xs >>
--           ipartl p i (length ys', length zs', length xs)

--         %by %reflexivity

--     %==
--       writeList i ((ys' ++ zs') ++ xs) >>
--         ipartl p i (length ys', length zs', length xs)

--         %by %rewrite writeList i (ys' ++ zs') >> writeList (i + length (ys' ++ zs')) xs
--                  %to writeList i ((ys' ++ zs') ++ xs)
--         %by %symmetry
--         %by writeList_append i (ys' ++ zs') xs

--     %==
--       writeList i (ys' ++ zs' ++ xs) >>
--         ipartl p i (length ys', length zs', length xs)

--         %by %rewrite (ys' ++ zs') ++ xs
--                  %to ys' ++ zs' ++ xs
--         %by %symmetry
--         %by %smt
--         %by append_associativity ys' zs' xs

--     %==
--       writeList i (ys' ++ zs' ++ xs) >>
--         ( pure (length ys', length zs', length xs) >>=
--             ipartl p i
--         )

--         %by %rewrite ipartl p i (length ys', length zs', length xs)
--                  %to pure (length ys', length zs', length xs) >>= ipartl p i
--         %by %symmetry
--         %by pure_bind (length ys', length zs', length xs) (ipartl p i)

--     %==
--       writeList i (ys' ++ zs' ++ xs) >>
--         pure (length ys', length zs', length xs) >>=
--           ipartl p i

--         %by %symmetry
--         %by seq_bind_associativity
--               (writeList i (ys' ++ zs' ++ xs))
--               (pure (length ys', length zs', length xs))
--               (ipartl p i)

--     %==
--       writeListToLength3 i (ys', zs', xs) >>=
--         ipartl p i

--         %by %rewrite writeList i (ys' ++ zs' ++ xs) >> pure (length ys', length zs', length xs)
--                  %to writeListToLength3 i (ys', zs', xs)
--         %by %symmetry
--         %by %reflexivity

--     %==
--       kleisli
--         (writeListToLength3 i)
--         (ipartl p i)
--         (ys', zs', xs)

--         %by %symmetry
--         %by %reflexivity
--   |]

-- --
-- -- ipartl_spec_steps5to6
-- --

-- {-@
-- ipartl_spec_steps5to6 ::
--   (Equality (M Natural), Equality (M Unit), Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   EqualProp (M (Natural, Natural))
--     {ipartl_spec_step5 p i x xs ys zs}
--     {ipartl_spec_step6 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps5to6 :: (Equality (M Natural), Equality (M Unit), Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps5to6 p i x xs ys zs =
--   [eqpropchain|
--     ipartl_spec_step5 p i x xs ys zs

--   %==
--     writeList (S (i + length ys + length zs)) xs >>
--       dispatch x p (ys, zs, xs) >>=
--         ipartl_spec_step5_aux p i

--       %-- defn ipartl_spec_step5
--       %by %reflexivity

--   %==
--     writeList (S (i + length ys + length zs)) xs >>
--       dispatch x p (ys, zs, xs) >>= \(ys', zs', xs) ->
--         writeList i (ys' ++ zs') >>
--           ipartl p i (length ys', length zs', length xs)

--       %-- defn ipartl_spec_step5_aux
--       %by %rewrite ipartl_spec_step5_aux p i
--                %to \(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)
--       %by %extend ys'_zs'_xs
--       %by %reflexivity

--   %==
--     writeList (S (i + length (ys ++ zs))) xs >>
--       dispatch x p (ys, zs, xs) >>= \(ys', zs', xs) ->
--         writeList i (ys' ++ zs') >>
--           ipartl p i (length ys', length zs', length xs)

--       %-- length_append
--       %by %rewrite length ys + length zs
--                %to length (ys ++ zs)
--       %by %smt
--       %by length_append ys zs

--   %==
--     dispatch x p (ys, zs, xs) >>=
--       seqk
--         (writeList (i + length (ys ++ zs)) xs)
--         ( \(ys', zs', xs) ->
--             writeList i (ys' ++ zs') >>
--               ipartl p i (length ys', length zs', length xs)
--         )

--       %-- dispatch_commutativity_seq_bind
--       %by dispatch_commutativity_seq_bind
--             (i + length (ys ++ zs))
--             xs
--             x
--             p
--             (ys, zs, xs)
--             (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs))

--   %==
--     dispatch x p (ys, zs, xs) >>= \(ys', zs', xs) ->
--       writeList (i + length (ys ++ zs)) xs >>
--         ( \(ys', zs', xs) ->
--             writeList i (ys' ++ zs') >>
--               ipartl p i (length ys', length zs', length xs)
--         ) (ys', zs', xs)

--       %by %rewrite seqk (writeList (i + length (ys ++ zs)) xs) (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs))
--                %to \(ys', zs', xs) -> writeList (i + length (ys ++ zs)) xs >> (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) (ys', zs', xs)
--       %by %extend (ys', zs', xs)
--       %by %reflexivity

--   %==
--     dispatch x p (ys, zs, xs) >>= \(ys', zs', xs) ->
--       writeList (i + length (ys ++ zs)) xs >>
--         ( writeList i (ys' ++ zs') >>
--             ipartl p i (length ys', length zs', length xs)
--         )

--       %-- extend, eta-equivalence
--       %by %rewrite \(ys', zs', xs) -> writeList (i + length (ys ++ zs)) xs >> (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) (ys', zs', xs)
--                %to \(ys', zs', xs) -> writeList (i + length (ys ++ zs)) xs >> (writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs))
--       %by %extend (ys', zs', xs)
--       %by %rewrite (\(ys', zs', xs) -> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) (ys', zs', xs)
--                %to writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)
--       %by %reflexivity

--   %==
--     dispatch x p (ys, zs, xs) >>= \(ys', zs', xs) ->
--       writeList (i + length (ys ++ zs)) xs >>
--         writeList i (ys' ++ zs') >>
--           ipartl p i (length ys', length zs', length xs)

--       %-- extend, seq_associativity
--       %by %rewrite \(ys', zs', xs) -> writeList (i + length (ys ++ zs)) xs >> (writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs))
--                %to \(ys', zs', xs) -> writeList (i + length (ys ++ zs)) xs >> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)
--       %by %extend (ys', zs', xs)
--       %by seq_associativity
--             (writeList (i + length (ys ++ zs)) xs)
--             (writeList i (ys' ++ zs'))
--             (ipartl p i (length ys', length zs', length xs))

--   %==
--     dispatch x p (ys, zs, xs) >>= \(ys', zs', xs) ->
--       writeList (i + length (ys' ++ zs')) xs >>
--         writeList i (ys' ++ zs') >>
--           ipartl p i (length ys', length zs', length xs)

--       %-- extend,
--       %by %rewrite \(ys', zs', xs) -> writeList (i + length (ys ++ zs)) xs >> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)
--                %to \(ys', zs', xs) -> writeList (i + length (ys' ++ zs')) xs >> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)
--       %by %extend (ys', zs', xs)
--       %by reflexivity ((\(ys', zs', xs) -> writeList (i + length (ys ++ zs)) xs >> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)) (ys', zs', xs))
--         ? dispatch_preserves_length_append_ys_zs x p xs ys zs

--   %==
--     dispatch x p (ys, zs, xs) >>= \(ys', zs', xs) ->
--       writeList i (ys' ++ zs') >>
--         writeList (i + length (ys' ++ zs')) xs >>
--           ipartl p i (length ys', length zs', length xs)

--       %-- extend, writeList_commutativity
--       %by %rewrite \(ys', zs', xs) -> writeList (i + length (ys' ++ zs')) xs >> writeList i (ys' ++ zs') >> ipartl p i (length ys', length zs', length xs)
--                %to \(ys', zs', xs) -> writeList i (ys' ++ zs') >> writeList (i + length (ys' ++ zs')) xs >> ipartl p i (length ys', length zs', length xs)
--       %by %extend (ys', zs', xs)
--       %by %rewrite writeList (i + length (ys' ++ zs')) xs >> writeList i (ys' ++ zs')
--                %to writeList i (ys' ++ zs') >> writeList (i + length (ys' ++ zs')) xs
--       %by %symmetry
--       %by writeList_commutativity  i (ys' ++ zs') xs

--   %==
--     dispatch x p (ys, zs, xs) >>=
--       ipartl_spec_step6_aux p i

--       %-- defn ipartl_spec_step6_aux
--       %by %rewrite \(ys', zs', xs) -> writeList i (ys' ++ zs') >> writeList (i + length (ys' ++ zs')) xs >> ipartl p i (length ys', length zs', length xs)
--                %to ipartl_spec_step6_aux p i
--       %by %extend (ys', zs', xs)
--       %by %symmetry
--       %by %reflexivity

--   %==
--     ipartl_spec_step6 p i x xs ys zs

--       %-- defn ipartl_spec_step6
--       %by %symmetry
--       %by %reflexivity

--   |]

-- --
-- -- ipartl_spec_steps6to7
-- --

-- {-@
-- ipartl_spec_steps6to7 ::
--   (Equality (() -> M (Natural, Natural)), Equality (M ()), Equality (List Int), Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   EqualProp (M (Natural, Natural))
--     {ipartl_spec_step6 p i x xs ys zs}
--     {ipartl_spec_step7 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps6to7 :: (Equality (() -> M (Natural, Natural)), Equality (M ()), Equality (List Int), Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps6to7 p i x xs ys zs =
--   [eqpropchain|
--       ipartl_spec_step6 p i x xs ys zs

--     %==
--       dispatch x p (ys, zs, xs) >>=
--         ipartl_spec_step6_aux p i

--         %by %reflexivity

--     %==
--       dispatch x p (ys, zs, xs) >>=
--         kleisli (writeListToLength3 i) (ipartl p i)

--         %by %rewrite ipartl_spec_step6_aux p i
--                  %to kleisli (writeListToLength3 i) (ipartl p i)
--         %by %extend (ys', zs', xs)
--         %by ipartl_spec_steps6to7_lemma p i (ys', zs', xs)

--     %==
--       dispatch x p (ys, zs, xs) >>=
--         writeListToLength3 i >>=
--           ipartl p i

--         %by %symmetry
--         %by bind_associativity_nofix (dispatch x p (ys, zs, xs)) (writeListToLength3 i) (ipartl p i)

--     %== -- defn ipartl_spec_step7
--       ipartl_spec_step7 p i x xs ys zs

--         %by %symmetry
--         %by %reflexivity
--   |]

-- --
-- -- ipartl_spec_steps4to7
-- --

-- -- uses:
-- -- - defn of `dispatch`
-- -- - function calls distribute into `if`
-- -- - `permute_preserves_length`
-- -- - commutativity
-- -- - [ref 9]
-- {-@
-- ipartl_spec_steps4to7 ::
--   (Equality (M Natural), Equality (() -> M (Natural, Natural)), Equality (List Int), Equality (M Unit), Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step4 p i x xs ys zs}
--     {ipartl_spec_step7 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps4to7 :: (Equality (M Natural), Equality (() -> M (Natural, Natural)), Equality (List Int), Equality (M Unit), Equality (M (Natural, Natural)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps4to7 p i x xs ys zs =
--   (refinesplus_equalprop (ipartl_spec_step4 p i x xs ys zs) (ipartl_spec_step7 p i x xs ys zs))
--     [eqpropchain|
--         ipartl_spec_step4 p i x xs ys zs

--       %==
--         ipartl_spec_step5 p i x xs ys zs

--           %by ipartl_spec_steps4to5 p i x xs ys zs

--       %==
--         ipartl_spec_step6 p i x xs ys zs

--           %by ipartl_spec_steps5to6 p i x xs ys zs

--       %==
--         ipartl_spec_step7 p i x xs ys zs

--           %by ipartl_spec_steps6to7 p i x xs ys zs
--     |]

-- --
-- -- ipartl_spec_steps7to8_lemma
-- --

-- {-@ reflect ipartl_spec_steps7to8_lemma_aux1 @-}
-- ipartl_spec_steps7to8_lemma_aux1 :: Int -> Natural -> (List Int, List Int, List Int) -> M (Natural, Natural)
-- ipartl_spec_steps7to8_lemma_aux1 p i (ys', zs', xs) =
--   kleisli
--     (writeListToLength3 i)
--     (ipartl p i)
--     (ys', zs', xs)

-- {-@ reflect ipartl_spec_steps7to8_lemma_aux2 @-}
-- ipartl_spec_steps7to8_lemma_aux2 :: Int -> Natural -> (List Int, List Int, List Int) -> M (Natural, Natural)
-- ipartl_spec_steps7to8_lemma_aux2 p i (ys', zs', xs) =
--   kleisli
--     (partl' p)
--     (writeListToLength2 i)
--     (ys', zs', xs)

-- {-@
-- ipartl_spec_steps7to8_lemma ::
--   (Equality (M Natural), Equality (() -> M ()), Equality (List Int -> M (Natural, Natural)), Equality (() -> M (Natural, Natural)), Equality (M Int), Equality (M (List Int)), Equality (M (List Int, List Int)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int)), Equality (M (Natural, Natural)), Equality (M Unit), Equality (List Int)) =>
--   p:Int -> i:Natural -> ys'_zs'_xs:(List Int, List Int, List Int) ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_steps7to8_lemma_aux1 p i ys'_zs'_xs}
--     {ipartl_spec_steps7to8_lemma_aux2 p i ys'_zs'_xs}
-- @-}
-- ipartl_spec_steps7to8_lemma :: (Equality (M Natural), Equality (() -> M ()), Equality (List Int -> M (Natural, Natural)), Equality (() -> M (Natural, Natural)), Equality (M Int), Equality (M (List Int)), Equality (M (List Int, List Int)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int)), Equality (M (Natural, Natural)), Equality (M Unit), Equality (List Int)) => Int -> Natural -> (List Int, List Int, List Int) -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps7to8_lemma p i (ys', zs', xs) =
--   (refinesplus_transitivity aux1 aux2 aux4)
--     step1
--     ( (refinesplus_transitivity aux2 aux3 aux4)
--         step2
--         step3
--     )
--   where
--     aux1 = kleisli (writeListToLength3 i) (ipartl p i) (ys', zs', xs)
--     aux2 = ipartl_spec_aux1 p i xs ys' zs'
--     aux3 = ipartl_spec_aux2 p i xs ys' zs'
--     aux4 = kleisli (partl' p) (writeListToLength2 i) (ys', zs', xs)
--     step1 =
--       (refinesplus_equalprop aux1 aux2)
--         [eqpropchain|
--             kleisli
--               (writeListToLength3 i)
--               (ipartl p i)
--               (ys', zs', xs)

--           %== -- defn kleisli
--             writeListToLength3 i (ys', zs', xs) >>=
--               ipartl p i

--               %by %reflexivity

--           %== -- defn writeListToLength3
--             writeList i (ys' ++ zs' ++ xs) >>
--               pure (length ys', length zs', length xs) >>=
--                 ipartl p i

--               %by %rewrite writeListToLength3 i (ys', zs', xs)
--                       %to writeList i (ys' ++ zs' ++ xs) >> pure (length ys', length zs', length xs)
--               %by %reflexivity

--           %== -- seq_bind_associativity
--             writeList i (ys' ++ zs' ++ xs) >>
--               ( pure (length ys', length zs', length xs) >>=
--                   ipartl p i
--               )

--               %by seq_bind_associativity
--                     (writeList i (ys' ++ zs' ++ xs))
--                     (pure (length ys', length zs', length xs))
--                     (ipartl p i)

--           %== -- pure_bind
--             writeList i (ys' ++ zs' ++ xs) >>
--               ipartl p i (length ys', length zs', length xs)

--               %by %rewrite pure (length ys', length zs', length xs) >>= ipartl p i
--                       %to ipartl p i (length ys', length zs', length xs)
--               %by pure_bind (length ys', length zs', length xs) (ipartl p i)

--           %== -- defn ipartl_spec_aux1
--             ipartl_spec_aux1 p i xs ys' zs'

--               %by %symmetry
--               %by %reflexivity
--         |]
--     step2 = ipartl_spec p i xs ys' zs'
--     step3 =
--       (refinesplus_equalprop aux3 aux4)
--         [eqpropchain|
--             ipartl_spec_aux2 p i xs ys' zs'

--           %== -- defn ipartl_spec_aux2
--             partl' p (ys', zs', xs) >>=
--               writeListToLength2 i

--               %by %reflexivity

--           %== -- defn kleisli
--             kleisli
--               (partl' p)
--               (writeListToLength2 i)
--               (ys', zs', xs)

--               %by %symmetry
--               %by %reflexivity
--         |]

-- --
-- -- ipartl_spec_steps7to8
-- --

-- -- uses:
-- -- - monad laws
-- -- - inductive hypothesis
-- {-@
-- ipartl_spec_steps7to8 ::
--   (Equality (M Natural), Equality (() -> M ()), Equality (List Int -> M (Natural, Natural)), Equality (() -> M (Natural, Natural)), Equality (M Int), Equality (M (List Int)), Equality (M (List Int, List Int)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int)), Equality (M (Natural, Natural)), Equality (M Unit), Equality (List Int)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step7 p i x xs ys zs}
--     {ipartl_spec_step8 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps7to8 :: (Equality (M Natural), Equality (() -> M ()), Equality (List Int -> M (Natural, Natural)), Equality (() -> M (Natural, Natural)), Equality (M Int), Equality (M (List Int)), Equality (M (List Int, List Int)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int)), Equality (M (Natural, Natural)), Equality (M Unit), Equality (List Int)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps7to8 p i x xs ys zs =
--   (refinesplus_transitivity aux1 aux2 aux4)
--     step1
--     ( (refinesplus_transitivity aux2 aux3 aux4)
--         step2
--         step3
--     )
--   where
--     aux1 = ipartl_spec_step7 p i x xs ys zs
--     aux2 = dispatch x p (ys, zs, xs) >>= ipartl_spec_steps7to8_lemma_aux1 p i
--     aux3 = dispatch x p (ys, zs, xs) >>= ipartl_spec_steps7to8_lemma_aux2 p i
--     aux4 = ipartl_spec_step8 p i x xs ys zs
--     step1 =
--       (refinesplus_equalprop aux1 aux2)
--         [eqpropchain|
--             ipartl_spec_step7 p i x xs ys zs

--           %== -- defn ipartl_spec_step7
--             dispatch x p (ys, zs, xs) >>=
--               writeListToLength3 i >>=
--                 ipartl p i

--               %by %reflexivity

--           %== -- bind_associativity
--             dispatch x p (ys, zs, xs) >>=
--               kleisli
--                 (writeListToLength3 i)
--                 (ipartl p i)

--               %by bind_associativity_nofix
--                     (dispatch x p (ys, zs, xs))
--                     (writeListToLength3 i)
--                     (ipartl p i)

--           %== -- eta-equivalence
--             dispatch x p (ys, zs, xs) >>= \(ys', zs', xs) ->
--               kleisli
--                 (writeListToLength3 i)
--                 (ipartl p i)
--                 (ys', zs', xs)

--               %by %rewrite kleisli (writeListToLength3 i) (ipartl p i)
--                        %to \(ys', zs', xs) -> kleisli (writeListToLength3 i) (ipartl p i) (ys', zs', xs)
--               %by %extend (ys', zs', xs)
--               %by %symmetry
--               %by %reflexivity
--       |]
--     step2 =
--       refinesplus_substitutabilityF
--         step2_aux
--         (ipartl_spec_steps7to8_lemma_aux1 p i)
--         (ipartl_spec_steps7to8_lemma_aux2 p i)
--         (\k1 k2 -> reflexivity (step2_aux k1 <+> step2_aux k2))
--         (ipartl_spec_steps7to8_lemma p i)
--     step2_aux k = dispatch x p (ys, zs, xs) >>= k
--     step3 =
--       (refinesplus_equalprop aux3 aux4)
--         [eqpropchain|
--             dispatch x p (ys, zs, xs) >>= \(ys', zs', xs) ->
--               kleisli
--                 (partl' p)
--                 (writeListToLength2 i)
--                 (ys', zs', xs)

--           %== -- eta-equivalence
--             dispatch x p (ys, zs, xs) >>=
--               kleisli
--                 (partl' p)
--                 (writeListToLength2 i)

--               %by %rewrite \(ys', zs', xs) -> kleisli (partl' p) (writeListToLength2 i) (ys', zs', xs)
--                        %to kleisli (partl' p) (writeListToLength2 i)
--               %by %extend (ys', zs', xs)
--               %by %reflexivity

--           %== -- bind_associativity
--             dispatch x p (ys, zs, xs) >>=
--               partl' p >>=
--                 writeListToLength2 i

--               %by %symmetry
--               %by bind_associativity_nofix
--                     (dispatch x p (ys, zs, xs))
--                     (partl' p)
--                     (writeListToLength2 i)

--           %== -- defn ipartl_spec_step8
--             ipartl_spec_step8 p i x xs ys zs

--               %by %symmetry
--               %by %reflexivity
--         |]

-- -- uses:
-- -- - defn of `partl`'
-- {-@
-- ipartl_spec_steps8to9 ::
--   (Equality (M (Natural, Natural)), Equality (M (List Int, List Int))) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step8 p i x xs ys zs}
--     {ipartl_spec_step9 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps8to9 :: (Equality (M (Natural, Natural)), Equality (M (List Int, List Int))) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps8to9 p i x xs ys zs =
--   ( refinesplus_equalprop
--       (ipartl_spec_step8 p i x xs ys zs)
--       (ipartl_spec_step9 p i x xs ys zs)
--   )
--     [eqpropchain|
--         ipartl_spec_step8 p i x xs ys zs

--       %== -- defn ipartl_spec_step8
--         dispatch x p (ys, zs, xs) >>=
--           partl' p >>=
--             writeListToLength2 i

--           %by %reflexivity

--       %== -- defn partl'
--         partl' p (ys, zs, Cons x xs) >>=
--           writeListToLength2 i

--           %by %rewrite dispatch x p (ys, zs, xs) >>= partl' p
--                    %to partl' p (ys, zs, Cons x xs)
--           %by %symmetry
--           %by %reflexivity

--       %== -- defn ipartl_spec_aux2
--         ipartl_spec_aux2 p i (Cons x xs) ys zs

--           %by %symmetry
--           %by %reflexivity

--       %== -- defn ipartl_spec_step9
--         ipartl_spec_step9 p i x xs ys zs

--           %by %symmetry
--           %by %reflexivity
--   |]

-- --
-- -- ipartl_spec_steps
-- --

-- {-@
-- ipartl_spec_steps ::
--   (Equality (M Natural), Equality (() -> M ()), Equality (List Int -> M (Natural, Natural)), Equality (() -> M (Natural, Natural)), Equality (M (List Int)), Equality (M Int), Equality (M (List Int, List Int)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int)), Equality (M (Natural, Natural)), Equality (M Unit), Equality (List Int)) =>
--   p:Int -> i:Natural -> x:Int -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_step1 p i x xs ys zs}
--     {ipartl_spec_step9 p i x xs ys zs}
-- @-}
-- ipartl_spec_steps :: (Equality (M Natural), Equality (() -> M ()), Equality (List Int -> M (Natural, Natural)), Equality (() -> M (Natural, Natural)), Equality (M (List Int)), Equality (M Int), Equality (M (List Int, List Int)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int)), Equality (M (Natural, Natural)), Equality (M Unit), Equality (List Int)) => Int -> Natural -> Int -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec_steps p i x xs ys zs =
--   (refinesplus_transitivity step1 step3 step9)
--     -- 1 refines 3
--     (ipartl_spec_steps1to3 p i x xs ys zs)
--     ( (refinesplus_transitivity step3 step4 step9)
--         -- 3 refines 4
--         (ipartl_spec_steps3to4 p i x xs ys zs)
--         ( (refinesplus_transitivity step4 step7 step9)
--             -- 4 refines 7
--             (ipartl_spec_steps4to7 p i x xs ys zs)
--             ( (refinesplus_transitivity step7 step8 step9)
--                 -- 7 refines 8
--                 (ipartl_spec_steps7to8 p i x xs ys zs)
--                 -- 8 refines 9
--                 (ipartl_spec_steps8to9 p i x xs ys zs)
--             )
--         )
--     )
--   where
--     -- steps
--     step1 = ipartl_spec_step1 p i x xs ys zs
--     step3 = ipartl_spec_step3 p i x xs ys zs
--     step4 = ipartl_spec_step4 p i x xs ys zs
--     step7 = ipartl_spec_step7 p i x xs ys zs
--     step8 = ipartl_spec_step8 p i x xs ys zs
--     step9 = ipartl_spec_step9 p i x xs ys zs

-- --
-- -- ipartl_spec
-- --

-- -- [ref 10]
-- -- I am ignoring the previous spec for ipartl given at the top of the same page
-- -- as [ref 10], but I'm pretty sure that's ok. That spec isn't used anywhere
-- -- right?
-- {-@
-- ipartl_spec ::
--   (Equality (M Natural), Equality (() -> M ())m Equality (List Int -> M (Natural, Natural)), Equality (() -> M (Natural, Natural)), Equality (M Int), Equality (M (List Int)), Equality (M (List Int, List Int)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int)), Equality (M (Natural, Natural)), Equality (M Unit), Equality (List Int)) =>
--   p:Int -> i:Natural -> xs:List Int -> ys:List Int -> zs:List Int ->
--   RefinesPlus (Natural, Natural)
--     {ipartl_spec_aux1 p i xs ys zs}
--     {ipartl_spec_aux2 p i xs ys zs}
-- @-}
-- ipartl_spec :: (Equality (M Natural), Equality (() -> M ()), Equality (List Int -> M (Natural, Natural)), Equality (() -> M (Natural, Natural)), Equality (M Int), Equality (M (List Int)), Equality (M (List Int, List Int)), Equality (M (Natural, Natural, Natural)), Equality (M (List Int, List Int, List Int)), Equality (M (Natural, Natural)), Equality (M Unit), Equality (List Int)) => Int -> Natural -> List Int -> List Int -> List Int -> EqualityProp (M (Natural, Natural))
-- ipartl_spec p i Nil ys zs =
--   ( refinesplus_equalprop
--       (ipartl_spec_aux1 p i Nil ys zs)
--       (ipartl_spec_aux2 p i Nil ys zs)
--   )
--     [eqpropchain|
--         ipartl_spec_aux1 p i Nil ys zs

--       %== -- defn ipartl_spec_aux1
--         writeList i (ys ++ zs ++ Nil) >> ipartl p i (length ys, length zs, length Nil)

--           %by %reflexivity

--       %== -- append_identity
--         writeList i (ys ++ zs) >> ipartl p i (length ys, length zs, length Nil)

--           %by %rewrite zs ++ Nil
--                    %to zs
--           %by %smt
--           %by append_identity zs

--       %== -- defn length
--         writeList i (ys ++ zs) >> ipartl p i (length ys, length zs, Z)

--           %by %rewrite length Nil
--                    %to Z
--           %by %reflexivity

--       %== -- defn ipartl
--         writeList i (ys ++ zs) >> pure (length ys, length zs)

--           %by %rewrite ipartl p i (length ys, length zs, Z)
--                    %to pure (length ys, length zs)
--           %by %reflexivity

--       %== -- defn writeListToLength2
--         writeListToLength2 i (ys, zs)

--           %by %symmetry
--           %by %reflexivity

--       %== -- pure_bind
--         pure (ys, zs) >>= writeListToLength2 i

--           %by %symmetry
--           %by pure_bind (ys, zs) (writeListToLength2 i)

--       %== -- defn partl'
--         partl' p (ys, zs, Nil) >>= writeListToLength2 i

--           %by %rewrite pure (ys, zs)
--                    %to partl' p (ys, zs, Nil)
--           %by %symmetry
--           %by %reflexivity

--       %== -- defn ipartl_spec_aux2
--         ipartl_spec_aux2 p i Nil ys zs

--           %by %symmetry
--           %by %reflexivity
--   |]
-- ipartl_spec p i (Cons x xs) ys zs =
--   ipartl_spec_steps p i x xs ys zs

-- --
-- -- iqsort_spec auxilliaries
-- --

-- -- {-@ reflect iqsort_spec_aux1 @-}
-- -- iqsort_spec_aux1 :: Natural -> List Int -> M ()
-- -- iqsort_spec_aux1 i xs = writeList i xs >> iqsort i (length xs)

-- -- step1

-- {-@ reflect iqsort_spec_step1_aux @-}
-- iqsort_spec_step1_aux :: Natural -> Int -> List Int -> M Unit
-- iqsort_spec_step1_aux i p xs =
--   writeList i (Cons p xs)
--     >> ipartl p (S i) (Z, Z, length xs) >>= \(ny, nz) ->
--       swap i (i + ny)
--         >> iqsort i ny
--         >> iqsort (S (i + ny)) nz

-- -- step2

-- {-@ reflect iqsort_spec_step2_aux @-}
-- iqsort_spec_step2_aux :: Natural -> Int -> List Int -> M Unit
-- iqsort_spec_step2_aux i p xs =
--   partl' p (Nil, Nil, xs) >>= iqsort_spec_step2_aux_aux1 i p xs

-- {-@ reflect iqsort_spec_step2_aux_aux1 @-}
-- iqsort_spec_step2_aux_aux1 :: Natural -> Int -> List Int -> (List Int, List Int) -> M Unit
-- iqsort_spec_step2_aux_aux1 i p xs (ys, zs) =
--   -- BEGIN: [ref 13]
--   writeList i (Cons p ys)
--     >> swap i (i + length ys)
--     -- END: [ref 13]
--     >> writeList (S (i + length (ys ++ Cons p Nil))) zs
--     >> iqsort i (length ys)
--     >> iqsort (S (i + length ys)) (length zs)

-- {-@ reflect iqsort_spec_step2_aux_aux2 @-}
-- iqsort_spec_step2_aux_aux2 :: Natural -> Int -> List Int -> (List Int, List Int) -> M ()
-- iqsort_spec_step2_aux_aux2 i p xs (ys, zs) =
--   ( permute ys >>= \ys' ->
--       writeList i (ys' ++ Cons p Nil ++ zs)
--   )
--     >> iqsort i (length ys)
--     >> iqsort (S (i + length ys)) (length zs)

-- -- step3

-- {-@ reflect iqsort_spec_step3_aux @-}
-- iqsort_spec_step3_aux :: Natural -> Int -> List Int -> M ()
-- iqsort_spec_step3_aux i p xs =
--   partl' p (Nil, Nil, xs) >>= iqsort_spec_step3_aux_aux i p xs

-- {-@ reflect iqsort_spec_step3_aux_aux @-}
-- iqsort_spec_step3_aux_aux :: Natural -> Int -> List Int -> (List Int, List Int) -> M ()
-- iqsort_spec_step3_aux_aux i p xs (ys, zs) =
--   permute ys >>= \ys' ->
--     writeList i (ys' ++ Cons p Nil ++ zs)
--       >> iqsort i (length ys)
--       >> iqsort (S (i + length ys)) (length zs)

-- -- step4

-- -- {-@ reflect iqsort_spec_aux2 @-}
-- -- iqsort_spec_aux2 :: Natural -> List Int -> M ()
-- -- iqsort_spec_aux2 i xs = slowsort xs >>= writeList i

-- --
-- -- iqsort_spec_step1
-- --

-- -- by definition of iqsort
-- {-@
-- iqsort_spec_step1 ::
--   (Equality (M ())) =>
--   i:Natural -> p:Int -> xs:List Int ->
--   RefinesPlus (Unit)
--     {iqsort_spec_aux1 i (Cons p xs)}
--     {iqsort_spec_step1_aux i p xs}
-- @-}
-- iqsort_spec_step1 :: (Equality (M ())) => Natural -> Int -> List Int -> EqualityProp (M Unit)
-- iqsort_spec_step1 i p xs =
--   (refinesplus_equalprop (iqsort_spec_aux1 i (Cons p xs)) (iqsort_spec_step1_aux i p xs))
--     [eqpropchain|
--         iqsort_spec_aux1 i (Cons p xs)

--       %==
--         writeList i (Cons p xs) >>
--         iqsort i (length (Cons p xs))

--       %==
--         writeList i (Cons p xs) >>
--         ( read i >>=
--           iqsort_aux1 i (length (Cons p xs))
--         )

--       %==
--         writeList i (Cons p xs) >>
--         ( read i >>=
--           iqsort_aux1 i (length (Cons p xs))
--         )

--       %==
--         writeList i (Cons p xs) >>
--         ipartl p (S i) (Z, Z, length xs) >>= \(ny, nz) ->
--           swap i (i + ny) >>
--           iqsort i ny >>
--           iqsort (S (i + ny)) nz

--         %by %rewrite iqsort i (length (Cons p xs))
--                  %to ipartl p (S i) (Z, Z, length xs) >>= \(ny, nz) -> swap i (i + ny) >> iqsort i ny >> iqsort (S (i + ny)) nz
--         %by %reflexivity

--       %==
--         writeList i (Cons p xs) >>
--         ipartl p (S i) (Z, Z, length xs) >>= \(ny, nz) ->
--           swap i (i + ny) >>
--           iqsort i ny >>
--           iqsort (S (i + ny)) nz

--       %==
--         iqsort_spec_step1_aux i p xs

--           %by %symmetry
--           %by %reflexivity
--     |]

-- --
-- -- iqsort_spec_step2
-- --

-- {-@
-- iqsort_spec_step2 ::
--   (Equality (M (List Int, List Int)), Equality (M ())) =>
--   i:Natural -> p:Int -> xs:List Int ->
--   RefinesPlus (Unit)
--     {iqsort_spec_step1_aux i p xs}
--     {iqsort_spec_step2_aux i p xs}
-- @-}
-- iqsort_spec_step2 :: (Equality (M (List Int, List Int)), Equality (M ())) => Natural -> Int -> List Int -> EqualityProp (M ())
-- iqsort_spec_step2 i p xs =
--   ( (refinesplus_transitivity aux1 aux2 aux5)
--       step1
--       ( (refinesplus_transitivity aux2 aux3 aux5)
--           step2
--           ( (refinesplus_transitivity aux3 aux4 aux5)
--               step3
--               step4
--           )
--       )
--   )
--   where
--     aux1 = iqsort_spec_step3_aux i p xs
--     step1 = refinesplus_equalprop aux1 aux2 (reflexivity aux1)
--     aux2 =
--       partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
--         permute ys >>= \ys' ->
--           writeList i (ys' ++ Cons p Nil ++ zs)
--             >> iqsort i (length ys)
--             >> iqsort (S (i + length ys)) (length zs)
--     step2 = reflexivity aux2
--     aux3 =
--       ( pure (partition p xs) >>= \(ys, zs) ->
--           slowsort ys >>= \ys' ->
--             slowsort zs >>= \zs' ->
--               pure (ys' ++ Cons p Nil ++ zs')
--       )
--         >>= writeList i
--     step3 = reflexivity aux3
--     aux4 = divide_and_conquer_aux p xs >>= writeList i
--     step4 = refinesplus_equalprop aux4 aux5 (symmetry aux4 aux5 (reflexivity aux5))
--     aux5 = iqsort_spec_aux2 i (Cons p xs)

-- {-
-- writeList i (Cons p xs) >>
-- ipartl p (S i) (Z, Z, length xs) >>= \(ny, nz) ->
--   swap i (i + ny) >>
--   iqsort i ny >>
--   iqsort (S (i + ny)) nz

-- refines

-- partl' p (Nil, Nil, xs) >>= \(ys, zs) =
--   writeList i (Cons p ys) >>
--   swap i (i + length ys) >>
--   writeList (S (i + length (ys ++ Cons p Nil))) zs >>
--   iqsort i (length ys) >>
--   iqsort (S (i + length ys)) (length zs)
-- -}

-- --
-- -- iqsort_spec_step3
-- --

-- -- [ref 13]
-- -- uses: iqsort_spec_lemma1 [ref 10], ipartl_spec_lemma3 [ref 11]
-- -- desc: Now that we have introduced `partl'`, the next goal is to embed
-- -- `ipartl`. The status of the array before the two calls to `iqsort` is given
-- -- by `writeList i (ys' ++ [p] ++ zs)`. That is, `ys' ++ [p] ++ zs` is stored in
-- -- the array from index `i`, where `ys'` is a permutation of `ys`. The
-- -- postcondition of `ipartl`, according to the specification [ref 10], ends up
-- -- with `ys` and `zs` stored consecutively. To connect the two conditions, we
-- -- use a lemma that is dual to [ref 11] ...
-- -- This is what the typical quicksort algorithm does: swapping the pivot
-- -- with the last element of `ys`, and [ref 13] says that it is valid because
-- -- that is one of the many permutations of `ys`. With [ref 13] and [ref 10], the
-- -- specification can be refined to:
-- {-@
-- iqsort_spec_step3 ::
--   (Equality (M (List Int, List Int)), Equality (M ())) =>
--   i:Natural -> p:Int -> xs:List Int ->
--   RefinesPlus (Unit)
--     {iqsort_spec_step2_aux i p xs}
--     {iqsort_spec_step3_aux i p xs}
-- @-}
-- iqsort_spec_step3 :: (Equality (M (List Int, List Int)), Equality (M ())) => Natural -> Int -> List Int -> EqualityProp (M ())
-- iqsort_spec_step3 i p xs =
--   (refinesplus_transitivity aux1 aux2 aux3)
--     step1
--     step2
--   where
--     aux1 = partl' p (Nil, Nil, xs) >>= iqsort_spec_step2_aux_aux1 i p xs
--     step1 = refinesplus_substitutabilityF f k1 k2 f_morphismF k1_refinesF_k2
--     aux2 = partl' p (Nil, Nil, xs) >>= iqsort_spec_step2_aux_aux2 i p xs
--     step2 = refinesplus_equalprop aux2 aux3 aux2_eqprop_aux3
--     aux3 = partl' p (Nil, Nil, xs) >>= iqsort_spec_step3_aux_aux i p xs

--     f k = partl' p (Nil, Nil, xs) >>= k
--     k1 = iqsort_spec_step2_aux_aux1 i p xs
--     k2 = iqsort_spec_step2_aux_aux2 i p xs
--     f_morphismF k1 k2 = reflexivity (f k1 <+> f k2)
--     k1_refinesF_k2 (ys, zs) = refinesplus_substitutability g x y g_morphism x_refines_y
--       where
--         g x =
--           x >> iqsort i (length ys)
--             >> iqsort (S (i + length ys)) (length zs)
--         x =
--           writeList i (Cons p ys)
--             >> swap i (i + length ys)
--         y =
--           permute ys >>= \ys' ->
--             writeList i (ys' ++ Cons p Nil ++ zs)
--         g_morphism a b = reflexivity (g x <+> g y)
--         -- [ref 13]
--         x_refines_y =
--           [eqpropchain|
--               x <+> y
--             %==
--               (writeList i (Cons p ys) >> swap i (i + length ys)) <+>
--               (permute ys >>= \ys' -> writeList i (ys' ++ Cons p Nil ++ zs))
--             %==
--               y
--           |]

--     aux2_eqprop_aux3 =
--       [eqpropchain|
--           aux2

--         %==
--           partl' p (Nil, Nil, xs) >>= iqsort_spec_step2_aux_aux2 i p xs

--         %==
--           partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
--             ( permute ys >>= \ys' ->
--                 writeList i (ys' ++ Cons p Nil ++ zs)
--             )
--               >> iqsort i (length ys)
--               >> iqsort (S (i + length ys)) (length zs)
--             %by %rewrite iqsort_spec_step2_aux_aux2 i p xs
--                      %to \(ys, zs) -> (permute ys >>= \ys' -> writeList i (ys' ++ Cons p Nil ++ zs)) >> iqsort i (length ys) >> iqsort (S (i + length ys)) (length zs)
--             %by %extend (ys, zs)
--             %by %reflexivity

--         %==
--           partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
--             permute ys >>= \ys' ->
--               writeList i (ys' ++ Cons p Nil ++ zs)
--                 >> iqsort i (length ys)
--                 >> iqsort (S (i + length ys)) (length zs)

--         %==
--           partl' p (Nil, Nil, xs) >>= iqsort_spec_step3_aux_aux i p xs
--             %by %rewrite \(ys, zs) -> permute ys >>= \ys' -> writeList i (ys' ++ Cons p Nil ++ zs) >> iqsort i (length ys) >> iqsort (S (i + length ys)) (length zs)
--                      %to iqsort_spec_step3_aux_aux i p xs
--             %by %extend (ys, zs)
--             %by %symmetry
--             %by %reflexivity

--         %==
--           aux3
--       |]

-- --
-- -- iqsort_spec_step4
-- --

-- -- uses: [ref 9] and [ref 12] (recursively) and divide_and_conquer
-- -- desc: For this to work, we introduced two `perm` to permute both partitions
-- -- generated by partition. We can do so because `perm >=> perm = perm` and thus
-- -- `perm >=> slowsort = slowsort`. The term `perm zs` was combined with
-- -- `partition p`, yielding `partl' p`, while `perm ys` will be needed later. We
-- -- also needed [ref 9] to split `writeList i (ys' ++ [x] ++ zs')` into two
-- -- parts. Assuming that [ref 12] has been met for lists shorter than `xs`, two
-- -- subexpressions are folded back to `iqsort`.
-- {-@
-- iqsort_spec_step4 ::
--   (Equality (M (List Int)), Equality (M (List Int)),Equality (M ())) =>
--   i:Natural -> p:Int -> xs:List Int ->
--   RefinesPlus (Unit)
--     {iqsort_spec_step3_aux i p xs}
--     {iqsort_spec_aux2 i (Cons p xs)}
-- @-}
-- iqsort_spec_step4 :: (Equality (M (List Int)), Equality (M (List Int)), Equality (M ())) => Natural -> Int -> List Int -> EqualityProp (M Unit)
-- iqsort_spec_step4 i p xs =
--   [eqpropchain|
--       iqsort_spec_step3_aux i p xs

--     %==
--       partl' p (Nil, Nil, xs) >>= iqsort_spec_step3_aux_aux i p xs

--     %==
--       partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
--         permute ys >>= \ys' ->
--           writeList i (ys' ++ Cons p Nil ++ zs) >>
--           iqsort i (length ys) >>
--           iqsort (S (i + length ys)) (length zs)

--     %==
--       partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
--         permute ys >>= \ys' ->
--           writeList i ys' >>
--           writeList (S (i + length ys')) (Cons p Nil ++ zs) >>
--           iqsort i (length ys) >>
--           iqsort (S (i + length ys)) (length zs)

--         %-- TODO: by writeList_append i ys' (Cons p Nil ++ zs)

--     %==
--       partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
--         permute ys >>= \ys' ->
--           writeList i ys' >> iqsort i (length ys) >>
--           writeList (S (i + length ys')) (Cons p Nil ++ zs) >>
--           iqsort (S (i + length ys)) (length zs)

--         %-- TODO: rearrange sequenced writes

--     %==
--       partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
--         permute ys >>= \ys' ->
--           slowsort ys' >>= writeList i >>
--           writeList (S (i + length ys')) (Cons p Nil ++ zs) >>
--           iqsort (S (i + length ys)) (length zs)

--       %-- TODO: inductive hypothesis

--     %==
--       partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
--         permute ys >>= \ys' ->
--           slowsort ys' >>= writeList i >>
--           write (S (i + length ys')) p >>
--           writeList (S (S (i + length ys'))) zs >>
--           iqsort (S (i + length ys)) (length zs)

--       %-- TODO: defn writeList

--     %==
--       pure (partition p xs) >>=
--         ( \(ys, zs) ->
--             slowsort ys >>= \ys' ->
--               slowsort zs >>= \zs' ->
--                 pure (ys' ++ Cons p Nil ++ zs')
--         ) >>=
--         writeList i

--     %==
--       divide_and_conquer_aux p xs >>=
--         writeList i

--         %-- TODO: defn divide_and_conquer_aux

--     %==
--       slowsort (Cons p xs) >>= writeList i

--         %by %rewrite divide_and_conquer_aux p xs
--                  %to slowsort (Cons p xs)
--         %by divide_and_conquer p xs

--     %==
--       iqsort_spec_aux2 i (Cons p xs)

--         %by %symmetry
--         %by %reflexivity
--   |]

-- --
-- -- iqsort_spec
-- --

-- {-@
-- iqsort_spec ::
--   (Equality (M (List Int)), Equality (M Unit), Equality (M (List Int, List Int))) =>
--   i:Natural -> xs:List Int ->
--   RefinesPlus (Unit)
--     {iqsort_spec_aux1 i xs}
--     {iqsort_spec_aux2 i xs}
-- @-}
-- iqsort_spec :: (Equality (M (List Int)), Equality (M Unit), Equality (M (List Int, List Int))) => Natural -> List Int -> EqualityProp (M Unit)
-- iqsort_spec i Nil =
--   (refinesplus_equalprop (iqsort_spec_aux1 i Nil) (iqsort_spec_aux2 i Nil))
--     [eqpropchain|
--             iqsort_spec_aux1 i Nil
--         %==
--             iqsort_spec_aux2 i Nil
--     |]
-- iqsort_spec i (Cons p xs) =
--   (refinesplus_transitivity aux1 aux2 aux5)
--     step1
--     ( (refinesplus_transitivity aux2 aux3 aux5)
--         step2
--         ( (refinesplus_transitivity aux3 aux4 aux5)
--             step3
--             step4
--         )
--     )
--   where
--     aux1 = iqsort_spec_aux1 i (Cons p xs)
--     step1 = iqsort_spec_step1 i p xs
--     aux2 = iqsort_spec_step1_aux i p xs
--     step2 = iqsort_spec_step2 i p xs
--     aux3 = iqsort_spec_step2_aux i p xs
--     step3 = iqsort_spec_step3 i p xs
--     aux4 = iqsort_spec_step3_aux i p xs
--     step4 = iqsort_spec_step4 i p xs
--     aux5 = iqsort_spec_aux2 i (Cons p xs)

-- -- uses: [ref 9] and [ref 12] (recursively) and divide_and_conquer
-- -- desc: For this to work, we introduced two `perm` to permute both partitions
-- -- generated by partition. We can do so because `perm >=> perm = perm` and thus
-- -- `perm >=> slowsort = slowsort`. The term `perm zs` was combined with
-- -- `partition p`, yielding `partl' p`, while `perm ys` will be needed later. We
-- -- also needed [ref 9] to split `writeList i (ys' ++ [x] ++ zs')` into two
-- -- parts. Assuming that [ref 12] has been met for lists shorter than `xs`, two
-- -- subexpressions are folded back to `iqsort`.
-- {-@
-- iqsort_spec_lemma1 ::
--   Equality (M ()) =>
--   p:Int -> i:Natural -> xs:List Int ->
--   EqualProp (M ())
--     {iqsort_spec_lemma1_aux p i xs}
--     {iqsort_spec_aux2 i (Cons p xs)}
-- @-}
-- iqsort_spec_lemma1 :: Equality (M ()) => Int -> Natural -> List Int -> EqualityProp (M ())
-- iqsort_spec_lemma1 p i xs =
--   -- !ADMITTED
--   [eqpropchain|
--       iqsort_spec_lemma1_aux p i xs
--     %==
--       iqsort_spec_aux2 i (Cons p xs)
--   |]

-- -- [ref 13]
-- -- uses: iqsort_spec_lemma1 [ref 10], ipartl_spec_lemma3 [ref 11]
-- -- desc: Now that we have introduced `partl'`, the next goal is to embed
-- -- `ipartl`. The status of the array before the two calls to `iqsort` is given
-- -- by `writeList i (ys' ++ [p] ++ zs)`. That is, `ys' ++ [p] ++ zs` is stored in
-- -- the array from index `i`, where `ys'` is a permutation of `ys`. The
-- -- postcondition of `ipartl`, according to the specification [ref 10], ends up
-- -- with `ys` and `zs` stored consecutively. To connect the two conditions, we
-- -- use a lemma that is dual to [ref 11]:
-- {-@
-- iqsort_spec_lemma2 ::
--   Equality (M Unit) =>
--   p:Int -> i:Natural -> ys:List Int ->
--   RefinesPlus (Unit)
--     {seq (writeList i (append (Cons p Nil) ys)) (swap i (add i (length ys)))}
--     {iqsort_spec_lemma2_aux1 p i ys}
-- @-}
-- iqsort_spec_lemma2 :: Equality (M Unit) => Int -> Natural -> List Int -> EqualityProp (M Unit)
-- iqsort_spec_lemma2 p i ys =
--   -- !ADMITTED
--   [eqpropchain|
--       seq (writeList i (append (Cons p Nil) ys)) (swap i (add i (length ys)))
--     %==
--       iqsort_spec_lemma2_aux1 p i ys
--   |]

-- -- uses: iqsort_spec_lemma1, iqsort_spec_lemma2 [ref 13]
-- -- desc. This is what the typical quicksort algorithm does: swapping the pivot
-- -- with the last element of `ys`, and [ref 13] says that it is valid because
-- -- that is one of the many permutations of `ys`. With [ref 13] and [ref 10], the
-- -- specification can be refined to:
-- {-@
-- iqsort_spec_lemma3 ::
--   Equality (M ()) =>
--   p:Int -> i:Natural -> xs:List Int ->
--   RefinesPlus (Unit)
--     {iqsort_spec_lemma3_aux p i xs}
--     {iqsort_spec_lemma1_aux p i xs}
-- @-}
-- iqsort_spec_lemma3 :: Equality (M ()) => Int -> Natural -> List Int -> EqualityProp (M ())
-- iqsort_spec_lemma3 p i xs =
--   -- !ADMITTED
--   [eqpropchain|
--       iqsort_spec_aux2 i (Cons p xs)
--     %== --
--       slowsort xs >>=
--         writeList i
--     %== --
--       partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
--         permute ys >>= \ys' ->
--           writeList i (ys' ++ Cons p Nil ++ zs) >>
--             iqsort i (length ys) >>
--               iqsort (S (i + length ys)) (length zs)
--     %== --
--       partl' p (Nil, Nil, xs) >>= \(ys, zs) ->
--         permute ys >>=
--           iqsort_spec_lemma1_aux_aux_aux p i ys zs
--     %== --
--       partl' p (Nil, Nil, xs) >>=
--         iqsort_spec_lemma1_aux_aux p i
--     %== --
--       iqsort_spec_lemma1_aux p i xs
--   |]

-- -- connects `iqsort_spec_lemma3` to `iqsort_spec` (`Cons` case)
-- {-@
-- iqsort_spec_lemma4 ::
--   Equality (M ()) =>
--   p:Int -> i:Natural -> xs:List Int ->
--   RefinesPlus (Unit)
--     {iqsort_spec_aux1 i (Cons p xs)}
--     {iqsort_spec_lemma3_aux p i xs}
-- @-}
-- iqsort_spec_lemma4 :: Equality (M ()) => Int -> Natural -> List Int -> EqualityProp (M ())
-- iqsort_spec_lemma4 p i xs =
--   -- !ADMITTED
--   [eqpropchain|
--       iqsort_spec_aux1 i (Cons p xs)
--     %==
--       iqsort_spec_lemma3_aux p i xs
--   |]
