local util = require('lib/util.lua')

local SessionManager = util.class()
local Session = util.class()

Session.state = {}
Session.state.ASSOCIATE = 0
Session.state.ASSOCIATED = 1
Session.state.DEAD = 2

function SessionManager:init(cryptnet)
	self.cryptnet = cryptnet
	self.sessions = {}
end

function Session:init(cryptnet, idLocal)
	self.idLocal = idLocal
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

return Session