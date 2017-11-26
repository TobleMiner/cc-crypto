local MAX_NUM_SESSIONS = 1000

local SESSION_TIMEOUT = 3000
local MSG_TIMEOUT = 1000
local MSG_RESEND_COUNT = 4


local util = require('lib/util.lua')
local Logger = require('lib/logger.lua')
local Timer = require('lib/timer.lua')
local Message, MessageAssoc, MessageAssocResponse, MessageData, MessageDataResponse, MessageDeassoc = require('lib/cryptnet/message.lua')
local Challenge = require('lib/cryptnet/challenge.lua')
local Random = require('lib/random.lua')

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
	self.logger = Logger.new('session')
	self.timer = Timer.new()
	self.random = Random.new()
end

function SessionManager:run()
	self.timer:run()
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
		self.logger.warn('Failed to allocate session id')
		return nil
	end
	
	local session = Session.new(self, id, ...)
	self.sessions[id] = session
end

function SessionManager:setUpSession(msg, resp_chan)
	local keyId = msg:getKeyid()
	local key = self.cryptnet:getKeyStore():getKey(keyId)
	if not key then
		self.logger.warn("Failed to find key for id")
		return 
	end
	
--[[ This would be 100% pseudo security, wouldn't it?
	if not key:validFor(msg:getId()) then
		self.logger:warn("Key not valid for sender")
		return
	end
]]	
	
	local session = self:allocateSession(key, msg:getId())
	if not session then
		self.logger.warn('Failed to allocate session')
		return
	end
	
	session:setRemoteId(msg:getId_a())
	
	session:getChallengeTx():set(msg:getChallenge())
	session:getChallengeRx():set(self.random:uint32())
	
	return session
end

function SessionManger:handleMessage(msg, resp_chan)
	local session = self:getSession(msg.getLocalId())
	if msg.isa(MessageAssoc) then
		session = self:setUpSession(msg, resp_chan)
	end
	if not session then
		return 
	end
	session:handleMessage(msg, resp_chan)
end

function SessionManager:getCryptnet()
	return self.cryptnet
end

function SessionManager:removeSession(session)
	return table.remove(self.sessions, session.getLocalId())
end

function SessionManager:getSession(localId)
	return self.sessions[localId]
end

function SessionManager:getTimer()
	return self.timer
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
	self.logger = Logger.new('session '..tostring(self.idLocal))
end

function Session:setTxIds(msg)
	-- logical connection ids (analogous to tcp/ip port)
	msg:setId_a(self:getLocalId())
	msg:setId_b(self:getRemoteId())
	
	-- computer ids as physical address (analogous to IP address (even though it is more like a MAC address))
	msg:setId(self.manger:getCryptnet():getOwnId())
	msg:setId_recipient(self.peerMac)
end

function Session:isMessageSane(msg)
	if msg:getLocalId() ~= self:getLocalId() then
		self.logger:warn('Local id of message does not match local session id')
		return false
	end

	if msg:getRemoteId() ~= self:getRemoteId() then
		self.logger:warn('Remote id of message does not match remote session id')
		return false
	end
	
	if msg:getId_recipient() ~= self.manger:getCryptnet():getOwnId() then
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
	if not self:isMessageSane() then
		self.logger:warn('Message does not seem to be sane, discarding message')
		return
	end
	
	if msg:isAutheticated() then
		if not msg:verify(self:getKey(), self:getChallengeRx()) then
			self.logger:warn('Message verification failed, discarding message')
			-- TODO: implement path for verification failures
			return
		end
	end
	
	local response = nil
	local handled = false
	
	if msg:isa(MessageAssoc) then
		response = session:handleAssoc(msg)
		handled = true
	elseif msg:isa(MessageAssocResponse) then
		self:handleAssocResponse()
		handled = true
	elseif msg:isa(MessageData) then
		self:handle
		handled = true
	end

	if handled then
		self:getChallengeRx():inc()
	end
	
	if response then
		if response:isAutheticated() then
			response:setHmac(response:hmac(self:getKey(), self:getChallengeTx()))
		end
		self.manager:getCryptnet():sendMessage(response:toTable(), self.peerMac)
	end
end

function Session:handleAssoc(msg)
	local assocResp = MessageAssocResponse.new()

	session:setTxIds(assocResp)
	assocResp:setChallenge(self:getChallengeRx():get())
	assocResp:setHmac(assocResp:hmac(self:getKey(), self:getChallengeTx()))

	-- "Handshake" complete (although everything might have gone wrong)
	self.state = Session.state.ASSOCIATED
	
	-- Kill unresponsive sessions
	self:resetTerminationTimeout()
	
	return assocResp
end

function Session:handleAssocResponse(msg)
	self:getChallengeTx():set(msg:getChallenge())

	-- "Handshake" complete (although everything might have gone wrong)
	self.state = Session.state.ASSOCIATED
	
	-- Kill unresponsive sessions
	self:resetTerminationTimeout()
end

function Session:resetTerminationTimeout()
	local timer = self.manager:getTimer()
	if self.timerTerminate then
		timer.clearTimeout(self.timerTerminate)
	end
	self.timerTerminate = timer.setTimeout(self.terminate, SESSION_TIMEOUT, self)
end

function Session:terminate()
	self.timerTerminate = nil
	self.manager:removeSession(self)
end

function Session:getLocalId()
	return self.idLocal
end

function Session:getRemoteId()
	return self.idRemote
end

function Session:setRemoteId(id_remote)
	self.idRemote = idRemote
end

function Session:getChallengeRx()
	return self:challengeRx
end

function Session:getChallengeTx()
	return self:challengeTx
end

function Session:getKey()
	return self.key
end

return SessionManager