import json
import math
import asyncio
import logging
import sqlite3
import os
from contextlib import asynccontextmanager
from datetime import datetime, time
from functools import lru_cache
from threading import Lock
from typing import Dict, Any, List, Optional
import concurrent.futures
from computefeatures import compute_features
import fastapi
import pandas as pd
import yfinance as yf
import numpy as np
import joblib
import pytz
from fastapi import HTTPException, Query
from fastapi.encoders import jsonable_encoder

# ================== CONFIGURATION ==================
CSV_PATH = "/Users/zubairahmed/Desktop/FynVerse/Backend/EQUITY_L.csv"
MARKET_TZ = pytz.timezone('Asia/Kolkata')
MARKET_OPEN = time(9, 15)
MARKET_CLOSE = time(15, 30)
PREDICTION_THRESHOLDS = {
    'STRONG_BUY': 0.75,
    'BUY': 0.60,
    'SELL': 0.40
}

# Global cache and locks
latest_data_cache = []
market_cap_cache = {}
db_lock = Lock()

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = fastapi.FastAPI(title="Optimized Stock Market API", version="3.0.0")

# ================== UTILITY FUNCTIONS ==================

def sanitize_data(obj):
    """Recursively sanitize data for JSON serialization"""
    if isinstance(obj, dict):
        return {k: sanitize_data(v) for k, v in obj.items()}
    elif isinstance(obj, list):
        return [sanitize_data(i) for i in obj]
    elif isinstance(obj, (np.floating, float)):
        return None if (math.isnan(obj) or math.isinf(obj)) else float(obj)
    elif isinstance(obj, (np.integer, int)):
        return int(obj)
    elif isinstance(obj, (np.bool_, bool)):
        return bool(obj)
    return obj

def clean_dataframe(df: pd.DataFrame) -> pd.DataFrame:
    """Clean DataFrame for JSON serialization"""
    df = df.replace([np.inf, -np.inf], np.nan).fillna(0)
    for col in df.columns:
        if df[col].dtype.kind == 'f':
            df[col] = df[col].astype(float)
    return df

def is_market_open() -> bool:
    """Check if market is currently open"""
    now = datetime.now(MARKET_TZ)
    return (now.weekday() < 5 and 
            MARKET_OPEN <= now.time() <= MARKET_CLOSE)

# ================== DATABASE MANAGEMENT ==================

def init_database():
    """Initialize SQLite database for market caps"""
    with sqlite3.connect('market_data.db') as conn:
        conn.execute('''
            CREATE TABLE IF NOT EXISTS market_caps (
                symbol TEXT PRIMARY KEY,
                market_cap REAL,
                last_updated DATE
            )
        ''')

def should_fetch_market_caps() -> bool:
    """Check if we need to fetch market caps today"""
    try:
        with sqlite3.connect('market_data.db') as conn:
            cursor = conn.cursor()
            cursor.execute('''
                SELECT COUNT(*) FROM market_caps 
                WHERE last_updated = DATE('now', 'localtime')
            ''')
            return cursor.fetchone()[0] == 0
    except:
        return True

def load_market_caps_from_db():
    """Load market caps from database into cache"""
    global market_cap_cache
    try:
        with sqlite3.connect('market_data.db') as conn:
            df = pd.read_sql_query('''
                SELECT symbol, market_cap FROM market_caps 
                WHERE last_updated = DATE('now', 'localtime')
            ''', conn)
            market_cap_cache = dict(zip(df['symbol'], df['market_cap']))
            logger.info(f"Loaded {len(market_cap_cache)} market caps from database")
    except Exception as e:
        logger.error(f"Error loading market caps: {e}")

def save_market_caps_to_db(market_caps: Dict[str, float]):
    """Save market caps to database"""
    with db_lock:
        try:
            with sqlite3.connect('market_data.db') as conn:
                today = datetime.now().date()
                data = [(symbol, cap, today) for symbol, cap in market_caps.items()]
                conn.executemany('''
                    INSERT OR REPLACE INTO market_caps 
                    (symbol, market_cap, last_updated) VALUES (?, ?, ?)
                ''', data)
                logger.info(f"Saved {len(market_caps)} market caps to database")
        except Exception as e:
            logger.error(f"Error saving market caps: {e}")

