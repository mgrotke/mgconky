--[[ ###########################################################################################################################################
# This script file was created by Matt Grotke (mgrotke@gmail.com) for the "mgconky Conky Theme" project: https://github.com/mgrotke/mgconky
# This file is in the public domain.
# ----------------------------------------------------------------------------------------------------------------------------------------- ]]--

-- ########################################################## GET CPU MAKE AND MODEL ###########################################################

function conky_shorten_cpu_name(cpu_name)
    -- Remove unnecessary parts like (R), (TM), "CPU", "@ XGHz", "Processor", and extra spaces
    return (cpu_name
        :gsub("%(R%)", "")        -- Remove (R)
        :gsub("%(TM%)", "")       -- Remove (TM)
        :gsub("CPU", "")          -- Remove "CPU"
        :gsub("Processor", "")    -- Remove "Processor"
        :gsub("@[%s%w%.]+", "")   -- Remove "@ XGHz"
        :gsub("%s%s+", " ")       -- Remove extra spaces
        :gsub("^%s+", "")         -- Trim leading spaces
        :gsub("%s+$", "")         -- Trim trailing spaces
    )
end

-- Cache so we only run this once.  The CPU will not change.
local conky_cpu_cached_output = nil
function conky_get_cpu_info()
    if conky_cpu_cached_output then
        return conky_cpu_cached_output
    else
        -- Open /proc/cpuinfo for reading
        local file = io.open("/proc/cpuinfo", "r")
        if not file then
            conky_cpu_cached_output = "Failed to open /proc/cpuinfo"
            return conky_cpu_cached_output
        end

        -- Read the contents of /proc/cpuinfo
        local cpu_info = file:read("*all")
        file:close()

        -- Find the 'model name' line
        for line in cpu_info:gmatch("[^\r\n]+") do
            local model_name = line:match("^model name%s*:%s*(.+)")
            if model_name then
                conky_cpu_cached_output = conky_shorten_cpu_name(model_name)
                return conky_cpu_cached_output
            end
        end

        -- Return nil if no model name is found
        conky_cpu_cached_output = "CPU model name not found"
        return conky_cpu_cached_output
    end
end

-- ########################################################## GET GU MAKE AND MODEL ###########################################################

function conky_shorten_gpu_name(gpu_name)
    return (gpu_name
        :gsub("NVIDIA Corporation", "NVIDIA")
        :gsub("Advanced Micro Devices, Inc%.", "AMD")
        :gsub("AMD Corporation", "AMD")
        :gsub("Intel Corporation", "Intel")
        :gsub("ATI Technologies Inc%.", "ATI")
        :gsub("Qualcomm Technologies, Inc%.", "Qualcomm")
        :gsub("ARM Holdings", "ARM")
        :gsub("Apple Inc%.", "Apple")
        :gsub("Matrox Graphics, Inc%.", "Matrox")
        :gsub("S3 Graphics Co%., Ltd%.", "S3 Graphics")
        :gsub("VIA Technologies, Inc%.", "VIA")
        :gsub("Imagination Technologies Ltd%.", "Imagination")
        :gsub("SiS %(Silicon Integrated Systems%)", "SiS")
        :gsub("XGI Technology Inc%.", "XGI")
        :gsub("3dfx Interactive, Inc%.", "3dfx")
        :gsub("Raspberry Pi Foundation", "Raspberry Pi")
        :gsub("Broadcom Inc%.", "Broadcom")
        :gsub("Lite Hash Rate", "LHR")
        :gsub("GA%d+%s%[", "")                  -- Remove chip identifier like "GA106 ["
        :gsub("%].*", "")                       -- Remove everything after "]"
        :gsub("%(.*%)", "")                     -- Remove revision info like "(rev a1)"
        :gsub("%s+", " ")                       -- Normalize spaces
        :match("^%s*(.-)%s*$")                  -- Trim leading/trailing spaces
    )
end

-- Cache so we only run this once.  The GPU will not change.
local conky_gpu_cached_output = nil
function conky_get_gpu_info()
    if conky_gpu_cached_output then
        return conky_gpu_cached_output
    else
        local handle = io.popen("lspci -nn")
        if not handle then
            conky_gpu_cached_output = "Failed to run lspci"
            return conky_gpu_cached_output
        end

        -- Read the output of the command
        local output = handle:read("*all")
        handle:close()

        -- Search for a VGA compatible controller or GPU entry
        for line in output:gmatch("[^\r\n]+") do
            if line:match("%[0300%]") then
                -- Extract the relevant information after the colon
                local gpu = line:match(": (.+)$")
                if gpu then
                    conky_gpu_cached_output = conky_shorten_gpu_name(gpu)
                    return conky_gpu_cached_output
                end
            end
        end

        -- If no graphics card is found
        conky_gpu_cached_output = "No graphics card found"
        return conky_gpu_cached_output
    end
end


-- ########################################################## GET DRIVES AND VOLUMES ###########################################################

-- Cache so we don't spam this every conky tick
local conky_drives_cache_duration = 300 -- Cache output for 5 minutes
local conky_drives_last_update_time = 0
local conky_drives_cached_output = ""

function conky_get_drives_and_volumes()
    local current_time = os.time()

    -- Check if cache is still valid
    if current_time - conky_drives_last_update_time < conky_drives_cache_duration then
        return conky_drives_cached_output
    end

    -- Start fresh output
    local output = ""

    -- Use lsblk to get all devices and their mount points
    local handle = io.popen("lsblk -ln -o NAME,TYPE,MOUNTPOINT,PKNAME")
    if not handle then
        return "Failed to execute lsblk command\n"
    end
    local result = handle:read("*a")
    handle:close()

    -- Parse the lsblk output and group partitions by parent drive
    local devices = {}
    local parent_drive = nil

    for line in (result or ""):gmatch("[^\r\n]+") do
        local name, dtype, mount, pkname = line:match("^(%S+)%s+(%S+)%s*(%S*)%s*(%S*)$")
        if dtype == "disk" then
            parent_drive = name
            devices[parent_drive] = { mountpoints = {} }
        elseif dtype == "part" and parent_drive and mount and mount ~= "" then
            table.insert(devices[parent_drive].mountpoints, mount)
        elseif dtype == "dm" and pkname and mount and mount ~= "" then
            -- Associate device-mapper (dm) devices with their parent physical disk
            devices[pkname] = devices[pkname] or { mountpoints = {} }
            table.insert(devices[pkname].mountpoints, mount)
        end
    end

    -- Generate the output, only including drives with active mount points
    for drive, data in pairs(devices) do
        if #data.mountpoints > 0 then
            output = output .. '${voffset 0}${color0}${font Neuropolitical:size=8:bold}DRIVE${font Courier:size=9} /dev/' .. drive .. '${color} ${color1}${hr 2}${color}\n'
            for _, mount in ipairs(data.mountpoints) do
                -- Use df to get the size and used space for the mount
                local handle = io.popen("df -h --output=target,size,used " .. mount .. " | tail -n 1")
                local df_result = handle:read("*a")
                handle:close()

                -- Parse df output
                local target, size, used = df_result:match("(%S+)%s+(%S+)%s+(%S+)")
                if target and size and used then
                    output = output .. '${voffset 2}' .. target .. ': ${alignr}${color3}' .. used .. 'B${color} of ${color3}' .. size .. 'B${color}\n'
                    output = output .. '${voffset -2}${color5}${fs_bar ' .. target .. '}${color}\n'
                end
            end
            output = output .. '\n' -- Add a blank line after the last mount point of the current drive
        end
    end

    -- Cache and return the output
    conky_drives_cached_output = output
    conky_drives_last_update_time = current_time

    return conky_drives_cached_output
end

-- Run and print the output (for standalone testing)
print(conky_get_drives_and_volumes())


-- ########################################################## GET VPN STATUS ###################################################################

-- Cache so we don't spam this every conky tick
local conky_vpn_cache = {
    last_update_time = 0,
    cache_duration = 15, -- Cache output for 15 seconds
    cached_output = ""
}

function conky_get_vpn_status()
    local current_time = os.time()

    -- Update cache only if more than 30 seconds have passed
    if current_time - conky_vpn_cache.last_update_time > conky_vpn_cache.cache_duration then
        -- Run the `ip a` command and capture its output
        local handle = io.popen("ip a")
        if not handle then
            return "${color7}Error: Failed to execute 'ip a'${color}"
        end

        local result = handle:read("*a")
        handle:close()

        -- Check for active VPN
        local vpn_status = "Off"
        local vpn_color = "${color7}" -- Red for Off

        for line in result:gmatch("[^\r\n]+") do
            -- Look for active POINTOPOINT interfaces
            if line:find("POINTOPOINT") and line:find("UP") then
                local device_name = line:match("^%d+: ([^:]+):")
                if device_name then
                    vpn_status = "On (" .. device_name .. ")"
                    vpn_color = "${color6}" -- Blue for On
                    break
                end
            end
        end

        -- Update cache
        conky_vpn_cache.cached_output = vpn_color .. vpn_status .. "${color}"
        conky_vpn_cache.last_update_time = current_time
    end

    -- Return cached status
    return conky_vpn_cache.cached_output
end

-- Test the function by printing the result
print(conky_get_vpn_status())

-- ########################################################## GET MEMORY USAGE #################################################################

-- Cache so we don't spam this every conky tick
local conky_memory_cache = {
    last_update_time_swapstatus = 0,
    last_update_time_memval = 0,
    last_update_time_swapval = 0,
    cache_duration = 15, -- Cache output for 1 minute
    cached_output_swapstatus = "", -- Possible values: "swapenabled" | "swapdisabled"
    cached_output_memval = "",
    cached_output_swapval = ""
}

function conky_grep_memory(grep_filter)

    -- Run the `free` command and capture its output
    local handle = io.popen("free -h --si | grep " .. grep_filter)
    if not handle then
        return "Error: Failed to execute 'free'"
    end
    local result = handle:read("*a")
    handle:close()
    return result
end

function conky_get_memory_usage(grep_filter)
    local current_time = os.time()

    -- Is arg "sys" or "swap"
    if grep_filter == "sys" then

        -- Is cache stale?
        if current_time - conky_memory_cache.last_update_time_memval > conky_memory_cache.cache_duration then

            -- Extract memory usage details
            local grep_result = conky_grep_memory("Mem")
            local total, used = grep_result:match("Mem:%s+(%S+)%s+(%S+)")
            if not total or not used then
                conky_memory_cache.cached_output_memval = "Error: Failed to parse memory usage"
            else
                -- Format the output as "X of Y" with color formatting
                conky_memory_cache.cached_output_memval = "${color3}" .. used .. "B${color} of ${color3}" .. total .. "B${color}"
            end

            -- Update cache time
            conky_memory_cache.last_update_time_memval = current_time

            -- Debug
            --print("DEBUG: UPDATED MEM VAL (" .. conky_memory_cache.cached_output_memval .. ")")
        end

        -- return mem cache (the mem cache has been updated if the duration has passed)
        return conky_memory_cache.cached_output_memval

    else -- If arg is not "sys" we assume they are looking for swap

        -- Is cache stale?
        if current_time - conky_memory_cache.last_update_time_swapval > conky_memory_cache.cache_duration then

            -- Extract swap usage details
            local grep_result = conky_grep_memory("Swap")
            local total, used = grep_result:match("Swap:%s+(%S+)%s+(%S+)")
            if not total or not used then
                conky_memory_cache.cached_output_swapval = "Error: Failed to parse swap usage"
            else
                -- Format the output as "X of Y" with color formatting
                conky_memory_cache.cached_output_swapval = "${color3}" .. used .. "B${color} of ${color3}" .. total .. "B${color}"
            end

            -- Update cache time
            conky_memory_cache.last_update_time_swapval = current_time

            -- Debug
            --print("DEBUG: UPDATED SWAP VAL (" .. conky_memory_cache.cached_output_swapval .. ")")
        end

        -- return swap cache (the swap cache has been updated if the duration has passed)
        return conky_memory_cache.cached_output_swapval
    end
end

function conky_check_swap_status()
    local current_time = os.time()

    -- Is cache stale?
    if current_time - conky_memory_cache.last_update_time_swapstatus > conky_memory_cache.cache_duration then

        local grep_result = conky_grep_memory("Swap")
        local total = grep_result:match("Swap:%s+(%S+)")
        if not total or total == "0B" or total == "0" then
            conky_memory_cache.cached_output_swapstatus = "swapdisabled"
        else
            conky_memory_cache.cached_output_swapstatus = "swapenabled"
        end

        -- Update cache
        conky_memory_cache.last_update_time_swapstatus = current_time
    end

    -- Debug
    --print("DEBUG: UPDATED SWAP STATUS (" .. conky_memory_cache.cached_output_swapstatus .. ")")

    -- Return cached output
    return conky_memory_cache.cached_output_swapstatus
end

-- Test the function by printing the result
print("Initial Memory Check Function Outputs:")
print("    CHECK SWAP STATUS = " .. conky_check_swap_status())
print("    GET MEMORY USAGE = " .. conky_get_memory_usage("mem"))
print("    GET SWAP USAGE = " .. conky_get_memory_usage("swap"))

