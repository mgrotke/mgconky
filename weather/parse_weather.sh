#!/bin/bash
###################################################################################################################################
# This script is from the Harmattan Conky theme project:  https://github.com/zagortenay333/Harmattan
# It has been modified by Matt Grotke (mgrotke@gmail.com).
# Below is Harmattan's license for these files:
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

weather=~/".cache/mgconky/weather.json"

main () {
    query="$1"

    if [[ $query == "iconid" ]] ; then
        echo $(jq --raw-output ".weather[0].id" "$weather")
    elif [[ $query == "description" ]] ; then
        echo $(jq --raw-output ".weather[0].description" "$weather")
    elif [[ $query == "location" ]] ; then
        echo $(jq --raw-output ".name" "$weather")
    elif [[ $query == "temperature" ]] ; then
        printf "%.0f" $(jq --raw-output ".main.temp" "$weather")
    elif [[ $query == "pressure" ]] ; then
        echo $(jq --raw-output ".main.pressure" "$weather")
    elif [[ $query == "humidity" ]] ; then
        echo $(jq --raw-output ".main.humidity" "$weather")
    elif [[ $query == "hourlyrainvolume" ]] ; then
        echo $(jq --raw-output ".rain.1h" "$weather")
    elif [[ $query == "windspeed" ]] ; then
        echo $(jq --raw-output ".wind.speed" "$weather")
    elif [[ $query == "winddeg" ]] ; then
        echo $(jq --raw-output ".wind.deg" "$weather")
    fi
}

[[ -r $weather ]] && main "$@"