# ================== DATA FETCHING ==================

def fetch_market_caps_batch(symbols: List[str]) -> Dict[str, float]:
    """Fetch market caps for a batch of symbols"""
    market_caps = {}
    batch_size = 50
    
    for i in range(0, len(symbols), batch_size):
        batch = symbols[i:i+batch_size]
        try:
            # Create tickers and fetch info in parallel
            with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
                future_to_symbol = {
                    executor.submit(lambda s: (s, yf.Ticker(s).info.get('marketCap')), symbol): symbol 
                    for symbol in batch
                }
                
                for future in concurrent.futures.as_completed(future_to_symbol, timeout=30):
                    try:
                        symbol, market_cap = future.result()
                        if market_cap:
                            market_caps[symbol] = market_cap
                    except Exception as e:
                        logger.warning(f"Failed to get market cap for a symbol: {e}")
                        
        except Exception as e:
            logger.error(f"Batch market cap fetch failed: {e}")
            
    return market_caps

def fetch_latest_prices_optimized() -> List[Dict[str, Any]]:
    """Optimized function to fetch latest prices with market caps"""
    # Load stock symbols
    df = pd.read_csv(CSV_PATH)
    df.columns = df.columns.str.strip()
    df = df[["SYMBOL", "NAME OF COMPANY", "SERIES", "FACE VALUE"]]
    df['YahooSymbol'] = np.where(
        df['SYMBOL'] == "NIFTY50", 
        "^NSEI", 
        df['SYMBOL'] + ".NS"
    )

    # Fetch price data in batches
    batch_size = 100
    all_price_data = {}
    
    for i in range(0, len(df), batch_size):
        batch_symbols = df['YahooSymbol'][i:i+batch_size].tolist()
        try:
            # Get 2 days of data for current and previous close
            data = yf.download(batch_symbols, period="2d", interval="1d", 
                            group_by='ticker' if len(batch_symbols) > 1 else None)
            
            if not data.empty:
                if len(batch_symbols) == 1:
                    # Single symbol case
                    symbol = batch_symbols[0]
                    closes = data['Close'].dropna()
                    if len(closes) >= 2:
                        all_price_data[symbol] = {
                            'previous_close': closes.iloc[-2],
                            'current_price': closes.iloc[-1]
                        }
                    elif len(closes) == 1:
                        all_price_data[symbol] = {
                            'previous_close': closes.iloc[0],
                            'current_price': closes.iloc[0]
                        }
                else:
                    # Multiple symbols case
                    for symbol in batch_symbols:
                        try:
                            if symbol in data.columns.get_level_values(0):
                                closes = data[symbol]['Close'].dropna()
                                if len(closes) >= 2:
                                    all_price_data[symbol] = {
                                        'previous_close': closes.iloc[-2],
                                        'current_price': closes.iloc[-1]
                                    }
                                elif len(closes) == 1:
                                    all_price_data[symbol] = {
                                        'previous_close': closes.iloc[0],
                                        'current_price': closes.iloc[0]
                                    }
                        except Exception:
                            continue
                            
        except Exception as e:
            logger.warning(f"Failed to fetch batch {i//batch_size + 1}: {e}")
            continue

    # Build final result
    results = []
    for _, row in df.iterrows():
        symbol = row['YahooSymbol']
        result = {
            'SYMBOL': row['SYMBOL'],
            'NAME OF COMPANY': row['NAME OF COMPANY'],
            'SERIES': row['SERIES'],
            'FACE VALUE': row['FACE VALUE'],
            'YahooSymbol': symbol
        }
        
        # Add price data
        if symbol in all_price_data:
            price_data = all_price_data[symbol]
            result.update({
                'Last Price': round(price_data['current_price'], 2),
                'Previous Close': round(price_data['previous_close'], 2),
                'P&L': round(price_data['current_price'] - price_data['previous_close'], 2),
                'Percent Change': round(
                    ((price_data['current_price'] - price_data['previous_close']) / 
                     price_data['previous_close']) * 100, 2
                )
            })
        else:
            # No price data available
            result.update({
                'Last Price': 0,
                'Previous Close': 0,
                'P&L': 0,
                'Percent Change': 0
            })
        
        # Add market cap from cache
        result['Market Cap'] = market_cap_cache.get(symbol, 0)
        
        results.append(result)

    return clean_dataframe(pd.DataFrame(results)).to_dict(orient="records")

