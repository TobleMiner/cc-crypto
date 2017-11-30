if not LD_LIBRARY_PATH then
	_G['LD_LIBRARY_PATH'] = 'lib/:util/'
end

_G['require'] = function(fname)
	if fs.exists(fname) then
		local f = assert(loadfile(fname))
		return f()
	else
		if not LD_LIBRARY_PATH then
			error('LD_LIBRARY_PATH not set')
		else
			for path in string.gmatch(LD_LIBRARY_PATH, '[^:]+') do
				local fabs = fs.combine(path, fname)
				if fs.exists(fabs) then
					return require(fabs)
				end
			end
			error('File not found')
		end
	end
end