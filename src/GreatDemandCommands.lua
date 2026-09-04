GreatDemandCommands = {}

GreatDemandCommands.COMMAND_START = "gdnGreatDemandStart"

local function findFreeDemandSlot(economyManager)
	for _, greatDemand in ipairs(economyManager.greatDemands) do
		if not greatDemand.isRunning then
			return greatDemand
		end
	end

	-- All slots busy, recycle the first one.
	local greatDemand = economyManager.greatDemands[1]
	if greatDemand ~= nil then
		economyManager:stopGreatDemand(greatDemand)
	end

	return greatDemand
end

-- GreatDemandSpecs:setUpRandomDemand picks one random station and gives up when that station
-- has no usable fill type, so it regularly returns an invalid demand. For a test command we
-- want a guaranteed hit, so collect every station/fill type pair ourselves instead.
local function collectCandidates(economyManager, targetDemand, fillTypeIndexFilter)
	local blockedStations = {}
	for _, greatDemand in ipairs(economyManager.greatDemands) do
		if greatDemand ~= targetDemand and greatDemand.isValid and greatDemand.sellStation ~= nil then
			blockedStations[greatDemand.sellStation] = true
		end
	end

	local candidates = {}
	local numStations = 0

	for _, station in pairs(g_currentMission.storageSystem:getUnloadingStations()) do
		if station.supportsGreatDemand and station.getSupportsGreatDemand ~= nil and not station.isGreatDemandActive and blockedStations[station] == nil then
			numStations = numStations + 1

			for fillTypeIndex, isAccepted in pairs(station.acceptedFillTypes) do
				if isAccepted and station:getSupportsGreatDemand(fillTypeIndex) and (fillTypeIndexFilter == nil or fillTypeIndex == fillTypeIndexFilter) then
					table.insert(candidates, {
						["station"] = station,
						["fillTypeIndex"] = fillTypeIndex
					})
				end
			end
		end
	end

	return candidates, numStations
end

function GreatDemandCommands:startGreatDemand(durationArg, fillTypeArg)
	if g_currentMission == nil or not g_currentMission:getIsServer() then
		return "Great demands are server controlled, run this command on the server"
	end

	local economyManager = g_currentMission.economyManager
	local environment = g_currentMission.environment

	local fillTypeIndexFilter = nil
	if fillTypeArg ~= nil then
		fillTypeIndexFilter = g_fillTypeManager:getFillTypeIndexByName(fillTypeArg)
		if fillTypeIndexFilter == nil then
			return string.format("Unknown fill type %q", fillTypeArg)
		end
	end

	local greatDemand = findFreeDemandSlot(economyManager)
	if greatDemand == nil then
		return "No great demand slots available"
	end

	local candidates, numStations = collectCandidates(economyManager, greatDemand, fillTypeIndexFilter)
	if #candidates == 0 then
		if fillTypeIndexFilter ~= nil then
			return string.format("No available selling station accepts %q with great demand support (%d stations checked)", fillTypeArg, numStations)
		end

		return string.format("No selling station supports a great demand right now (%d stations checked)", numStations)
	end

	local candidate = candidates[math.random(1, #candidates)]

	greatDemand.sellStation = candidate.station
	greatDemand.fillTypeIndex = candidate.fillTypeIndex
	greatDemand.demandMultiplier = math.random(11, 14) / 10
	greatDemand.demandDuration = math.max(1, math.floor(tonumber(durationArg) or math.random(1, 4) * 6))
	greatDemand.isValid = true
	greatDemand.isRunning = false

	-- manageGreatDemands compares against currentMonotonicDay, not currentDay.
	greatDemand.demandStart.day = environment.currentMonotonicDay
	greatDemand.demandStart.hour = environment.currentHour

	economyManager:startGreatDemand(greatDemand)
	g_server:broadcastEvent(GreatDemandsEvent.new(economyManager.greatDemands))

	local fillType = g_fillTypeManager:getFillTypeByIndex(greatDemand.fillTypeIndex)

	return string.format("Started great demand: %s at %s, price x%.2f for %d h (%d candidates)", fillType.title, greatDemand.sellStation:getName(), greatDemand.demandMultiplier, greatDemand.demandDuration, #candidates)
end

Mission00.loadMission00Finished = Utils.appendedFunction(Mission00.loadMission00Finished, function()
	addConsoleCommand(GreatDemandCommands.COMMAND_START, "Immediately starts a new great demand", "startGreatDemand", GreatDemandCommands, "[durationHours]; [fillTypeName]")
end)

Mission00.delete = Utils.prependedFunction(Mission00.delete, function()
	removeConsoleCommand(GreatDemandCommands.COMMAND_START)
end)
