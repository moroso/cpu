-- Helper bits

cp_regs = {}
for k,v in ipairs({"pflags", "ptb", "eha", "epc", "ec0", "ec1", "ec2", "ec3", "ea0", "ea1", "", "", "", "", "", "", "sp0", "sp1", "sp2", "sp3", "MAX"}) do
	cp_regs[k-1] = v
	cp_regs[v] = k-1
end

exceptions = {}
for k,v in ipairs({"NO_ERROR", "PAGEFAULT_ON_FETCH", "ILLEGAL_INSTRUCTION", "INSUFFICIENT_PERMISSIONS", "DUPLICATE_DESTINATION", "PAGEFAULT_ON_DATA_ACCESS", "INVALID_PHYSICAL_ADDRESS", "DIVIDE_BY_ZERO", "INTERRUPT", "SYSCALL", "BREAK", "HALT", "MAX"}) do
	exceptions[k-1] = v
	exceptions[v] = k-1
end

function osorom.disas_virt(va)
	local pa = osorom.virt_to_phys(va, false)
	if not pa then return "<cannot access memory>" end
	return osorom.disas_phys(pa)
end

-- Command implementations

commands = {}

commands.help = {
	shortdesc = "show this help",
	synonyms = { "?", "h" },
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
	synonyms = { "q" },
	func = function()
		-- Although it may be / a pile of debris!
		os.exit()
	end
}

