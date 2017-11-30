local class = require('hal/class')
local Hal = require('hal/hal')


local event = require('event')
local component = require('event')
local serialization = require('serialization')

local HalOpenOs = class(Hal)

function HalOpenOs:init()
	self.Timer = HalOpenOs.Timer.new()
end


--------
-- Timer
--------
HalOpenOs.Timer = class(Hal.Timer)

function HalOpenOs.Timer:sleep(t)
	os.sleep(t)
end

function HalOpenOs.Timer:_OS_setTimeout(t, cb)
	return event.timer(t, cb)
end

function HalOpenOs.Timer:_OS_clearTimeout(id)
	event.cancel(id)
end

function Hal.Timer._OS_hasCallbacks()
	return true
end


----------
-- Network
----------
HalOpenOs.Network = class(Hal.Network)

function HalOpenOs.Network:getInterfaces()
	local ifaces = {}
	for iface in component.list('modem', true) do
		table.insert(ifaces, HalOpenOs.Network.Interface.new(iface))
	end
	return ifaces
end

HalOpenOs.Network.Interface = class(Hal.Network.Interface)

function HalOpenOs.Network.Interface:init(iface)
	self:getClass():getSuperClass().init(self, iface.address, iface.isWireless())
	self.iface = iface
end

function HalOpenOs.Network.Interface:transmit(address, data)
	self.iface.send(address, 0, serialization.serialize(data))
end

function HalOpenOs.Network.Interface:receive(address, data)

end

--------
-- Event
--------
HalOpenOs.Event = class(Hal.Event)

function HalOpenOs.Event:pull(filter)
	return event.pull(nil, filter)
end

return HalOpenOs