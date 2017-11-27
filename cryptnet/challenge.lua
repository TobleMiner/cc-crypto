local util = require('util.lua')

local CHALLENGE_LENGTH = 31

local Challenge = util.class()

function Challenge:init(challenge)
	self.challenge = challenge
end

function Challenge:inc()
	if self.challenge == bit.blshift(1, CHALLENGE_LENGTH) - 1 then
		self.challenge = 0
	else
		self.challenge = self.challenge + 1
	end
end

function Challenge:getAndInc()
	local ret = self.challenge
	self:inc()
	return ret
end

function Challenge:get()
	return self.challenge
end

function Challenge:set(challenge)
	self.challenge = challenge
end

return Challenge