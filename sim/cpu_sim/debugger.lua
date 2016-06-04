commands = {}

commands.help = {
	shortdesc = "show this help",
	func = function(toks)
		print("Commands:")
		for k,v in pairs(commands) do
			print(string.format("%10s: %s", k, v.shortdesc or "(no description)")) 
		end
		
		return true
	end
}

commands.quit = {
	shortdesc = "so long mom, I'm off to drop the bomb, so don't wait up for me",
	func = function()
		-- Although it may be / a pile of debris!
		os.exit()
	end
}

commands.p = {
	shortdesc = "virtual -> physical address lookup",
	func = function(toks)
		if #toks ~= 2 then
			print("Give an address!")
			return false
		end
		
		local addr = tonumber(toks[2])
		local pa_ro = osorom.virt_to_phys(addr, false)
		local pa_rw = osorom.virt_to_phys(addr, true)
		
		if pa_ro then
			print(string.format("Virtual address 0x%x maps to physical address %x (%s)",
			                    addr, pa_ro, pa_rw and "rw" or "ro"))
		else
			print(string.format("Virtual address 0x%x has no physical mapping", addr))
		end
	end
}

function process_line(s)
	-- Special case this thing out.
	if s:sub(1,1) == "=" then
		local f,err = load("return "..s:sub(2))
		if not f then
			print("eval: I don't think so, homez: "..err)
			return false
		end
		local status,rv = pcall(f)
		if not status then
			print("eval: error while evaluating: "..rv)
			return false
		end
		
		print(tostring(rv))
		return true
	end
	
	-- Ok, Tolkienize and invoke.
	local toks = {}
	for i in s:gmatch("%S+") do
		table.insert(toks, i)
	end
	
	if #toks == 0 then
		print("No tokens?")
		return false
	end
	
	if not commands[toks[1]] then
		print("Invalid command: "..toks[1])
		-- Oh well.
		print("I'm not sure what you meant, so I'm handing your line to the old C++ processor")
		osorom.process_line(s)
		return true
	end
	
	toks[0] = s
	return commands[toks[1]].func(toks)
end

local last = ""
while true do
	local s = osorom.readline("mdblua> ")
	if not s then break end
	if s == "" then
		s = last
	else
		last = s
		osorom.add_history(s)
	end
	process_line(s)
end
