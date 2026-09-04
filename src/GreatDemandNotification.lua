GreatDemandNotification = {
    NOTIFICATION_DURATION = 15000,
    ICON_SIZE = 40,
}

---
function GreatDemandNotification.getPriceFormatted(sellStation, fillTypeIndex, demandMultiplier)
   	if sellStation.fillTypePrices == nil or sellStation.fillTypePrices[fillTypeIndex] == nil then
		return nil
	end

    local pricePerLiter = sellStation:getEffectiveFillTypePrice(fillTypeIndex)

    if not sellStation.isServer then
        pricePerLiter = pricePerLiter * demandMultiplier
    end

    return pricePerLiter * 1000
end

---
function GreatDemandNotification.getNotification(greatDemand)
    if greatDemand.sellStation == nil then
        return nil
    end

    local fillType = g_fillTypeManager:getFillTypeByIndex(greatDemand.fillTypeIndex)

    if fillType == nil or not greatDemand.sellStation:getSupportsGreatDemand(greatDemand.fillTypeIndex) then
		return nil
	end

    local price = GreatDemandNotification.getPriceFormatted(greatDemand.sellStation, greatDemand.fillTypeIndex, greatDemand.demandMultiplier)

    if price == nil then
        return nil
    end

    local title = string.format(g_i18n:getText("gdn_notificationTitle"), fillType.title)
    local info = string.format(g_i18n:getText("gdn_notificationInfo"), g_i18n:formatMoney(price, 0, true, true), g_i18n:getText("unit_literShort"), greatDemand.demandDuration)
    
    local iconFilename = fillType.hudOverlayFilename
	
    if iconFilename == "" then
		iconFilename = nil
	end

    return title, greatDemand.sellStation:getName(), info, iconFilename
end

---
function GreatDemandNotification.squareIcon(hud, iconFilename)
	local topNotification = hud.topNotification

	if topNotification == nil or topNotification.icons == nil then
		return
	end

	local icon = topNotification.icons[iconFilename]

	if icon ~= nil then
		icon:setDimension(topNotification:scalePixelToScreenWidth(GreatDemandNotification.ICON_SIZE), topNotification:scalePixelToScreenHeight(GreatDemandNotification.ICON_SIZE))
	end
end

---
function GreatDemandNotification.startGreatDemand(self, superFunc, greatDemand)

    local title, text, info, iconFilename = GreatDemandNotification.getNotification(greatDemand)

    if title == nil then
        if greatDemand.sellStation == nil then
            return
        end

        title = ""
        text = ""
        info = ""
    end

    g_currentMission.hud:addTopNotification(title, text, info, iconFilename, GreatDemandNotification.NOTIFICATION_DURATION)

	if iconFilename ~= nil then
		GreatDemandNotification.squareIcon(g_currentMission.hud, iconFilename)
	end

    g_gui.guiSoundPlayer:playSample(GuiSoundPlayer.SOUND_SAMPLES.NOTIFICATION)
end

EconomyManager.startGreatDemand = Utils.overwrittenFunction(EconomyManager.startGreatDemand, GreatDemandNotification.startGreatDemand)
