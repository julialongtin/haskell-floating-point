{-# LANGUAGE DataKinds #-}
{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
module Numeric.Rounded.Hardware.Backend.ViaRational where
import           Control.DeepSeq (NFData (..))
import           Control.Exception (assert)
import           Data.Coerce
import           Data.Ratio
import           Data.Tagged
import qualified Data.Vector.Generic as VG
import qualified Data.Vector.Generic.Mutable as VGM
import qualified Data.Vector.Storable as VS
import qualified Data.Vector.Unboxed as VU
import qualified Data.Vector.Unboxed.Mutable as VUM
import           Foreign.Storable (Storable)
import           GHC.Generics (Generic)
import           Numeric.Rounded.Hardware.Internal.Class
import           Numeric.Rounded.Hardware.Internal.Constants
import           Numeric.Rounded.Hardware.Internal.Conversion
import           Numeric.Floating.IEEE (nextDown, nextUp)

newtype ViaRational a = ViaRational a
  deriving (Eq,Ord,Show,Generic,Num,Storable)

instance NFData a => NFData (ViaRational a)

instance (RealFloat a, Num a, RealFloatConstants a) => RoundedRing (ViaRational a) where
  roundedAdd r (ViaRational x) (ViaRational y)
    | isNaN x || isNaN y || isInfinite x || isInfinite y = ViaRational (x + y)
    | x == 0 && y == 0 = ViaRational $ if isNegativeZero x == isNegativeZero y
                                       then x
                                       else roundedZero
    | otherwise = case toRational x + toRational y of
                    0 -> ViaRational roundedZero
                    z -> roundedFromRational r z
    where roundedZero = case r of
            ToNearest    ->  0
            TowardNegInf -> -0
            TowardInf    ->  0
            TowardZero   ->  0
  roundedSub r (ViaRational x) (ViaRational y)
    | isNaN x || isNaN y || isInfinite x || isInfinite y = ViaRational (x - y)
    | x == 0 && y == 0 = ViaRational $ if isNegativeZero x /= isNegativeZero y
                                       then x
                                       else roundedZero
    | otherwise = case toRational x - toRational y of
                    0 -> ViaRational roundedZero
                    z -> roundedFromRational r z
    where roundedZero = case r of
            ToNearest    ->  0
            TowardNegInf -> -0
            TowardInf    ->  0
            TowardZero   ->  0
  roundedMul r (ViaRational x) (ViaRational y)
    | isNaN x || isNaN y || isInfinite x || isInfinite y || isNegativeZero x || isNegativeZero y = ViaRational (x * y)
    | otherwise = roundedFromRational r (toRational x * toRational y)
  roundedFusedMultiplyAdd r (ViaRational x) (ViaRational y) (ViaRational z)
    | isNaN x || isNaN y || isNaN z || isInfinite x || isInfinite y || isInfinite z = ViaRational (x * y + z)
    | otherwise = case toRational x * toRational y + toRational z of
                    0 -> if z == 0 && isNegativeZero (x * y) == isNegativeZero z
                         then ViaRational z
                         else ViaRational roundedZero
                    w -> roundedFromRational r w
      where roundedZero = case r of
              ToNearest    ->  0
              TowardNegInf -> -0
              TowardInf    ->  0
              TowardZero   ->  0
  roundedFromInteger r x = ViaRational (fromInt r x)
  intervalFromInteger x = case intervalFromInteger_default x of
    (a, b) -> (ViaRational <$> a, ViaRational <$> b)
  backendNameT = Tagged "via Rational"
  {-# INLINE roundedFromInteger #-}
  {-# INLINE intervalFromInteger #-}
  {-# SPECIALIZE instance RoundedRing (ViaRational Float) #-}
  {-# SPECIALIZE instance RoundedRing (ViaRational Double) #-}

instance (RealFloat a, Num a, RealFloatConstants a) => RoundedFractional (ViaRational a) where
  roundedDiv r (ViaRational x) (ViaRational y)
    | isNaN x || isNaN y || isInfinite x || isInfinite y || x == 0 || y == 0 = ViaRational (x / y)
    | otherwise = roundedFromRational r (toRational x / toRational y)
  roundedFromRational r x = ViaRational $ fromRatio r (numerator x) (denominator x)
  roundedFromRealFloat r x | isNaN x = ViaRational (0/0)
                           | isInfinite x = ViaRational (if x > 0 then 1/0 else -1/0)
                           | isNegativeZero x = ViaRational (-0)
                           | otherwise = roundedFromRational r (toRational x)
  intervalFromRational x = case intervalFromRational_default x of
    (a, b) -> (ViaRational <$> a, ViaRational <$> b)
  {-# INLINE roundedFromRational #-}
  {-# INLINE intervalFromRational #-}
  {-# SPECIALIZE instance RoundedFractional (ViaRational Float) #-}
  {-# SPECIALIZE instance RoundedFractional (ViaRational Double) #-}

instance (RealFloat a, RealFloatConstants a) => RoundedSqrt (ViaRational a) where
  roundedSqrt r (ViaRational x)
    | r /= ToNearest && x >= 0 = ViaRational $
      case compare ((toRational y) ^ (2 :: Int)) (toRational x) of
        LT | r == TowardInf -> let z = nextUp y
                               in assert (toRational x < (toRational z) ^ (2 :: Int)) z
           | otherwise -> y
        EQ -> y
        GT | r == TowardInf -> y
           | otherwise -> let z = nextDown y
                          in assert ((toRational z) ^ (2 :: Int) < toRational x) z
    | otherwise = ViaRational y
    where y = sqrt x

instance (RealFloat a, RealFloatConstants a, Storable a) => RoundedRing_Vector VS.Vector (ViaRational a)
instance (RealFloat a, RealFloatConstants a, Storable a) => RoundedFractional_Vector VS.Vector (ViaRational a)
instance (RealFloat a, RealFloatConstants a, Storable a) => RoundedSqrt_Vector VS.Vector (ViaRational a)
instance (RealFloat a, RealFloatConstants a, VU.Unbox a) => RoundedRing_Vector VU.Vector (ViaRational a)
instance (RealFloat a, RealFloatConstants a, VU.Unbox a) => RoundedFractional_Vector VU.Vector (ViaRational a)
instance (RealFloat a, RealFloatConstants a, VU.Unbox a) => RoundedSqrt_Vector VU.Vector (ViaRational a)

--
-- instance for Data.Vector.Unboxed.Unbox
--

newtype instance VUM.MVector s (ViaRational a) = MV_ViaRational (VUM.MVector s a)
newtype instance VU.Vector (ViaRational a) = V_ViaRational (VU.Vector a)

instance VU.Unbox a => VGM.MVector VUM.MVector (ViaRational a) where
  basicLength (MV_ViaRational mv) = VGM.basicLength mv
  basicUnsafeSlice i l (MV_ViaRational mv) = MV_ViaRational (VGM.basicUnsafeSlice i l mv)
  basicOverlaps (MV_ViaRational mv) (MV_ViaRational mv') = VGM.basicOverlaps mv mv'
  basicUnsafeNew l = MV_ViaRational <$> VGM.basicUnsafeNew l
  basicInitialize (MV_ViaRational mv) = VGM.basicInitialize mv
  basicUnsafeReplicate i x = MV_ViaRational <$> VGM.basicUnsafeReplicate i (coerce x)
  basicUnsafeRead (MV_ViaRational mv) i = coerce <$> VGM.basicUnsafeRead mv i
  basicUnsafeWrite (MV_ViaRational mv) i x = VGM.basicUnsafeWrite mv i (coerce x)
  basicClear (MV_ViaRational mv) = VGM.basicClear mv
  basicSet (MV_ViaRational mv) x = VGM.basicSet mv (coerce x)
  basicUnsafeCopy (MV_ViaRational mv) (MV_ViaRational mv') = VGM.basicUnsafeCopy mv mv'
  basicUnsafeMove (MV_ViaRational mv) (MV_ViaRational mv') = VGM.basicUnsafeMove mv mv'
  basicUnsafeGrow (MV_ViaRational mv) n = MV_ViaRational <$> VGM.basicUnsafeGrow mv n

instance VU.Unbox a => VG.Vector VU.Vector (ViaRational a) where
  basicUnsafeFreeze (MV_ViaRational mv) = V_ViaRational <$> VG.basicUnsafeFreeze mv
  basicUnsafeThaw (V_ViaRational v) = MV_ViaRational <$> VG.basicUnsafeThaw v
  basicLength (V_ViaRational v) = VG.basicLength v
  basicUnsafeSlice i l (V_ViaRational v) = V_ViaRational (VG.basicUnsafeSlice i l v)
  basicUnsafeIndexM (V_ViaRational v) i = coerce <$> VG.basicUnsafeIndexM v i
  basicUnsafeCopy (MV_ViaRational mv) (V_ViaRational v) = VG.basicUnsafeCopy mv v
  elemseq (V_ViaRational v) x y = VG.elemseq v (coerce x) y

instance VU.Unbox a => VU.Unbox (ViaRational a)
