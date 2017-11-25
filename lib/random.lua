local util = require('lib/util.lua')

local Random = util.class()

function Random.uint32()
	return math.random(0, bit.blshift(1, 32) - 1)
end

return Random