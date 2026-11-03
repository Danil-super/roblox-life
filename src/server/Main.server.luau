--!strict
local ProfileService = require(script.Parent.ProfileService)
local JobService = require(script.Parent.JobService)
local profiles = ProfileService.start()
JobService.start(profiles)
