local MAX_NUM_SESSIONS = 1000

local SESSION_TIMEOUT = 3000
local MSG_TIMEOUT = 1000
local MSG_RESEND_COUNT = 4

local QUEUE_LIMIT = 10

local Logger = require('logger.lua')

local DEBUG_LEVEL = Logger.INFO

local util = require('util.lua')
local Timer = require('timer.lua')
local Message, MessageAssoc, MessageAssocResponse, MessageData, MessageDataResponse, MessageDeassoc = require('cryptnet/message.lua')
local Challenge = require('cryptnet/challenge.lua')
local Random = require('random.lua')
local Queue = require('queue.lua')

local QueueKeyPair = util.class()

function QueueKeyPair:init(queue, key)
	self.queue = queue
	self.key = key
end

function QueueKeyPair:getQueue()
	return self.queue
end

function QueueKeyPair:getKey()
	return self.key
end

local SessionManager = util.class()
local Session = util.class()

Session.state = {}
Session.state.IDLE = 0
Session.state.ASSOCIATE = 1
Session.state.ASSOCIATED = 2
Session.state.DEAD = 3

function SessionManager:init(cryptnet)
	self.cryptnet = cryptnet
	self.sessions = {}
	self.logger = Logger.new('manager', DEBUG_LEVEL)
	self.timer = Timer.new()
	self.random = Random.new()
	self.messageQueues = {}
end

function SessionManager:run()
	self.timer:run()
end

function SessionManager:enqueueMessage(msg, recipient, key)
	if not util.table_has(self.messageQueues, recipient) then
		self.messageQueues[recipient] = QueueKeyPair.new(Queue.new(QUEUE_LIMIT), key)
	end
	self.messageQueues[recipient]:getQueue():enqueue(msg)
	self:updateQueues()	
end

function SessionManager:updateQueues()
	for id,qkp in pairs(self.messageQueues) do
		self.logger:debug('Tx queue length: ' .. qkp:getQueue():length())
		if not qkp:getQueue():isEmpty() then
			local session = self:getSessionForPeer(id)
			if not session then
				self.logger:debug('No session found, creating new session')
				session = self:allocateSession(qkp:getKey(), id)
				if session then
					self:setUpSession(session)
					session:associate()
				end
			end
			if session then
				session:notify()
			end
		end
	end
end

function SessionManager:getFreeSessionId()
	for i=1,MAX_NUM_SESSIONS do
		if not util.table_has(self.sessions, i) then
			return i
		end
	end
	return nil
end

function SessionManager:allocateSession(...)
	local id = self:getFreeSessionId()
	if not id then
		self.logger:warn('Failed to allocate session id')
		return nil
	end
	
	local session = Session.new(self, id, ...)
	self.sessions[id] = session
	return session
end

function SessionManager:setUpSession(session)
		session:getChallengeRx():set(self.random:uint32())
end

function SessionManager:associateSession(msg, resp_chan)
	local keyId = msg:getKeyid()
	local key = self.cryptnet:getKeyStore():getKey(keyId)
	if not key then
		self.logger:warn("Failed to find key for id")
		return nil
	end
	
--[[ This would be 100% pseudo security, wouldn't it?
	if not key:validFor(msg:getId()) then
		self.logger:warn("Key not valid for sender")
		return
	end
]]	
	
	local session = self:allocateSession(key, msg:getId())
	if not session then
		self.logger:warn('Failed to allocate session')
		return nil
	end
	
	return session
end

function SessionManager:handleMessage(msg, resp_chan)
	local session = self:getSession(msg:getLocalId())
	if msg:getType() == MessageAssoc.getType() then
		self.logger:debug('Got association request, setting up new session')
		session = self:associateSession(msg, resp_chan)
	end
	if not session then
		self.logger:warn('No session for rx message found')
		return 
	end
	session:handleMessage(msg, resp_chan)
end

function SessionManager:getSessionForPeer(peerId)
	for _,session in ipairs(self.sessions) do
		if session:getPeerId() == peerId and not session:isDead() then
			return session
		end
	end
	
	return nil
end

function SessionManager:getOrCreateSession(peerId, key)
	local session = self:getSessionForPeer(peerId)
	if not session then
		session = self:allocateSession(key, peerId)
	end
	if not session then
		return nil
	end
	
	self:setUpSession(session)

	return session
end

function SessionManager:getCryptnet()
	return self.cryptnet
end

function SessionManager:removeSession(session)
	return table.remove(self.sessions, session:getLocalId())
end

function SessionManager:getSession(localId)
	return self.sessions[localId]
end

function SessionManager:getTimer()
	return self.timer
end