# ================== COMPREHENSIVE DATA & PREDICTION ==================
def safe_str(value):
    return str(value) if value is not None else "N/A"

def get_comprehensive_stock_data(symbol: str) -> Dict[str, Any]:
    try:
        ticker = yf.Ticker(symbol)
        info = ticker.info
        hist = ticker.history(period="5d")
        
        return {
            "symbol": symbol,
            "basic_info": {
                k: safe_str(info.get(v)) for k, v in {
                    "company_name": "longName",
                    "sector": "sector", 
                    "industry": "industry",
                    "country": "country",
                    "website": "website",
                    "business_summary": "longBusinessSummary",
                    "employees": "fullTimeEmployees",
                    "exchange": "exchange",
                    "currency": "currency"
                }.items()
            },
            "price_data": {
                **{k: safe_str(info.get(v)) for k, v in {
                    "current_price": "currentPrice",
                    "previous_close": "previousClose",
                    "open": "open",
                    "day_low": "dayLow",
                    "day_high": "dayHigh",
                    "52_week_low": "fiftyTwoWeekLow",
                    "52_week_high": "fiftyTwoWeekHigh",
                    "volume": "volume",
                    "avg_volume": "averageVolume",
                    "market_cap": "marketCap"
                }.items()},
                "historical_5d": hist.to_dict('records') if not hist.empty else []
            },
            "valuation_metrics": {
                k: safe_str(info.get(v)) for k, v in {
                    "pe_ratio": "trailingPE",
                    "forward_pe": "forwardPE",
                    "peg_ratio": "pegRatio",
                    "price_to_book": "priceToBook",
                    "price_to_sales": "priceToSalesTrailing12Months",
                    "enterprise_value": "enterpriseValue",
                    "ev_to_revenue": "enterpriseToRevenue",
                    "ev_to_ebitda": "enterpriseToEbitda"
                }.items()
            }
        }
    except Exception as e:
        logger.error(f"Error fetching comprehensive data for {symbol}: {e}")
        return {"error": str(e), "symbol": symbol}

    
