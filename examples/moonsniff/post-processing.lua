--- Demonstrates the basic usage of moonsniff in order to determine device induced latencies

local log       = require "log"
local dpdk	= require "dpdk"
local pcap	= require "pcap"
local profile 	= require "jit.p"

local ffi    = require "ffi"
local C = ffi.C

-- default values when no cli options are specified
local INPUT_PATH = "latencies.csv"
local TIME_THRESH = -50 	-- negative timevalues smaller than this value are not allowed

local MODE_MSCAP, MODE_PCAP = 0, 1
local MODE = MODE_MSCAP

-- skip the initialization of DPDK, as it is not needed for this script
dpdk.skipInit()

function configure(parser)
        parser:description("Demonstrate and test hardware latency induced by a device under test.\nThe ideal test setup is to use 2 taps, one should be connected to the ingress cable, the other one to the egress one.\n\n For more detailed information on possible setups and usage of this script have a look at moonsniff.md.")
	parser:option("-i --input", "Path to input file."):args(1)
	parser:option("-s --second-input", "Path to second input file."):args(1):target("second")
	parser:option("-o --output", "Name of the histogram which is generated"):args(1):default("hist")
	parser:option("-n --nrbuckets", "Size of a bucket for the resulting histogram"):args(1):convert(tonumber):default(1)
	parser:flag("-b --binary", "Read a file which was generated by moonsniff with the binary flag set")
	parser:flag("-d --debug", "Create additional debug information")
	parser:flag("-p --profile", "Profile the application. May decrease the overall performance")
        return parser:parse()
end


function master(args)
	if args.input then INPUT_PATH = args.input end
	if args.binary then INPUT_MODE = C.ms_binary end

	if string.match(args.input, ".*%.pcap") then
		MODE = MODE_PCAP
	--	matchPCAP(args)

	elseif string.match(args.input, ".*%.mscap") then
		MODE = MODE_MSCAP
	else
		log:err("Input with unknown file extension.\nCan only process .pcap or .mscap files.")
	end

	print(MODE)
	local PRE
	local POST

	if MODE == MODE_MSCAP then
		if not args.second then log:fatal("Detected .mscap file but there was no second file. Single .mscap files cannot be processed.") end

		if string.match(args.input, ".*%-pre%.mscap") and string.match(args.second, ".*%-post%.mscap") then
			PRE = args.input
			POST = args.second

		elseif string.match(args.second, ".*%-pre%.mscap") and string.match(args.input, ".*%-post%.mscap") then
			POST = args.input
			PRE = args.second
		else
			log:fatal("Could not decide which file is pre and which post. Pre should end with -pre.mscap and post with -post.mscap.")
		end
	end

	if MODE == MODE_PCAP then

		if not args.second then log:fatal("Detected .pcap file but there was no second file. Single .pcap files cannot be processed.") end

		if string.match(args.input, ".*%-pre%.pcap") and string.match(args.second, ".*%-post%.pcap") then
			PRE = args.input
			POST = args.second

		elseif string.match(args.second, ".*%-pre%.pcap") and string.match(args.input, ".*%-post%.pcap") then
			POST = args.input
			PRE = args.second
		else
			log:fatal("Could not decide which file is pre and which post. Pre should end with -pre.mscap and post with -post.mscap.")
		end
	end


	print(PRE)
	print(POST)


	-- retrieve additional information about input
	local file = assert(io.open(PRE, "r"))
        local size = fsize(file)
        file:close()
        file = assert(io.open(POST, "r"))
        size = size + fsize(file)
        file:close()
        log:info("File size: " .. size / 1e9 .. " [GB]")
        local nClock = os.clock()
        profile.start("-fl", "somefile.txt")

	-- run correct matching
	if MODE == MODE_PCAP then
		local tbb = require "tbbmatch"
		tbb.match(PRE, POST, args)
	elseif MODE == MODE_MSCAP then
		local arr = require "arrmatch"
		arr.match(PRE, POST, args)
	end

	-- finish operations
	profile.stop()

        local elapsed = os.clock() - nClock
        log:info("Elapsed time core: " .. elapsed .. " [sec]")
        log:info("Processing speed: " .. (size / 1e6) / elapsed .. " [MB/s]")
end

--- Compute the size of a file
function fsize(file)
        local current = file:seek()
        local size = file:seek("end")
        file:seek("set", current)
        return size
end
