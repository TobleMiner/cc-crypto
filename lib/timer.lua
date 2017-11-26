local util = require('lib/util.lua')

local TimerCallback = util.class()
local TimerManager = util.class()

function TimerCallback:init(callback, ...)
	self.callback = callback
	self.args = table.pack(...)
end

function TimerCallback:call()
	self.callback(table.unpack(self.args))
end


function TimerManager:init()
	self.timers = {}
end

function TimerManager:run()
	while true do
		local event, id = os.pullEvent('timer')
		if util.table_has(self.timers, id) then
			local callback = self.timers[id]
			table.remove(self.timers, id)
			callback:call()
		else
			os.queueEvent(event, id)
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

return TimerManager