def predict_stock(ticker: str) -> Dict[str, Any]:
    """Predict stock movement using ML model with comprehensive error handling"""
    try:
        # Get the directory where the script is located
        script_dir = os.path.dirname(os.path.abspath(__file__))
        scaler_path = os.path.join(script_dir, "scaler.joblib")
        model_path = os.path.join(script_dir, "lgb_5day_model.joblib")
        
        # Load model files with absolute paths
        if not all(os.path.exists(f) for f in [scaler_path, model_path]):
            missing_files = [f for f in [scaler_path, model_path] if not os.path.exists(f)]
            logger.error(f"Missing model files: {missing_files}")
            raise FileNotFoundError(f"ML model files not found: {missing_files}")
            
        scaler = joblib.load(scaler_path)
        model = joblib.load(model_path)
        
        logger.info(f"Starting prediction for ticker: {ticker}")
        
        # Download data with explicit error handling
        try:
            df_raw = yf.download(ticker, period="5y", interval="1d", progress=False)
            logger.info(f"Downloaded data shape: {df_raw.shape}")
            logger.info(f"Downloaded data columns: {list(df_raw.columns)}")
        except Exception as download_error:
            logger.error(f"Data download failed: {download_error}")
            raise RuntimeError(f"Failed to download data for {ticker}: {download_error}")
        
        if df_raw.empty:
            raise RuntimeError(f"No data found for ticker {ticker}")
        
        # Reset index to make sure it's clean
        df_raw = df_raw.reset_index()
        logger.info(f"Data shape after reset_index: {df_raw.shape}")
        
        # Handle multi-level columns if present (common issue with yfinance)
        if hasattr(df_raw.columns, 'nlevels') and df_raw.columns.nlevels > 1:
            # Flatten multi-level columns
            df_raw.columns = [col[0] if isinstance(col, tuple) else col for col in df_raw.columns]
            logger.info(f"Flattened columns: {list(df_raw.columns)}")
        
        # Ensure we have the required columns
        required_cols = ['Open', 'High', 'Low', 'Close', 'Volume']
        if not all(col in df_raw.columns for col in required_cols):
            logger.error(f"Missing columns. Available: {list(df_raw.columns)}")
            raise RuntimeError(f"Missing required columns for {ticker}")
        
        # Set Date as index if it exists
        if 'Date' in df_raw.columns:
            df_raw.set_index('Date', inplace=True)
        
        logger.info(f"Final data shape before feature computation: {df_raw.shape}")
        
        # Import and use compute_features function with error handling
        try:
            from computefeatures import compute_features
            df_feat = compute_features(df_raw)
            logger.info(f"Features computed successfully, shape: {df_feat.shape}")
        except Exception as feature_error:
            logger.error(f"Feature computation failed: {feature_error}")
            raise RuntimeError(f"Feature computation failed for {ticker}: {feature_error}")
        
        if df_feat.empty:
            raise RuntimeError("No features computed - empty DataFrame returned")
        
        # Prepare features for prediction
        try:
            # Remove target column if it exists
            feature_columns = [col for col in df_feat.columns if col != 'target']
            X_raw = df_feat[feature_columns].iloc[-1:].copy()
            
            logger.info(f"Features selected: {len(feature_columns)} columns")
            logger.info(f"Feature matrix shape: {X_raw.shape}")
            logger.info(f"Feature columns: {list(X_raw.columns)}")
            
            # Check for any remaining issues
            if X_raw.shape[0] != 1:
                raise RuntimeError(f"Expected 1 row for prediction, got {X_raw.shape[0]}")
            
            # Check for NaN values
            nan_cols = X_raw.columns[X_raw.isnull().iloc[0]].tolist()
            if nan_cols:
                logger.warning(f"NaN values found in columns: {nan_cols}")
                # Fill NaN with 0 or median (you might want to handle this differently)
                X_raw = X_raw.fillna(0)
            
            # Check for infinite values
            inf_mask = np.isinf(X_raw.values)
            if inf_mask.any():
                logger.warning("Infinite values found, replacing with 0")
                X_raw = X_raw.replace([np.inf, -np.inf], 0)
            
            # Convert to numpy array
            X_array = X_raw.values.astype(np.float64)
            logger.info(f"Numpy array shape: {X_array.shape}")
            
            if X_array.shape[1] == 0:
                raise RuntimeError("No features available for prediction")
                
        except Exception as prep_error:
            logger.error(f"Feature preparation failed: {prep_error}")
            raise RuntimeError(f"Feature preparation failed: {prep_error}")
        
        # Scale the features
        try:
            expected_features = getattr(scaler, 'n_features_in_', None)
            if expected_features and X_array.shape[1] != expected_features:
                logger.error(f"Feature count mismatch: got {X_array.shape[1]}, expected {expected_features}")
                raise RuntimeError(f"Feature count mismatch: model expects {expected_features} features, got {X_array.shape[1]}")
            
            X_scaled = scaler.transform(X_array)
            logger.info(f"Features scaled successfully, shape: {X_scaled.shape}")
            
        except Exception as scale_error:
            logger.error(f"Feature scaling failed: {scale_error}")
            raise RuntimeError(f"Feature scaling failed: {scale_error}")
        
        # Make prediction
        try:
            prob_array = model.predict_proba(X_scaled)
            logger.info(f"Prediction completed, probability array shape: {prob_array.shape}")
            
            if prob_array.shape[1] < 2:
                raise RuntimeError("Model did not return probabilities for both classes")
            
            prob_up = float(prob_array[0, 1])  # Probability for class 1 (up)
            logger.info(f"Probability of price going up: {prob_up}")
            
        except Exception as pred_error:
            logger.error(f"Model prediction failed: {pred_error}")
            raise RuntimeError(f"Model prediction failed: {pred_error}")
        
        # Determine signal
        if prob_up >= PREDICTION_THRESHOLDS['STRONG_BUY']:
            signal = "BUY_STRONG"
        elif prob_up >= PREDICTION_THRESHOLDS['BUY']:
            signal = "BUY"
        elif prob_up >= PREDICTION_THRESHOLDS['SELL']:
            signal = "HOLD"
        else:
            signal = "SELL"
        
        return {
            'ticker': ticker,
            'date': str(X_raw.index[0]) if len(X_raw.index) > 0 else datetime.now().date().isoformat(),
            'probability': prob_up,
            'signal': signal,
            'confidence': abs(prob_up - 0.5) * 2,  # Convert to 0-1 confidence scale
            'debug_info': {
                'raw_data_shape': df_raw.shape,
                'features_shape': df_feat.shape,
                'final_features_count': X_array.shape[1],
                'model_expected_features': getattr(scaler, 'n_features_in_', 'unknown'),
                'feature_names': list(X_raw.columns)[:10]  # First 10 for brevity
            }
        }
        
    except Exception as e:
        logger.error(f"Prediction error for {ticker}: {e}")
        raise HTTPException(status_code=500, detail=f"Prediction failed for {ticker}: {str(e)}")
