if(type(require) ~= 'function') then
	os.loadAPI("util/include")
end

local aeslua = require('lib/aeslua.lua')
local sha1 = require('lib/sha1.lua')
local md5 = require('lib/md5.lua')
local util = require('lib/util.lua')
local logger = require('lib/logger.lua')

local SessionManger = require('lib/cryptnet/session.lua')

local Message = require('lib/cryptnet/message.lua')

local DEBUG_LEVEL = logger.DEBUG

local Cryptnet = util.class()

--[[
	This is a rough explanation of the message format. It should be reasonably(TM) secure

	Messages:
		ASSOC:
			Initial message for session setup. Sets up session and challenge on remote side. Sent A -> B
			(cleartext)
				type: "associate"
				id_a: local session id of requesting station
				id: id of sender (computer id)
				id_recipient: id of recipient
				keyid: id of key to use
				challenge: Random blob of data
			
			
		ASSOC_RESP:
			Association response, proves knowledge of secret key and sets up challenge on A. Sent B -> A
			(cleartext)
				type: "associate_response"
				id_a: local session id of requesting station
				id_b: local session id of responding station
				id: id of sender (computer id)
				id_recipient: id of recipient
				challenge: Random blob of data (my own challenge)
				hmac: hmac of all other paramters + challenge from ASSOC
				
				
		DATA:
			Messages sent after session setup. Sent A <-> B
			(cleartext)
				type: "data"
				id_a: local session id of sending station
				id_b: local session id of receiving station
				id: id of sender (computer id)
				id_recipient: id of recipient
				hmac: hmac of all other paramters + (ciphertext) + current challenge
			(ciphertext)
				data: payload
				
				
		DATA_RESP:
			This packet is not really authenticated too well but adding authentication would result in problems with lost response messages, too.
			Also current_challenge changes with each msg received thus it should be a rather small-ish problem
			(cleartext)
				type: "data_response"
				id_a: local session id of sending station
				id_b: local session id of receiving station
				id: id of sender (computer id)
				id_recipient: id of recipient
				success: [boolean] received msg was ok
				current_challenge: challenge expected by sender
				hmac: hmac of all other paramters
				
				
		DEASSOC:
			Deassociation message. Typically sent by A but can also be transmitted by B. Properly authenticated to prevent WLAN deauth-type fuckups
			(cleartexr)
				type: "deassociate"
				id_a: local session id of sending station
				id_b: local session id of receiving station
				id: id of sender (computer id)
				id_recipient: id of recipient
				hmac: hmac of all other paramters + current challenge
]]

function Cryptnet:init(side, keyStore, proto)
	local modem = peripheral.wrap(side)
	local logger_str = 'CRYPTNET ' .. side;
	if proto then
		logger_str = logger_str .. ' (' .. proto .. ')' 
	end
	
	self.ownId = os.getComputerID()
	self.keyStore = keystore
	self.sessionManger = SessionManger.new(self)
	self.logger = Logger.new(logger_str, DEBUG_LEVEL)
	self.modem = modem
	self.proto = proto
end

function Cryptnet:sendMessage(msg, chan)
	self.modem.transmit(chan, self.ownId, msg)
end

function Cryptnet:run()
	if not self.modem.isOpen(self.ownId) then
		self.modem.open(self.ownId)	
	end
	
	while true do
		local event, side, chan, resp_chan, msg, dist = os.pullEvent('modem_message')
		if side == self.side and chan == self.ownId then
			local message = Message.parse(self, msg)
			if message then
				self.sessionManger:handleMessage(message, resp_chan)
			end
		else
			os.queueEvent(event, side, chan, resp_chan, msg, dist)
		end
	end
end

function Cryptnet:getOwnId()
	return self.ownId
end

function Cryptnet:getKeyStore()
	return self.keyStore
end

function Cryptnet:getLogger()
	return self.logger
end

return Cryptnet