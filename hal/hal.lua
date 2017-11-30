local class = require('hal/class')

local Hal = class()

-----------
-- Callback
-----------
Hal.Callback = class()

function Hal.Callback:init(callback, ...)
	self.callback = callback
	self.args = table.pack(...)
end

function Hal.Callback:call()
	return pcall(self.callback, table.unpack(self.args))
end


--------
-- Timer
--------
Hal.Timer = class()

function Hal.Timer:init()
	self.timers = {}
end

function Hal.Timer:run()
	if self:getClass()._OS_hasCallbacks() then
		return
	end

	while true do
		local id = Hal.Event:pullTimerEvent()
		if self.timers[id] then
			local callback = self.timers[id]
			self.timers[id] = nil
			callback:call()
		end
	end
end

function Hal.Timer:setTimeout(callback, t, ...)
	local cb = Hal.Callback.new(callback, ...)
	if self:getClass()._OS_hasCallbacks() then
		return self:_OS_setTimeout(t, function() cb:call() end)
	else
		local id = self:_OS_setTimeout(t)
		self.timers[id] = cb
		return id
	end
end

function Hal.Timer:clearTimeout(id)
	self.timers[id] = nil
	self:_OS_clearTimeout(id)
end

function Hal.Timer:_OS_setTimeout(t, cb)
	error('Hal.Timer:_OS_setTimeout not implemented')
end

function Hal.Timer:_OS_clearTimeout(id)
	error('Hal.Timer:_OS_clearTimeout not implemented')
end

function Hal.Timer._OS_hasCallbacks()
	error('Hal.Timer._OS_hasCallbacks not implemented')
end

function Hal.Timer:sleep(t)
	error('Hal.Timer:sleep not implemented')
end


----------
-- Network
----------
Hal.Network = class()

function Hal.Network:getInterfaces()
	error('Hal.Network:getInterfaces not implemented')	
end

-- returns localAddress, address, data
function Hal.Network:receive()
	error('Hal.Network:receive not implemented')		
end


Hal.Network.Interface = class()

function Hal.Network.Interface:init(address, wireless)
	self.address = address
	self.wireless = wireless
	self.config = nil
end

function Hal.Network.Interface:transmit(address, data)
	error('Hal.Network.Interface:transmit not implemented')		
end

-- returns address, data
function Hal.Network.Interface:receive()
	error('Hal.Network.Interface:receive not implemented')		
end

function Hal.Network.Interface:equals(iface)
	return self:getAddress() == iface:getAddress()
end

function Hal.Network.Interface.isWireless()
	return self.wireless
end

function Hal.Network.Interface.isWired()
	return not self:isWireless()
end

function Hal.Network.Interface.getAddress()
	return self.address
end

function Hal.Network.Interface:setConfig(config)
	self.config = config
end

function Hal.Network.Interface:getConfig(config)
	return self.config
end

Hal.Network.Interface.Config = class()


--------
-- Event
--------
Hal.Event = class()

function Hal.Event:pullTimerEvent()
	error('Hal.Event:pullTimerEvent not implemented')	
end

function Hal.Event:pull(filter)
	error('Hal.Event:pull not implemented')
end

return Hal