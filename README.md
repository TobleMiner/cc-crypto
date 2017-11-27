Cryptnet
========

Cryptnet is a simple cryptography layer for computer craft modems. It uses AES-128 CBC for data encryption and HMAC-SHA1 for message authentication.

# Usage examples

## Sending messages

### Receiver

```lua
-- PHP style-ish vardump
_G['vardump'] = function(var, longform, prefix, refs)
	if not prefix then
		prefix = ''
	end
	
	if not refs then
		refs = {}
	end
	
	if type(var) == 'table' then
		local cyclic = not not refs[var]
		refs[var] = true
		print(prefix .. tostring(var) .. (cyclic and ' (cyclic)' or ''))
		if not cyclic then
			prefix = prefix .. ' '
			for k,v in pairs(var) do
				print(prefix .. k .. ': ' .. '(' .. type(v) .. ')')
				vardump(v, longform, prefix .. '| ', refs)
			end
			refs[var] = not longform			
		end
	else
		local str = tostring(var)
		str = string.gsub(str, '[^%a%s%d%p%%%^%$%(%)%[%]%*%+%-%?_~|{}\\]', '?')
		print(prefix .. (type(var) == 'string' and '"' .. str .. '"' or str))
	end
end

-- Replacement for require
os.loadAPI('util/include')

local Cryptnet, KeyStore, Key = require('cryptnet.lua')

-- Create key storage
local keyStore = KeyStore.new()
-- Create new shared key
local key = Key.new('superSecretSharedKey')
-- Add key to key storage
keyStore:addKey(key)

-- Create new cryptnet instance, arguments: <modem side>, <key store>, <message rx callback>
local cryptnet = Cryptnet.new('top', keyStore, function(msg) vardump(msg) end)

-- Start cryptnet coroutine
cryptnet:run()
```

### Sender

```lua
-- Replacement for require
os.loadAPI('util/include')

local Cryptnet, KeyStore, Key = require('cryptnet.lua')

-- Create key storage
local keyStore = KeyStore.new()
-- Create new shared key
local key = Key.new('superSecretSharedKey')
-- Add key to key storage
keyStore:addKey(key)

-- Create new cryptnet instance, arguments: <modem side>, <key store>
local cryptnet = Cryptnet.new('back', keyStore)

parallel.waitForAll(
	-- Start cryptnet worker coroutine
	function() cryptnet:run() end,
	-- Send some messages, arguments: <message>, <recipient computer id>, <key>
	function() cryptnet:send('Hello World', 1, key); cryptnet:send({ foo = 'bar', bar = 'foo' }, 1, key); cryptnet:send(true, 1, key) end)
```

## Ping

### Client
```lua
-- Replacement for require
os.loadAPI('util/include')

local Cryptnet, KeyStore, Key = require('cryptnet.lua')

-- Create key storage
local keyStore = KeyStore.new()
-- Create new shared key
local key = Key.new('superSecretSharedKey')
-- Add key to key storage
keyStore:addKey(key)

-- Create new cryptnet instance, arguments: <modem side>, <key store>
local cryptnet = Cryptnet.new('back', keyStore)

cryptnet:setRxCallback(function(msg, senderId) print('got pong ' .. tostring(msg)) end)

parallel.waitForAll(
	-- Start cryptnet worker coroutine
	function() cryptnet:run() end,
	-- Send periodic ping
	function() 
		local msgId = 0
		while true do
			print('sending ping ' .. tostring(msgId))
			cryptnet:send(msgId, 1, key)
			msgId = msgId + 1
			sleep(1) 
		end
	end)
```

### Server
```lua
-- Replacement for require
os.loadAPI('util/include')

local Cryptnet, KeyStore, Key = require('cryptnet.lua')

-- Create key storage
local keyStore = KeyStore.new()
-- Create new shared key
local key = Key.new('superSecretSharedKey')
-- Add key to key storage
keyStore:addKey(key)

-- Create new cryptnet instance, arguments: <modem side>, <key store>
local cryptnet = Cryptnet.new('top', keyStore)

cryptnet:setRxCallback(
	function(msg, senderId) 
		print('got ping ' .. tostring(msg) .. ' from ' .. tostring(senderId))
		print('sending pong ' .. tostring(msg) .. ' to ' .. tostring(senderId))
		cryptnet:send(msg, senderId, key) 
	end)

-- Start cryptnet worker coroutine
cryptnet:run()
```