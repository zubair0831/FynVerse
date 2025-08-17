import json
import fastapi
import pandas as pd
import yfinance as yf
from contextlib import asynccontextmanager
import asyncio
import numpy as np
from fastapi.encoders import jsonable_encoder
import datetime
from computefeatures import compute_features, rate_stock
import math
import joblib

CSV_PATH = "/Users/zubairahmed/Desktop/MLmodel/EQUITY_L.csv"
latest_data_cache = []

app = fastapi.FastAPI()

def sanitize(obj):
    if isinstance(obj, dict):
        return {k: sanitize(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [sanitize(i) for i in obj]
    elif isinstance(obj, (np.floating, float)):
        if math.isnan(obj) or math.isinf(obj):
            return None
        return float(obj)
    elif isinstance(obj, (np.integer, int)):
        return int(obj)
    elif isinstance(obj, (np.bool_, bool)):
        return bool(obj)
    else:
        return obj

def clean_dataframe_for_json(df: pd.DataFrame) -> pd.DataFrame:
    df = df.replace([np.inf, -np.inf], np.nan)
    df = df.fillna(0)
    for col in df.columns:
        if df[col].dtype.kind == 'f':
            df[col] = df[col].astype(float)
    return df

def fetch_latest_prices():
    df = pd.read_csv(CSV_PATH)
    df.columns = df.columns.str.strip()
    df = df[["SYMBOL", "NAME OF COMPANY", "SERIES", "FACE VALUE"]]
    df['YahooSymbol'] = np.where(df['SYMBOL'] == "NIFTY50", "^NSEI", df['SYMBOL'] + ".NS")

    batch_size = 100
    latest_prices = {}
    previous_close_prices = {}

    for i in range(0, len(df), batch_size):
        batch_symbols = df['YahooSymbol'][i:i+batch_size].tolist()
        data = yf.download(batch_symbols, period="2d", interval="1d")['Close']

        if isinstance(data, pd.Series):
            closes = data.dropna()
            if len(closes) == 2:
                previous_close_prices[closes.index[0]] = closes.iloc[0]
                latest_prices[closes.index[1]] = closes.iloc[1]
            elif len(closes) == 1:
                latest_prices[closes.index[0]] = closes.iloc[0]
        else:
            for symbol in batch_symbols:
                series = data[symbol].dropna()
                if len(series) == 2:
                    previous_close_prices[symbol] = series.iloc[0]
                    latest_prices[symbol] = series.iloc[1]
                elif len(series) == 1:
                    latest_prices[symbol] = series.iloc[0]

    df['Last Price'] = df['YahooSymbol'].map(latest_prices)
    df['Previous Close'] = df['YahooSymbol'].map(previous_close_prices)
    df['P&L'] = df['Last Price'] - df['Previous Close']
    df['Percent Change'] = (df['P&L'] / df['Previous Close']) * 100

    df = df.round(2)
    df = clean_dataframe_for_json(df)

    return df.to_dict(orient="records")

@app.on_event("startup")
async def startup_event():
    # Start periodic update as background asyncio task on app startup
    asyncio.create_task(periodic_update_task())

async def periodic_update_task():
    global latest_data_cache
    today = datetime.datetime.today().weekday()

    # Market open & close times
    market_open = datetime.time(9, 0)
    market_close = datetime.time(15, 30)

    # If weekend, fetch once only
    if today in (5, 6):
        if not latest_data_cache:
            print("✅ Weekend: Fetching stock data once...")
            latest_data_cache = fetch_latest_prices()
    else:
        print("🟢 Starting periodic fetching (Mon-Fri, 9:00–15:30)")
        while True:
            now = datetime.datetime.now().time()
            if market_open <= now <= market_close:
                print(f"✅ {now} — Market open, updating stock data...")
                latest_data_cache = fetch_latest_prices()
            else:
                print(f"⏸ {now} — Market closed, skipping update.")

            await asyncio.sleep(1200)  # check every 5 minutes


PROB_THRESH_BUY = 0.60
PROB_THRESH_STRONG_BUY = 0.75
PROB_THRESH_SELL = 0.40

def predict_stock(ticker: str):
    scaler = joblib.load("scaler.joblib")
    model = joblib.load("lgb_5day_model.joblib")
    df_raw = yf.download(ticker, period="5y", interval="1d")
    if df_raw.empty:
        raise RuntimeError(f"No data found for ticker {ticker}")
    if isinstance(df_raw.columns, pd.MultiIndex):
        df_raw.columns = [col[0] if isinstance(col, tuple) else col for col in df_raw.columns]
    df_raw = df_raw.loc[:, ~df_raw.columns.duplicated()]
    df_raw.index = pd.to_datetime(df_raw.index)
    df_feat = compute_features(df_raw)
    if df_feat.empty:
        raise RuntimeError("No features computed (check data or feature function)")
    X_raw = df_feat.drop(columns=['target']).iloc[-1:]
    if X_raw.isnull().values.any():
        raise RuntimeError("Latest features contain NaNs, can't predict")
    X_scaled = pd.DataFrame(scaler.transform(X_raw), columns=X_raw.columns)
    prob_up = model.predict_proba(X_scaled)[:, 1][0]
    if prob_up >= PROB_THRESH_STRONG_BUY:
        signal = "BUY_STRONG"
    elif prob_up >= PROB_THRESH_BUY:
        signal = "BUY"
    elif prob_up >= PROB_THRESH_SELL:
        signal = "HOLD"
    else:
        signal = "SELL"
    date = X_raw.index[0].date()
    return {'date': date, 'probability': prob_up, 'signal': signal}

@app.get("/allstocks")
def get_allstocks():
    return jsonable_encoder(latest_data_cache)

@app.get("/prediction5d")
def get_prediction5d(ticker: str):
    if(ticker == "NIFTY50.NS"):
        return predict_stock(ticker="NSEI")
    else:
        return predict_stock(ticker=ticker)

@app.get("/shortlongterm")
def get_shortlongterm(ticker: str):
    if(ticker == "NIFTY50.NS"):
        result = rate_stock("^NSEI", short_months=3, long_years=2)
    else:
        result = rate_stock(ticker, short_months=3, long_years=2)
    return sanitize(result)

#uvicorn app:app --reload
#uvicorn FetchingStocks:app --reload

#jupyter nbconvert --to script Model.ipynb
#uvicorn FetchingStocks:app --host 0.0.0.0 --port 8000