commands.p = {
	shortdesc = "virtual -> physical address lookup",
	synonyms = {},
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
	synonyms = { "r" },
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

function addr_to_sym(addr)
	local func = osorom.func_at(addr)
	if func then return string.format("0x%08x <%s+0x%x>", addr, func.name, func.offset)
	else return string.format("0x%08x <???>", addr)
	end
end

function where()
	local st = osorom.get_state()
	local sym = addr_to_sym(st.pc)
	local inst = osorom.disas_virt(st.pc)
	print(string.format("pc = %s  %s", sym, inst))
end

commands.where = {
	shortdesc = "Does Anybody Really Know What Time It Is?",
	synonyms = { "wh" },
	func = function (toks)
		where()
	end
}

commands.stepi = {
	shortdesc = "step one packet forward",
	synonyms = { "si", "i" },
	func = function (toks)
		osorom.step_program()
		where()
	end
}

commands.disas = {
	shortdesc = "disassemble a region",
	synonyms = { "d", "dis", "disassemble" },
	func = function (toks)
		local addr
		if #toks >= 2 then
			addr = tonumber(toks[2])
			if not addr then
				print(toks[1]..": look, "..toks[2].." isn't even a number")
				return false
			end
		end
		if not addr then
			addr = osorom.get_state().pc
		end
		if (addr & 0xF) ~= 0 then
			print(toks[1]..": hey, you can't fool me, "..string.format("0x%x", addr).." isn't packet-aligned")
			print(toks[1]..": (did you mistakenly specify a packet count instead of an address or something?  cause that ain't how this works.)")
			return false
		end
		
		local start_addr = addr - 0x30
		if start_addr < 0 then start_addr = 0 end
		local lastfuncname = nil
		for i=0,7 do
			local thisaddr = start_addr + i * 0x10
			local thisfunc = osorom.func_at(thisaddr)
			if lastfuncname and not thisfunc then
				print("<???>:")
			elseif thisfunc and lastfuncname ~= thisfunc.name then
				print(string.format("<%s+0x%x>:", thisfunc.name, thisfunc.offset))
				lastfuncname = thisfunc.name
			end
			print(string.format("%s%s%8x %s",
			                    false and "!" or " ", -- no breakpt support yet
			                    thisaddr == addr and ">" or " ",
			                    thisaddr,
			                    osorom.disas_virt(thisaddr)))
		end
	end
}

commands["break/e"] = {
	shortdesc = "manage exceptions to break on",
	synonyms = { "b/e", "break/exn", "break/exception", "b/exn", "b/exception", "break-exception" },
	func = function (toks)
		local exn_breaks = osorom.exn_breaks_get()
		if #toks == 1 then
			print("Breaking on exceptions:")
			for i=0,exceptions.MAX-1 do
				if exn_breaks[i] then
					print(string.format("  %d (%s)", i, exceptions[i]))
				end
			end
		else
			for i=2,#toks do
				local v = exceptions[toks[i]:upper()] or tonumber(toks[i])
				if not v then
					print(toks[1]..": I don't even know what \""..toks[i].."\" even means")
					return false
				end
				if v >= exceptions.MAX then
					print(toks[1]..": you can't fool me, there's no such exception as "..v)
					return false
				end
				print(string.format("%sed breakpoint on exception %d (that's %s to you).", exn_breaks[v] and "Remov" or "Add", v, exceptions[v]))
				osorom.exn_breaks_set(v, not exn_breaks[v])
			end
		end
	end
}

commands["x"] = {
	shortdesc = "x is for examine, is good enough for me",
	synonyms = { "xp?", "xp?/%d+[bhl]?", "xp?/[bhl]" },
	func = function (toks)
		-- ok, let's start by breaking this mess down.  we know it
		-- matches one of the syntaxes above, so we can simplify a
		-- bit
		local phys,count,sz = toks[1]:match("x(p?)/?(%d*)([bhl]?)")
		phys = phys == "p"
		count = count == "" and 1 or tonumber(count)
		if sz == "b" then sz = 8
		elseif sz == "h" then sz = 16
		elseif sz == "l" or sz == "" then sz = 32
		end
		
		local addr
		if #toks >= 2 then addr = tonumber(toks[2]) end
		if addr == nil then addr = osorom.get_state().pc end
		
		-- now we can do the hard work.
		local s = ""
		for i=0,count-1 do
			local va = addr + i * sz / 8
			local pa
			if not phys then
				pa = osorom.virt_to_phys(va, false)
				if not pa then s = s .. string.format("<invalid access at 0x%x> ", va) end
			else
				pa = thisaddr
			end
			
			s = s .. string.format(string.format("0x%%0%dx ", sz/4), osorom.physmem(sz, pa))
		end
		print(s)
	end
}

commands["break"] = {
	shortdesc = "manage pc addresses to break on",
	synonyms = { "b", "b/w", "break/w" },
	func = function (toks)
		local iswatch = toks[1] == "b/w" or toks[1] == "break/w"
		local _get = iswatch and osorom.write_watchpoints_get or osorom.breakpoints_get
		local _add = iswatch and osorom.write_watchpoints_add or osorom.breakpoints_add
		local _name = iswatch and "Watch" or "Break"
		local _mkaddr = iswatch and function (a) return string.format("0x%08x", a) end or addr_to_sym
		
		if #toks == 1 then
			print(_name .. "points:")
			for k,v in ipairs(_get()) do
				print(string.format("%4d at %s", v.id, _mkaddr(v.address)))
			end
		else
			for i=2,#toks do
				local addr = tonumber(toks[i])
				if not addr then
					print(toks[1]..": "..toks[i].." ain't no country I've ever heard of")
					return false
				end
				local id = _add(addr)
				print(string.format(_name .. "point %d set at %s", id, _mkaddr(addr)))
			end
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
	
	-- Who's that Pokemon?
	local cmd = commands[toks[1]]
	if not cmd then
		for k,v in pairs(commands) do
			for _,v2 in ipairs(v.synonyms) do
				if toks[1]:match("^"..v2.."$") then
					cmd = v
				end
			end
		end
	end
	
	if not cmd then
		print("Invalid command: "..toks[1])
		-- Oh well.
		print("I'm not sure what you meant, so I'm handing your line to the old C++ processor")
		osorom.process_line(s)
		return true
	end
	
	toks[0] = s
	return cmd.func(toks)
end

local last = ""
while true do
	local s = osorom.readline(string.format("mdb@0x%08x> ", osorom.get_state().pc))
	if not s then break end
	if s == "" then
		s = last
	else
		last = s
		osorom.add_history(s)
	end
	process_line(s)
end
