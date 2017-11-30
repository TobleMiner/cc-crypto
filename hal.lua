local function class(parent)
	local class = {}
	local class_mt = { __index = class 	}
	
	if parent then
		setmetatable(class, { __index = parent })
	end
	
	return class
end

local HalLoader = class()
local HalLoaderCraftOS = class(HalLoader)
local HalLoaderOpenOS = class(HalLoader)

local ABSTRACTION_LAYERS = {HalLoaderCraftOS, HalLoaderOpenOS}


-----------
-- Abstract
-----------
function HalLoader.probe()
	error('probe not implemented')
end

function HalLoader.load()
	error('load not implemented')
end


----------
-- CraftOS
----------
function HalLoaderCraftOS.probe()
	if not os or type(os) ~= 'table' then
		return false
	end
	
	local success, version = pcall(os.version)
	if not success then
		return false
	end
	
	if not version or type(version) ~= 'string' then
		return false
	end
	
	local osName = 'CraftOS'
	return string.sub(version, 1, #osName) == osName
end

function HalLoaderCraftOS.load()
	os.loadAPI('hal/require.lua')
	
	local HalCraftOs = require('hal/craft_os/hal')
	return HalCraftOs.new()
end

---------
-- OpenOS
---------
function HalLoaderOpenOS.probe()
	if not _OSVERSION or type(_OSVERSION) ~= 'string' then
		return false
	end

	local osName = 'OpenOS'
	return string.sub(_OSVERSION, 1, #osName) == osName
end

function HalLoaderOpenOS.load()
	local HalOpenOs = require('hal/open_os/hal')
	return HalOpenOs.new()
end

for _, layer in pairs(ABSTRACTION_LAYERS) do
	if layer.probe() then
		return layer.load()
	end
end

error('No HAL for your OS found')