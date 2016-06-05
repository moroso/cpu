cp_regs = {}
for k,v in ipairs({"pflags", "ptb", "eha", "epc", "ec0", "ec1", "ec2", "ec3", "ea0", "ea1", "", "", "", "", "", "", "sp0", "sp1", "sp2", "sp3", "MAX"}) do
	cp_regs[k-1] = v
	cp_regs[v] = k-1
end

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

commands.regs = {
	shortdesc = "dump registers (options: r; r pc; r c; r p; r all)",
	func = function(toks)
		local pr_regs = false
		local pr_pc = false
		local pr_cp = false
		local pr_p = false
		
		local st = osorom.get_state()
		
		if #toks == 1 then pr_regs = true end
		
		for k,v in ipairs(toks) do
			if k == 1 then
			elseif v == "all" then
				pr_regs = true
				pr_pc = true
				pr_cp = true
				pr_p = true
			elseif v == "p" or v == "pred" then
				pr_p = true
			elseif v == "c" or v == "co" or v == "cp" or v == "cpsr" then
				pr_cp = true
			elseif v == "pc" then
				pr_pc = true
			elseif v == "regs" or v == "gpr" or v == "gprs" then
				pr_regs = true
			else
				print("regs: what is a "..v..", anyway?")
				return false
			end
		end
		
		if pr_regs then
			local s = ""
			for i=0,31 do
				s = s .. string.format("%sr%d = 0x%08x ", (i >= 10 and "" or " "), i, st.r[i])
				if (i % 4) == 3 and i ~= 31 then s = s .. "\n" end
			end
			print(s)
		end
		
		if pr_pc then
			print(string.format("pc = 0x%08x", st.pc))
		end
		
		if pr_cp then
			local s = ""
			for i=0,cp_regs.MAX-1 do
				if cp_regs[i] ~= "" then
					s = s .. string.format("%6s = 0x%08x", cp_regs[i], st.cp[i])
					if (i % 2) == 1 then s = s .. "\n" end
				end
			end
			s = s .. string.format("%6s = 0x%08x%6s = 0x%08x",
			                       "ovf", st.ovf,
			                       "kmode", st.kmode)
			print(s)
		end
		
		if pr_p then
			print(string.format("pred = { %d, %d, %d }", st.pred[0], st.pred[1], st.pred[2]))
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
