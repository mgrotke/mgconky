#!/usr/bin/env python3

import os
import sys
import time
import json
import argparse
import requests
from datetime import datetime, timedelta

CACHE_DIR = os.path.expanduser("~/.cache/mgconky/stocks_alphavantage/")
API_DELAY_SECONDS = 1
NO_THRASH_SECONDS = 60 * 60 # 1 hour


def fetch_intraday_data(api_key, symbol, interval="1min"):
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

            if time_series:
                sorted_timestamps = sorted(time_series.keys())
                open_time = sorted_timestamps[0]
                latest_time = sorted_timestamps[-1]

                return {
                    "current_price": float(time_series[latest_time]["4. close"]),
                    "compare_price": float(time_series[open_time]["1. open"]),
                }
            else:
                print(f"Error: No 'Time Series ({interval})' data found for {symbol}.", file=sys.stderr)
        else:
            print(f"Error: Failed to fetch intraday data for {symbol} (HTTP {response.status_code})", file=sys.stderr)
    except requests.RequestException as e:
        print(f"Error: Failed to fetch intraday data for {symbol} - {e}", file=sys.stderr)

    return None


def fetch_historical_data(api_key, symbol, range_in_days):
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

            if time_series:
                latest_date = max(time_series.keys())
                current_price = float(time_series[latest_date]["4. close"])

                target = datetime.now() - timedelta(days=range_in_days)
                historical_price = None
                for offset in range(10):
                    d = (target - timedelta(days=offset)).strftime("%Y-%m-%d")
                    if d in time_series:
                        historical_price = float(time_series[d]["4. close"])
                        break

                return {
                    "current_price": current_price,
                    "compare_price": historical_price,
                }
            else:
                print(f"Error: No 'Time Series (Daily)' data found for {symbol}.", file=sys.stderr)
        else:
            print(f"Error: Failed to fetch historical data for {symbol} (HTTP {response.status_code})", file=sys.stderr)
    except requests.RequestException as e:
        print(f"Error: Failed to fetch historical data for {symbol} - {e}", file=sys.stderr)

    return None


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--api_key", required=True)
    parser.add_argument("--symbols", required=True)
    parser.add_argument("--range_in_days", type=int, default=0)
    args = parser.parse_args()

    symbols = args.symbols.strip().upper().split(",")
    os.makedirs(CACHE_DIR, exist_ok=True)

    for i, symbol in enumerate(symbols):
        cache_path = os.path.join(CACHE_DIR, f"{symbol}.json")

        # --- No-thrash protection ---
        if os.path.exists(cache_path):
            try:
                with open(cache_path, "r") as f:
                    payload = json.load(f)

                if (
                    isinstance(payload, dict)
                    and "timestamp" in payload
                    and isinstance(payload["timestamp"], (int, float))
                    and (time.time() - payload["timestamp"]) < NO_THRASH_SECONDS
                ):
                    # Cache is recent enough ---> skip API call
                    continue
            except Exception:
                # Any error ---> fall through and refetch
                pass

        fetched_data = (
            fetch_intraday_data(args.api_key, symbol)
            if args.range_in_days < 1
            else fetch_historical_data(args.api_key, symbol, args.range_in_days)
        )

        if (
            isinstance(fetched_data, dict)
            and "current_price" in fetched_data
            and isinstance(fetched_data["current_price"], (int, float))
        ):
            tmp = os.path.join(CACHE_DIR, f"{symbol}.json.tmp")
            final = os.path.join(CACHE_DIR, f"{symbol}.json")

            payload = {
                "symbol": symbol,
                "range_in_days": args.range_in_days,
                "timestamp": int(time.time()),
                "data": fetched_data,
            }

            with open(tmp, "w") as f:
                json.dump(payload, f)
            os.replace(tmp, final)

        if i < len(symbols) - 1:
            time.sleep(API_DELAY_SECONDS)

if __name__ == "__main__":
    main()

