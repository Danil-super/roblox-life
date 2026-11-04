--!strict
local ProfileService = require(script.Parent.ProfileService)
local JobService = require(script.Parent.JobService)
local HomeService = require(script.Parent.HomeService)
local Scenery = require(script.Parent.NeighborhoodScenery)
Scenery.start()
local profiles = ProfileService.start()
JobService.start(profiles)
HomeService.start(profiles)
