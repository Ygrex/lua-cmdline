local cmdline = assert(require "cmdline");
local luaunit = assert(require "luaunit");

local function test_parse_optstring()
	local optstring = ":ab:c::d:";
	local opt_parsed = assert(cmdline.parse_optstring(optstring));
	assertEquals(
		opt_parsed,
		{
			{ "a" },
			{ "b", ":" },
			{ "c", "::" },
			{ "d", ":" },
			a = true,
			b = ":",
			c = "::",
			d = ":",
		}
	);
end;

local function test_long_parse()
	local opts = assert(
		cmdline.parse(
			arg[0],
			{
				"--help",
				"--abc",
				"--def=ghi",
				"--ghi=jkl",
				"--mno",
				"pqr",
				"hello",
				"world",
			},
			"",
			{
				help = true,
				abc = "::",
				def = ":",
				ghi = "::",
				mno = ":",
			}
		)
	);
	assertTrue(opts.help);
	assertTrue(opts.abc);
	assertEquals(opts.def, "ghi");
	assertEquals(opts.ghi, "jkl");
	assertEquals(opts.mno, "pqr");
	assertEquals(#opts, 6);
end;

local function test_long_only_parse()
	local opts = assert(
		cmdline.parse(
			arg[0],
			{
				"-help",
				"-ab",
				"-def=ghi",
				"--ghi",
				"--mno",
				"pqr",
				"hello",
				"world",
			},
			"ab",
			{
				help = true,
				def = ":",
				ghi = "::",
				mno = ":",
			},
			false,
			true
		)
	);
	assertEquals(opts.help, true);
	assertEquals(opts.a, true);
	assertEquals(opts.b, true);
	assertEquals(opts.def, "ghi");
	assertEquals(opts.ghi, true);
	assertEquals(opts.mno, "pqr");
	assertEquals(#opts, 6);
end;

local function test_short_parse()
	local opts = assert(
		cmdline.parse(
			arg[0],
			{
				"-c",
				"cval",
				"-abc",
				"-d",
				"-e-d",
				"hello",
				"world",
			},
			"ab:c:d::e::"
		)
	);
	assertTrue(opts.a);
	assertEquals(opts.b, "c");
	assertEquals(opts.c, "cval");
	assertTrue(opts.d);
	assertEquals(opts.e, "-d");
	assertEquals(#opts, 5);
end;

local function test_permutation()
	local argv = {"<regex>", "fileA", "-R", "fileB"};
	local opts = assert(cmdline.parse(arg[0], argv, "R"));
	assertEquals(
		argv,
		{"-R", "<regex>", "fileA", "fileB"}
	);
	assertEquals(#opts, 1);
end;

local function test_permutation_stopped()
	local argv = {"<regex>", "fileA", "-R", "fileB", "--", "-cm1"};
	local opts = assert(cmdline.parse(arg[0], argv, "R"));
	assertEquals(
		argv,
		{"-R", "--", "<regex>", "fileA", "fileB", "-cm1"}
	);
	assertTrue(opts.R);
	assertNil(opts.c);
	assertEquals(#opts, 2);
end;

local function test_posixly_correct()
	local argv = {
		"-t",
		"1000",
		"--kill-after",
		"800",
		"timeout",
		"-t",
		"500",
		"--kill-after",
		"300",
		"--",
		"file",
	};
	local shortopts = "t:";
	local longopts = { ["kill-after"] = ":" };
	local opts = assert(
		cmdline.parse(argv[0], argv, shortopts, longopts, true)
	);
	assertEquals(#opts, 4);
	assertEquals(opts.t, "1000");
	assertEquals(opts["kill-after"], "800");
end;

local function test_oop()
	local gop = assert(cmdline.Cmdline:new(arg[0]));
	gop:setLong {
		help = true,
		["mandatory"] = ":",
		["optional-a"] = "::",
		["optional-b"] = "::",
	};
	gop:setShort "a::b::m:v";
	gop:setLongOnly(true);
	gop:setPosixlyCorrect(true);
	local parsed = assert(gop {
		"-vm",
		"4",
		"-a1",
		"-b",
		"-mandatory",
		"1",
		"--optional-a",
		"--optional-b=2",
		"stop here",
		"-help",
		"hello",
		"world",
	});
	assertEquals(#parsed, 8);
	assertEquals(parsed.v, true);
	assertEquals(parsed.m, "4");
	assertEquals(parsed.a, "1");
	assertEquals(parsed.mandatory, "1");
	assertEquals(parsed["optional-a"], true);
	assertEquals(parsed["optional-b"], "2");
	assertNil(parsed["help"]);
end;

local function test_oop_chained()
	local parsed = assert(
		cmdline.Cmdline:new(arg[0])
	):setLong(
		{help = true}
	):setShort("v"):setLongOnly(true):setPosixlyCorrect(true) {
		"-v",
		"-help",
		"hello",
		"world",
	};
	assertEquals(#parsed, 2);
	assertEquals(parsed.v, true);
	assertEquals(parsed.help, true);
end;

lu = assert(LuaUnit.new());
lu:setOutputType("TAP");
os.exit(
	lu:runSuiteByInstances {
		{"Simple optstring parser", test_parse_optstring},
		{"Short options parser", test_short_parse},
		{"Long options parser", test_long_parse},
		{"Permutation", test_permutation},
		{"Permutation with double dash", test_permutation_stopped},
		{"Posixly correct parsing", test_posixly_correct},
		{"Long options only parser", test_long_only_parse},
		{"OOP parser", test_oop},
		{"OOP chained API", test_oop_chained},
	}
);

