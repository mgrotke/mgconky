#!/usr/bin/env python3

import os
import sys
import time
import json
import argparse
from datetime import datetime, timedelta

# Directory containing cached per-symbol JSON files
CACHE_DIR = os.path.expanduser("~/.cache/mgconky/stocks_alphavantage/")

def main():
    # Parse command-line arguments (reader does not need api_key)
    parser = argparse.ArgumentParser(description="Process cached Alpha Vantage stock data.")
    parser.add_argument("--symbols", required=True, help="Comma-separated list of stock symbols")
    parser.add_argument("--range_in_days", type=int, default=0, help="Number of days for historical comparison")
    parser.add_argument("--price_dec_places", type=int, default=0, help="Decimal places for prices")
    parser.add_argument("--percent_dec_places", type=int, default=1, help="Decimal places for percentages")
    parser.add_argument("--stale_seconds", type=int, default=13 * 3600, help="Seconds before cached data is considered stale")
    args = parser.parse_args()

    # Split ticker symbols by comma
    symbols = args.symbols.strip().upper().split(",")

    # Collect formatted output lines for Conky
    output = []

    # Conky color and layout formatting
    color_header = "${color}"
    color_label = "${color3}"
    color_value = "${color3}"
    color_good = "${color6}"
    color_bad = "${color7}"
    line_tab1_offset = "${goto 25}"
    line_tab2_offset = "${goto 90}"
    line_tab3_offset = "${alignr}"

    # Process each symbol
    for symbol in symbols:
        cache_path = os.path.join(CACHE_DIR, f"{symbol}.json")

        # Missing cache file -- display formatted placeholder
        if not os.path.exists(cache_path):
            output.append(
                f"{line_tab1_offset}{color_bad}{symbol}: "
                f"{line_tab2_offset}{color_value}-- "
                f"{line_tab3_offset}{color_value}-- (--%)"
            )
            continue

        # Determine cache age using file modification time
        age_seconds = time.time() - os.stat(cache_path).st_mtime

        # Symbol turns red (color_bad) if cached data is stale
        symbol_color = color_bad if age_seconds > args.stale_seconds else color_label

        # Load cached JSON payload
        try:
            with open(cache_path, "r") as f:
                payload = json.load(f)

            # Validate payload structure before use
            if not isinstance(payload, dict) or "data" not in payload:
                raise ValueError("Invalid cache payload")

            fetched_data = payload["data"]

        except Exception:
            # Corrupt or unreadable cache file -- display formatted placeholder
            output.append(
                f"{line_tab1_offset}{color_bad}{symbol}: "
                f"{line_tab2_offset}{color_value}-- "
                f"{line_tab3_offset}{color_value}-- (--%)"
            )
            continue

        # ------------------------------
        # VALIDATION
        # ------------------------------
        if (
            isinstance(fetched_data, dict)
            and "current_price" in fetched_data
            and isinstance(fetched_data["current_price"], (int, float))
        ):
            current_price = fetched_data["current_price"]
            compare_price = fetched_data["compare_price"]

            # Comparison price may be missing if no trading day was found
            if not isinstance(compare_price, (int, float)):
                symbol_color = color_bad
                output.append(
                    f"{line_tab1_offset}{symbol_color}{symbol}: "
                    f"{line_tab2_offset}{color_value}-- "
                    f"{line_tab3_offset}{color_value}-- (--%)"
                )
                continue

            # Compute absolute and percentage change
            price_difference = current_price - compare_price
            percent_change = (price_difference / current_price) * 100

            # Color change based on price movement direction
            color_dynamic = (
                color_good if round(price_difference, args.price_dec_places) > 0
                else color_bad if round(price_difference, args.price_dec_places) < 0
                else color_value
            )

            # The actual formatted line with valid stock data
            output.append(
                f"{line_tab1_offset}{symbol_color}{symbol}: "
                f"{line_tab2_offset}{color_value}{round(current_price, args.price_dec_places):.{args.price_dec_places}f} "
                f"{line_tab3_offset}{color_dynamic}{round(price_difference, args.price_dec_places):+.{args.price_dec_places}f} "
                f"({round(percent_change, args.percent_dec_places):+.{args.percent_dec_places}f}%)"
            )
        else:
            # Cached data missing required fields -- display formatted placeholder
            output.append(
                f"{line_tab1_offset}{color_bad}{symbol}: "
                f"{line_tab2_offset}{color_value}-- "
                f"{line_tab3_offset}{color_value}-- (--%)"
            )

    # Header label depends on intraday vs historical mode
    header_label = "Intraday" if args.range_in_days < 1 else f"{args.range_in_days} Day"

    # Formatted header line
    header_line = (
        f"{line_tab1_offset}{color_header}Ticker"
        f"{line_tab2_offset}Price ($$)"
        f"{line_tab3_offset}{header_label}{color_label}"
    )

    # Print final output for Conky to render
    print(
        header_line
        + "\n"
        + f"{line_tab1_offset}{color_header}${{voffset -5}}${{hr 1}}"
        + "\n"
        + "\n".join(output)
    )

if __name__ == "__main__":
    main()