function SessionManager:dequeMessage(peerId)
	if not util.table_has(self.messageQueues, peerId) then
		return nil
	end
	
	local qkp = self.messageQueues[peerId]	
	return qkp:getQueue():dequeue()
end






function Session:init(manager, idLocal, key, peerMac)
	self.manager = manager
	self.idLocal = idLocal
	self.key = key
	self.peerMac = peerMac
	self.idRemote = nil
	self.challengeRx = Challenge.new(0)
	self.challengeTx = Challenge.new(0)
	self.state = Session.state.IDLE
	
	self.timerTerminate = nil
	self.logger = Logger.new('session '..tostring(self.idLocal), DEBUG_LEVEL)
end

----------------------
-- TX message handling
----------------------
function Session:setTxIds(msg)
	-- logical connection ids (analogous to tcp/ip port)
	msg:setId_a(self:getLocalId())
	if msg.setId_b then
		msg:setId_b(self:getRemoteId())
	end
	
	-- computer ids as physical address (analogous to IP address (even though it is more like a MAC address))
	msg:setId(self.manager:getCryptnet():getOwnId())
	msg:setId_recipient(self.peerMac)
end

function Session:associate()
	if self.state ~= Session.state.IDLE then
		self.logger:error('Trying to associate in invalid state '..tostring(self.state))
	end

	self.logger:debug('Associating session')
	
	self:getChallengeRx():set(self.manager.random:uint32())
	
	local assoc = MessageAssoc.new()
	self:setTxIds(assoc)
	assoc:setKeyid(self:getKey():getId())
	assoc:setChallenge(self:getChallengeRx():get())
	
	-- Wait for handshake
	self.state = Session.state.ASSOCIATE
	
	-- Kill unresponsive sessions
	self:resetTerminationTimeout()
	
	self.manager:getCryptnet():sendMessage(assoc:toTable(), self.peerMac)
end

function Session:notify()
	while true do
		if self.state ~= Session.state.ASSOCIATED then
			self.logger:debug('Ignoring notify, not associated')
			return
		end
		
		local message = self.manager:dequeMessage(self.peerMac)
		if not message then
			return
		end
		
		local data = MessageData.new()
		self:setTxIds(data)
		data:encrypt(self.key, message)
		self.logger:debug('Sign '..data:getType()..' '..tostring(self:getChallengeTx():get()))
		data:setHmac(data:calcHmac(self:getKey(), self:getChallengeTx()))
		
		-- Kill unresponsive sessions
		-- self:resetTerminationTimeout()
		
		self.logger:debug('inc challenge TX')
		self:getChallengeTx():inc()
		self.manager:getCryptnet():sendMessage(data:toTable(), self.peerMac)
	end
end




----------------------
-- RX message handling
----------------------
function Session:isMessageSane(msg)
	if self.state > Session.state.ASSOCIATE then -- TODO: Define closer constraint
		if msg:getLocalId() ~= self:getLocalId() then
			self.logger:warn('Local id of message does not match local session id')
			return false
		end
	end
	
	if self.state > Session.state.ASSOCIATE then -- TODO: Define closer constraint		
		if msg:getRemoteId() ~= self:getRemoteId() then
			self.logger:warn('Remote id of message does not match remote session id')
			return false
		end
	end
		
	if msg:getId_recipient() ~= self.manager:getCryptnet():getOwnId() then
		self.logger:warn('Recipient id does not match our own id')
		return false
	end
	
	if msg:getId() ~= self.peerMac then
		self.logger:warn('Id does not match peer id')
		return false
	end
	
	return true
end

function Session:handleMessage(msg)
	if not self:isMessageSane(msg) then
		self.logger:warn('Message does not seem to be sane, discarding message')
		return
	end
	
	if msg:isAuthenticated() then
		self.logger:debug('Verify '..msg:getType()..' '..tostring(self:getChallengeRx():get()))
		if not msg:verify(self:getKey(), self:getChallengeRx()) then
			self.logger:warn('Message verification failed, discarding message')
			-- TODO: implement path for verification failures
			return
		end
	end
	
	local stateBefore = self.state
	
	local response = nil
	local handled = false
	
	if msg:getType() == MessageAssoc.getType() then
		response = self:handleAssoc(msg)
		handled = true
	elseif msg:getType() == MessageAssocResponse.getType() then
		self:handleAssocResponse(msg)
		handled = true
	elseif msg:getType() == MessageData.getType() then
		response = self:handleData(msg)
		handled = true
	elseif msg:getType() == MessageDataResponse.getType() then
		-- TODO: Maybe implement resend via handleDataResponse return value?
		self:handleDataResponse(msg)
		handled = true
	elseif msg:getType() == MessageDeassoc.getType() then
		self:handleDeassoc(msg)
		handled = true
	else
		self.logger:warn('Can not handle message, unknown message type')
	end

	if handled then
		self.logger:debug('inc challenge RX')
		self:getChallengeRx():inc()
	end
	
	if response then
		if response:isAuthenticated() then
			self.logger:debug('Sign '..response:getType()..' '..tostring(self:getChallengeTx():get()))
			response:setHmac(response:calcHmac(self:getKey(), self:getChallengeTx()))
		end
		self.manager:getCryptnet():sendMessage(response:toTable(), self.peerMac)
		self.logger:debug('inc challenge TX')
		self:getChallengeTx():inc()
	end
	
	if self.state == Session.state.ASSOCIATED then
		self:notify()
	end
