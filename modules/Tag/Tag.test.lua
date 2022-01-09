local T = {}

local x = "error"
local function tassert(t, Tag, result, expected, msg)
	if expected == x then
		if Tag.typeof(result) ~= "ErrorTag" then
			t:Errorf("%s: error expected", msg)
		end
		t:Logf("ok: %s: %s", msg, tostring(result))
		return
	end
	if result ~= expected then
		t:Errorf("%s: expected %s, got %s", msg, tostring(expected), tostring(result))
		return
	end
end

function T.TestOperators(t, require)
	local Tag = require()

	local e    = Tag.empty
	local xA   = Tag.error("A")
	local xB   = Tag.error("B")
	local sA   = Tag.static("A")
	local sB   = Tag.static("B")
	local sAB  = sA + sB
	local cA   = Tag.class("A")
	local cB   = Tag.class("B")
	local cAB  = cA + cB
	local iAX  = cA "X"
	local iAY  = cA "Y"
	local iBX  = cB "X"
	local iBY  = cB "Y"
	local iABX = cAB "X"
	local iABY = cAB "Y"

	tassert(t , Tag , e    + e    , e    , "e    + e    == e"   )
	tassert(t , Tag , e    + xA   , xA   , "e    + xA   == xA"  )
	tassert(t , Tag , e    + xB   , xB   , "e    + xB   == xB"  )
	tassert(t , Tag , e    + sA   , sA   , "e    + sA   == sA"  )
	tassert(t , Tag , e    + sB   , sB   , "e    + sB   == sB"  )
	tassert(t , Tag , e    + sAB  , sAB  , "e    + sAB  == sAB" )
	tassert(t , Tag , e    + cA   , cA   , "e    + cA   == cA"  )
	tassert(t , Tag , e    + cB   , cB   , "e    + cB   == cB"  )
	tassert(t , Tag , e    + cAB  , cAB  , "e    + cAB  == cAB" )
	tassert(t , Tag , e    + iAX  , iAX  , "e    + iAX  == iAX" )
	tassert(t , Tag , e    + iAY  , iAY  , "e    + iAY  == iAY" )
	tassert(t , Tag , e    + iBX  , iBX  , "e    + iBX  == iBX" )
	tassert(t , Tag , e    + iBY  , iBY  , "e    + iBY  == iBY" )
	tassert(t , Tag , e    + iABX , iABX , "e    + iABX == iABX")
	tassert(t , Tag , e    + iABY , iABY , "e    + iABY == iABY")
	tassert(t , Tag , xA   + e    , xA   , "xA   + e    == xA"  )
	tassert(t , Tag , xA   + xA   , xA   , "xA   + xA   == xA"  )
	tassert(t , Tag , xA   + xB   , xA   , "xA   + xB   == xA"  )
	tassert(t , Tag , xA   + sA   , xA   , "xA   + sA   == xA"  )
	tassert(t , Tag , xA   + sB   , xA   , "xA   + sB   == xA"  )
	tassert(t , Tag , xA   + sAB  , xA   , "xA   + sAB  == xA"  )
	tassert(t , Tag , xA   + cA   , xA   , "xA   + cA   == xA"  )
	tassert(t , Tag , xA   + cB   , xA   , "xA   + cB   == xA"  )
	tassert(t , Tag , xA   + cAB  , xA   , "xA   + cAB  == xA"  )
	tassert(t , Tag , xA   + iAX  , xA   , "xA   + iAX  == xA"  )
	tassert(t , Tag , xA   + iAY  , xA   , "xA   + iAY  == xA"  )
	tassert(t , Tag , xA   + iBX  , xA   , "xA   + iBX  == xA"  )
	tassert(t , Tag , xA   + iBY  , xA   , "xA   + iBY  == xA"  )
	tassert(t , Tag , xA   + iABX , xA   , "xA   + iABX == xA"  )
	tassert(t , Tag , xA   + iABY , xA   , "xA   + iABY == xA"  )
	tassert(t , Tag , xB   + e    , xB   , "xB   + e    == xB"  )
	tassert(t , Tag , xB   + xA   , xB   , "xB   + xA   == xB"  )
	tassert(t , Tag , xB   + xB   , xB   , "xB   + xB   == xB"  )
	tassert(t , Tag , xB   + sA   , xB   , "xB   + sA   == xB"  )
	tassert(t , Tag , xB   + sB   , xB   , "xB   + sB   == xB"  )
	tassert(t , Tag , xB   + sAB  , xB   , "xB   + sAB  == xB"  )
	tassert(t , Tag , xB   + cA   , xB   , "xB   + cA   == xB"  )
	tassert(t , Tag , xB   + cB   , xB   , "xB   + cB   == xB"  )
	tassert(t , Tag , xB   + cAB  , xB   , "xB   + cAB  == xB"  )
	tassert(t , Tag , xB   + iAX  , xB   , "xB   + iAX  == xB"  )
	tassert(t , Tag , xB   + iAY  , xB   , "xB   + iAY  == xB"  )
	tassert(t , Tag , xB   + iBX  , xB   , "xB   + iBX  == xB"  )
	tassert(t , Tag , xB   + iBY  , xB   , "xB   + iBY  == xB"  )
	tassert(t , Tag , xB   + iABX , xB   , "xB   + iABX == xB"  )
	tassert(t , Tag , xB   + iABY , xB   , "xB   + iABY == xB"  )
	tassert(t , Tag , sA   + e    , sA   , "sA   + e    == sA"  )
	tassert(t , Tag , sA   + xA   , xA   , "sA   + xA   == xA"  )
	tassert(t , Tag , sA   + xB   , xB   , "sA   + xB   == xB"  )
	tassert(t , Tag , sA   + sA   , sA   , "sA   + sA   == sA"  )
	tassert(t , Tag , sA   + sB   , sAB  , "sA   + sB   == sAB" )
	tassert(t , Tag , sA   + sAB  , sAB  , "sA   + sAB  == sAB" )
	tassert(t , Tag , sA   + cA   , cA   , "sA   + cA   == cA"  )
	tassert(t , Tag , sA   + cB   , cAB  , "sA   + cB   == cAB" )
	tassert(t , Tag , sA   + cAB  , cAB  , "sA   + cAB  == cAB" )
	tassert(t , Tag , sA   + iAX  , iAX  , "sA   + iAX  == iAX" )
	tassert(t , Tag , sA   + iAY  , iAY  , "sA   + iAY  == iAY" )
	tassert(t , Tag , sA   + iBX  , iABX , "sA   + iBX  == iABX")
	tassert(t , Tag , sA   + iBY  , iABY , "sA   + iBY  == iABY")
	tassert(t , Tag , sA   + iABX , iABX , "sA   + iABX == iABX")
	tassert(t , Tag , sA   + iABY , iABY , "sA   + iABY == iABY")
	tassert(t , Tag , sB   + e    , sB   , "sB   + e    == sB"  )
	tassert(t , Tag , sB   + xA   , xA   , "sB   + xA   == xA"  )
	tassert(t , Tag , sB   + xB   , xB   , "sB   + xB   == xB"  )
	tassert(t , Tag , sB   + sA   , sAB  , "sB   + sA   == sAB" )
	tassert(t , Tag , sB   + sB   , sB   , "sB   + sB   == sB"  )
	tassert(t , Tag , sB   + sAB  , sAB  , "sB   + sAB  == sAB" )
	tassert(t , Tag , sB   + cA   , cAB  , "sB   + cA   == cAB" )
	tassert(t , Tag , sB   + cB   , cB   , "sB   + cB   == cB"  )
	tassert(t , Tag , sB   + cAB  , cAB  , "sB   + cAB  == cAB" )
	tassert(t , Tag , sB   + iAX  , iABX , "sB   + iAX  == iABX")
	tassert(t , Tag , sB   + iAY  , iABY , "sB   + iAY  == iABY")
	tassert(t , Tag , sB   + iBX  , iBX  , "sB   + iBX  == iBX" )
	tassert(t , Tag , sB   + iBY  , iBY  , "sB   + iBY  == iBY" )
	tassert(t , Tag , sB   + iABX , iABX , "sB   + iABX == iABX")
	tassert(t , Tag , sB   + iABY , iABY , "sB   + iABY == iABY")
	tassert(t , Tag , sAB  + e    , sAB  , "sAB  + e    == sAB" )
	tassert(t , Tag , sAB  + xA   , xA   , "sAB  + xA   == xA"  )
	tassert(t , Tag , sAB  + xB   , xB   , "sAB  + xB   == xB"  )
	tassert(t , Tag , sAB  + sA   , sAB  , "sAB  + sA   == sAB" )
	tassert(t , Tag , sAB  + sB   , sAB  , "sAB  + sB   == sAB" )
	tassert(t , Tag , sAB  + sAB  , sAB  , "sAB  + sAB  == sAB" )
	tassert(t , Tag , sAB  + cA   , cAB  , "sAB  + cA   == cAB" )
	tassert(t , Tag , sAB  + cB   , cAB  , "sAB  + cB   == cAB" )
	tassert(t , Tag , sAB  + cAB  , cAB  , "sAB  + cAB  == cAB" )
	tassert(t , Tag , sAB  + iAX  , iABX , "sAB  + iAX  == iABX")
	tassert(t , Tag , sAB  + iAY  , iABY , "sAB  + iAY  == iABY")
	tassert(t , Tag , sAB  + iBX  , iABX , "sAB  + iBX  == iABX")
	tassert(t , Tag , sAB  + iBY  , iABY , "sAB  + iBY  == iABY")
	tassert(t , Tag , sAB  + iABX , iABX , "sAB  + iABX == iABX")
	tassert(t , Tag , sAB  + iABY , iABY , "sAB  + iABY == iABY")
	tassert(t , Tag , cA   + e    , cA   , "cA   + e    == cA"  )
	tassert(t , Tag , cA   + xA   , xA   , "cA   + xA   == xA"  )
	tassert(t , Tag , cA   + xB   , xB   , "cA   + xB   == xB"  )
	tassert(t , Tag , cA   + sA   , cA   , "cA   + sA   == cA"  )
	tassert(t , Tag , cA   + sB   , cAB  , "cA   + sB   == cAB" )
	tassert(t , Tag , cA   + sAB  , cAB  , "cA   + sAB  == cAB" )
	tassert(t , Tag , cA   + cA   , cA   , "cA   + cA   == cA"  )
	tassert(t , Tag , cA   + cB   , cAB  , "cA   + cB   == cAB" )
	tassert(t , Tag , cA   + cAB  , cAB  , "cA   + cAB  == cAB" )
	tassert(t , Tag , cA   + iAX  , iAX  , "cA   + iAX  == iAX" )
	tassert(t , Tag , cA   + iAY  , iAY  , "cA   + iAY  == iAY" )
	tassert(t , Tag , cA   + iBX  , iABX , "cA   + iBX  == iABX")
	tassert(t , Tag , cA   + iBY  , iABY , "cA   + iBY  == iABY")
	tassert(t , Tag , cA   + iABX , iABX , "cA   + iABX == iABX")
	tassert(t , Tag , cA   + iABY , iABY , "cA   + iABY == iABY")
	tassert(t , Tag , cB   + e    , cB   , "cB   + e    == cB"  )
	tassert(t , Tag , cB   + xA   , xA   , "cB   + xA   == xA"  )
	tassert(t , Tag , cB   + xB   , xB   , "cB   + xB   == xB"  )
	tassert(t , Tag , cB   + sA   , cAB  , "cB   + sA   == cAB" )
	tassert(t , Tag , cB   + sB   , cB   , "cB   + sB   == cB"  )
	tassert(t , Tag , cB   + sAB  , cAB  , "cB   + sAB  == cAB" )
	tassert(t , Tag , cB   + cA   , cAB  , "cB   + cA   == cAB" )
	tassert(t , Tag , cB   + cB   , cB   , "cB   + cB   == cB"  )
	tassert(t , Tag , cB   + cAB  , cAB  , "cB   + cAB  == cAB" )
	tassert(t , Tag , cB   + iAX  , iABX , "cB   + iAX  == iABX")
	tassert(t , Tag , cB   + iAY  , iABY , "cB   + iAY  == iABY")
	tassert(t , Tag , cB   + iBX  , iBX  , "cB   + iBX  == iBX" )
	tassert(t , Tag , cB   + iBY  , iBY  , "cB   + iBY  == iBY" )
	tassert(t , Tag , cB   + iABX , iABX , "cB   + iABX == iABX")
	tassert(t , Tag , cB   + iABY , iABY , "cB   + iABY == iABY")
	tassert(t , Tag , cAB  + e    , cAB  , "cAB  + e    == cAB" )
	tassert(t , Tag , cAB  + xA   , xA   , "cAB  + xA   == xA"  )
	tassert(t , Tag , cAB  + xB   , xB   , "cAB  + xB   == xB"  )
	tassert(t , Tag , cAB  + sA   , cAB  , "cAB  + sA   == cAB" )
	tassert(t , Tag , cAB  + sB   , cAB  , "cAB  + sB   == cAB" )
	tassert(t , Tag , cAB  + sAB  , cAB  , "cAB  + sAB  == cAB" )
	tassert(t , Tag , cAB  + cA   , cAB  , "cAB  + cA   == cAB" )
	tassert(t , Tag , cAB  + cB   , cAB  , "cAB  + cB   == cAB" )
	tassert(t , Tag , cAB  + cAB  , cAB  , "cAB  + cAB  == cAB" )
	tassert(t , Tag , cAB  + iAX  , iABX , "cAB  + iAX  == iABX")
	tassert(t , Tag , cAB  + iAY  , iABY , "cAB  + iAY  == iABY")
	tassert(t , Tag , cAB  + iBX  , iABX , "cAB  + iBX  == iABX")
	tassert(t , Tag , cAB  + iBY  , iABY , "cAB  + iBY  == iABY")
	tassert(t , Tag , cAB  + iABX , iABX , "cAB  + iABX == iABX")
	tassert(t , Tag , cAB  + iABY , iABY , "cAB  + iABY == iABY")
	tassert(t , Tag , iAX  + e    , iAX  , "iAX  + e    == iAX" )
	tassert(t , Tag , iAX  + xA   , xA   , "iAX  + xA   == xA"  )
	tassert(t , Tag , iAX  + xB   , xB   , "iAX  + xB   == xB"  )
	tassert(t , Tag , iAX  + sA   , iAX  , "iAX  + sA   == iAX" )
	tassert(t , Tag , iAX  + sB   , iABX , "iAX  + sB   == iABX")
	tassert(t , Tag , iAX  + sAB  , iABX , "iAX  + sAB  == iABX")
	tassert(t , Tag , iAX  + cA   , iAX  , "iAX  + cA   == iAX" )
	tassert(t , Tag , iAX  + cB   , iABX , "iAX  + cB   == iABX")
	tassert(t , Tag , iAX  + cAB  , iABX , "iAX  + cAB  == iABX")
	tassert(t , Tag , iAX  + iAX  , x    , "iAX  + iAX  == x"   )
	tassert(t , Tag , iAX  + iAY  , x    , "iAX  + iAY  == x"   )
	tassert(t , Tag , iAX  + iBX  , x    , "iAX  + iBX  == x"   )
	tassert(t , Tag , iAX  + iBY  , x    , "iAX  + iBY  == x"   )
	tassert(t , Tag , iAX  + iABX , x    , "iAX  + iABX == x"   )
	tassert(t , Tag , iAX  + iABY , x    , "iAX  + iABY == x"   )
	tassert(t , Tag , iAY  + e    , iAY  , "iAY  + e    == iAY" )
	tassert(t , Tag , iAY  + xA   , xA   , "iAY  + xA   == xA"  )
	tassert(t , Tag , iAY  + xB   , xB   , "iAY  + xB   == xB"  )
	tassert(t , Tag , iAY  + sA   , iAY  , "iAY  + sA   == iAY" )
	tassert(t , Tag , iAY  + sB   , iABY , "iAY  + sB   == iABY")
	tassert(t , Tag , iAY  + sAB  , iABY , "iAY  + sAB  == iABY")
	tassert(t , Tag , iAY  + cA   , iAY  , "iAY  + cA   == iAY" )
	tassert(t , Tag , iAY  + cB   , iABY , "iAY  + cB   == iABY")
	tassert(t , Tag , iAY  + cAB  , iABY , "iAY  + cAB  == iABY")
	tassert(t , Tag , iAY  + iAX  , x    , "iAY  + iAX  == x"   )
	tassert(t , Tag , iAY  + iAY  , x    , "iAY  + iAY  == x"   )
	tassert(t , Tag , iAY  + iBX  , x    , "iAY  + iBX  == x"   )
	tassert(t , Tag , iAY  + iBY  , x    , "iAY  + iBY  == x"   )
	tassert(t , Tag , iAY  + iABX , x    , "iAY  + iABX == x"   )
	tassert(t , Tag , iAY  + iABY , x    , "iAY  + iABY == x"   )
	tassert(t , Tag , iBX  + e    , iBX  , "iBX  + e    == iBX" )
	tassert(t , Tag , iBX  + xA   , xA   , "iBX  + xA   == xA"  )
	tassert(t , Tag , iBX  + xB   , xB   , "iBX  + xB   == xB"  )
	tassert(t , Tag , iBX  + sA   , iABX , "iBX  + sA   == iABX")
	tassert(t , Tag , iBX  + sB   , iBX  , "iBX  + sB   == iBX" )
	tassert(t , Tag , iBX  + sAB  , iABX , "iBX  + sAB  == iABX")
	tassert(t , Tag , iBX  + cA   , iABX , "iBX  + cA   == iABX")
	tassert(t , Tag , iBX  + cB   , iBX  , "iBX  + cB   == iBX" )
	tassert(t , Tag , iBX  + cAB  , iABX , "iBX  + cAB  == iABX")
	tassert(t , Tag , iBX  + iAX  , x    , "iBX  + iAX  == x"   )
	tassert(t , Tag , iBX  + iAY  , x    , "iBX  + iAY  == x"   )
	tassert(t , Tag , iBX  + iBX  , x    , "iBX  + iBX  == x"   )
	tassert(t , Tag , iBX  + iBY  , x    , "iBX  + iBY  == x"   )
	tassert(t , Tag , iBX  + iABX , x    , "iBX  + iABX == x"   )
	tassert(t , Tag , iBX  + iABY , x    , "iBX  + iABY == x"   )
	tassert(t , Tag , iBY  + e    , iBY  , "iBY  + e    == iBY" )
	tassert(t , Tag , iBY  + xA   , xA   , "iBY  + xA   == xA"  )
	tassert(t , Tag , iBY  + xB   , xB   , "iBY  + xB   == xB"  )
	tassert(t , Tag , iBY  + sA   , iABY , "iBY  + sA   == iABY")
	tassert(t , Tag , iBY  + sB   , iBY  , "iBY  + sB   == iBY" )
	tassert(t , Tag , iBY  + sAB  , iABY , "iBY  + sAB  == iABY")
	tassert(t , Tag , iBY  + cA   , iABY , "iBY  + cA   == iABY")
	tassert(t , Tag , iBY  + cB   , iBY  , "iBY  + cB   == iBY" )
	tassert(t , Tag , iBY  + cAB  , iABY , "iBY  + cAB  == iABY")
	tassert(t , Tag , iBY  + iAX  , x    , "iBY  + iAX  == x"   )
	tassert(t , Tag , iBY  + iAY  , x    , "iBY  + iAY  == x"   )
	tassert(t , Tag , iBY  + iBX  , x    , "iBY  + iBX  == x"   )
	tassert(t , Tag , iBY  + iBY  , x    , "iBY  + iBY  == x"   )
	tassert(t , Tag , iBY  + iABX , x    , "iBY  + iABX == x"   )
	tassert(t , Tag , iBY  + iABY , x    , "iBY  + iABY == x"   )
	tassert(t , Tag , iABX + e    , iABX , "iABX + e    == iABX")
	tassert(t , Tag , iABX + xA   , xA   , "iABX + xA   == xA"  )
	tassert(t , Tag , iABX + xB   , xB   , "iABX + xB   == xB"  )
	tassert(t , Tag , iABX + sA   , iABX , "iABX + sA   == iABX")
	tassert(t , Tag , iABX + sB   , iABX , "iABX + sB   == iABX")
	tassert(t , Tag , iABX + sAB  , iABX , "iABX + sAB  == iABX")
	tassert(t , Tag , iABX + cA   , iABX , "iABX + cA   == iABX")
	tassert(t , Tag , iABX + cB   , iABX , "iABX + cB   == iABX")
	tassert(t , Tag , iABX + cAB  , iABX , "iABX + cAB  == iABX")
	tassert(t , Tag , iABX + iAX  , x    , "iABX + iAX  == x"   )
	tassert(t , Tag , iABX + iAY  , x    , "iABX + iAY  == x"   )
	tassert(t , Tag , iABX + iBX  , x    , "iABX + iBX  == x"   )
	tassert(t , Tag , iABX + iBY  , x    , "iABX + iBY  == x"   )
	tassert(t , Tag , iABX + iABX , x    , "iABX + iABX == x"   )
	tassert(t , Tag , iABX + iABY , x    , "iABX + iABY == x"   )
	tassert(t , Tag , iABY + e    , iABY , "iABY + e    == iABY")
	tassert(t , Tag , iABY + xA   , xA   , "iABY + xA   == xA"  )
	tassert(t , Tag , iABY + xB   , xB   , "iABY + xB   == xB"  )
	tassert(t , Tag , iABY + sA   , iABY , "iABY + sA   == iABY")
	tassert(t , Tag , iABY + sB   , iABY , "iABY + sB   == iABY")
	tassert(t , Tag , iABY + sAB  , iABY , "iABY + sAB  == iABY")
	tassert(t , Tag , iABY + cA   , iABY , "iABY + cA   == iABY")
	tassert(t , Tag , iABY + cB   , iABY , "iABY + cB   == iABY")
	tassert(t , Tag , iABY + cAB  , iABY , "iABY + cAB  == iABY")
	tassert(t , Tag , iABY + iAX  , x    , "iABY + iAX  == x"   )
	tassert(t , Tag , iABY + iAY  , x    , "iABY + iAY  == x"   )
	tassert(t , Tag , iABY + iBX  , x    , "iABY + iBX  == x"   )
	tassert(t , Tag , iABY + iBY  , x    , "iABY + iBY  == x"   )
	tassert(t , Tag , iABY + iABX , x    , "iABY + iABX == x"   )
	tassert(t , Tag , iABY + iABY , x    , "iABY + iABY == x"   )
	tassert(t , Tag , e    - e    , e    , "e    - e    == e"   )
	tassert(t , Tag , e    - xA   , xA   , "e    - xA   == e"   )
	tassert(t , Tag , e    - xB   , xB   , "e    - xB   == e"   )
	tassert(t , Tag , e    - sA   , e    , "e    - sA   == e"   )
	tassert(t , Tag , e    - sB   , e    , "e    - sB   == e"   )
	tassert(t , Tag , e    - sAB  , e    , "e    - sAB  == e"   )
	tassert(t , Tag , e    - cA   , e    , "e    - cA   == e"   )
	tassert(t , Tag , e    - cB   , e    , "e    - cB   == e"   )
	tassert(t , Tag , e    - cAB  , e    , "e    - cAB  == e"   )
	tassert(t , Tag , e    - iAX  , e    , "e    - iAX  == e"   )
	tassert(t , Tag , e    - iAY  , e    , "e    - iAY  == e"   )
	tassert(t , Tag , e    - iBX  , e    , "e    - iBX  == e"   )
	tassert(t , Tag , e    - iBY  , e    , "e    - iBY  == e"   )
	tassert(t , Tag , e    - iABX , e    , "e    - iABX == e"   )
	tassert(t , Tag , e    - iABY , e    , "e    - iABY == e"   )
	tassert(t , Tag , xA   - e    , xA   , "xA   - e    == xA"  )
	tassert(t , Tag , xA   - xA   , xA   , "xA   - xA   == xA"  )
	tassert(t , Tag , xA   - xB   , xA   , "xA   - xB   == xA"  )
	tassert(t , Tag , xA   - sA   , xA   , "xA   - sA   == xA"  )
	tassert(t , Tag , xA   - sB   , xA   , "xA   - sB   == xA"  )
	tassert(t , Tag , xA   - sAB  , xA   , "xA   - sAB  == xA"  )
	tassert(t , Tag , xA   - cA   , xA   , "xA   - cA   == xA"  )
	tassert(t , Tag , xA   - cB   , xA   , "xA   - cB   == xA"  )
	tassert(t , Tag , xA   - cAB  , xA   , "xA   - cAB  == xA"  )
	tassert(t , Tag , xA   - iAX  , xA   , "xA   - iAX  == xA"  )
	tassert(t , Tag , xA   - iAY  , xA   , "xA   - iAY  == xA"  )
	tassert(t , Tag , xA   - iBX  , xA   , "xA   - iBX  == xA"  )
	tassert(t , Tag , xA   - iBY  , xA   , "xA   - iBY  == xA"  )
	tassert(t , Tag , xA   - iABX , xA   , "xA   - iABX == xA"  )
	tassert(t , Tag , xA   - iABY , xA   , "xA   - iABY == xA"  )
	tassert(t , Tag , xB   - e    , xB   , "xB   - e    == xB"  )
	tassert(t , Tag , xB   - xA   , xB   , "xB   - xA   == xB"  )
	tassert(t , Tag , xB   - xB   , xB   , "xB   - xB   == xB"  )
	tassert(t , Tag , xB   - sA   , xB   , "xB   - sA   == xB"  )
	tassert(t , Tag , xB   - sB   , xB   , "xB   - sB   == xB"  )
	tassert(t , Tag , xB   - sAB  , xB   , "xB   - sAB  == xB"  )
	tassert(t , Tag , xB   - cA   , xB   , "xB   - cA   == xB"  )
	tassert(t , Tag , xB   - cB   , xB   , "xB   - cB   == xB"  )
	tassert(t , Tag , xB   - cAB  , xB   , "xB   - cAB  == xB"  )
	tassert(t , Tag , xB   - iAX  , xB   , "xB   - iAX  == xB"  )
	tassert(t , Tag , xB   - iAY  , xB   , "xB   - iAY  == xB"  )
	tassert(t , Tag , xB   - iBX  , xB   , "xB   - iBX  == xB"  )
	tassert(t , Tag , xB   - iBY  , xB   , "xB   - iBY  == xB"  )
	tassert(t , Tag , xB   - iABX , xB   , "xB   - iABX == xB"  )
	tassert(t , Tag , xB   - iABY , xB   , "xB   - iABY == xB"  )
	tassert(t , Tag , sA   - e    , sA   , "sA   - e    == sA"  )
	tassert(t , Tag , sA   - xA   , xA   , "sA   - xA   == xA"  )
	tassert(t , Tag , sA   - xB   , xB   , "sA   - xB   == xB"  )
	tassert(t , Tag , sA   - sA   , e    , "sA   - sA   == e"   )
	tassert(t , Tag , sA   - sB   , sA   , "sA   - sB   == sA"  )
	tassert(t , Tag , sA   - sAB  , e    , "sA   - sAB  == e"   )
	tassert(t , Tag , sA   - cA   , e    , "sA   - cA   == e"   )
	tassert(t , Tag , sA   - cB   , sA   , "sA   - cB   == sA"  )
	tassert(t , Tag , sA   - cAB  , e    , "sA   - cAB  == e"   )
	tassert(t , Tag , sA   - iAX  , e    , "sA   - iAX  == e"   )
	tassert(t , Tag , sA   - iAY  , e    , "sA   - iAY  == e"   )
	tassert(t , Tag , sA   - iBX  , sA   , "sA   - iBX  == sA"  )
	tassert(t , Tag , sA   - iBY  , sA   , "sA   - iBY  == sA"  )
	tassert(t , Tag , sA   - iABX , e    , "sA   - iABX == e"   )
	tassert(t , Tag , sA   - iABY , e    , "sA   - iABY == e"   )
	tassert(t , Tag , sB   - e    , sB   , "sB   - e    == sB"  )
	tassert(t , Tag , sB   - xA   , xA   , "sB   - xA   == xA"  )
	tassert(t , Tag , sB   - xB   , xB   , "sB   - xB   == xB"  )
	tassert(t , Tag , sB   - sA   , sB   , "sB   - sA   == sB"  )
	tassert(t , Tag , sB   - sB   , e    , "sB   - sB   == e"   )
	tassert(t , Tag , sB   - sAB  , e    , "sB   - sAB  == e"   )
	tassert(t , Tag , sB   - cA   , sB   , "sB   - cA   == sB"  )
	tassert(t , Tag , sB   - cB   , e    , "sB   - cB   == e"   )
	tassert(t , Tag , sB   - cAB  , e    , "sB   - cAB  == e"   )
	tassert(t , Tag , sB   - iAX  , sB   , "sB   - iAX  == sB"  )
	tassert(t , Tag , sB   - iAY  , sB   , "sB   - iAY  == sB"  )
	tassert(t , Tag , sB   - iBX  , e    , "sB   - iBX  == e"   )
	tassert(t , Tag , sB   - iBY  , e    , "sB   - iBY  == e"   )
	tassert(t , Tag , sB   - iABX , e    , "sB   - iABX == e"   )
	tassert(t , Tag , sB   - iABY , e    , "sB   - iABY == e"   )
	tassert(t , Tag , sAB  - e    , sAB  , "sAB  - e    == sAB" )
	tassert(t , Tag , sAB  - xA   , xA   , "sAB  - xA   == xA"  )
	tassert(t , Tag , sAB  - xB   , xB   , "sAB  - xB   == xB"  )
	tassert(t , Tag , sAB  - sA   , sB   , "sAB  - sA   == sB"  )
	tassert(t , Tag , sAB  - sB   , sA   , "sAB  - sB   == sA"  )
	tassert(t , Tag , sAB  - sAB  , e    , "sAB  - sAB  == e"   )
	tassert(t , Tag , sAB  - cA   , sB   , "sAB  - cA   == sB"  )
	tassert(t , Tag , sAB  - cB   , sA   , "sAB  - cB   == sA"  )
	tassert(t , Tag , sAB  - cAB  , e    , "sAB  - cAB  == e"   )
	tassert(t , Tag , sAB  - iAX  , sB   , "sAB  - iAX  == sB"  )
	tassert(t , Tag , sAB  - iAY  , sB   , "sAB  - iAY  == sB"  )
	tassert(t , Tag , sAB  - iBX  , sA   , "sAB  - iBX  == sA"  )
	tassert(t , Tag , sAB  - iBY  , sA   , "sAB  - iBY  == sA"  )
	tassert(t , Tag , sAB  - iABX , e    , "sAB  - iABX == e"   )
	tassert(t , Tag , sAB  - iABY , e    , "sAB  - iABY == e"   )
	tassert(t , Tag , cA   - e    , cA   , "cA   - e    == cA"  )
	tassert(t , Tag , cA   - xA   , xA   , "cA   - xA   == xA"  )
	tassert(t , Tag , cA   - xB   , xB   , "cA   - xB   == xB"  )
	tassert(t , Tag , cA   - sA   , e    , "cA   - sA   == e"   )
	tassert(t , Tag , cA   - sB   , cA   , "cA   - sB   == cA"  )
	tassert(t , Tag , cA   - sAB  , e    , "cA   - sAB  == e"   )
	tassert(t , Tag , cA   - cA   , e    , "cA   - cA   == e"   )
	tassert(t , Tag , cA   - cB   , cA   , "cA   - cB   == cA"  )
	tassert(t , Tag , cA   - cAB  , e    , "cA   - cAB  == e"   )
	tassert(t , Tag , cA   - iAX  , e    , "cA   - iAX  == e"   )
	tassert(t , Tag , cA   - iAY  , e    , "cA   - iAY  == e"   )
	tassert(t , Tag , cA   - iBX  , cA   , "cA   - iBX  == cA"  )
	tassert(t , Tag , cA   - iBY  , cA   , "cA   - iBY  == cA"  )
	tassert(t , Tag , cA   - iABX , e    , "cA   - iABX == e"   )
	tassert(t , Tag , cA   - iABY , e    , "cA   - iABY == e"   )
	tassert(t , Tag , cB   - e    , cB   , "cB   - e    == cB"  )
	tassert(t , Tag , cB   - xA   , xA   , "cB   - xA   == xA"  )
	tassert(t , Tag , cB   - xB   , xB   , "cB   - xB   == xB"  )
	tassert(t , Tag , cB   - sA   , cB   , "cB   - sA   == cB"  )
	tassert(t , Tag , cB   - sB   , e    , "cB   - sB   == e"   )
	tassert(t , Tag , cB   - sAB  , e    , "cB   - sAB  == e"   )
	tassert(t , Tag , cB   - cA   , cB   , "cB   - cA   == cB"  )
	tassert(t , Tag , cB   - cB   , e    , "cB   - cB   == e"   )
	tassert(t , Tag , cB   - cAB  , e    , "cB   - cAB  == e"   )
	tassert(t , Tag , cB   - iAX  , cB   , "cB   - iAX  == cB"  )
	tassert(t , Tag , cB   - iAY  , cB   , "cB   - iAY  == cB"  )
	tassert(t , Tag , cB   - iBX  , e    , "cB   - iBX  == e"   )
	tassert(t , Tag , cB   - iBY  , e    , "cB   - iBY  == e"   )
	tassert(t , Tag , cB   - iABX , e    , "cB   - iABX == e"   )
	tassert(t , Tag , cB   - iABY , e    , "cB   - iABY == e"   )
	tassert(t , Tag , cAB  - e    , cAB  , "cAB  - e    == cAB" )
	tassert(t , Tag , cAB  - xA   , xA   , "cAB  - xA   == xA"  )
	tassert(t , Tag , cAB  - xB   , xB   , "cAB  - xB   == xB"  )
	tassert(t , Tag , cAB  - sA   , cB   , "cAB  - sA   == cB"  )
	tassert(t , Tag , cAB  - sB   , cA   , "cAB  - sB   == cA"  )
	tassert(t , Tag , cAB  - sAB  , e    , "cAB  - sAB  == e"   )
	tassert(t , Tag , cAB  - cA   , cB   , "cAB  - cA   == cB"  )
	tassert(t , Tag , cAB  - cB   , cA   , "cAB  - cB   == cA"  )
	tassert(t , Tag , cAB  - cAB  , e    , "cAB  - cAB  == e"   )
	tassert(t , Tag , cAB  - iAX  , cB   , "cAB  - iAX  == cB"  )
	tassert(t , Tag , cAB  - iAY  , cB   , "cAB  - iAY  == cB"  )
	tassert(t , Tag , cAB  - iBX  , cA   , "cAB  - iBX  == cA"  )
	tassert(t , Tag , cAB  - iBY  , cA   , "cAB  - iBY  == cA"  )
	tassert(t , Tag , cAB  - iABX , e    , "cAB  - iABX == e"   )
	tassert(t , Tag , cAB  - iABY , e    , "cAB  - iABY == e"   )
	tassert(t , Tag , iAX  - e    , iAX  , "iAX  - e    == iAX" )
	tassert(t , Tag , iAX  - xA   , xA   , "iAX  - xA   == xA"  )
	tassert(t , Tag , iAX  - xB   , xB   , "iAX  - xB   == xB"  )
	tassert(t , Tag , iAX  - sA   , e    , "iAX  - sA   == e"   )
	tassert(t , Tag , iAX  - sB   , iAX  , "iAX  - sB   == iAX" )
	tassert(t , Tag , iAX  - sAB  , e    , "iAX  - sAB  == e"   )
	tassert(t , Tag , iAX  - cA   , e    , "iAX  - cA   == e"   )
	tassert(t , Tag , iAX  - cB   , iAX  , "iAX  - cB   == iAX" )
	tassert(t , Tag , iAX  - cAB  , e    , "iAX  - cAB  == e"   )
	tassert(t , Tag , iAX  - iAX  , x    , "iAX  - iAX  == x"   )
	tassert(t , Tag , iAX  - iAY  , x    , "iAX  - iAY  == x"   )
	tassert(t , Tag , iAX  - iBX  , x    , "iAX  - iBX  == x"   )
	tassert(t , Tag , iAX  - iBY  , x    , "iAX  - iBY  == x"   )
	tassert(t , Tag , iAX  - iABX , x    , "iAX  - iABX == x"   )
	tassert(t , Tag , iAX  - iABY , x    , "iAX  - iABY == x"   )
	tassert(t , Tag , iAY  - e    , iAY  , "iAY  - e    == iAY" )
	tassert(t , Tag , iAY  - xA   , xA   , "iAY  - xA   == xA"  )
	tassert(t , Tag , iAY  - xB   , xB   , "iAY  - xB   == xB"  )
	tassert(t , Tag , iAY  - sA   , e    , "iAY  - sA   == e"   )
	tassert(t , Tag , iAY  - sB   , iAY  , "iAY  - sB   == iAY" )
	tassert(t , Tag , iAY  - sAB  , e    , "iAY  - sAB  == e"   )
	tassert(t , Tag , iAY  - cA   , e    , "iAY  - cA   == e"   )
	tassert(t , Tag , iAY  - cB   , iAY  , "iAY  - cB   == iAY" )
	tassert(t , Tag , iAY  - cAB  , e    , "iAY  - cAB  == e"   )
	tassert(t , Tag , iAY  - iAX  , x    , "iAY  - iAX  == x"   )
	tassert(t , Tag , iAY  - iAY  , x    , "iAY  - iAY  == x"   )
	tassert(t , Tag , iAY  - iBX  , x    , "iAY  - iBX  == x"   )
	tassert(t , Tag , iAY  - iBY  , x    , "iAY  - iBY  == x"   )
	tassert(t , Tag , iAY  - iABX , x    , "iAY  - iABX == x"   )
	tassert(t , Tag , iAY  - iABY , x    , "iAY  - iABY == x"   )
	tassert(t , Tag , iBX  - e    , iBX  , "iBX  - e    == iBX" )
	tassert(t , Tag , iBX  - xA   , xA   , "iBX  - xA   == xA"  )
	tassert(t , Tag , iBX  - xB   , xB   , "iBX  - xB   == xB"  )
	tassert(t , Tag , iBX  - sA   , iBX  , "iBX  - sA   == iBX" )
	tassert(t , Tag , iBX  - sB   , e    , "iBX  - sB   == e"   )
	tassert(t , Tag , iBX  - sAB  , e    , "iBX  - sAB  == e"   )
	tassert(t , Tag , iBX  - cA   , iBX  , "iBX  - cA   == iBX" )
	tassert(t , Tag , iBX  - cB   , e    , "iBX  - cB   == e"   )
	tassert(t , Tag , iBX  - cAB  , e    , "iBX  - cAB  == e"   )
	tassert(t , Tag , iBX  - iAX  , x    , "iBX  - iAX  == x"   )
	tassert(t , Tag , iBX  - iAY  , x    , "iBX  - iAY  == x"   )
	tassert(t , Tag , iBX  - iBX  , x    , "iBX  - iBX  == x"   )
	tassert(t , Tag , iBX  - iBY  , x    , "iBX  - iBY  == x"   )
	tassert(t , Tag , iBX  - iABX , x    , "iBX  - iABX == x"   )
	tassert(t , Tag , iBX  - iABY , x    , "iBX  - iABY == x"   )
	tassert(t , Tag , iBY  - e    , iBY  , "iBY  - e    == iBY" )
	tassert(t , Tag , iBY  - xA   , xA   , "iBY  - xA   == xA"  )
	tassert(t , Tag , iBY  - xB   , xB   , "iBY  - xB   == xB"  )
	tassert(t , Tag , iBY  - sA   , iBY  , "iBY  - sA   == iBY" )
	tassert(t , Tag , iBY  - sB   , e    , "iBY  - sB   == e"   )
	tassert(t , Tag , iBY  - sAB  , e    , "iBY  - sAB  == e"   )
	tassert(t , Tag , iBY  - cA   , iBY  , "iBY  - cA   == iBY" )
	tassert(t , Tag , iBY  - cB   , e    , "iBY  - cB   == e"   )
	tassert(t , Tag , iBY  - cAB  , e    , "iBY  - cAB  == e"   )
	tassert(t , Tag , iBY  - iAX  , x    , "iBY  - iAX  == x"   )
	tassert(t , Tag , iBY  - iAY  , x    , "iBY  - iAY  == x"   )
	tassert(t , Tag , iBY  - iBX  , x    , "iBY  - iBX  == x"   )
	tassert(t , Tag , iBY  - iBY  , x    , "iBY  - iBY  == x"   )
	tassert(t , Tag , iBY  - iABX , x    , "iBY  - iABX == x"   )
	tassert(t , Tag , iBY  - iABY , x    , "iBY  - iABY == x"   )
	tassert(t , Tag , iABX - e    , iABX , "iABX - e    == iABX")
	tassert(t , Tag , iABX - xA   , xA   , "iABX - xA   == xA"  )
	tassert(t , Tag , iABX - xB   , xB   , "iABX - xB   == xB"  )
	tassert(t , Tag , iABX - sA   , iBX  , "iABX - sA   == iBX" )
	tassert(t , Tag , iABX - sB   , iAX  , "iABX - sB   == iAX" )
	tassert(t , Tag , iABX - sAB  , e    , "iABX - sAB  == e"   )
	tassert(t , Tag , iABX - cA   , iBX  , "iABX - cA   == iBX" )
	tassert(t , Tag , iABX - cB   , iAX  , "iABX - cB   == iAX" )
	tassert(t , Tag , iABX - cAB  , e    , "iABX - cAB  == e"   )
	tassert(t , Tag , iABX - iAX  , x    , "iABX - iAX  == x"   )
	tassert(t , Tag , iABX - iAY  , x    , "iABX - iAY  == x"   )
	tassert(t , Tag , iABX - iBX  , x    , "iABX - iBX  == x"   )
	tassert(t , Tag , iABX - iBY  , x    , "iABX - iBY  == x"   )
	tassert(t , Tag , iABX - iABX , x    , "iABX - iABX == x"   )
	tassert(t , Tag , iABX - iABY , x    , "iABX - iABY == x"   )
	tassert(t , Tag , iABY - e    , iABY , "iABY - e    == iABY")
	tassert(t , Tag , iABY - xA   , xA   , "iABY - xA   == xA"  )
	tassert(t , Tag , iABY - xB   , xB   , "iABY - xB   == xB"  )
	tassert(t , Tag , iABY - sA   , iBY  , "iABY - sA   == iBY" )
	tassert(t , Tag , iABY - sB   , iAY  , "iABY - sB   == iAY" )
	tassert(t , Tag , iABY - sAB  , e    , "iABY - sAB  == e"   )
	tassert(t , Tag , iABY - cA   , iBY  , "iABY - cA   == iBY" )
	tassert(t , Tag , iABY - cB   , iAY  , "iABY - cB   == iAY" )
	tassert(t , Tag , iABY - cAB  , e    , "iABY - cAB  == e"   )
	tassert(t , Tag , iABY - iAX  , x    , "iABY - iAX  == x"   )
	tassert(t , Tag , iABY - iAY  , x    , "iABY - iAY  == x"   )
	tassert(t , Tag , iABY - iBX  , x    , "iABY - iBX  == x"   )
	tassert(t , Tag , iABY - iBY  , x    , "iABY - iBY  == x"   )
	tassert(t , Tag , iABY - iABX , x    , "iABY - iABX == x"   )
	tassert(t , Tag , iABY - iABY , x    , "iABY - iABY == x"   )
end

return T