# ================== LIFESPAN MANAGEMENT ==================

@asynccontextmanager
async def lifespan(app: fastapi.FastAPI):
    global latest_data_cache
    
    logger.info("🚀 Starting application...")
    
    # Initialize database and load cached data
    init_database()
    load_market_caps_from_db()
    
    # Fetch market caps if needed
    if should_fetch_market_caps():
        logger.info("📊 Fetching market caps...")
        try:
            df = pd.read_csv(CSV_PATH)
            df.columns = df.columns.str.strip()
            symbols = df["SYMBOL"].apply(
                lambda x: "^NSEI" if x == "NIFTY50" else f"{x}.NS"
            ).tolist()
            
            market_caps = await asyncio.to_thread(fetch_market_caps_batch, symbols)
            if market_caps:
                market_cap_cache.update(market_caps)
                save_market_caps_to_db(market_caps)
                logger.info(f"✅ Fetched {len(market_caps)} market caps")
        except Exception as e:
            logger.error(f"❌ Market cap fetch failed: {e}")
    
    # Initial price fetch
    logger.info("💰 Fetching initial stock prices...")
    try:
        latest_data_cache = await asyncio.wait_for(
            asyncio.to_thread(fetch_latest_prices_optimized),
            timeout=300.0
        )
        valid_prices = len([r for r in latest_data_cache if r.get("Last Price", 0) > 0])
        logger.info(f"✅ Loaded {len(latest_data_cache)} stocks, {valid_prices} with prices")
    except Exception as e:
        logger.error(f"❌ Initial price fetch failed: {e}")
        latest_data_cache = []
    
    # Start periodic updates for weekdays
    task = None
    if datetime.now(MARKET_TZ).weekday() < 5:
        async def periodic_update():
            global latest_data_cache
            while True:
                try:
                    if is_market_open():
                        logger.info("🔄 Periodic update...")
                        latest_data_cache = await asyncio.wait_for(
                            asyncio.to_thread(fetch_latest_prices_optimized),
                            timeout=180.0
                        )
                        logger.info("✅ Cache updated")
                    await asyncio.sleep(300)  # 5 minutes
                except asyncio.CancelledError:
                    break
                except Exception as e:
                    logger.error(f"❌ Periodic update error: {e}")
                    await asyncio.sleep(300)
        
        task = asyncio.create_task(periodic_update())
        logger.info("🔄 Started periodic updates")
    
    yield
    
    # Cleanup
    if task:
        task.cancel()
        try:
            await task
        except asyncio.CancelledError:
            pass
    
    logger.info("✅ Application shutdown complete")

