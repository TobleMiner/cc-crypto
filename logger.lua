local util = require('lib/util.lua')

local Logger = util.class()

Logger.DEBUG = 0
Logger.INFO = 1
Logger.WARNING = 2
Logger.ERROR = 3

function Logger:log(msg, level)
	local prefixed_msg = "[" .. self.name .. "] " .. msg
	if level == Logger.ERROR then
		error(prefixed_msg)
	elseif level >= self.level then
		print(prefixed_msg)
	end
end

function Logger:error(msg)
	self:log(msg, Logger.ERROR)
end

function Logger:warn(msg)
	self:log(msg, Logger.WARNING)
end

function Logger:info(msg)
	self:log(msg, Logger.INFO)
end

function Logger:debug(msg)
	self:log(msg, Logger.DEBUG)
end

function Logger:init(name, level)
	if not level then
		level = Logger.DEBUG
	end
	self.name = name
	self.level = level
end

return Logger