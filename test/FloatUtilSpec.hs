module FloatUtilSpec (spec) where
import           Numeric.Rounded.Hardware.Internal
import           Test.Hspec
import           Test.Hspec.QuickCheck (prop)
import           Test.QuickCheck
import           Util (sameFloatP)

foreign import ccall unsafe "nextafter"
  c_nextafter_double :: Double -> Double -> Double
foreign import ccall unsafe "nextafterf"
  c_nextafter_float :: Float -> Float -> Float

class Fractional a => CNextAfter a where
  c_nextafter :: a -> a -> a

instance CNextAfter Double where c_nextafter = c_nextafter_double
instance CNextAfter Float where c_nextafter = c_nextafter_float

c_nextUp, c_nextDown :: (RealFloat a, CNextAfter a) => a -> a
c_nextUp x = c_nextafter x (1/0)
c_nextDown x = c_nextafter x (-1/0)

prop_nextUp_match :: (RealFloat a, CNextAfter a, Show a) => a -> Property
prop_nextUp_match x = nextUp x `sameFloatP` c_nextUp x

prop_nextDown_match :: (RealFloat a, CNextAfter a, Show a) => a -> Property
prop_nextDown_match x = nextDown x `sameFloatP` c_nextDown x

isPositiveZero :: RealFloat a => a -> Bool
isPositiveZero x = x == 0 && not (isNegativeZero x)

prop_nextUp_nextDown :: (RealFloat a, Show a) => a -> Property
prop_nextUp_nextDown x = x /= (-1/0) ==>
  let x' = nextUp (nextDown x)
  in x' `sameFloatP` x .||. (isPositiveZero x .&&. isNegativeZero x')

prop_nextDown_nextUp :: (RealFloat a, Show a) => a -> Property
prop_nextDown_nextUp x = x /= (1/0) ==>
  let x' = nextDown (nextUp x)
  in x' `sameFloatP` x .||. (isNegativeZero x .&&. isPositiveZero x')

spec :: Spec
spec = do
  describe "Double" $ do
    prop "nextUp vs C nextafter" (prop_nextUp_match :: Double -> Property)
    prop "nextDown vs C nextafter" (prop_nextDown_match :: Double -> Property)
    prop "nextUp . nextDown == id (unless -inf)" (prop_nextUp_nextDown :: Double -> Property)
    prop "nextDown . nextUp == id (unless inf)" (prop_nextDown_nextUp :: Double -> Property)
  describe "Float" $ do
    prop "nextUp vs C nextafter" (prop_nextUp_match :: Float -> Property)
    prop "nextDown vs C nextafter" (prop_nextDown_match :: Float -> Property)
    prop "nextUp . nextDown == id (unless -inf)" (prop_nextUp_nextDown :: Float -> Property)
    prop "nextDown . nextUp == id (unless inf)" (prop_nextDown_nextUp :: Float -> Property)
