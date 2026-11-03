--!strict
local ProfileService = require(script.Parent.ProfileService)
local JobService = require(script.Parent.JobService)
local HomeService = require(script.Parent.HomeService)
local profiles = ProfileService.start()
JobService.start(profiles)
HomeService.start(profiles)
