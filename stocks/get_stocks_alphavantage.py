#!/usr/bin/env python3

import os
import sys
import time
import json
import argparse
import requests
from datetime import datetime, timedelta

# Directory where per-symbol cache JSON files are stored
CACHE_DIR = os.path.expanduser("~/.cache/mgconky/stocks_alphavantage/")

# Delay between API calls to respect AlphaVantage rate limits
API_DELAY_SECONDS = 1

# Minimum age before re-querying a symbol to avoid API thrashing
NO_THRASH_SECONDS = 60 * 60  # 1 hour


def log_error(message):
    """Print timestamped error message to stderr and flush immediately."""
    ts = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{ts}] {message}", file=sys.stderr, flush=True)


def fetch_intraday_data(api_key, symbol, interval="1min"):
    # Query AlphaVantage intraday endpoint for the given symbol
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
                # Use earliest bar as open price and latest bar as current price
                sorted_timestamps = sorted(time_series.keys())
                open_time = sorted_timestamps[0]
                latest_time = sorted_timestamps[-1]

                return {
                    "current_price": float(time_series[latest_time]["4. close"]),
                    "compare_price": float(time_series[open_time]["1. open"]),
                }
            else:
                # API responded but did not include expected time series data
                log_error(f"No 'Time Series ({interval})' data found for {symbol}.")
        else:
            # HTTP error from AlphaVantage
            log_error(f"Failed to fetch intraday data for {symbol} (HTTP {response.status_code})")
    except requests.RequestException as e:
        # Network or request failure
        log_error(f"Failed to fetch intraday data for {symbol} - {e}")

    return None


def fetch_historical_data(api_key, symbol, range_in_days):
    # Query AlphaVantage daily endpoint for historical comparison
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
                # Most recent trading day's close is the current price
                latest_date = max(time_series.keys())
                current_price = float(time_series[latest_date]["4. close"])

                # Target calendar date for comparison
                target = datetime.now() - timedelta(days=range_in_days)

                # Walk backward up to 10 days to find a valid trading day
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
                # API responded but did not include expected daily series data
                log_error(f"No 'Time Series (Daily)' data found for {symbol}.")
        else:
            # HTTP error from AlphaVantage
            log_error(f"Failed to fetch historical data for {symbol} (HTTP {response.status_code})")

    except requests.RequestException as e:
        # Network or request failure
        log_error(f"Failed to fetch historical data for {symbol} - {e}")

    return None


def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser()
    parser.add_argument("--api_key", required=True)
    parser.add_argument("--symbols", required=True)
    parser.add_argument("--range_in_days", type=int, default=0)
    args = parser.parse_args()

    # Normalize and split ticker symbols
    symbols = args.symbols.strip().upper().split(",")

    # Ensure cache directory exists
    os.makedirs(CACHE_DIR, exist_ok=True)

    for i, symbol in enumerate(symbols):
        cache_path = os.path.join(CACHE_DIR, f"{symbol}.json")

        # --- No-thrash protection: skip API call if cache is still fresh ---
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
                    # Cached data is recent enough -> skip querying AlphaVantage
                    continue
            except Exception:
                # Any read/parse error -> ignore cache and refetch
                pass

        # Fetch either intraday or historical data depending on range
        fetched_data = (
            fetch_intraday_data(args.api_key, symbol)
            if args.range_in_days < 1
            else fetch_historical_data(args.api_key, symbol, args.range_in_days)
        )

        # Only write cache if fetched data is structurally valid
        if (
            isinstance(fetched_data, dict)
            and "current_price" in fetched_data
            and isinstance(fetched_data["current_price"], (int, float))
        ):
            tmp = os.path.join(CACHE_DIR, f"{symbol}.json.tmp")
            final = os.path.join(CACHE_DIR, f"{symbol}.json")

            # Payload includes metadata for staleness and debugging
            payload = {
                "symbol": symbol,
                "range_in_days": args.range_in_days,
                "timestamp": int(time.time()),
                "data": fetched_data,
            }

            # Atomic write to avoid corrupting existing cache
            with open(tmp, "w") as f:
                json.dump(payload, f)
            os.replace(tmp, final)

        # Rate-limit delay between symbols
        if i < len(symbols) - 1:
            time.sleep(API_DELAY_SECONDS)


if __name__ == "__main__":
    main()

