local function str2tbl(str)
	local r = {};
	for c in str:gmatch "." do
		r[#r + 1] = c;
	end;
	return r;
end;

local function parse_optstring(optstring)
	local r = {};
	local cur = 1;
	local opttbl = str2tbl(optstring);
	if opttbl[1] == ":" then
		-- starting colon is insignificant
		cur = cur + 1;
	end;
	while cur <= #opttbl do
		local flag = opttbl[cur];
		local mod = nil;
		if opttbl[cur + 2] == ":" and opttbl[cur + 1] == ":" then
			mod = "::";
		elseif opttbl[cur + 1] == ":" then
			mod = ":";
		end;
		r[#r + 1] = {flag, mod};
		r[flag] = mod or true;
		assert(#flag > 0);
		cur = cur + #flag + #(mod or "");
	end;
	return r;
end;

local function parse_error(warn, name, err_msg)
	if warn then
		io.stderr:write(("%s: %s\n"):format(name, err_msg));
	end;
	return nil, err_msg;
end;

local function parse_long_option(longopts, argv, iarg, rettbl)
	local dashes;
	if argv[iarg]:sub(1, 2) == "--" then
		-- double dash form
		dashes = "--"
	else
		-- single dash form
		dashes = "-"
	end;
	local stripped = argv[iarg]:sub(#dashes + 1);
	local sep_pos = stripped:find "=";
	local argname;
	local value;
	if sep_pos then
		argname = stripped:sub(1, sep_pos - 1)
		value = stripped:sub(sep_pos + 1);
	else
		argname = stripped;
		value = argv[iarg + 1];
	end;
	local argmod = longopts[argname];
	if not argmod then
		return nil, "Unknown long option: " .. dashes .. argname;
	end;
	if argmod == ":" then
		if not value then
			return nil, "Argument required: " .. dashes .. argname;
		end;
		rettbl[argname] = value;
		if sep_pos then
			return 1;
		end;
		return 2;
	elseif argmod == "::" and sep_pos then
		rettbl[argname] = value;
	else
		rettbl[argname] = true;
	end;
	return 1;
end;

local function parse_short_option(opttbl, argv, iarg, rettbl)
	local argtbl = assert(str2tbl(argv[iarg]));
	for iopt = 2, #argtbl do
		local optflag = argtbl[iopt];
		local optmod = opttbl[optflag];
		if not optmod then
			return nil, "Unrecognized option: -" .. optflag;
		end
		if iopt < #argtbl and (
			optmod == ":" or optmod == "::"
		) then
			-- argument expected and it is given in the
			-- same option word
			rettbl[optflag] = argv[iarg]:sub(iopt + 1);
			break;
		elseif optmod == ":" then
			-- argument expected and it is given in the
			-- next option word
			if iarg == #argv then
				return nil, "Missing argument: -" .. optflag;
			end;
			rettbl[optflag] = argv[iarg + 1];
			return 2;
		else
			-- optional argument missing or not expected
			rettbl[optflag] = true;
		end;
	end;
	return 1;
end;

local function permute_argv(argv, skipped)
	local first_skipped = 1;
	while first_skipped < #argv and not skipped[first_skipped] do
		first_skipped = first_skipped + 1;
	end;
	if not skipped[first_skipped] then
		return;
	end;
	local next_processed = first_skipped + 1;
	while skipped[next_processed] do
		next_processed = next_processed + 1;
	end;
	if next_processed > #argv then
		return;
	end;
	skipped[next_processed] = true;
	skipped[first_skipped] = false;
	while next_processed > first_skipped do
		argv[next_processed], argv[next_processed - 1] =
			argv[next_processed - 1], argv[next_processed]
		next_processed = next_processed - 1;
	end;
	return permute_argv(argv, skipped);
end;

local function skip_the_rest(skipped, start, finish)
	for i = start, finish, 1 do
		skipped[i] = true;
	end;
end;

local function parse(
	name,
	argv,
	optstring,
	longopts,
	posixly_correct,
	long_only
)
	local r = {};
	local skipped = {};
	longopts = longopts or {};
	if posixly_correct == nil then
		posixly_correct = os.getenv("POSIXLY_CORRECT");
	end;
	local warn = optstring:sub(1, 1) == ":";
	local opttbl = assert(parse_optstring(optstring));
	local double_dash;
	local iarg = 1;
	local shift, err_msg;
	while iarg <= #argv do
		if argv[iarg] == "--" then
			r[#r + 1] = argv[iarg];
			skip_the_rest(skipped, iarg + 1, #argv);
			break;
		end;
		if argv[iarg]:sub(1, 1) ~= "-" then
			if posixly_correct then
				skip_the_rest(skipped, iarg, #argv);
				break;
			end;
			skipped[iarg] = true;
			shift = 1;
			goto continue;
		end;
		double_dash = argv[iarg]:sub(1, 2) == "--";
		shift = nil;
		if double_dash or long_only then
			shift, err_msg =
				parse_long_option(longopts, argv, iarg, r);
		end;
		if shift == nil and not double_dash then
			shift, err_msg =
				parse_short_option(opttbl, argv, iarg, r);
		end;
		if not shift then
			return parse_error(warn, name, err_msg);
		end;
		for i = 1, shift do
			r[#r + 1] = argv[iarg + i];
		end;
		::continue::
		iarg = iarg + shift;
	end;
	if not posixly_correct then
		permute_argv(argv, skipped);
	end;
	return r;
end;

local function deep_copy(t)
	local r = {};
	if not pcall(next, t) then
		-- not iterable
		return t;
	end;
	for k, v in pairs(t) do
		r[k] = deep_copy(v);
	end;
	return r;
end;

local Cmdline do
	local idx_Cmdline = {};
	local mt_Cmdline = { __index = idx_Cmdline };

	function idx_Cmdline:new(name)
		local o = {
			argv = nil,
			long_options = deep_copy(self.long_options),
			long_only = self.long_only,
			name = name or self.name,
			posixly_correct = self.posixly_correct,
			short_options = self.short_options,
		};
		return setmetatable(o, getmetatable(self));
	end;

	function idx_Cmdline:setLong(long_options)
		self.long_options = deep_copy(long_options);
		return self;
	end;

	function idx_Cmdline:setShort(short_options)
		self.short_options = short_options;
		return self;
	end;

	function idx_Cmdline:setPosixlyCorrect(posixly_correct)
		self.posixly_correct = posixly_correct and posixly_correct;
		return self;
	end;

	function idx_Cmdline:setLongOnly(long_only)
		self.long_only = long_only and long_only;
		return self;
	end;

	function idx_Cmdline:getName()
		return self.name;
	end;

	function idx_Cmdline:getShortOptions()
		return self.short_options;
	end;

	function idx_Cmdline:getLongOptions(as_is)
		if as_is then
			return self.long_options;
		end;
		return deep_copy(self.long_options);
	end;

	function idx_Cmdline:getPosixlyCorrect()
		return self.posixly_correct;
	end;

	function idx_Cmdline:getLongOnly()
		return self.long_only;
	end;

	function idx_Cmdline:setArguments(argv)
		self.argv = deep_copy(argv);
	end;

	function idx_Cmdline:getArguments(as_is)
		if as_is then
			return self.argv;
		end;
		return deep_copy(self.argv);
	end;

	function mt_Cmdline:__call(argv)
		if argv then
			self:setArguments(argv);
		end;
		return parse(
			self:getName(),
			self:getArguments(true),
			self:getShortOptions(),
			self:getLongOptions(),
			self:getPosixlyCorrect(),
			self:getLongOnly()
		);
	end;

	Cmdline = setmetatable({}, mt_Cmdline);
end;

return {
	Cmdline = Cmdline,
	parse = parse,
	parse_optstring = parse_optstring,
};