app.router.lifespan_context = lifespan

# ================== API ENDPOINTS ==================

@app.get("/")
async def root():
    return {"message": "Optimized Stock Data API", "version": "3.0.0"}

@app.get("/health")
async def health_check():
    valid_prices = len([r for r in latest_data_cache if r.get("Last Price", 0) > 0])
    return {
        "status": "healthy",
        "cache_size": len(latest_data_cache),
        "valid_prices": valid_prices,
        "market_cap_cache_size": len(market_cap_cache),
        "market_status": "OPEN" if is_market_open() else "CLOSED",
        "last_update": datetime.now(MARKET_TZ).isoformat()
    }

@app.get("/allstocks")
def get_allstocks():
    """Get basic price data for all stocks"""
    valid_prices = len([r for r in latest_data_cache if r.get("Last Price", 0) > 0])
    logger.info(f"📊 Returning {len(latest_data_cache)} stocks, {valid_prices} with prices")
    return jsonable_encoder(latest_data_cache)

@app.get("/stock/{symbol}/comprehensive")
async def get_comprehensive_stock(symbol: str):
    """Get comprehensive data for a single stock"""
    yahoo_symbol = symbol if symbol.endswith('.NS') else f"{symbol}.NS"
    data = await asyncio.to_thread(get_comprehensive_stock_data, yahoo_symbol)
    return jsonable_encoder(data)

@app.get("/stock/{symbol}/news")
async def get_stock_news(symbol: str, limit: int = Query(10, description="Number of news items")):
    """Get latest news for a stock"""
    yahoo_symbol = symbol if symbol.endswith('.NS') else f"{symbol}.NS"
    try:
        ticker = yf.Ticker(yahoo_symbol)
        news = ticker.news
        return jsonable_encoder({
            "symbol": yahoo_symbol,
            "news": news[:limit] if news else []
        })
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/prediction5d")
def get_prediction5d(ticker: str):
    """Get 5-day price prediction"""
    return predict_stock(ticker=ticker)

@app.post("/force-update")
async def force_update():
    """Force update stock data"""
    global latest_data_cache
    try:
        logger.info("🔄 Force update requested...")
        latest_data_cache = await asyncio.wait_for(
            asyncio.to_thread(fetch_latest_prices_optimized),
            timeout=180.0
        )
        valid_prices = len([r for r in latest_data_cache if r.get("Last Price", 0) > 0])
        return {
            "message": "Update completed successfully",
            "total_records": len(latest_data_cache),
            "valid_prices": valid_prices,
            "timestamp": datetime.now(MARKET_TZ).isoformat()
        }
    except asyncio.TimeoutError:
        raise HTTPException(status_code=408, detail="Update timed out")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Update failed: {e}")

@app.get("/market-status")
async def get_market_status():
    """Get current market status"""
    now = datetime.now(MARKET_TZ)
    return {
        "is_open": is_market_open(),
        "current_time": now.isoformat(),
        "timezone": str(MARKET_TZ),
        "market_open_time": MARKET_OPEN.isoformat(),
        "market_close_time": MARKET_CLOSE.isoformat(),
        "weekday": now.weekday(),
        "is_weekend": now.weekday() >= 5
    }

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("FetchingStocks:app", host="0.0.0.0", port=8000, reload=False)

# Usage:
# uvicorn FetchingStocks:app --host 0.0.0.0 --port 8000
