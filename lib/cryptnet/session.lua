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

function SessionManager:allocateSession()
	local id = self:getFreeSessionId()
	if not id then
		self.logger.warn('Failed to allocate session id')
		return nil
	end
	
	local session = Session.new(self, id)
	self.sessions[id] = session
end

function SessionManager:setUpSession(msg, resp_chan)
	local session = self:allocateSession()
	if not session then
		self.logger.warn('Failed to allocate session')
		return
	end
	
	session:getChallengeTx():set(msg:getChallenge())
	session:getChallengeRx():set(self.random:uint32())
end

function SessionManger:handleMessage(msg, resp_chan)
	if msg.isa(MessageAssoc) then
		self:setUpSession(msg, resp_chan)
	else
		local session = self:getSession(msg.getLocalId())
		if not session then
			return 
		end
	end
end

function SessionManager:getCryptnet()
	return self.cryptnet
end

function SessionManager:getSession(localId)
	return self.sessions[localId]
end


function Session:init(manager, idLocal)
	self.manager = manager
	self.idLocal = idLocal
	self.challengeRx = Challenge.new(0)
	self.challengeTx = Challenge.new(0)
	self.state = Session.state.IDLE
end

function Session:getLocalId()
	return self.idRemote
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

return SessionManager