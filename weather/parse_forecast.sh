#!/bin/bash
###################################################################################################################################
# This script is from the "Harmattan Conky Theme" project: https://github.com/zagortenay333/Harmattan
# It has been modified by Matt Grotke (mgrotke@gmail.com) for the "mgconky Conky Theme" project: https://github.com/mgrotke/mgconky
# Below is Harmattan's original license for this file.
# ---------------------------------------------------------------------------------------------------------------------------------
# This project is available under 2 licenses -- choose whichever you prefer.
# ---
# ALTERNATIVE A - MIT License Copyright (c) 2019 zagortenay333
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions: The above copyright
# notice and this permission notice shall be included in all copies or
# substantial portions of the Software.  THE SOFTWARE IS PROVIDED "AS IS",
# WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED
# TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE
# FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR
# THE USE OR OTHER DEALINGS IN THE SOFTWARE.
# ---
# ALTERNATIVE B - Public Domain (www.unlicense.org)
# This is free and unencumbered software released into the public domain.
# Anyone is free to copy, modify, publish, use, compile, sell, or distribute
# this software, either in source code form or as a compiled binary, for any
# purpose, commercial or non-commercial, and by any means.  In jurisdictions
# that recognize copyright laws, the author or authors of this software
# dedicate any and all copyright interest in the software to the public domain.
# We make this dedication for the benefit of the public at large and to the
# detriment of our heirs and successors. We intend this dedication to be an
# overt act of relinquishment in perpetuity of all present and future rights to
# this software under copyright law.  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT
# WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM,
# DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
# OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE
# OR OTHER DEALINGS IN THE SOFTWARE.
###################################################################################################################################
set -eu

forecast=~/".cache/mgconky/forecast.json"

get_time () {
    local idx="$1"

    time=$(jq ".list[$idx].dt_txt" "$forecast")
    time="${time##* }"
    time="${time%%\"}"

    echo "$time"
}

find_position () {
    local day="$1"
    local pos=0
    local idx=0
    local time=""

    [[ $day == 0 ]] && echo "$idx" && return

    while true; do
        time=$(get_time "$idx")

        [[ $time == "00:00:00" ]] && ((pos++))

        [[ $time == "null" ]] && break
        [[ $pos == "$day" ]] && break

        ((idx++))
    done

    echo "$idx"
}

# Currently, the free accounts on openweathermap.org only get a 5 day forecast
# with data records for every 3 hours instead of the average value for the day,
# so we have to compute the average temp_min, temp_max, etc manually.
get_avg_property () {
    local res=0

    local prop="$1"
    local day="$2"

    local idx
    idx=$(find_position "$day")

    local prop_num=0
    local time=0
    local it=0

    while true; do
        [[ $time == "null" ]] && break

        it=$(jq ".list[$idx]$prop" "$forecast")

        it="$res+$it"
        res=$(bc -l <<< "$it")

        (( prop_num++ ))
        (( idx++ ))

        time=$(get_time "$idx")

        # The records for every 3 hours are dumped in an array with no
        # indication to which day they belong.
        # The first record of each day (except today) is calculated at time
        # '00:00:00', so we use that to know when a new day starts.
        [[ $time == "00:00:00" ]] && break
    done

    res="$(bc -l <<< "$res/$prop_num")"

    [[ $res == "null" ]] && echo $res && return

    LC_NUMERIC=C printf %.0f $res
}

# Same description as get_avg_property(), but getting the lowest number for this property, instead of the average.
get_min_property () {
    local res=1000

    local prop="$1"
    local day="$2"

    local idx
    idx=$(find_position "$day")

    local prop_num=0
    local time=0
    local it=0

    while true; do
        [[ $time == "null" ]] && break

        it=$(jq ".list[$idx]$prop" "$forecast")
        if (( $(bc -l <<< $(echo "$it<$res")) )) ; then
            res="$it"
        fi

        (( prop_num++ ))
        (( idx++ ))

        time=$(get_time "$idx")

        # The records for every 3 hours are dumped in an array with no
        # indication to which day they belong.
        # The first record of each day (except today) is calculated at time
        # '00:00:00', so we use that to know when a new day starts.
        [[ $time == "00:00:00" ]] && break
    done

    [[ $res == "null" ]] && echo $res && return

    LC_NUMERIC=C printf %.0f $res
}

# Same description as get_avg_property(), but getting the highest number for this property, instead of the average.
get_max_property () {
    local res=0

    local prop="$1"
    local day="$2"

    local idx
    idx=$(find_position "$day")

    local prop_num=0
    local time=0
    local it=0

    while true; do
        [[ $time == "null" ]] && break

        it=$(jq ".list[$idx]$prop" "$forecast")
        if (( $(bc -l <<< $(echo "$it>$res")) )) ; then
            res="$it"
        fi

        (( prop_num++ ))
        (( idx++ ))

        time=$(get_time "$idx")

        # The records for every 3 hours are dumped in an array with no
        # indication to which day they belong.
        # The first record of each day (except today) is calculated at time
        # '00:00:00', so we use that to know when a new day starts.
        [[ $time == "00:00:00" ]] && break
    done

    [[ $res == "null" ]] && echo $res && return

    LC_NUMERIC=C printf %.0f $res
}

# Certain values cannot be averaged (e.g., the weather description).
# In that case we just use the value from the first record for that day.
get_first_property () {
    local res=0

    local prop="$1"
    local day="$2"

    local idx
    idx=$(find_position "$day")

    res=$(jq ".list[$idx]$prop" "$forecast")

    [[ $res == "null" ]] && echo $res && return

    LC_NUMERIC=C printf %.0f $res
}

# Same description as get_first_property(), but for text properties (not numeric)
get_first_property_text () {
    local res=0

    local prop="$1"
    local day="$2"

    local idx
    idx=$(find_position "$day")

    res=$(jq --raw-output ".list[$idx]$prop" "$forecast")

    [[ $res == "null" ]] && echo $res && return

    echo "$res"
}

main () {
    type="$1"
    prop="$2"
    day="$3"

    if [[ $type == "avg" ]] ; then
        echo "$(get_avg_property "$2" "$3")"
    elif [[ $type == "first" ]] ; then
        echo "$(get_first_property "$2" "$3")"
    elif [[ $type == "firsttext" ]] ; then
        echo "$(get_first_property_text "$2" "$3")"
    elif [[ $type == "min" ]] ; then
        echo "$(get_min_property "$2" "$3")"
    elif [[ $type == "max" ]] ; then
        echo "$(get_max_property "$2" "$3")"
    fi
}

[[ -r $forecast ]] && main "$@"
