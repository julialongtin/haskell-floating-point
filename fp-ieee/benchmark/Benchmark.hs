{-# LANGUAGE CPP #-}
{-# LANGUAGE HexFloatLiterals #-}
{-# LANGUAGE NumericUnderscores #-}
import           Data.Coerce
import           Data.Functor.Identity
import           Data.Word
import           Gauge.Main
import           GHC.Float (isDoubleFinite, isFloatFinite)
import           Numeric.Floating.IEEE
import           Numeric.Floating.IEEE.Internal
#if defined(USE_HALF)
import           Numeric.Half hiding (isZero)
import qualified Numeric.Half
#endif

foreign import ccall unsafe "fma"
  c_fma_double :: Double -> Double -> Double -> Double
foreign import ccall unsafe "fmaf"
  c_fma_float :: Float -> Float -> Float -> Float

class Fractional a => CFloat a where
  c_fma :: a -> a -> a -> a

instance CFloat Double where
  c_fma = c_fma_double

instance CFloat Float where
  c_fma = c_fma_float

fusedMultiplyAddDouble_generic :: Double -> Double -> Double -> Double
fusedMultiplyAddDouble_generic = coerce (fusedMultiplyAdd :: Identity Double -> Identity Double -> Identity Double -> Identity Double)
fusedMultiplyAddFloat_generic :: Float -> Float -> Float -> Float
fusedMultiplyAddFloat_generic = coerce (fusedMultiplyAdd :: Identity Float -> Identity Float -> Identity Float -> Identity Float)

fusedMultiplyAddDouble_twoProduct_generic :: Double -> Double -> Double -> Double
fusedMultiplyAddDouble_twoProduct_generic = coerce (fusedMultiplyAdd_twoProduct :: Identity Double -> Identity Double -> Identity Double -> Identity Double)
fusedMultiplyAddFloat_twoProduct_generic :: Float -> Float -> Float -> Float
fusedMultiplyAddFloat_twoProduct_generic = coerce (fusedMultiplyAdd_twoProduct :: Identity Float -> Identity Float -> Identity Float -> Identity Float)

main :: IO ()
main = defaultMain
       [ bgroup "FMA"
         [ let arg = (1.0, 2.0, 3.0) :: (Double, Double, Double)
           in bgroup "Double"
           [ bench "C" $ nf (\(x,y,z) -> c_fma x y z) arg
           , bench "Haskell (default)" $ nf (\(x,y,z) -> fusedMultiplyAdd x y z) arg
           , bench "Haskell (default, generic)" $ nf (\(x,y,z) -> fusedMultiplyAddDouble_generic x y z) arg
           , bench "Haskell (via Rational)" $ nf (\(x,y,z) -> fusedMultiplyAdd_viaRational x y z) arg
           , bench "Haskell (via Integer)" $ nf (\(x,y,z) -> fusedMultiplyAdd_viaInteger x y z) arg
           , bench "Haskell (TwoProduct)" $ nf (\(x,y,z) -> fusedMultiplyAdd_twoProduct x y z) arg
           , bench "Haskell (TwoProduct, generic)" $ nf (\(x,y,z) -> fusedMultiplyAddDouble_twoProduct_generic x y z) arg
           , bench "non-fused" $ nf (\(x,y,z) -> x * y + z) arg
           ]
         , let arg = (1.0, 2.0, 3.0) :: (Float, Float, Float)
           in bgroup "Float"
           [ bench "C" $ nf (\(x,y,z) -> c_fma x y z) arg
           , bench "Haskell (default)" $ nf (\(x,y,z) -> fusedMultiplyAdd x y z) arg
           , bench "Haskell (default, generic)" $ nf (\(x,y,z) -> fusedMultiplyAddFloat_generic x y z) arg
           , bench "Haskell (via Rational)" $ nf (\(x,y,z) -> fusedMultiplyAdd_viaRational x y z) arg
           , bench "Haskell (via Integer)" $ nf (\(x,y,z) -> fusedMultiplyAdd_viaInteger x y z) arg
           , bench "Haskell (TwoProduct)" $ nf (\(x,y,z) -> fusedMultiplyAdd_twoProduct x y z) arg
           , bench "Haskell (TwoProduct, generic)" $ nf (\(x,y,z) -> fusedMultiplyAddFloat_twoProduct_generic x y z) arg
           , bench "Haskell (via Double)" $ nf (\(x,y,z) -> fusedMultiplyAddFloat_viaDouble x y z) arg
           , bench "non-fused" $ nf (\(x,y,z) -> x * y + z) arg
           ]
         ]
       , bgroup "isNormal"
         [ let arg = pi :: Double
           in bgroup "Double"
              [ bench "default" $ nf isNormal arg
              , bench "generic" $ nf (isNormal . Identity) arg
              ]
         , let arg = pi :: Float
           in bgroup "Float"
              [ bench "default" $ nf isNormal arg
              , bench "generic" $ nf (isNormal . Identity) arg
              ]
         ]
       , bgroup "isFinite"
         [ let arg = pi :: Double
           in bgroup "Double"
              [ bench "default" $ nf isFinite arg
              , bench "generic" $ nf (isFinite . Identity) arg
              , bench "GHC.Float.isDoubleFinite" $ nf isDoubleFinite arg
              ]
         , let arg = pi :: Float
           in bgroup "Float"
              [ bench "default" $ nf isFinite arg
              , bench "generic" $ nf (isFinite . Identity) arg
              , bench "GHC.Float.isFloatFinite" $ nf isFloatFinite arg
              ]
         ]
       , bgroup "twoProduct"
         [ let arg :: (Double, Double)
               arg = (1.3 * 2^500, pi / 2^500)
           in bgroup "Double"
              [ bench "Haskell (default)" $ nf (uncurry twoProduct) arg
              , bench "Haskell (nonscaling)" $ nf (uncurry twoProduct_nonscaling) arg
#if defined(HAS_FAST_FMA)
              , bench "FMA" $ nf (uncurry fastTwoProductDouble) arg
#endif
              ]
         , let arg :: (Float, Float)
               arg = (1.3 * 2^50, pi / 2^50)
           in bgroup "Float"
              [ bench "Haskell (default)" $ nf (uncurry twoProduct) arg
              , bench "Haskell (nonscaling)" $ nf (uncurry twoProduct_nonscaling) arg
              , bench "Haskell (via Double)" $ nf (uncurry twoProductFloat_viaDouble) arg
#if defined(HAS_FAST_FMA)
              , bench "FMA" $ nf (uncurry fastTwoProductFloat) arg
#endif
              ]
         ]
       , bgroup "fromInteger"
         [ let x = 418237418 * 2^80 + 4811 * 2^32 + 1412
             in bgroup "large"
           [ bgroup "Double"
             [ bench "stock" $ nf (fromInteger :: Integer -> Double) x
             , bench "fromIntegerTiesToEven" $ nf (fromIntegerTiesToEven :: Integer -> Double) x
             , bench "fromIntegerTiesToAway" $ nf (fromIntegerTiesToAway :: Integer -> Double) x
             , bench "fromIntegerTowardPositive" $ nf (fromIntegerTowardPositive :: Integer -> Double) x
             , bench "fromIntegerTowardNegative" $ nf (fromIntegerTowardNegative :: Integer -> Double) x
             , bench "fromIntegerTowardZero" $ nf (fromIntegerTowardZero :: Integer -> Double) x
             ]
           , bgroup "Float"
             [ bench "stock" $ nf (fromInteger :: Integer -> Float) x
             , bench "fromIntegerTiesToEven" $ nf (fromIntegerTiesToEven :: Integer -> Float) x
             , bench "fromIntegerTiesToAway" $ nf (fromIntegerTiesToAway :: Integer -> Float) x
             , bench "fromIntegerTowardPositive" $ nf (fromIntegerTowardPositive :: Integer -> Float) x
             , bench "fromIntegerTowardNegative" $ nf (fromIntegerTowardNegative :: Integer -> Float) x
             , bench "fromIntegerTowardZero" $ nf (fromIntegerTowardZero :: Integer -> Float) x
             ]
           ]
         , let x = 3 * 2^19 + 4811 * 2^7 + 1412
           in bgroup "small"
           [ bgroup "Double"
             [ bench "stock" $ nf (fromInteger :: Integer -> Double) x
             , bench "fromIntegerTiesToEven" $ nf (fromIntegerTiesToEven :: Integer -> Double) x
             , bench "fromIntegerTiesToAway" $ nf (fromIntegerTiesToAway :: Integer -> Double) x
             , bench "fromIntegerTowardPositive" $ nf (fromIntegerTowardPositive :: Integer -> Double) x
             , bench "fromIntegerTowardNegative" $ nf (fromIntegerTowardNegative :: Integer -> Double) x
             , bench "fromIntegerTowardZero" $ nf (fromIntegerTowardZero :: Integer -> Double) x
             ]
           , bgroup "Float"
             [ bench "stock" $ nf (fromInteger :: Integer -> Float) x
             , bench "fromIntegerTiesToEven" $ nf (fromIntegerTiesToEven :: Integer -> Float) x
             , bench "fromIntegerTiesToAway" $ nf (fromIntegerTiesToAway :: Integer -> Float) x
             , bench "fromIntegerTowardPositive" $ nf (fromIntegerTowardPositive :: Integer -> Float) x
             , bench "fromIntegerTowardNegative" $ nf (fromIntegerTowardNegative :: Integer -> Float) x
             , bench "fromIntegerTowardZero" $ nf (fromIntegerTowardZero :: Integer -> Float) x
             ]
           ]
         ]
       , bgroup "fromIntegral"
         [ bgroup "Word64"
           [ let x = 0xdead_beef_1234_7777 :: Word64
             in bgroup "large"
                [ bgroup "Double"
                  [ bench "stock" $ nf (fromIntegral :: Word64 -> Double) x
                  , bench "fromIntegralTiesToEven" $ nf (fromIntegralTiesToEven :: Word64 -> Double) x
                  , bench "fromIntegralTiesToAway" $ nf (fromIntegralTiesToAway :: Word64 -> Double) x
                  , bench "fromIntegralTowardPositive" $ nf (fromIntegralTowardPositive :: Word64 -> Double) x
                  , bench "fromIntegralTowardNegative" $ nf (fromIntegralTowardNegative :: Word64 -> Double) x
                  , bench "fromIntegralTowardZero" $ nf (fromIntegralTowardZero :: Word64 -> Double) x
                  ]
                , bgroup "Float"
                  [ bench "stock" $ nf (fromIntegral :: Word64 -> Float) x
                  , bench "fromIntegralTiesToEven" $ nf (fromIntegralTiesToEven :: Word64 -> Float) x
                  , bench "fromIntegralTiesToAway" $ nf (fromIntegralTiesToAway :: Word64 -> Float) x
                  , bench "fromIntegralTowardPositive" $ nf (fromIntegralTowardPositive :: Word64 -> Float) x
                  , bench "fromIntegralTowardNegative" $ nf (fromIntegralTowardNegative :: Word64 -> Float) x
                  , bench "fromIntegralTowardZero" $ nf (fromIntegralTowardZero :: Word64 -> Float) x
                  ]
                ]
           , let x = 0x14_7777 :: Word64
             in bgroup "small"
                [ bgroup "Double"
                  [ bench "stock" $ nf (fromIntegral :: Word64 -> Double) x
                  , bench "fromIntegralTiesToEven" $ nf (fromIntegralTiesToEven :: Word64 -> Double) x
                  , bench "fromIntegralTiesToAway" $ nf (fromIntegralTiesToAway :: Word64 -> Double) x
                  , bench "fromIntegralTowardPositive" $ nf (fromIntegralTowardPositive :: Word64 -> Double) x
                  , bench "fromIntegralTowardNegative" $ nf (fromIntegralTowardNegative :: Word64 -> Double) x
                  , bench "fromIntegralTowardZero" $ nf (fromIntegralTowardZero :: Word64 -> Double) x
                  ]
                , bgroup "Float"
                  [ bench "stock" $ nf (fromIntegral :: Word64 -> Float) x
                  , bench "fromIntegralTiesToEven" $ nf (fromIntegralTiesToEven :: Word64 -> Float) x
                  , bench "fromIntegralTiesToAway" $ nf (fromIntegralTiesToAway :: Word64 -> Float) x
                  , bench "fromIntegralTowardPositive" $ nf (fromIntegralTowardPositive :: Word64 -> Float) x
                  , bench "fromIntegralTowardNegative" $ nf (fromIntegralTowardNegative :: Word64 -> Float) x
                  , bench "fromIntegralTowardZero" $ nf (fromIntegralTowardZero :: Word64 -> Float) x
                  ]
                ]
           ]
         ]
       , bgroup "fromRational"
         [ let x = (418237418 * 2^80 + 4811 * 2^32 + 1412) / (2234321954 * 2^75 + 2345234566) :: Rational
           in bgroup "large/large"
              [ bgroup "Double"
                [ bench "stock" $ nf (fromRational :: Rational -> Double) x
                , bench "fromRationalTiesToEven" $ nf (fromRationalTiesToEven :: Rational -> Double) x
                , bench "fromRationalTiesToAway" $ nf (fromRationalTiesToAway :: Rational -> Double) x
                , bench "fromRationalTowardPositive" $ nf (fromRationalTowardPositive :: Rational -> Double) x
                , bench "fromRationalTowardNegative" $ nf (fromRationalTowardNegative :: Rational -> Double) x
                , bench "fromRationalTowardZero" $ nf (fromRationalTowardZero :: Rational -> Double) x
                ]
              , bgroup "Float"
                [ bench "stock" $ nf (fromRational :: Rational -> Float) x
                , bench "fromRationalTiesToEven" $ nf (fromRationalTiesToEven :: Rational -> Float) x
                , bench "fromRationalTiesToAway" $ nf (fromRationalTiesToAway :: Rational -> Float) x
                , bench "fromRationalTowardPositive" $ nf (fromRationalTowardPositive :: Rational -> Float) x
                , bench "fromRationalTowardNegative" $ nf (fromRationalTowardNegative :: Rational -> Float) x
                , bench "fromRationalTowardZero" $ nf (fromRationalTowardZero :: Rational -> Float) x
                ]
              ]
         , let x = 355 / 113 :: Rational
           in bgroup "small/small"
              [ bgroup "Double"
                [ bench "stock" $ nf (fromRational :: Rational -> Double) x
                , bench "fromRationalTiesToEven" $ nf (fromRationalTiesToEven :: Rational -> Double) x
                , bench "fromRationalTiesToAway" $ nf (fromRationalTiesToAway :: Rational -> Double) x
                , bench "fromRationalTowardPositive" $ nf (fromRationalTowardPositive :: Rational -> Double) x
                , bench "fromRationalTowardNegative" $ nf (fromRationalTowardNegative :: Rational -> Double) x
                , bench "fromRationalTowardZero" $ nf (fromRationalTowardZero :: Rational -> Double) x
                ]
              , bgroup "Float"
                [ bench "stock" $ nf (fromRational :: Rational -> Float) x
                , bench "fromRationalTiesToEven" $ nf (fromRationalTiesToEven :: Rational -> Float) x
                , bench "fromRationalTiesToAway" $ nf (fromRationalTiesToAway :: Rational -> Float) x
                , bench "fromRationalTowardPositive" $ nf (fromRationalTowardPositive :: Rational -> Float) x
                , bench "fromRationalTowardNegative" $ nf (fromRationalTowardNegative :: Rational -> Float) x
                , bench "fromRationalTowardZero" $ nf (fromRationalTowardZero :: Rational -> Float) x
                ]
              ]
         , let x = 0x1.deafbeefcafec0ffeep100 :: Rational
           in bgroup "binary"
              [ bgroup "Double"
                [ bench "stock" $ nf (fromRational :: Rational -> Double) x
                , bench "fromRationalTiesToEven" $ nf (fromRationalTiesToEven :: Rational -> Double) x
                , bench "fromRationalTiesToAway" $ nf (fromRationalTiesToAway :: Rational -> Double) x
                , bench "fromRationalTowardPositive" $ nf (fromRationalTowardPositive :: Rational -> Double) x
                , bench "fromRationalTowardNegative" $ nf (fromRationalTowardNegative :: Rational -> Double) x
                , bench "fromRationalTowardZero" $ nf (fromRationalTowardZero :: Rational -> Double) x
                ]
              , bgroup "Float"
                [ bench "stock" $ nf (fromRational :: Rational -> Float) x
                , bench "fromRationalTiesToEven" $ nf (fromRationalTiesToEven :: Rational -> Float) x
                , bench "fromRationalTiesToAway" $ nf (fromRationalTiesToAway :: Rational -> Float) x
                , bench "fromRationalTowardPositive" $ nf (fromRationalTowardPositive :: Rational -> Float) x
                , bench "fromRationalTowardNegative" $ nf (fromRationalTowardNegative :: Rational -> Float) x
                , bench "fromRationalTowardZero" $ nf (fromRationalTowardZero :: Rational -> Float) x
                ]
              ]
         ]
       , bgroup "encodeFloat"
         [ let arg = (0xcafe_0000_abcd_7777, -25) :: (Integer, Int)
           in bgroup "Double"
              [ bench "stock" $ nf (uncurry encodeFloat :: (Integer, Int) -> Double) arg
              , bench "encodeFloatTiesToEven" $ nf (uncurry encodeFloatTiesToEven :: (Integer, Int) -> Double) arg
              , bench "encodeFloatTiesToAway" $ nf (uncurry encodeFloatTiesToAway :: (Integer, Int) -> Double) arg
              , bench "encodeFloatTowardPositive" $ nf (uncurry encodeFloatTowardPositive :: (Integer, Int) -> Double) arg
              , bench "encodeFloatTowardNegative" $ nf (uncurry encodeFloatTowardNegative :: (Integer, Int) -> Double) arg
              , bench "encodeFloatTowardZero" $ nf (uncurry encodeFloatTowardZero :: (Integer, Int) -> Double) arg
              ]
         , let arg = (0xcafe_0000_abcd_7777, -25) :: (Integer, Int)
           in bgroup "Float"
              [ bench "stock" $ nf (uncurry encodeFloat :: (Integer, Int) -> Float) arg
              , bench "encodeFloatTiesToEven" $ nf (uncurry encodeFloatTiesToEven :: (Integer, Int) -> Float) arg
              , bench "encodeFloatTiesToAway" $ nf (uncurry encodeFloatTiesToAway :: (Integer, Int) -> Float) arg
              , bench "encodeFloatTowardPositive" $ nf (uncurry encodeFloatTowardPositive :: (Integer, Int) -> Float) arg
              , bench "encodeFloatTowardNegative" $ nf (uncurry encodeFloatTowardNegative :: (Integer, Int) -> Float) arg
              , bench "encodeFloatTowardZero" $ nf (uncurry encodeFloatTowardZero :: (Integer, Int) -> Float) arg
              ]
         ]
#if defined(USE_HALF)
       , bgroup "Half"
         [ bgroup "from Half"
           [ let x = 1.3 :: Half
             in bgroup "to Float"
                [ bench "half" $ nf fromHalf x
#if defined(HAS_FAST_HALF_CONVERSION)
                , bench "C impl" $ nf fastHalfToFloat x
#endif
                , bench "realToFrac" $ nf (realToFrac :: Half -> Float) x
                , bench "realFloatToFrac" $ nf (realFloatToFrac :: Half -> Float) x
                ]
           , let x = 1.3 :: Half
             in bgroup "to Double"
                [
#if defined(HAS_FAST_HALF_CONVERSION)
                  bench "C impl" $ nf fastHalfToDouble x ,
#endif
                  bench "realToFrac" $ nf (realToFrac :: Half -> Double) x
                , bench "realFloatToFrac" $ nf (realFloatToFrac :: Half -> Double) x
                ]
           ]
         , bgroup "to Half"
           [ let x = 1.3 :: Float
             in bgroup "from Float"
                [ bench "half" $ nf toHalf x
#if defined(HAS_FAST_HALF_CONVERSION)
                , bench "C impl" $ nf fastFloatToHalf x
#endif
                , bench "realToFrac" $ nf (realToFrac :: Float -> Half) x
                , bench "realFloatToFrac" $ nf (realFloatToFrac :: Float -> Half) x
                ]
           , let x = 1.3 :: Double
             in bgroup "from Double"
                [
#if defined(HAS_FAST_HALF_CONVERSION)
                  bench "C impl" $ nf fastDoubleToHalf x ,
#endif
                  bench "realToFrac" $ nf (realToFrac :: Double -> Half) x
                , bench "realFloatToFrac" $ nf (realFloatToFrac :: Double -> Half) x
                ]
           ]
         , let arg = pi :: Half
           in bgroup "isNormal"
              [ bench "default" $ nf isNormal arg
              , bench "generic" $ nf (isNormal . Identity) arg
              ]
         , let arg = pi :: Half
           in bgroup "isFinite"
              [ bench "default" $ nf isFinite arg
              , bench "generic" $ nf (isFinite . Identity) arg
              ]
         , let arg = -0 :: Half
           in bgroup "isZero"
              [ bench "default" $ nf isZero arg
              , bench "generic" $ nf (isZero . Identity) arg
              , bench "Numeric.Half.isZero" $ nf Numeric.Half.isZero arg
              ]
         ]
#endif
       ]