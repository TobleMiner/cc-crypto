os.loadAPI("util/include")

sha1 = require('lib/sha1.lua')

local util = require('lib/util.lua')
local Logger = require('lib/logger.lua')

local SessionManger = require('lib/cryptnet/session.lua')

local Message = require('lib/cryptnet/message.lua')

local DEBUG_LEVEL = Logger.INFO

local Callback = util.class()

function Callback:init(callback, ...)
	self.callback = callback
	self.args = table.pack(...)
end

function Callback:call(...)
	local args = table.pack(...)
	pcall(function()
		if #self.args > 0 then
			self.callback(table.unpack(self.args), table.unpack(args))
		else
			self.callback(table.unpack(args))
		end
	end)
end

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
			Also current_challenge changes with each msg received thus it should be a rather small-ish problem. It might be possible however to use this message
			to force a reset of te challenge to a known value resulting in a replay attack scenario
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

function Cryptnet:init(side, keyStore, rxCallback, ...)
	local modem = peripheral.wrap(side)
	local logger_str = 'CRYPTNET ' .. side
	
	self.side = side
	self.ownId = os.getComputerID()
	self.keyStore = keyStore
	self.sessionManger = SessionManger.new(self)
	self.logger = Logger.new(logger_str, DEBUG_LEVEL)
	self.modem = modem
	if rxCallback then
		self.rxCallback = Callback.new(rxCallback, ...)
	end
end

function Cryptnet:sendMessage(msg, chan)
	self.modem.transmit(chan, self.ownId, msg)
end

function Cryptnet:run()
	parallel.waitForAll(
		function() self:listen() end,
		function() self.sessionManger:run() end)
end

function Cryptnet:listen()
	if not self.modem.isOpen(self.ownId) then
		self.modem.open(self.ownId)	
	end
	
	self.logger:debug('Listening...')
	while true do
		local event, side, chan, resp_chan, msg, dist = os.pullEvent('modem_message')
		if side == self.side and chan == self.ownId then
			self.logger:debug('Got message')
			if not pcall(function()
				local message = Message.parse(self, msg)
				if message then
					self.sessionManger:handleMessage(message, resp_chan)
				end
			end) then
				self.logger.warn('Message handling failed')
			end
		else
			os.queueEvent(event, side, chan, resp_chan, msg, dist)
		end
	end
end

function Cryptnet:send(msg, recipient, key)
	self.sessionManger:enqueueMessage(msg, recipient, key)
end

function Cryptnet:onRx(msg)
	if self.rxCallback then
		self.rxCallback:call(msg)
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