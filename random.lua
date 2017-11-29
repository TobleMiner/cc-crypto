local util = require('util.lua')

local Random = util.class()

function Random.uint32()
	return math.random(0, bit.blshift(1, 30) - 1) -- Going any higher than 30 causes lua vm errors
end

function Random.uint8()
	return math.random(0, 255)
end

return Random