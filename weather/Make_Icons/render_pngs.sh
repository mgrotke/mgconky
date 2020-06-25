#!/bin/bash
###################################################################################################################################
# This script was used from the Harmattan Conky theme project:  https://github.com/zagortenay333/Harmattan
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


# ======================================
# ANSI
# ======================================
ansi_reset='\e[0m'

bold='\e[1m'

blue='\e[34m'

yellow_b='\e[1;33m'

red_b='\e[1;31m'

darkgray_b='\e[1;90m'


# ======================================
#   Constants
# ======================================
svg_src="SVG"

png_dest="renders"

default_color="#000"

default_size="32"


# ======================================
# User Input
# ======================================
echo

echo -e "${bold}Enter icon icon_size (skip for default): ${ansi_reset}"
read -r icon_size

echo -e "${bold}Enter 1 or more colors (space or tab separated): ${ansi_reset}"
read -r -a icon_colors


# ======================================
# Checks
# ======================================
# If no colors given, add default color to array
[ ${#icon_colors[*]} -eq 0 ] && icon_colors[0]="$default_color"

mkdir -p "$png_dest"

icon_size=${icon_size:-"$default_size"}


# ======================================
# RENDER
# ======================================
for color in ${icon_colors[*]}; do
    echo
    echo -e "${darkgray_b}---------------------------------------${ansi_reset}"


    # Check whether the png folder already exits
    if [ -d "$png_dest/${color}__$icon_size" ]; then
        echo
        echo -e "${red_b}$png_dest/${color}__$icon_size exists!${ansi_reset}"
        continue
    fi


    mkdir -p "${color}__$icon_size"


    trap 'sed -i "s/<path fill=\"$color\"/<path/" $svg_src/*.svg; exit' INT TERM


    sed -i "s/<path/<path fill=\"$color\"/" "$svg_src"/*.svg


    # Loop through SVG folder & render png's
    for i in $svg_src/*.svg; do

        # Get basename
        i2=${i##*/}  i2=${i2%.*}

        # If png exists, skip
        if [ -f "${color}__$icon_size/$i2.png" ]; then
            echo
            echo -e "${darkgray_b}${color}__$icon_size/$i2.png exists.${ansi_reset}"

        else
            echo
            echo -e "${blue}Rendering ${yellow_b}${color}__$icon_size/$i2.png${ansi_reset}"

            inkscape -e "${color}__$icon_size/$i2.png" "$i" \
                     --export-width="$icon_size" --export-height="$icon_size" &> /dev/null
        fi
    done


    # Inkscape has trouble exporting into
    # arbitrary depth paths, so move manually
    mv "${color}__${icon_size}" "$png_dest"


    # Revert edit of svg's before next iteration or EXIT
    sed -i "s/<path fill=\"$color\"/<path/" "$svg_src"/*.svg

done


# If notify-send installed, send notif
hash notify-send 2>/dev/null &&
notify-send -i 'terminal' \
            -a 'Terminal' \
            'Terminal'    \
            'Finished rendering icons!'
