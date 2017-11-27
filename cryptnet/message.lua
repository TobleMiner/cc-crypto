local Logger = require('lib/logger.lua')

local DEBUG_LEVEL = Logger.INFO

local util = require('lib/util.lua')

local sha1 = require('lib/sha1.lua')
local aeslua = require("/lib/aeslua.lua")
require("lib/base64.lua")


local Message = util.class()
local MessageAssoc = util.class(Message)
local MessageAssocResponse = util.class(Message)
local MessageData = util.class(Message)
local MessageDataResponse = util.class(Message)
local MessageDeassoc = util.class(Message)

Message.type = {}
Message.type.ASSOC = 'associate'
Message.type.ASSOC_RESP = 'associate_response'
Message.type.DATA = 'data'
Message.type.DATA_RESP = 'data_response'
Message.type.DEASSOC = 'deassociate'

Message.typeMap = {}
Message.typeMap[Message.type.ASSOC] = MessageAssoc
Message.typeMap[Message.type.ASSOC_RESP] = MessageAssocResponse
Message.typeMap[Message.type.DATA] = MessageData
Message.typeMap[Message.type.DATA_RESP] = MessageDataResponse
Message.typeMap[Message.type.DEASSOC] = MessageDeassoc

function Message.getParams()
	return {'type', 'id', 'id_recipient', 'id_a'}
end

function Message.parse(cryptnet, msg)
	if not util.table_has(msg, Message.getParams()) then
		cryptnet:getLogger():warn('Failed to parse packet, missing keys')
		return nil
	end
	
	local msgType = msg.type
	if util.table_has(Message.typeMap, msgType) then
		return Message.typeMap[msgType]:fromMsg(cryptnet, msg)
	end

	cryptnet:getLogger():warn('Received message with unknown type')
end

function Message.fromMsg(clazz, cryptnet, msg)
	if not util.table_has(msg, clazz.getParams()) then
		cryptnet:getLogger():warn('Failed to parse message, missing keys')
		return nil
	end

	local message = clazz.new()
	message.isTx = false
	message:copyParams(msg)
	return message
end

function Message:init()
	self.isTx = true
	self.logger = Logger.new('message ' .. (self.getType and self.getType() or ''), DEBUG_LEVEL)
	
	-- Set up getters and setters based on params
	if self.getParams then
		for _,v in ipairs(self.getParams()) do
		local param = string.gsub(v, '^[a-z]', string.upper)
		local getter = 'get' .. param
		local setter = 'set' .. param
		self.logger:debug('Adding getter ' .. getter)
		self[getter] = function(self) return self[v] end
		self.logger:debug('Adding setter ' .. setter)
		self[setter] = function(self, value) self[v] = value end
		end
	end
	
	-- Set type if applicable
	if self:getClass().getType then
		self:setType(self:getClass().getType())
	end
end

function Message:copyParams(msg)
	for _, k in ipairs(self.getParams()) do
		self[k] = msg[k]
	end
end

function Message:calcHmac(key, challenge)
	local strHmac = self:strHmac() .. tostring(challenge:get())
	return sha1.hmac(key:getKey(), strHmac)
end

function Message:verify(key, challenge)
	local expected = self:calcHmac(key, challenge)
	local actual = self:getHmac()
	return expected == actual
end

function Message:toTable()
	local tbl = {}
	for _,v in ipairs(self.getParams()) do
		tbl[v] = self[v]
	end
	return tbl
end

function Message:getLocalId()
	return self.isTx and self.id_a or self.id_b
end

function Message:getRemoteId()
	return self.isTx and self.id_b or self.id_a
end

function Message:getSenderId()
	return self.id
end

function Message:getRecipientId()
	return self.id_recipient
end

function Message:getHmac()
	return self.hmac
end

function Message:isAuthenticated()
	return true
end




function MessageAssoc.getType()
	return Message.type.ASSOC
end

function MessageAssoc.getParams()
	return {'type', 'id', 'id_recipient', 'id_a', 'keyid', 'challenge'}
end

function MessageAssoc:isAuthenticated()
	return false
end




function MessageAssocResponse.getType()
	return Message.type.ASSOC_RESP
end

function MessageAssocResponse.getParams()
	return {'type', 'id', 'id_recipient', 'id_a', 'id_b', 'challenge', 'hmac'}
end

function MessageAssocResponse:strHmac()
	return self.type .. tostring(self.id) .. tostring(self.id_recipient) .. tostring(self.id_a) .. tostring(self.id_b) .. tostring(self.challenge) 
end




function MessageData.getType()
	return Message.type.DATA
end

function MessageData.getParams()
	return {'type', 'id', 'id_recipient', 'id_a', 'id_b', 'hmac', 'data'}
end

function MessageData:strHmac()
	return self.type .. tostring(self.id) .. tostring(self.id_recipient) .. tostring(self.id_a) .. tostring(self.id_b) .. tostring(self.data) 
end

function MessageData:encrypt(key, data)
	self.data = base64_encode(aeslua.encrypt(key:getKey(), textutils.serialize(data), aeslua.AES128, aeslua.CBCMODE))
end

function MessageData:decrypt(key)
	return textutils.unserialize(aeslua.decrypt(key:getKey(), base64_decode(self.data), aeslua.AES128, aeslua.CBCMODE))
end




function MessageDataResponse.getType()
	return Message.type.DATA_RESP
end

function MessageDataResponse.getParams()
	return {'type', 'id', 'id_recipient', 'id_a', 'id_b', 'hmac', 'success', 'challenge'}
end

function MessageDataResponse:strHmac()
	return self.type .. tostring(self.id) .. tostring(self.id_recipient) .. tostring(self.id_a) .. tostring(self.id_b) .. tostring(self.success) .. tostring(self.challenge)
end

function MessageDataResponse:calcHmac(key)
	local strHmac = self:strHmac()
	return sha1.hmac(key:getKey(), strHmac)
end




function MessageDeassoc.getType()
	return Message.type.DEASSOC
end

function MessageDeassoc.getParams()
	return {'type', 'id', 'id_recipient', 'id_a', 'id_b', 'hmac'}
end

function MessageData:strHmac()
	return self.type .. tostring(self.id) .. tostring(self.id_recipient) .. tostring(self.id_a) .. tostring(self.id_b)
end




return Message, MessageAssoc, MessageAssocResponse, MessageData, MessageDataResponse, MessageDeassoc