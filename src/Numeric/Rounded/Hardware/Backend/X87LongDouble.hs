{-# LANGUAGE DataKinds #-}
{-# LANGUAGE HexFloatLiterals #-}
{-# OPTIONS_GHC -Wno-orphans #-}
module Numeric.Rounded.Hardware.Backend.X87LongDouble
  (
  ) where
import           Data.Functor.Product
import           Data.Ratio
import           Foreign.Marshal (alloca, with)
import           Foreign.Ptr (Ptr)
import           Foreign.Storable (peek)
import           Numeric.LongDouble (LongDouble)
import           Numeric.Rounded.Hardware.Internal
import           System.IO.Unsafe

foreign import ccall unsafe "rounded_hw_add_longdouble"
  c_rounded_add_longdouble :: Int -> Ptr LongDouble -> Ptr LongDouble -> Ptr LongDouble -> IO ()
foreign import ccall unsafe "rounded_hw_sub_longdouble"
  c_rounded_sub_longdouble :: Int -> Ptr LongDouble -> Ptr LongDouble -> Ptr LongDouble -> IO ()
foreign import ccall unsafe "rounded_hw_mul_longdouble"
  c_rounded_mul_longdouble :: Int -> Ptr LongDouble -> Ptr LongDouble -> Ptr LongDouble -> IO ()
foreign import ccall unsafe "rounded_hw_div_longdouble"
  c_rounded_div_longdouble :: Int -> Ptr LongDouble -> Ptr LongDouble -> Ptr LongDouble -> IO ()
foreign import ccall unsafe "rounded_hw_sqrt_longdouble"
  c_rounded_sqrt_longdouble :: Int -> Ptr LongDouble -> Ptr LongDouble -> IO ()
foreign import ccall unsafe "rounded_hw_fma_longdouble"
  c_rounded_fma_longdouble :: Int -> Ptr LongDouble -> Ptr LongDouble -> Ptr LongDouble -> Ptr LongDouble -> IO ()

roundedAdd_ld :: RoundingMode -> LongDouble -> LongDouble -> LongDouble
roundedAdd_ld mode x y = unsafePerformIO $
  with x $ \xPtr ->
  with y $ \yPtr ->
  alloca $ \resultPtr -> do
  c_rounded_add_longdouble (fromEnum mode) resultPtr xPtr yPtr
  peek resultPtr

roundedSub_ld :: RoundingMode -> LongDouble -> LongDouble -> LongDouble
roundedSub_ld mode x y = unsafePerformIO $
  with x $ \xPtr ->
  with y $ \yPtr ->
  alloca $ \resultPtr -> do
  c_rounded_sub_longdouble (fromEnum mode) resultPtr xPtr yPtr
  peek resultPtr

roundedMul_ld :: RoundingMode -> LongDouble -> LongDouble -> LongDouble
roundedMul_ld mode x y = unsafePerformIO $
  with x $ \xPtr ->
  with y $ \yPtr ->
  alloca $ \resultPtr -> do
  c_rounded_mul_longdouble (fromEnum mode) resultPtr xPtr yPtr
  peek resultPtr

roundedDiv_ld :: RoundingMode -> LongDouble -> LongDouble -> LongDouble
roundedDiv_ld mode x y = unsafePerformIO $
  with x $ \xPtr ->
  with y $ \yPtr ->
  alloca $ \resultPtr -> do
  c_rounded_div_longdouble (fromEnum mode) resultPtr xPtr yPtr
  peek resultPtr

roundedSqrt_ld :: RoundingMode -> LongDouble -> LongDouble
roundedSqrt_ld mode x = unsafePerformIO $
  with x $ \xPtr ->
  alloca $ \resultPtr -> do
  c_rounded_sqrt_longdouble (fromEnum mode) resultPtr xPtr
  peek resultPtr

roundedFMA_ld :: RoundingMode -> LongDouble -> LongDouble -> LongDouble -> LongDouble
roundedFMA_ld mode x y z = unsafePerformIO $
  with x $ \xPtr ->
  with y $ \yPtr ->
  with z $ \zPtr ->
  alloca $ \resultPtr -> do
  c_rounded_fma_longdouble (fromEnum mode) resultPtr xPtr yPtr zPtr
  peek resultPtr

instance RealFloatConstants LongDouble where
  positiveInfinity = 1/0
  negativeInfinity = -1/0
  maxFinite = 0x1.fffffffffffffffep+16383
  minPositive = (1/2)^16445 -- The literal 0x1p-16445 yields 0 on long-double-0.1
  pi_down = Rounded 0x3.243f6a8885a308dp+0
  pi_up   = Rounded 0x3.243f6a8885a308d4p+0
  -- log(2)
  log2_down = Rounded 0xb.17217f7d1cf79abp-4
  log2_up   = Rounded 0xb.17217f7d1cf79acp-4
  -- exp(1)
  exp1_down = Rounded 0x2.b7e151628aed2a68p+0
  exp1_up   = Rounded 0x2.b7e151628aed2a6cp+0
  -- exp(1/2)
  exp1_2_down = Rounded 0x1.a61298e1e069bc96p+0
  exp1_2_up   = Rounded 0x1.a61298e1e069bc98p+0
  -- exp(-1/2)
  expm1_2_down = Rounded 0x9.b4597e37cb04ff3p-4
  expm1_2_up   = Rounded 0x9.b4597e37cb04ff4p-4
  -- sqrt(2)
  sqrt2_down = Rounded 0x1.6a09e667f3bcc908p+0
  sqrt2_up   = Rounded 0x1.6a09e667f3bcc90ap+0
  -- sqrt(2)-1
  sqrt2m1_down = Rounded 0x6.a09e667f3bcc9088p-4
  sqrt2m1_up   = Rounded 0x6.a09e667f3bcc909p-4

instance RoundedRing LongDouble where
  roundedAdd = roundedAdd_ld
  roundedSub = roundedSub_ld
  roundedMul = roundedMul_ld
  roundedFromInteger rn x = fromInt rn x
  intervalFromInteger x = case fromIntF x :: Product (Rounded 'TowardNegInf) (Rounded 'TowardInf) LongDouble of
    Pair a b -> (a, b)
  {-# INLINE roundedAdd #-}
  {-# INLINE roundedSub #-}
  {-# INLINE roundedMul #-}
  {-# INLINE roundedFromInteger #-}
  {-# INLINE intervalFromInteger #-}

instance RoundedFractional LongDouble where
  roundedDiv = roundedDiv_ld
  roundedFromRational rn x = fromRatio rn (numerator x) (denominator x)
  intervalFromRational x = case fromRatioF (numerator x) (denominator x) :: Product (Rounded 'TowardNegInf) (Rounded 'TowardInf) LongDouble of
    Pair a b -> (a, b)
  {-# INLINE roundedDiv #-}
  {-# INLINE roundedFromRational #-}
  {-# INLINE intervalFromRational #-}

instance RoundedSqrt LongDouble where
  roundedSqrt = roundedSqrt_ld
  {-# INLINE roundedSqrt #-}
