local util = require('lib/util.lua')

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
		cryptnet.getLogger().error('Failed to parse packet, missing keys')
	end
	
	local msgType = msg.type
	if util.table_has(Message.typeMap, msgType) then
		return Message.typeMap[msgType]:fromMsg(cryptnet, msg)
	end

	cryptnet.getLogger().warn('Received message with unknown type')
end

function Message.fromMsg(clazz, cryptnet, msg)
	if not util.table_has(msg, clazz.getParams()) then
			cryptnet.getLogger().error('Failed to parse message, missing keys')
	end

	local message = clazz.create()
	message:copyParams(msg)
	return message
end

function Message:copyParams(msg)
	for _, k in ipairs(self.getParams()) do
		self[k] = msg[k]
	end
end


function MessageAssoc.getParams()
	return {'type', 'id', 'id_recipient', 'id_a', 'keyid', 'challenge'}
end

function MessageAssoc:handle(cryptnet)

end

function MessageAssocResponse.getParams()
	return {'type', 'id', 'id_recipient', 'id_a', 'id_b', 'challenge', 'hmac'}
end


function MessageData.getParams()
	return {'type', 'id', 'id_recipient', 'id_a', 'id_b', 'hmac', 'data'}
end


function MessageDataResponse.getParams()
	return {'type', 'id', 'id_recipient', 'id_a', 'id_b', 'hmac', 'data', 'success', 'challenge'}
end


function MessageDeassoc.getParams()
	return {'type', 'id', 'id_recipient', 'id_a', 'id_b', 'hmac'}
end

return Message, MessageAssoc