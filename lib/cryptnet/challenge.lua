local util = require('lib/util.lua')

local CHALLENGE_LENGTH = 32

local Challenge = util.class()

function Challenge:init(challenge)
	self.challenge = challenge
end

function Challenge:getAndInc()
	local ret = self.challenge
	if self.challenge == bit.blshift(1, CHALLENGE_LENGTH) - 1 then
		challenge = 0
	else
		challenge = challenge + 1
	end
	return ret
end

function Challenge:get()
	return self.challenge
end

function Challenge:set(challenge)
	self.challenge = challenge
end

return Challenge