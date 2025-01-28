#!/usr/bin/env python3

import requests
import argparse
from datetime import datetime, timedelta


def fetch_current_stock_data(api_key, symbol):
    url = "https://finnhub.io/api/v1/quote"
    params = {
        'symbol': symbol,
        'token': api_key
    }
    try:
        response = requests.get(url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            return {
                "symbol": symbol,
                "current_price": data.get("c"),
                "open_price": data.get("o")
            }
        else:
            print(f"Error: Failed to fetch current data for {symbol} (HTTP {response.status_code})")
            return None
    except requests.RequestException as e:
        print(f"Error: Failed to get current stock data for {symbol} - {e}")
        return None


def fetch_current_crypto_data(api_key, symbol):
    url = "https://finnhub.io/api/v1/crypto/candle"
    current_time = int(datetime.now().timestamp())
    params = {
        'symbol': symbol,
        'resolution': '1',  # 1-minute resolution
        'from': current_time - 60,  # Last minute
        'to': current_time,
        'token': api_key
    }
    try:
        response = requests.get(url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if data.get("s") == "ok" and "c" in data:
                return {
                    "symbol": symbol,
                    "current_price": data["c"][-1],  # Last closing price
                    "open_price": data["o"][-1]  # Last opening price
                }
            else:
                print(f"Error: Crypto data not OK for {symbol}")
                return None
        else:
            print(f"Error: Failed to fetch crypto data for {symbol} (HTTP {response.status_code})")
            return None
    except requests.RequestException as e:
        print(f"Error: Failed to get crypto data for {symbol} - {e}")
        return None


def fetch_historical_data(api_key, symbol, range_in_days):
    url = "https://finnhub.io/api/v1/stock/candle" if ':' in symbol else "https://finnhub.io/api/v1/crypto/candle"
    end_time = int(datetime.now().timestamp())
    start_time = int((datetime.now() - timedelta(days=range_in_days)).timestamp())
    params = {
        'symbol': symbol,
        'resolution': 'D',  # Daily candles
        'from': start_time,
        'to': end_time,
        'token': api_key
    }
    try:
        response = requests.get(url, params=params, timeout=10)
        if response.status_code == 200:
            data = response.json()
            if data.get("s") == "ok":
                return {
                    "symbol": symbol,
                    "timestamps": data["t"],
                    "close_prices": data["c"]
                }
            else:
                print(f"Error: Historical data not ok for {symbol}")
                return None
        else:
            print(f"Error: Failed to fetch historical data for {symbol} (HTTP {response.status_code})")
            return None
    except requests.RequestException as e:
        print(f"Error: Failed to get historical stock data for {symbol} - {e}")
        return None

def main():
    # Parse command-line arguments
    parser = argparse.ArgumentParser(description="Fetch stock data from FinnHub.")
    parser.add_argument("--api_key", required=True, help="Your personal FinnHub API key")
    parser.add_argument("--symbols", required=True, help="Stock symbols (comma separated) to fetch")
    parser.add_argument("--range_in_days", default=0, type=int, help="Number of days to compare against (optional, default is 0)")
    parser.add_argument("--price_dec_places", default=0, type=int, help="Number of decimal places for prices (default is 0)")
    parser.add_argument("--percent_dec_places", default=1, type=int, help="Number of decimal places for percentages (default is 1)")
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
    historical_data_exists = False

    # Iterate symbols (crypto symbols have a colon in them, i.e. BINANCE:BTCUSDT; COINBASE:BTCUSD)
    for symbol in symbols:
        current_data = fetch_current_crypto_data(args.api_key, symbol) if ':' in symbol else fetch_current_stock_data(args.api_key, symbol)
        if current_data:
            current_price = current_data['current_price']
            if args.range_in_days > 0:
                # Fetch historical data if range_in_days > 0
                historical_data = fetch_historical_data(args.api_key, symbol, args.range_in_days)
                if historical_data:
                    historical_data_exists = True
                    # Find the closing price for exactly X days ago
                    target_date = (datetime.now() - timedelta(days=args.range_in_days)).strftime("%Y-%m-%d")
                    timestamps = historical_data["timestamps"]
                    close_prices = historical_data["close_prices"]

                    # Convert timestamps to dates and find the target date's index
                    date_to_close_price = {
                        datetime.fromtimestamp(ts).strftime("%Y-%m-%d"): price
                        for ts, price in zip(timestamps, close_prices)
                    }

                    historical_closing_price = date_to_close_price.get(target_date, None)
                    if historical_closing_price is not None:
                        # Calculate difference in value from current price to historical close
                        price_difference = current_price - historical_closing_price
                        percent_change = (price_difference / historical_closing_price) * 100
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
                        output.append(
                            f"{symbol}: {round(current_price, args.price_dec_places):.{args.price_dec_places}f} "
                            f"| {args.range_in_days} days: No historical data"
                        )
                else:
                    output.append(f"{symbol}: Error fetching historical data")
            else:
                # Only include intraday change if no historical data is requested
                open_price = current_data['open_price']
                if open_price is not None and current_price is not None:
                    intraday_change = current_price - open_price
                    intraday_percent_change = (intraday_change / open_price) * 100
                    color_dynamic = (
                        color_good if round(intraday_change, args.price_dec_places) > 0 
                        else color_bad if round(intraday_change, args.price_dec_places) < 0 
                        else color_value
                    )
                    output.append(
                        f"{line_tab1_offset}{color_label}{symbol}: {line_tab2_offset}{color_value}{round(current_price, args.price_dec_places):.{args.price_dec_places}f} "
                        f"{line_tab3_offset}{color_dynamic}{round(intraday_change, args.price_dec_places):+.{args.price_dec_places}f} "
                        f"({round(intraday_percent_change, args.percent_dec_places):+.{args.percent_dec_places}f}%)"
                    )
                else:
                    output.append(
                        f"{symbol}: {round(current_price, args.price_dec_places):.{args.price_dec_places}f} | Intraday: N/A"
                    )
        else:
            output.append(f"{symbol}: Error fetching current data")

    # Join all parts of the output and print it
    header_label = f"{args.range_in_days} Day" if historical_data_exists else "Intraday"
    header_line = f"{line_tab1_offset}{color_header}Ticker{line_tab2_offset}Price ($$){line_tab3_offset}{header_label}{color_label}"
    return header_line + "\n" + f"{line_tab1_offset}{color_header}${{voffset -5}}${{hr 1}}" + "\n" + "\n".join(output)

if __name__ == "__main__":
    print(main())

