local util = require('lib/util.lua')
local sha1 = require('lib/sha1.lua')
local Logger = require('lib/logger.lua')

local KeyStore = util.class()
local Key = util.class()

function KeyStore:init()
	self.logger = Logger.new('keystore', Logger.INFO)
	self.keys = {}
end

function KeyStore:addKey(key)
	if util.table_has(self.keys, key:getId()) then
		self.logger.warn('Duplicate key id '..key)
	end
	self.keys[key:getId()] = key
end

function KeyStore:getKey(keyId)
	return self.keys[keyId]
end

function Key:init(key, ...)
	self.key = key
	self.id = sha1(key)
	self.validIds = {}
	for _,v in ipairs(table.pack(...)) do
		self.validIds[v] = true
	end
end

function Key:getId()
	return self.id
end

function Key:getKey()
	return self.key
end

function Key:validFor(id)
	if #self.validIds == 0 then
		return 
	end
	return util.table_has(self.validIds, id)
end

return KeyStore, Key