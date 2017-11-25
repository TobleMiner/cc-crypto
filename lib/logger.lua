local logger = {}

logger.DEBUG = 0
logger.INFO = 1
logger.WARNING = 2
logger.ERROR = 3

local function logger_log(self, msg, level)
	local prefixed_msg = "[" .. self.name .. "] " .. msg
	if level == logger.ERROR then
		error(prefixed_msg)
	elseif level >= self.level then
		print(prefixed_msg)
	end
end

function logger.new(name, level)
	return {	name = name,
				level = level,
				log = logger_log,
				error = function(self, msg) self:log(msg, logger.ERROR) end,
				warn = function(self, msg) self:log(msg, logger.WARNING) end,
				info = function(self, msg) self:log(msg, logger.INFO) end,
				debug = function(self, msg) self:log(msg, logger.DEBUG) end }
end

return logger