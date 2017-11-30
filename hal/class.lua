return function(parent)
	local class = {}
	local class_mt = { __index = class 	}
	
	function class.create()
		local obj = {}
		setmetatable(obj, class_mt)
		return obj
	end

	function class.new(...)
		local obj = class:create()
		if obj.init then
			obj:init(...)
		end
		return obj
	end
	
	if parent then
		setmetatable(class, { __index = parent })
	end
	
	function class:getClass()
		return class
	end
	
	function class:getSuperClass()
		return parent
	end
	
	function class:isa(clazz)
		local cursor = class
		while cursor do
			if cursor == clazz then
				return true
			end
			cursor = cursor:getSuperClass()
		end
		return false
	end
	
	return class
end