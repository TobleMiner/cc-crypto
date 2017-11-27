local util = require('lib/util.lua')

local Random = util.class()

function Random.uint32()
	return math.random(0, bit.blshift(1, 30) - 1) -- Going any higher than 30 causes lua vm errors
end

return Random