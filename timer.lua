local util = require('util.lua')

local TimerCallback = util.class()
local TimerManager = util.class()

function TimerCallback:init(callback, ...)
	self.callback = callback
	self.args = table.pack(...)
end

function TimerCallback:call(...)
	self.callback(table.unpack(self.args), ...)
end


function TimerManager:init(errorCallback, ...)
	self.timers = {}
	self:setErrorCallback(errorCallback, ...)
end

function TimerManager:run()
	while true do
		local event, id = os.pullEvent('timer')
		if util.table_has(self.timers, id) then
			local callback = self.timers[id]
			table.remove(self.timers, id)
			local success, err = pcall(function()
				callback:call()
			end)
			if not success and self.errorCallback then
				self.errorCallback:call(id, err)
			end
		end
	end
end

function TimerManager:setTimeout(callback, timeout, ...)
	local id = os.startTimer(timeout / 1000)
	self.timers[id] = TimerCallback.new(callback, ...)
	return id
end

function TimerManager:clearTimeout(id)
	os.cancelTimer(id)
	table.remove(self.timers, id)
end

function TimerManager:setErrorCallback(cb, ...)
	if cb then
		self.errorCallback = TimerCallback.new(cb, ...)
	else
		self.errorCallback = nil
	end
end

return TimerManager