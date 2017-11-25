	if(type(require) ~= 'function') then
		os.loadAPI("util/include")
	end

	local aeslua = require('lib/aeslua.lua')
	local sha1 = require('lib/sha1.lua')
	local md5 = require('lib/md5.lua')
	local util = require('lib/util.lua')
	local logger = require('lib/logger.lua')
	
	local Message, MessageAssoc = require('lib/cryptnet/message.lua')

	local DEBUG_LEVEL = logger.DEBUG

	local MAX_NUM_SESSIONS = 1000

	local SESSION_TIMEOUT = 3000
	local MSG_TIMEOUT = 1000
	local MSG_RESEND_COUNT = 4


	local Cryptnet = {}

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

	Cryptnet.state = {}
	Cryptnet.state.ASSOCIATE = 0
	Cryptnet.state.ASSOCIATED = 1
		
	-- This is a pretty bad rng. math.random is only a PRNG
	local cryptnet_random32()
		return math.random(0, bit.blshift(1, 32) - 1)
	end

	local cryptnet_find_free_local_id(self)
		for local id=0, MAX_NUM_SESSIONS do
			if util.table_has(self.sessions, id) then
				return id
			end
		end
		return nil
	end

	local function cryptnet_session_reset_timeout(self)

	end

	function Cryptnet.Session.new(cryptnet)
		local id_a = cryptnet_find_free_local_id(cryptnet)
		local logger = logger.new("[SESSION " .. tostring(id_a) .. "]")
		if not id_a then
			logger.error("No free local session id found")
		end
		local challenge_rx = cryptnet_random32()
		return {	id_a = id_a,
					id_b = nil,
					logger = logger
					challenge_rx = challenge_rx,
					challenge_tx = nil,
					state = Cryptnet.state.ASSOCIATE }
	end
	
	local function cryptnet_check_msg_base(self, msg)
		if not util.table_has(msg, 'type') then
			self.logger:warn('Received message has no ')
			return false
		end
		if not util.table_has(msg, 'id') then
			return false
		end
	end
	
	local function cryptnet_handle_msg(self, msg, chan, resp_chan)
		
		if msg.type == Cryptnet.msg_type.ASSOC then
		
		elseif msg.type == Cryptnet.msg_type.ASSOC_RESP then
		
		elseif msg.type == Cryptnet.msg_type.DATA then
		
		elseif msg.type == Cryptnet.msg_type.DATA_RESP then
		
		elseif msg.type == Cryptnet.msg_type.DEASSOC then
		
		else
		
		end
		if not table_key_exists(msg, 'id') then
			return nil
		end
		if type(msg.id) ~= 'number' then
			return nil
		end
		
		if not table_key_exists(msg, 'hmac') then
			return nil
		end
		if type(msg.hmac) ~= 'string' then
			return nil
		end

		if not table_key_exists(msg, 'data') then
			return nil
		end
		if type(msg.data) ~= 'string' then
			return nil
		end
		
		local id_hmac = msg.id;
		if msg.id ~= sender_id then
			return nil
		end		
	end

	function cryptnet_send(self, msg, id_to)
		
	end

	function cryptnet_receive(self)
		while true do
			local side, chan, resp_chan, msg, dist = os.pullEvent('modem_message')
			if side == self.side then
				cryptnet_handle_msg(self, msg, chan, resp_chan)
			else
				-- Nope, not our event
				os.queueEvent('mode_message', side, chan, resp_chan, msg, dist)
			end
		end
	end

	function Cryptnet.new(side, keystore, proto)
		local modem = peripheral.wrap(side)
		local logger_str = 'CRYPTNET ' .. modem;
		if proto then
			logger_str = logger_str .. ' (' .. proto .. ')' 
		end
		rednet.open(modem)
		return { 	keystore = keystore, 
					side = side,
					modem = modem,
					proto = proto,
					sessions = {},
					logger = logger.new(logger_str, DEBUG_LEVEL),
					send = cryptnet_send,
					receive = cryptnet_receive,
					getLogger = function(self) return self.logger; end}
	end

	local Key = {}

	local function key_get_id(self)
		return self.id
	end

	local function key_get_valid_remote_ids(self)
		return self.remote_ids
	end

	function Key.new(logger, key, remote_ids)
		if remote_ids ~= 'nil' and type(remote_ids) ~= 'table' then
			logger:error('Remote ids must be a table')
		end
		local id = md5.sumhexa(key)
		return {	id = id,
					key = key,
					remote_ids = remote_ids,
					get_id = key_get_id,
					get_valid_remote_ids = key_get_valid_remote_ids }
	end

	local Keystore = {}

	local function keystore_add(self, key, remote_ids)
		local key = Key.new(self.logger, key, remote_ids)
		if(util.table_has(self.keys, key:get_id())) then
			self.logger:warn("Duplicate key id '" .. id .. "' overwriting old key")
		end

		self.keys[key.get_id()] = key
	end

	local function keystore_get(self, id)
		return self.keys[id]
	end

	function Keystore.new()
		return { 	keys = {},
					logger = logger.new('KEYSTORE', DEBUG_LEVEL),
					add_key = keystore_add,
					get_key = keystore_get }
	end

	return Cryptnet, Keystore