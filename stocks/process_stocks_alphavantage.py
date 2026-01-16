#!/usr/bin/env python3

import os
import sys
import time
import json
import argparse
from datetime import datetime, timedelta

CACHE_DIR = os.path.expanduser("~/.cache/mgconky/stocks_alphavantage/")

def main():
    # Parse command-line arguments (same shape as original, minus api_key)
    parser = argparse.ArgumentParser(description="Process cached Alpha Vantage stock data.")
    parser.add_argument("--symbols", required=True, help="Comma-separated list of stock symbols")
    parser.add_argument("--range_in_days", type=int, default=0, help="Number of days for historical comparison")
    parser.add_argument("--price_dec_places", type=int, default=0, help="Decimal places for prices")
    parser.add_argument("--percent_dec_places", type=int, default=1, help="Decimal places for percentages")
    parser.add_argument("--stale_seconds", type=int, default=13 * 3600, help="Seconds before cached data is considered stale")
    args = parser.parse_args()

    # Split symbols (unchanged)
    symbols = args.symbols.strip().upper().split(",")

    # Output builder (unchanged)
    output = []

    # Formatting (unchanged)
    color_header = "${color}"
    color_label = "${color3}"
    color_value = "${color3}"
    color_good = "${color6}"
    color_bad = "${color7}"
    line_tab1_offset = "${goto 25}"
    line_tab2_offset = "${goto 90}"
    line_tab3_offset = "${alignr}"

    # Iterate symbols (structure preserved)
    for symbol in symbols:
        cache_path = os.path.join(CACHE_DIR, f"{symbol}.json")

        # Missing cache file → invalid
        if not os.path.exists(cache_path):
            output.append(
                f"{line_tab1_offset}{color_bad}{symbol}: "
                f"{line_tab2_offset}{color_value}-- "
                f"{line_tab3_offset}{color_value}-- (--%)"
            )
            continue

        # Determine staleness from mtime
        age_seconds = time.time() - os.stat(cache_path).st_mtime
        symbol_color = color_bad if age_seconds > args.stale_seconds else color_label

        # Load cached JSON
        try:
            with open(cache_path, "r") as f:
                payload = json.load(f)
            if not isinstance(payload, dict) or "data" not in payload:
                raise ValueError("Invalid cache payload")
            fetched_data = payload["data"]

        except Exception:
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

            # Defensive: compare_price may still be None
            if not isinstance(compare_price, (int, float)):
                symbol_color = color_bad
                output.append(
                    f"{line_tab1_offset}{symbol_color}{symbol}: "
                    f"{line_tab2_offset}{color_value}-- "
                    f"{line_tab3_offset}{color_value}-- (--%)"
                )
                continue

            price_difference = current_price - compare_price
            percent_change = (price_difference / current_price) * 100

            color_dynamic = (
                color_good if round(price_difference, args.price_dec_places) > 0
                else color_bad if round(price_difference, args.price_dec_places) < 0
                else color_value
            )

            output.append(
                f"{line_tab1_offset}{symbol_color}{symbol}: "
                f"{line_tab2_offset}{color_value}{round(current_price, args.price_dec_places):.{args.price_dec_places}f} "
                f"{line_tab3_offset}{color_dynamic}{round(price_difference, args.price_dec_places):+.{args.price_dec_places}f} "
                f"({round(percent_change, args.percent_dec_places):+.{args.percent_dec_places}f}%)"
            )
        else:
            # Invalid cached data → treat as bad/stale
            output.append(
                f"{line_tab1_offset}{color_bad}{symbol}: "
                f"{line_tab2_offset}{color_value}-- "
                f"{line_tab3_offset}{color_value}-- (--%)"
            )

    # Header (unchanged naming)
    header_label = "Intraday" if args.range_in_days < 1 else f"{args.range_in_days} Day"
    header_line = (
        f"{line_tab1_offset}{color_header}Ticker"
        f"{line_tab2_offset}Price ($$)"
        f"{line_tab3_offset}{header_label}{color_label}"
    )

    print(
        header_line
        + "\n"
        + f"{line_tab1_offset}{color_header}${{voffset -5}}${{hr 1}}"
        + "\n"
        + "\n".join(output)
    )

if __name__ == "__main__":
    main()

