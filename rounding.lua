--[[ ##############################################################################################################################
# This lua file was created by Matt Grotke (mgrotke@gmail.com) and is in the public domain.
# ---------------------------------------------------------------------------------------------------------------------------------
# The function below is intended to be called by a Conky config file in the following way:
#     ${lua MyRound <value to round> <decimal places> <rounding type> <unit to use> <option>}
#
# Note that the function name in this file is "conky_MyRound" but it is called from Conky using "MyRound".  This is normal.
#
# All arguments are mandatory:
#     <value to round>        Requires a numeric value, which may or may not contiain a trailing unit letter (it is expected that the Conky configuration variable "short_units" is set to "yes").
#     <decimal places>        Requires an integer, such as 0 (for no decimal places), 1, 2, etc.
#     <rounding type>         Requires one of the following (no quotes used): halfup, floor, ceil.  Halfup is "standard" rounding where less than .5 goes down, and .5 and over goes up.
#     <unit to use>           Requires one of the following (no quotes used): auto, B, K, M, G, T.  They will convert the number to Bytes, Kilobytes, Megabytes, Gigabytes, or Terabytes.
#     <options>               Requires one of the following (no quotes used): normal, hideUnit, addSpace.
# Examples:
#     ${lua MyRound ${mem} 0 halfup auto normal}        # Displays memory used, rounded to the nearest whole number, shown in whatever unit Conky determines is the most appropriate.
#     ${lua MyRound ${mem} 0 halfup M normal}           # Displays memory used, rounded to the nearest whole number, shown in Megabytes.
#     ${lua MyRound ${mem} 0 ceil G hideUnit}           # Displays memory used, rounded to the next whole number.  The value WILL be in Megabytes, but a unit will not be displayed.
#     ${lua MyRound ${mem} 1 halfup G addSpace}         # Displays memory used, rounded to the nearest 1 decimal place, shown in Gigabytes.  There will be a space before the G.
############################################################################################################################## ]]--
do
    function conky_MyRound(arg, places, roundType, useUnit, modify)

        -- Get args passed from Conky
        local sArg = conky_parse(arg)
        local sPlaces = conky_parse(places)
        local sRoundType = conky_parse(roundType)
        local sUseUnit = conky_parse(useUnit)
        local sModify = conky_parse(modify)

        -- Convert args into types
        local nPlaces = tonumber(sPlaces)
        local nValue = tonumber(sArg)
        local sLastChar = ""
        if nValue == nil then
            -- It's not a number, because we assume it has a single char unit trailing
            sLastChar = string.sub(sArg, -1) --select the last char
            nValue = tonumber(string.sub(sArg, 0, string.len(sArg) - 1)) --select the first part of the string, except for the last char
            if nValue == nil then return "Error, not number" end -- Still not a number
        end

        -- Convert unit
        local sUnitText = ""
        if sUseUnit == "auto" then
            sUnitText = sLastChar
        elseif sUseUnit == sLastChar then
            sUnitText = sLastChar
        else
            sUnitText = sUseUnit
            if sLastChar == "B" then
                if sUseUnit == "K" then
                    nValue = nValue / 1000
                elseif sUseUnit == "M" then
                    nValue = nValue / 1000000
                elseif sUseUnit == "G" then
                    nValue = nValue / 1000000000
                elseif sUseUnit == "T" then
                    nValue = nValue / 1000000000000
                else
                    return "Error, invalid unit"
                end
            elseif sLastChar == "K" then
                if sUseUnit == "B" then
                    nValue = nValue * 1000
                elseif sUseUnit == "M" then
                    nValue = nValue / 1000
                elseif sUseUnit == "G" then
                    nValue = nValue / 1000000
                elseif sUseUnit == "T" then
                    nValue = nValue / 1000000000
                else
                    return "Error, invalid unit"
                end
            elseif sLastChar == "M" then
                if sUseUnit == "B" then
                    nValue = nValue * 1000000
                elseif sUseUnit == "K" then
                    nValue = nValue * 1000
                elseif sUseUnit == "G" then
                    nValue = nValue / 1000
                elseif sUseUnit == "T" then
                    nValue = nValue / 1000000
                else
                    return "Error, invalid unit"
                end
            elseif sLastChar == "G" then
                if sUseUnit == "B" then
                    nValue = nValue * 1000000000
                elseif sUseUnit == "K" then
                    nValue = nValue * 1000000
                elseif sUseUnit == "M" then
                    nValue = nValue * 1000
                elseif sUseUnit == "T" then
                    nValue = nValue / 1000
                else
                    return "Error, invalid unit"
                end
            elseif sLastChar == "T" then
                if sUseUnit == "B" then
                    nValue = nValue * 1000000000000
                elseif sUseUnit == "K" then
                    nValue = nValue * 1000000000
                elseif sUseUnit == "M" then
                    nValue = nValue * 1000000
                elseif sUseUnit == "G" then
                    nValue = nValue * 1000
                else
                    return "Error, invalid unit"
                end
            else
                return "Error, invalid unit"
            end
        end

        -- Modify unit?
        if sModify == "normal" then
            --do nothing (keep unit text how it is)
        elseif sModify == "hideUnit" then
            sUnitText = ""
        elseif sModify == "addSpace" then
            sUnitText = string.format(" %s", sUnitText)
        else
            return "Error, invalid modify"
        end

        -- Do the rounding
        local nRounded = 0
        if sRoundType == "halfup" then
            local nPower = math.pow(10, nPlaces or 0)
            nValue = nValue * nPower
            if nValue >= 0 then nValue = math.floor(nValue + 0.5) else nValue = math.ceil(nValue - 0.5) end
            nRounded = nValue / nPower
        elseif sRoundType == "ceil" then
            local nPower = math.pow(10, nPlaces or 0)
            nRounded = math.ceil(nValue * nPower) / nPower
        elseif sRoundType == "floor" then
            local nPower = math.pow(10, nPlaces or 0)
            nRounded = math.floor(nValue * nPower) / nPower
        else
            return "Error, invalid round type"
        end
        local sFormatter = string.format("%s%s%s", "%.", tostring(nPlaces), "f%s")
        return string.format(sFormatter, nRounded, sUnitText)
    end
end
