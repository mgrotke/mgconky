#!/usr/bin/env python3

import requests
from datetime import datetime, timedelta
import argparse

def fetch_intraday_data(api_key, symbol, interval="1min"):
    """Fetch current and historical intraday price using TIME_SERIES_INTRADAY."""
    url = "https://www.alphavantage.co/query"
    params = {
        "function": "TIME_SERIES_INTRADAY",
        "symbol": symbol,
        "interval": interval,
        "apikey": api_key
    }
    try:
        response = requests.get(url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            time_series = data.get(f"Time Series ({interval})")

            # Debug: Log the raw response
            #print(f"DEBUG: Response data for {symbol}: {data}")

            if time_series:
                # Sort the timestamps to get the first (open) and latest price
                sorted_timestamps = sorted(time_series.keys())
                open_time = sorted_timestamps[0]  # Earliest timestamp of the day
                latest_time = sorted_timestamps[-1]  # Most recent timestamp

                # Extract open price and latest price
                open_price = float(time_series[open_time]["1. open"])
                latest_price = float(time_series[latest_time]["4. close"])

                return {
                    "current_price": latest_price,
                    "compare_price": open_price
                }
            else:
                print(f"Error: No 'Time Series ({interval})' data found for {symbol}.")
                return None
        else:
            print(f"Error: Failed to fetch intraday data for {symbol} (HTTP {response.status_code})")
            return None
    except requests.RequestException as e:
        print(f"Error: Failed to fetch intraday data for {symbol} - {e}")
        return None


def fetch_historical_data(api_key, symbol, range_in_days):
    """Fetch current and historical price using TIME_SERIES_DAILY, allowing fallback to nearby dates."""
    url = "https://www.alphavantage.co/query"
    params = {
        "function": "TIME_SERIES_DAILY",
        "symbol": symbol,
        "apikey": api_key
    }
    try:
        response = requests.get(url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            time_series = data.get("Time Series (Daily)")

            # Debug: Log the raw response
            #print(f"DEBUG: Response data for {symbol}: {data}")

            if time_series:
                # Current price is the latest closing price
                latest_date = max(time_series.keys())
                latest_data = time_series[latest_date]
                current_price = float(latest_data["4. close"])

                # Dates to check: exact, one day before, one day after
                target_date = (datetime.now() - timedelta(days=range_in_days)).strftime("%Y-%m-%d")
                fallback_dates = [
                    target_date,
                    (datetime.now() - timedelta(days=range_in_days + 1)).strftime("%Y-%m-%d"),
                    (datetime.now() - timedelta(days=range_in_days - 1)).strftime("%Y-%m-%d")
                ]

                # Find the first available date in the fallback list
                historical_price = None
                for date in fallback_dates:
                    if date in time_series:
                        historical_price = float(time_series[date]["4. close"])
                        break

                return {
                    "current_price": current_price,
                    "compare_price": historical_price
                }
            else:
                print(f"Error: No 'Time Series (Daily)' data found for {symbol}.")
                return None
        else:
            print(f"Error: Failed to fetch historical data for {symbol} (HTTP {response.status_code})")
            return None
    except requests.RequestException as e:
        print(f"Error: Failed to fetch historical data for {symbol} - {e}")
        return None

def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Fetch stock data from Alpha Vantage.")
    parser.add_argument("--api_key", required=True, help="Your Alpha Vantage API key")
    parser.add_argument("--symbols", required=True, help="Comma-separated list of stock symbols")
    parser.add_argument("--range_in_days", type=int, default=0, help="Number of days for historical comparison (0 for none)")
    parser.add_argument("--price_dec_places", type=int, default=0, help="Decimal places for prices")
    parser.add_argument("--percent_dec_places", type=int, default=1, help="Decimal places for percentages")
    args = parser.parse_args()

    # Split symbols
    symbols = args.symbols.strip().upper().split(",")

    # Use a list to build the final output string
    output = []

    # Prepare for printing output
    color_header = "${color}"
    color_label = "${color3}"
    color_value = "${color3}"
    color_good = "${color6}"
    color_bad = "${color7}"
    line_tab1_offset = "${goto 25}"
    line_tab2_offset = "${goto 90}"
    line_tab3_offset = "${alignr}" # Could also replace this with goto 120 if you don't like the right alignment

    # Iterate symbols
    for symbol in symbols:
        fetched_data = fetch_intraday_data(args.api_key, symbol) if args.range_in_days < 1 else fetch_historical_data(args.api_key, symbol, args.range_in_days)
        if fetched_data:
            current_price = fetched_data["current_price"]
            compare_price = fetched_data["compare_price"]
            price_difference = current_price - compare_price
            percent_change = (price_difference / current_price) * 100
            color_dynamic = (
                color_good if round(price_difference, args.price_dec_places) > 0 
                else color_bad if round(price_difference, args.price_dec_places) < 0 
                else color_value
            )
            output.append(
                f"{line_tab1_offset}{color_label}{symbol}: {line_tab2_offset}{color_value}{round(current_price, args.price_dec_places):.{args.price_dec_places}f} "
                f"{line_tab3_offset}{color_dynamic}{round(price_difference, args.price_dec_places):+.{args.price_dec_places}f} "
                f"({round(percent_change, args.percent_dec_places):+.{args.percent_dec_places}f}%)"
            )
        else:
            output.append(f"{symbol}: Error fetching data")

    # Join all parts of the output and print it
    header_label = f"Intraday" if args.range_in_days < 1 else f"{args.range_in_days} Day"
    header_line = f"{line_tab1_offset}{color_header}Ticker{line_tab2_offset}Price ($$){line_tab3_offset}{header_label}{color_label}"
    return header_line + "\n" + f"{line_tab1_offset}{color_header}${{voffset -5}}${{hr 1}}" + "\n" + "\n".join(output)

if __name__ == "__main__":
    print(main())

