local util = require('util.lua')

local Queue = util.class()
local Element = util.class()

function Queue:init()
	local elem = Element.new()
	elem:setNext(elem)
	elem:setPrev(elem)
	self.head = elem
	self.length = 0
	end

function Queue:isEmpty()
	return self.head == self:getTail()
end

function Queue:size()
	return self.length
end

function Queue:enqueue(val)
	local elem = Element.new(val, self.head, self:getTail())
	self:getTail():setNext(elem)
	self.head:setPrev(elem)
	self.length = self.length + 1
end

function Queue:dequeue()
	if self:isEmpty() then
		return nil
	end
	
	local valHead = self.head:getNext()
	-- Fix references to head
	valHead:getNext():setPrev(self.head)
	valHead:getPrev():setNext(valHead:getNext())
	-- Disconnect head
	valHead:setNext(valHead)
	valHead:setPrev(valHead)
	self.length = self.length - 1
	return valHead:getValue()
end

function Queue:getTail()
	return self.head:getPrev()
end

function Element:init(val, next, prev)
	self.val = val
	self.next = next
	self.prev = prev
end

function Element:getValue()
	return self.val
end

function Element:getNext()
	return self.next
end

function Element:setNext(next)
	self.next = next
end

function Element:getPrev()
	return self.prev
end

function Element:setPrev(prev)
	self.prev = prev
end

return Queue