end

function Session:handleAssoc(msg)
	if self.state ~= Session.state.IDLE then
		self.logger:warn('Received association in invalid state '..tostring(self.state))
		return
	end
		
	self:setRemoteId(msg:getRemoteId())
	self:getChallengeTx():set(msg:getChallenge())
	self:getChallengeRx():set(self.manager.random:uint32())

	local assocResp = MessageAssocResponse.new()
	
	self:setTxIds(assocResp)
	assocResp:setChallenge(self:getChallengeRx():get())

	-- "Handshake" complete (although everything might have gone wrong)
	self.state = Session.state.ASSOCIATED
	
	-- Kill unresponsive sessions
	self:resetTerminationTimeout()
	
	return assocResp
end

function Session:handleAssocResponse(msg)
	if self.state ~= Session.state.ASSOCIATE then
		self.logger:warn('Received association response in invalid state '..tostring(self.state))
		return
	end

	self:setRemoteId(msg:getRemoteId())
	self:getChallengeTx():set(msg:getChallenge())
	self:getChallengeTx():inc()

	-- "Handshake" complete (although everything might have gone wrong)
	self.state = Session.state.ASSOCIATED
	
	-- Kill unresponsive sessions
	self:resetTerminationTimeout()
	
	self:notify()
end

function Session:handleData(msg)
	if self.state ~= Session.state.ASSOCIATED then
		self.logger:warn('Received data in invalid state '..tostring(self.state))
		return
	end

	self.manager:getCryptnet():onRx(msg:decrypt(self:getKey()), self:getPeerId())

	local dataResp = MessageDataResponse.new()

	self:setTxIds(dataResp)
	-- Special challenge reset function; Only nedded for verification failure path
	-- dataResp:setChallenge(self:getChallengeRx():get())
	dataResp:setChallenge('nil')
	dataResp:setSuccess(true)
	
	-- Kill unresponsive sessions
	self:resetTerminationTimeout()
	
	return dataResp
end

function Session:handleDataResponse(msg)
	if self.state ~= Session.state.ASSOCIATED then
		self.logger:warn('Received data response in invalid state '..tostring(self.state))
		return
	end

	-- TODO: implement
	self.logger:debug(tostring(msg:getSuccess()))
	
	-- Kill unresponsive sessions
	self:resetTerminationTimeout()
end

function Session:handleDeassoc(msg)
	if self.state ~= Session.state.ASSOCIATED then
		self.logger:warn('Received deassoc in invalid state '..tostring(self.state))
		return
	end

	self:kill()
end



--------------------------
-- Session lifecycle stuff
--------------------------
function Session:resetTerminationTimeout()
	local timer = self.manager:getTimer()
	if self.timerTerminate then
		timer:clearTimeout(self.timerTerminate)
	end
	self.timerTerminate = timer:setTimeout(self.terminate, SESSION_TIMEOUT, self)
end

function Session:kill()
	if self.timerTerminate then
		self.manager:getTimer():clearTimeout(self.timerTerminate)
	end
	self:terminate()
end

-- Do not call manually, might leave dangling timers
function Session:terminate()
	self.logger:debug('Terminating session')
	self.state = Session.state.DEAD
	self.timerTerminate = nil
	self.manager:removeSession(self)
	self.manager:updateQueues()
end




------------------
-- Getters/setters
------------------
function Session:getLocalId()
	return self.idLocal
end

function Session:getRemoteId()
	return self.idRemote
end

function Session:setRemoteId(idRemote)
	self.idRemote = idRemote
end

function Session:getChallengeRx()
	return self.challengeRx
end

function Session:getChallengeTx()
	return self.challengeTx
end

function Session:getKey()
	return self.key
end

function Session:getPeerId()
	return self.peerMac
end

function Session:isDead()
	return self.stat == Session.state.DEAD
end

return SessionManager