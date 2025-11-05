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
import fastapi
import pandas as pd
import yfinance as yf
import numpy as np
import joblib
import pytz
from fastapi import HTTPException, Query
from fastapi.encoders import jsonable_encoder
from pydantic import BaseModel
from sklearn.ensemble import RandomForestRegressor, IsolationForest
from sklearn.preprocessing import StandardScaler
import warnings
warnings.filterwarnings('ignore')

# ================== CONFIGURATION ==================
CSV_PATH = "/Users/zubairahmed/Desktop/FynVerse/Backend/EQUITY_L.csv"
MARKET_CAP_EXCEL_PATH = "/Users/zubairahmed/Desktop/FynVerse/Backend/Average MCAP_July2024ToDecember 2024 (1).xlsx"
MARKET_TZ = pytz.timezone('Asia/Kolkata')
MARKET_OPEN = time(9, 15)
MARKET_CLOSE = time(15, 30)

# Global cache and locks
latest_data_cache = []
market_cap_cache = {}
db_lock = Lock()

# Setup logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# ================== SECTOR GROWTH RATES (Research-Based) ==================

SECTOR_GROWTH_RATES = {
    'Technology': 12.5,
    'Consumer Cyclical': 15.0,
    'Energy': 8.0,
    'Utilities': 7.5,
    'Financial Services': 10.0,
    'Healthcare': 11.0,
    'Industrials': 9.0,
    'Basic Materials': 8.5,
    'Communication Services': 10.5,
    'Consumer Defensive': 8.0,
    'Real Estate': 9.5,
    'Renewable Energy': 20.0,
    'Electric Vehicles': 25.0,
    'Fintech': 18.0,
}

def get_sector_growth_rate(sector: str) -> float:
    """Get expected CAGR for a sector"""
    return SECTOR_GROWTH_RATES.get(sector, 10.0)

def calculate_peg_ratio(pe_ratio: float, earnings_growth: float) -> Optional[float]:
    """PEG Ratio = P/E / Earnings Growth Rate"""
    if earnings_growth and earnings_growth > 0:
        return pe_ratio / (earnings_growth * 100)
    return None

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

# ================== MARKET CAP FROM EXCEL ==================

def load_market_caps_from_excel() -> Dict[str, float]:
    """Load market caps from Excel file"""
    global market_cap_cache
    try:
        df = pd.read_excel(MARKET_CAP_EXCEL_PATH)
        df.columns = df.columns.str.strip()
        
        symbol_col = df.columns[1]
        mcap_col = df.columns[3]
        
        def parse_indian_number(value):
            if pd.isna(value):
                return None
            try:
                if isinstance(value, str):
                    cleaned = value.replace(',', '')
                    return float(cleaned)
                return float(value)
            except:
                return None
        
        market_cap_dict = {}
        for _, row in df.iterrows():
            symbol = str(row[symbol_col]).strip()
            mcap_value = parse_indian_number(row[mcap_col])
            
            if symbol and mcap_value is not None:
                market_cap_dict[symbol] = mcap_value
                market_cap_dict[f"{symbol}.NS"] = mcap_value
        
        if "NIFTY50" in market_cap_dict:
            market_cap_dict["^NSEI"] = market_cap_dict["NIFTY50"]
        
        market_cap_cache = market_cap_dict
        logger.info(f"✅ Loaded {len(market_cap_dict)} market caps from Excel file")
        return market_cap_dict
        
    except FileNotFoundError:
        logger.error(f"❌ Excel file not found at: {MARKET_CAP_EXCEL_PATH}")
        return {}
    except Exception as e:
        logger.error(f"❌ Error loading market caps from Excel: {e}")
        return {}

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

def save_excel_to_db():
    """Save Excel market caps to database as backup"""
    if not market_cap_cache:
        return
    
    try:
        with sqlite3.connect('market_data.db') as conn:
            today = datetime.now().date()
            data = [(symbol, cap, today) for symbol, cap in market_cap_cache.items()]
            conn.executemany('''
                INSERT OR REPLACE INTO market_caps 
                (symbol, market_cap, last_updated) VALUES (?, ?, ?)
            ''', data)
            logger.info(f"💾 Saved {len(data)} market caps to database")
    except Exception as e:
        logger.error(f"❌ Error saving to database: {e}")

# ================== DATA FETCHING ==================

def fetch_latest_prices_optimized() -> List[Dict[str, Any]]:
    """Optimized function to fetch latest prices"""
    df = pd.read_csv(CSV_PATH)
    df.columns = df.columns.str.strip()
    df = df[["SYMBOL", "NAME OF COMPANY", "SERIES", "FACE VALUE"]]
    df['YahooSymbol'] = np.where(
        df['SYMBOL'] == "NIFTY50", 
        "^NSEI", 
        df['SYMBOL'] + ".NS"
    )

    batch_size = 100
    all_price_data = {}
    
    for i in range(0, len(df), batch_size):
        batch_symbols = df['YahooSymbol'][i:i+batch_size].tolist()
        try:
            data = yf.download(batch_symbols, period="2d", interval="1d", 
                            group_by='ticker' if len(batch_symbols) > 1 else None,
                            progress=False)
            
            if not data.empty:
                if len(batch_symbols) == 1:
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

    results = []
    for _, row in df.iterrows():
        symbol = row['YahooSymbol']
        base_symbol = row['SYMBOL']
        
        result = {
            'SYMBOL': base_symbol,
            'NAME OF COMPANY': row['NAME OF COMPANY'],
            'SERIES': row['SERIES'],
            'FACE VALUE': row['FACE VALUE'],
            'YahooSymbol': symbol
        }
        
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
            result.update({
                'Last Price': 0,
                'Previous Close': 0,
                'P&L': 0,
                'Percent Change': 0
            })
        
        mcap = market_cap_cache.get(symbol) or market_cap_cache.get(base_symbol)
        result['Market Cap'] = mcap if mcap is not None else "N/A"
        
        results.append(result)

    valid_prices = sum(1 for r in results if r.get('Last Price', 0) > 0)
    total_stocks = len(results)
    success_rate = (valid_prices / total_stocks * 100) if total_stocks > 0 else 0
    
    if success_rate < 95:
        logger.warning(f"⚠️ Only {success_rate:.1f}% stocks have prices. Keeping old cache.")
        return None
    
    logger.info(f"✅ {success_rate:.1f}% stocks have valid prices. Updating cache.")
    return clean_dataframe(pd.DataFrame(results)).to_dict(orient="records")

# ================== CONTEXT-AWARE P/E ANALYSIS ==================

def assess_pe_with_context(
    symbol: str,
    pe_ratio: float,
    sector: str,
    revenue_growth: Optional[float] = None,
    earnings_growth: Optional[float] = None,
    profit_margin: Optional[float] = None,
    roe: Optional[float] = None
) -> Dict[str, Any]:
    """
    Research-based P/E assessment considering sector growth and fundamentals.
    """
    
    if not pe_ratio or pe_ratio <= 0:
        return {
            "score": 50,
            "grade": "N/A",
            "assessment": "No valid P/E ratio",
            "reasoning": []
        }
    
    sector_cagr = get_sector_growth_rate(sector)
    peg_ratio = calculate_peg_ratio(pe_ratio, earnings_growth)
    
    score = 0
    reasoning = []
    
    # 1. PEG RATIO ANALYSIS (40 points)
    if peg_ratio:
        if peg_ratio < 1.0:
            score += 40
            reasoning.append({
                "type": "positive",
                "message": f"Undervalued: PEG {peg_ratio:.2f} suggests growth justifies P/E {pe_ratio:.1f}"
            })
        elif peg_ratio <= 2.0:
            score += 30
            reasoning.append({
                "type": "neutral",
                "message": f"Fair value: PEG {peg_ratio:.2f} indicates reasonable pricing"
            })
        elif peg_ratio <= 3.0:
            score += 15
            reasoning.append({
                "type": "warning",
                "message": f"Stretched: PEG {peg_ratio:.2f} suggests premium pricing"
            })
        else:
            score += 5
            reasoning.append({
                "type": "negative",
                "message": f"Overvalued: PEG {peg_ratio:.2f}, P/E {pe_ratio:.1f} not supported by growth"
            })
    else:
        if pe_ratio < sector_cagr * 1.5:
            score += 25
        else:
            score += 10
    
    # 2. FUNDAMENTAL STRENGTH (30 points)
    if revenue_growth and revenue_growth > 0.20:
        score += 15
        reasoning.append({
            "type": "positive",
            "message": f"Strong {revenue_growth*100:.1f}% revenue growth supports valuation"
        })
    elif revenue_growth and revenue_growth > 0.10:
        score += 10
    elif revenue_growth and revenue_growth < 0:
        score -= 10
        reasoning.append({
            "type": "negative",
            "message": f"Declining revenue raises concerns"
        })
    
    if profit_margin and profit_margin > 0.15:
        score += 10
    elif profit_margin and profit_margin < 0:
        score -= 10
        reasoning.append({
            "type": "negative",
            "message": "Company unprofitable"
        })
    
    if roe and roe > 0.15:
        score += 5
    
    # 3. SECTOR-SPECIFIC ADJUSTMENT (30 points)
    if sector in ['Renewable Energy', 'Electric Vehicles', 'Fintech', 'Technology']:
        if pe_ratio < 40:
            score += 30
            reasoning.append({
                "type": "positive",
                "message": f"High P/E justified for high-growth {sector} sector"
            })
        elif pe_ratio < 60:
            score += 20
        else:
            score += 10
            reasoning.append({
                "type": "warning",
                "message": f"Very high P/E {pe_ratio:.1f} even for {sector} - speculative"
            })
    elif sector in ['Utilities', 'Basic Materials', 'Consumer Defensive']:
        if pe_ratio < 20:
            score += 30
        elif pe_ratio < 30:
            score += 15
        else:
            score += 5
            reasoning.append({
                "type": "warning",
                "message": f"High P/E {pe_ratio:.1f} unusual for mature {sector} sector"
            })
    else:
        if pe_ratio < 25:
            score += 25
        elif pe_ratio < 35:
            score += 15
        else:
            score += 5
    
    score = max(0, min(100, score))
    
    if score >= 80:
        grade = "A"
        assessment = "Strong Buy - High P/E justified by growth and fundamentals"
    elif score >= 60:
        grade = "B"
        assessment = "Buy - P/E reasonable considering growth prospects"
    elif score >= 40:
        grade = "C"
        assessment = "Hold - P/E elevated but may be justified"
    elif score >= 20:
        grade = "D"
        assessment = "Caution - High P/E with weak fundamentals"
    else:
        grade = "F"
        assessment = "Avoid - Speculative valuation"
    
    return {
        "score": round(score, 1),
        "grade": grade,
        "assessment": assessment,
        "pe_ratio": round(pe_ratio, 2),
        "peg_ratio": round(peg_ratio, 2) if peg_ratio else None,
        "sector_cagr": sector_cagr,
        "reasoning": reasoning,
        "methodology": "PEG-adjusted P/E with sector-specific growth expectations"
    }

# ================== COMPREHENSIVE STOCK DATA ==================

def safe_str(value):
    return str(value) if value is not None else "N/A"

def get_comprehensive_stock_data(symbol: str) -> Dict[str, Any]:
    try:
        ticker = yf.Ticker(symbol)
        info = ticker.info
        hist = ticker.history(period="5d")
        
        base_symbol = symbol.replace('.NS', '').replace('^', '')
        cached_mcap = market_cap_cache.get(symbol) or market_cap_cache.get(base_symbol)
        
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
                    "avg_volume": "averageVolume"
                }.items()},
                "market_cap": cached_mcap if cached_mcap is not None else "N/A (New Stock)",
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

# ================== STOCK ANALYSIS WITH RESEARCH-BASED P/E ==================

def analyze_stock_comprehensive(ticker: str) -> Dict[str, Any]:
    """Comprehensive stock analysis with research-based P/E valuation"""
    try:
        yahoo_symbol = ticker if ticker.endswith('.NS') else f"{ticker}.NS"
        base_symbol = yahoo_symbol.replace('.NS', '')
        
        stock = yf.Ticker(yahoo_symbol)
        info = stock.info
        df = yf.download(yahoo_symbol, period="1y", interval="1d", progress=False)
        
        if isinstance(df.columns, pd.MultiIndex):
            df.columns = df.columns.get_level_values(0)
        
        if df.empty:
            raise ValueError(f"No data available for {ticker}")
        
        current_price = float(df['Close'].iloc[-1])
        
        # Technical indicators
        df['ma_20'] = df['Close'].rolling(20).mean()
        df['ma_50'] = df['Close'].rolling(50).mean()
        df['ma_200'] = df['Close'].rolling(200).mean()
        
        ma_20 = float(df['ma_20'].iloc[-1]) if not pd.isna(df['ma_20'].iloc[-1]) else None
        ma_50 = float(df['ma_50'].iloc[-1]) if not pd.isna(df['ma_50'].iloc[-1]) else None
        ma_200 = float(df['ma_200'].iloc[-1]) if len(df) >= 200 and not pd.isna(df['ma_200'].iloc[-1]) else None
        
        # RSI
        delta = df['Close'].diff()
        gain = delta.where(delta > 0, 0).rolling(14).mean()
        loss = -delta.where(delta < 0, 0).rolling(14).mean()
        rs = gain / (loss + 1e-9)
        rsi = (100 - (100 / (1 + rs))).iloc[-1]
        
        # Volatility
        returns_data = df['Close'].pct_change().dropna()
        volatility_60d = float(returns_data.rolling(60).std().iloc[-1] * np.sqrt(252) * 100) if len(returns_data) >= 60 else None
        
        # 52-week range
        high_52w = float(df['High'].rolling(252).max().iloc[-1]) if len(df) >= 252 else float(df['High'].max())
        low_52w = float(df['Low'].rolling(252).min().iloc[-1]) if len(df) >= 252 else float(df['Low'].min())
        position_in_range = ((current_price - low_52w) / (high_52w - low_52w) * 100) if high_52w != low_52w else 50.0
        
        # Returns
        returns = {}
        periods = {'1_week': 5, '1_month': 21, '3_month': 63, '6_month': 126}
        for name, days in periods.items():
            if len(df) > days:
                ret = df['Close'].pct_change(days).iloc[-1]
                returns[name] = float(ret * 100) if not pd.isna(ret) else None
            else:
                returns[name] = None
        
        # Volume
        avg_volume = float(df['Volume'].rolling(20).mean().iloc[-1]) if len(df) >= 20 else float(df['Volume'].mean())
        recent_volume = float(df['Volume'].iloc[-1])
        volume_ratio = recent_volume / avg_volume if avg_volume > 0 else 1.0
        
        # Fundamentals
        cached_mcap = market_cap_cache.get(yahoo_symbol) or market_cap_cache.get(base_symbol)
        
        sector = info.get('sector', 'Unknown')
        pe_ratio = info.get('trailingPE')
        revenue_growth = info.get('revenueGrowth')
        earnings_growth = info.get('earningsGrowth')
        profit_margin = info.get('profitMargins')
        roe = info.get('returnOnEquity')
        
        # CONTEXT-AWARE P/E ASSESSMENT
        pe_assessment = assess_pe_with_context(
            symbol=ticker,
            pe_ratio=pe_ratio if pe_ratio else 0,
            sector=sector,
            revenue_growth=revenue_growth,
            earnings_growth=earnings_growth,
            profit_margin=profit_margin,
            roe=roe
        )
        
        fundamentals = {
            'pe_ratio': pe_ratio,
            'forward_pe': info.get('forwardPE'),
            'pb_ratio': info.get('priceToBook'),
            'ps_ratio': info.get('priceToSalesTrailing12Months'),
            'debt_to_equity': info.get('debtToEquity'),
            'current_ratio': info.get('currentRatio'),
            'roe': roe,
            'profit_margin': profit_margin,
            'revenue_growth': revenue_growth,
            'earnings_growth': earnings_growth,
            'dividend_yield': info.get('dividendYield'),
            'payout_ratio': info.get('payoutRatio'),
            'beta': info.get('beta'),
            'market_cap': cached_mcap if cached_mcap is not None else "N/A (New Stock)"
        }
        
        # Scoring with research-based P/E
        score = 0
        max_score = 0
        signals = []
        
        # Technical (2 points)
        max_score += 2
        if ma_20 and ma_50 and current_price > ma_20 and ma_20 > ma_50:
            score += 2
            signals.append({"type": "positive", "message": "Strong uptrend"})
        elif ma_20 and ma_50 and current_price < ma_20 and ma_20 < ma_50:
            signals.append({"type": "negative", "message": "Downtrend"})
        else:
            score += 1
            signals.append({"type": "neutral", "message": "Mixed technical signals"})
        
        # RESEARCH-BASED P/E VALUATION (3 points)
        max_score += 3
        pe_score_normalized = (pe_assessment['score'] / 100) * 3
        score += pe_score_normalized
        
        for reason in pe_assessment['reasoning']:
            signals.append(reason)
        
        # Financial health (2 points)
        max_score += 2
        debt = fundamentals['debt_to_equity']
        if debt and debt < 50:
            score += 2
            signals.append({"type": "positive", "message": "Strong balance sheet"})
        elif debt and debt < 100:
            score += 1
        elif debt:
            signals.append({"type": "warning", "message": "High debt levels"})
        
        # Growth (2 points)
        max_score += 2
        if earnings_growth and earnings_growth > 0.15:
            score += 2
            signals.append({"type": "positive", "message": f"Strong earnings growth ({earnings_growth*100:.1f}%)"})
        elif earnings_growth and earnings_growth > 0:
            score += 1
        elif earnings_growth:
            signals.append({"type": "negative", "message": "Declining earnings"})
        
        # RSI signal
        if rsi > 70:
            signals.append({"type": "warning", "message": f"Overbought (RSI: {rsi:.1f})"})
        elif rsi < 30:
            signals.append({"type": "warning", "message": f"Oversold (RSI: {rsi:.1f})"})
        
        score_pct = (score / max_score * 100) if max_score > 0 else 0
        
        if score_pct >= 75:
            overall_assessment = "Strong fundamentals with justified valuation"
            recommendation = "POSITIVE"
        elif score_pct >= 50:
            overall_assessment = "Mixed signals - monitor closely"
            recommendation = "NEUTRAL"
        else:
            overall_assessment = "Multiple concerns present"
            recommendation = "CAUTIOUS"
        
        return {
            "ticker": ticker,
            "company_name": info.get('longName', ticker),
            "sector": sector,
            "industry": info.get('industry', 'N/A'),
            "timestamp": pd.Timestamp.now().isoformat(),
            "price_data": {
                "current_price": round(current_price, 2),
                "ma_20": round(ma_20, 2) if ma_20 else None,
                "ma_50": round(ma_50, 2) if ma_50 else None,
                "ma_200": round(ma_200, 2) if ma_200 else None,
                "52_week_high": round(high_52w, 2),
                "52_week_low": round(low_52w, 2),
                "position_in_52w_range": round(position_in_range, 1),
                "rsi": round(rsi, 1) if not pd.isna(rsi) else None
            },
            "performance": {
                "1_week": round(returns['1_week'], 2) if returns['1_week'] else None,
                "1_month": round(returns['1_month'], 2) if returns['1_month'] else None,
                "3_month": round(returns['3_month'], 2) if returns['3_month'] else None,
                "6_month": round(returns['6_month'], 2) if returns['6_month'] else None
            },
            "fundamentals": {
                "pe_ratio": round(fundamentals['pe_ratio'], 2) if fundamentals['pe_ratio'] else None,
                "forward_pe": round(fundamentals['forward_pe'], 2) if fundamentals['forward_pe'] else None,
                "pb_ratio": round(fundamentals['pb_ratio'], 2) if fundamentals['pb_ratio'] else None,
                "debt_to_equity": round(fundamentals['debt_to_equity'], 1) if fundamentals['debt_to_equity'] else None,
                "roe": round(fundamentals['roe'] * 100, 1) if fundamentals['roe'] else None,
                "profit_margin": round(fundamentals['profit_margin'] * 100, 1) if fundamentals['profit_margin'] else None,
                "revenue_growth": round(fundamentals['revenue_growth'] * 100, 1) if fundamentals['revenue_growth'] else None,
                "earnings_growth": round(fundamentals['earnings_growth'] * 100, 1) if fundamentals['earnings_growth'] else None,
                "dividend_yield": round(fundamentals['dividend_yield'] * 100, 2) if fundamentals['dividend_yield'] else None,
                "beta": round(fundamentals['beta'], 2) if fundamentals['beta'] else None,
                "market_cap": fundamentals['market_cap']
            },
            "valuation_analysis": pe_assessment,
            "risk_metrics": {
                "volatility_60d_annualized": round(volatility_60d, 1) if volatility_60d else None,
                "volume_ratio": round(volume_ratio, 2),
                "avg_volume_20d": int(avg_volume)
            },
            "analysis": {
                "score": round(score, 2),
                "max_score": max_score,
                "score_percentage": round(score_pct, 1),
                "recommendation": recommendation,
                "overall_assessment": overall_assessment,
                "signals": signals
            },
            "methodology": {
                "approach": "Research-based P/E valuation integrated with technical and fundamental analysis",
                "pe_framework": "PEG-adjusted P/E with sector-specific growth rates",
                "research_basis": "High P/E acceptable when justified by growth + strong fundamentals",
                "reference": "Emerging sector valuation analysis (2024)"
            },
            "disclaimer": {
                "message": "This analysis is for informational purposes only and does NOT constitute financial advice.",
                "warnings": [
                    "Past performance does not guarantee future results",
                    "All investments carry risk of loss",
                    "This analysis may not account for recent news or events",
                    "Consult a qualified financial advisor before making investment decisions"
                ]
            }
        }
        
    except Exception as e:
        logger.error(f"Stock analysis error for {ticker}: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to analyze {ticker}: {str(e)}")

# ================== ML PORTFOLIO ANALYZER ==================

class MLPortfolioAnalyzer:
    """Portfolio analyzer with research-based P/E scoring"""
    
    def __init__(self):
        self.risk_model = None
        self.anomaly_detector = None
        self.scaler = StandardScaler()
        self.is_trained = False
        
    def calculate_context_aware_pe_score(self, holdings_data: List[Dict]) -> float:
        """Calculate portfolio P/E score using research-based methodology"""
        if not holdings_data:
            return 50.0
        
        pe_scores = []
        
        for holding in holdings_data:
            pe_ratio = holding.get('pe_ratio', 0)
            sector = holding.get('sector', 'Unknown')
            revenue_growth = holding.get('revenue_growth')
            earnings_growth = holding.get('earnings_growth')
            profit_margin = holding.get('profit_margin')
            roe = holding.get('roe')
            
            if not pe_ratio or pe_ratio <= 0:
                continue
            
            assessment = assess_pe_with_context(
                symbol=holding.get('symbol', ''),
                pe_ratio=pe_ratio,
                sector=sector,
                revenue_growth=revenue_growth,
                earnings_growth=earnings_growth,
                profit_margin=profit_margin,
                roe=roe
            )
            
            pe_scores.append(assessment['score'])
        
        return sum(pe_scores) / len(pe_scores) if pe_scores else 50.0
        
    def extract_ml_features(self, holdings_data: List[Dict]) -> np.ndarray:
        """Extract features including context-aware P/E"""
        if not holdings_data:
            return np.array([])
        
        total_value = sum(h['current_value'] for h in holdings_data)
        
        # Sector concentration
        sector_weights = {}
        for h in holdings_data:
            sector = h.get('sector', 'Unknown')
            weight = h['current_value'] / total_value
            sector_weights[sector] = sector_weights.get(sector, 0) + weight
        hhi = sum(w**2 for w in sector_weights.values())
        
        # Market cap distribution
        cap_distribution = {'Large': 0, 'Mid': 0, 'Small': 0}
        for h in holdings_data:
            cap_type = h.get('market_cap_category', 'Large')
            weight = h['current_value'] / total_value
            cap_distribution[cap_type] += weight
        
        # Beta statistics
        betas = [h['beta'] for h in holdings_data if h.get('beta')]
        avg_beta = np.mean(betas) if betas else 1.0
        std_beta = np.std(betas) if len(betas) > 1 else 0.0
        
        # Traditional P/E statistics
        pes = [h['pe_ratio'] for h in holdings_data if h.get('pe_ratio') and h['pe_ratio'] > 0]
        avg_pe = np.mean(pes) if pes else 20.0
        std_pe = np.std(pes) if len(pes) > 1 else 0.0
        
        # Context-aware P/E score
        context_pe_score = self.calculate_context_aware_pe_score(holdings_data)
        
        # Position concentration
        weights = sorted([h['current_value']/total_value for h in holdings_data])
        n = len(weights)
        gini = (2 * sum((i+1) * w for i, w in enumerate(weights))) / (n * sum(weights)) - (n+1)/n
        
        features = np.array([
            len(holdings_data),
            hhi,
            len(sector_weights),
            max(sector_weights.values()) if sector_weights else 0,
            cap_distribution['Large'],
            cap_distribution['Mid'],
            cap_distribution['Small'],
            avg_beta,
            std_beta,
            avg_pe,
            std_pe,
            gini,
            max(h['current_value']/total_value for h in holdings_data) if holdings_data else 0,
            min(h['current_value']/total_value for h in holdings_data) if holdings_data else 0,
            context_pe_score / 100
        ])
        
        return features.reshape(1, -1)
    
    def predict_risk_score(self, holdings_data: List[Dict]) -> Dict[str, Any]:
        """Predict future risk using ML model"""
        if not self.is_trained:
            return {
                "ml_risk_score": None,
                "confidence": 0,
                "prediction_available": False
            }
        
        features = self.extract_ml_features(holdings_data)
        features_scaled = self.scaler.transform(features)
        
        predicted_risk = self.risk_model.predict(features_scaled)[0]
        ml_risk_score = max(0, min(100, 100 - (predicted_risk * 100)))
        
        tree_predictions = np.array([
            tree.predict(features_scaled)[0] 
            for tree in self.risk_model.estimators_
        ])
        confidence = 100 - (np.std(tree_predictions) * 100)
        confidence = max(0, min(100, confidence))
        
        return {
            "ml_risk_score": round(ml_risk_score, 1),
            "predicted_volatility": round(predicted_risk, 3),
            "confidence": round(confidence, 1),
            "prediction_available": True
        }
    
    def detect_anomalies(self, holdings_data: List[Dict]) -> Dict[str, Any]:
        """Detect unusual portfolio characteristics"""
        if not self.anomaly_detector:
            return {
                "is_anomaly": False,
                "anomaly_score": 0,
                "warnings": []
            }
        
        features = self.extract_ml_features(holdings_data)
        features_scaled = self.scaler.transform(features)
        
        prediction = self.anomaly_detector.predict(features_scaled)[0]
        anomaly_score = self.anomaly_detector.score_samples(features_scaled)[0]
        
        normalized_score = max(0, min(100, (-anomaly_score + 0.5) * 100))
        
        warnings = []
        if prediction == -1:
            warnings.append("Portfolio structure is unusual compared to typical portfolios")
            if features[0][1] > 0.5:
                warnings.append("Extreme sector concentration detected")
            if features[0][7] > 1.5:
                warnings.append("Unusually high volatility exposure")
        
        return {
            "is_anomaly": bool(prediction == -1),
            "anomaly_score": round(normalized_score, 1),
            "warnings": warnings
        }
    
    def get_feature_importance(self) -> Dict[str, float]:
        """Get feature importance"""
        if not self.is_trained:
            return {}
        
        feature_names = [
            "holdings_count", "sector_hhi", "sector_count", "max_sector_weight",
            "large_cap_pct", "mid_cap_pct", "small_cap_pct",
            "avg_beta", "beta_std", "avg_pe", "pe_std",
            "gini_concentration", "max_position", "min_position",
            "context_pe_score"
        ]
        
        importances = self.risk_model.feature_importances_
        return dict(zip(feature_names, importances))
    
    def save_models(self, path_prefix: str = "ml_models/portfolio"):
        """Save trained models"""
        if self.is_trained:
            os.makedirs(os.path.dirname(path_prefix), exist_ok=True)
            joblib.dump(self.risk_model, f"{path_prefix}_risk.joblib")
            joblib.dump(self.scaler, f"{path_prefix}_scaler.joblib")
            if self.anomaly_detector:
                joblib.dump(self.anomaly_detector, f"{path_prefix}_anomaly.joblib")
            logger.info(f"✅ Models saved to {path_prefix}_*.joblib")
    
    def load_models(self, path_prefix: str = "ml_models/portfolio"):
        """Load trained models"""
        try:
            self.risk_model = joblib.load(f"{path_prefix}_risk.joblib")
            self.scaler = joblib.load(f"{path_prefix}_scaler.joblib")
            self.anomaly_detector = joblib.load(f"{path_prefix}_anomaly.joblib")
            self.is_trained = True
            logger.info("✅ Models loaded successfully with research-based P/E features")
        except FileNotFoundError:
            logger.warning("⚠️ Models not found. Train models first.")

# Global ML analyzer
ml_analyzer = MLPortfolioAnalyzer()

# ================== PORTFOLIO MODELS ==================

class PortfolioHolding(BaseModel):
    symbol: str
    quantity: int
    invested_amount: float

class PortfolioAnalysisRequest(BaseModel):
    holdings: List[PortfolioHolding]

# ================== PORTFOLIO ANALYSIS ==================

def categorize_market_cap(market_cap: float) -> str:
    """Categorize market cap"""
    if market_cap >= 20000:
        return 'Large'
    elif market_cap >= 5000:
        return 'Mid'
    else:
        return 'Small'

def calculate_portfolio_metrics(holdings_data: List[Dict]) -> Dict[str, Any]:
    """Portfolio analysis with research-based P/E scoring"""
    
    if not holdings_data:
        return {"error": "No holdings data provided"}
    
    total_value = sum(h['current_value'] for h in holdings_data)
    
    # 1. DIVERSIFICATION SCORE
    sector_weights = {}
    for holding in holdings_data:
        sector = holding.get('sector', 'Unknown')
        weight = holding['current_value'] / total_value
        sector_weights[sector] = sector_weights.get(sector, 0) + weight
    
    hhi = sum(w * w for w in sector_weights.values())
    diversification_base = (1 - hhi) * 100
    
    max_sector_weight = max(sector_weights.values()) if sector_weights else 0
    concentration_penalty = max(0, (max_sector_weight - 0.4) * 50) if max_sector_weight > 0.4 else 0
    sector_count_penalty = 0 if len(sector_weights) >= 3 else (3 - len(sector_weights)) * 15
    
    diversification_score = max(0, min(100, diversification_base - concentration_penalty - sector_count_penalty))
    
    # 2. RESEARCH-BASED P/E ANALYSIS
    pe_scores = []
    pe_details = []
    
    for holding in holdings_data:
        pe_ratio = holding.get('pe_ratio')
        sector = holding.get('sector', 'Unknown')
        
        if not pe_ratio or pe_ratio <= 0:
            continue
        
        assessment = assess_pe_with_context(
            symbol=holding.get('symbol', ''),
            pe_ratio=pe_ratio,
            sector=sector,
            revenue_growth=holding.get('revenue_growth'),
            earnings_growth=holding.get('earnings_growth'),
            profit_margin=holding.get('profit_margin'),
            roe=holding.get('roe')
        )
        
        pe_scores.append(assessment['score'])
        pe_details.append({
            'symbol': holding.get('symbol'),
            'pe_ratio': pe_ratio,
            'grade': assessment['grade'],
            'assessment': assessment['assessment']
        })
    
    pe_rating_score = sum(pe_scores) / len(pe_scores) if pe_scores else 50
    
    # 3. RISK SCORE
    betas = [h['beta'] for h in holdings_data if h.get('beta')]
    
    if betas:
        avg_beta = sum(betas) / len(betas)
        
        if avg_beta <= 0.8:
            beta_score = 90
        elif avg_beta <= 1.0:
            beta_score = 75
        elif avg_beta <= 1.2:
            beta_score = 60
        else:
            beta_score = 40
        
        stock_weights = [h['current_value'] / total_value for h in holdings_data]
        max_stock_weight = max(stock_weights)
        
        if max_stock_weight <= 0.25:
            concentration_score = 100
        elif max_stock_weight <= 0.35:
            concentration_score = 70
        else:
            concentration_score = 50
        
        risk_score = beta_score * 0.6 + concentration_score * 0.4
    else:
        avg_beta = 1.0
        risk_score = 60
    
    # 4. ALLOCATION QUALITY
    stock_weights = [h['current_value'] / total_value for h in holdings_data]
    
    balance_score = 0
    for weight in stock_weights:
        if 0.15 <= weight <= 0.30:
            balance_score += 20
        elif 0.10 <= weight <= 0.35:
            balance_score += 15
        elif 0.05 <= weight <= 0.40:
            balance_score += 10
        else:
            balance_score += 5
    
    balance_score = balance_score / len(holdings_data)
    
    holding_count = len(holdings_data)
    if 8 <= holding_count <= 15:
        count_score = 30
    elif 5 <= holding_count <= 20:
        count_score = 20
    else:
        count_score = 10
    
    allocation_score = min(100, balance_score + count_score)
    
    # 5. MARKET CAP DISTRIBUTION
    cap_weights = {'Large': 0, 'Mid': 0, 'Small': 0}
    
    for holding in holdings_data:
        cap_type = holding.get('market_cap_category', 'Large')
        weight = holding['current_value'] / total_value
        cap_weights[cap_type] = cap_weights.get(cap_type, 0) + weight
    
    cap_score = 0
    
    if 0.6 <= cap_weights['Large'] <= 0.8:
        cap_score += 40
    elif 0.5 <= cap_weights['Large'] <= 0.9:
        cap_score += 30
    else:
        cap_score += 20
    
    if 0.15 <= cap_weights['Mid'] <= 0.3:
        cap_score += 30
    elif 0.1 <= cap_weights['Mid'] <= 0.4:
        cap_score += 20
    else:
        cap_score += 10
    
    if 0.05 <= cap_weights['Small'] <= 0.15:
        cap_score += 30
    else:
        cap_score += 15
    
    market_cap_score = cap_score
    
    # 6. OVERALL RATING
    overall_score = (
        diversification_score * 0.25 +
        pe_rating_score * 0.20 +
        risk_score * 0.25 +
        allocation_score * 0.15 +
        market_cap_score * 0.15
    )
    
    if overall_score >= 80:
        grade = 'A'
        assessment = 'Excellent'
    elif overall_score >= 70:
        grade = 'B'
        assessment = 'Good'
    elif overall_score >= 60:
        grade = 'C'
        assessment = 'Average'
    elif overall_score >= 50:
        grade = 'D'
        assessment = 'Below Average'
    else:
        grade = 'F'
        assessment = 'Needs Improvement'
    
    # Generate insights
    insights = []
    recommendations = []
    
    if diversification_score < 60:
        insights.append({
            "type": "warning",
            "category": "Diversification",
            "message": f"Portfolio concentrated in {len(sector_weights)} sector(s)"
        })
        recommendations.append("Consider adding stocks from different sectors")
    
    if max_sector_weight > 0.4:
        top_sector = max(sector_weights, key=sector_weights.get)
        insights.append({
            "type": "warning",
            "category": "Sector Concentration",
            "message": f"{top_sector} sector represents {max_sector_weight*100:.1f}% of portfolio"
        })
        recommendations.append(f"Reduce {top_sector} exposure to below 40%")
    
    # P/E insights with research context
    if pe_rating_score < 50:
        insights.append({
            "type": "warning",
            "category": "Valuation",
            "message": "Portfolio contains stocks with weak P/E fundamentals"
        })
        recommendations.append("Review high P/E stocks - ensure growth justifies valuation")
    elif pe_rating_score >= 70:
        insights.append({
            "type": "positive",
            "category": "Valuation",
            "message": "Strong valuation profile with well-justified P/E ratios"
        })
    
    if avg_beta > 1.3:
        insights.append({
            "type": "warning",
            "category": "Risk",
            "message": f"High portfolio beta ({avg_beta:.2f}) indicates volatility"
        })
        recommendations.append("Add defensive stocks to reduce volatility")
    
    if holding_count < 5:
        insights.append({
            "type": "warning",
            "category": "Diversification",
            "message": f"Only {holding_count} holdings - under-diversified"
        })
        recommendations.append("Increase to 8-12 holdings for better diversification")
    
    if cap_weights['Large'] < 0.5:
        insights.append({
            "type": "warning",
            "category": "Risk",
            "message": f"Only {cap_weights['Large']*100:.1f}% in large caps"
        })
        recommendations.append("Increase large-cap allocation to 60-70%")
    
    return {
        "overall": {
            "score": round(overall_score, 1),
            "grade": grade,
            "assessment": assessment,
            "total_value": round(total_value, 2),
            "holdings_count": holding_count
        },
        "scores": {
            "diversification": round(diversification_score, 1),
            "pe_rating": round(pe_rating_score, 1),
            "risk_management": round(risk_score, 1),
            "allocation_quality": round(allocation_score, 1),
            "market_cap_mix": round(market_cap_score, 1)
        },
        "pe_analysis_details": pe_details,
        "metrics": {
            "average_beta": round(avg_beta, 2) if betas else None,
            "sector_count": len(sector_weights),
            "max_sector_weight": round(max_sector_weight * 100, 1),
            "max_stock_weight": round(max(stock_weights) * 100, 1) if stock_weights else 0
        },
        "distribution": {
            "sectors": {k: round(v * 100, 1) for k, v in sector_weights.items()},
            "market_caps": {k: round(v * 100, 1) for k, v in cap_weights.items()}
        },
        "insights": insights,
        "recommendations": recommendations,
        "methodology": {
            "pe_framework": "Research-based PEG-adjusted P/E with sector growth rates",
            "research_basis": "High P/E acceptable when justified by growth + fundamentals"
        }
    }

def enhanced_portfolio_analysis(
    holdings_data: List[Dict],
    rules_based_metrics: Dict,
    ml_analyzer: MLPortfolioAnalyzer
) -> Dict[str, Any]:
    """Combine rules-based scoring with ML predictions"""
    
    ml_risk = ml_analyzer.predict_risk_score(holdings_data)
    anomaly_detection = ml_analyzer.detect_anomalies(holdings_data)
    
    enhanced_result = rules_based_metrics.copy()
    
    enhanced_result['ml_insights'] = {
        "risk_prediction": ml_risk,
        "anomaly_detection": anomaly_detection
    }
    
    if ml_risk['prediction_available'] and ml_risk['ml_risk_score'] < 60:
        adjustment = (60 - ml_risk['ml_risk_score']) * 0.1
        enhanced_result['overall']['score'] -= adjustment
        enhanced_result['insights'].append({
            "type": "warning",
            "category": "ML Risk Prediction",
            "message": f"ML model predicts higher risk (Score: {ml_risk['ml_risk_score']})"
        })
    
    if anomaly_detection['is_anomaly']:
        enhanced_result['recommendations'].insert(0, 
            "⚠️ Portfolio structure is unusual - review allocation carefully"
        )
        enhanced_result['insights'].extend([
            {
                "type": "warning",
                "category": "Anomaly Detection",
                "message": warning
            }
            for warning in anomaly_detection['warnings']
        ])
    
    return enhanced_result

# ================== FASTAPI APP INITIALIZATION ==================

app = fastapi.FastAPI(title="Stock Market API with Research-Based Portfolio Analysis", version="5.0.0")

# ================== LIFESPAN MANAGEMENT ==================

@asynccontextmanager
async def lifespan(app: fastapi.FastAPI):
    global latest_data_cache, ml_analyzer
    
    logger.info("🚀 Starting application with research-based P/E analysis...")
    
    init_database()
    
    logger.info("📊 Loading market caps from Excel...")
    await asyncio.to_thread(load_market_caps_from_excel)
    
    if market_cap_cache:
        await asyncio.to_thread(save_excel_to_db)
    else:
        logger.warning("⚠️ No market caps loaded")
    
    try:
        ml_analyzer.load_models("ml_models/portfolio")
    except:
        logger.info("ℹ️ ML models not found - using standard analysis")
    
    logger.info("💰 Fetching initial stock prices...")
    try:
        latest_data_cache = await asyncio.wait_for(
            asyncio.to_thread(fetch_latest_prices_optimized),
            timeout=300.0
        )
        if latest_data_cache:
            valid_prices = len([r for r in latest_data_cache if r.get("Last Price", 0) > 0])
            logger.info(f"✅ Loaded {len(latest_data_cache)} stocks, {valid_prices} with prices")
        else:
            latest_data_cache = []
    except Exception as e:
        logger.error(f"❌ Initial price fetch failed: {e}")
        latest_data_cache = []
    
    task = None
    if datetime.now(MARKET_TZ).weekday() < 5:
        async def periodic_update():
            global latest_data_cache
            while True:
                try:
                    if is_market_open():
                        logger.info("🔄 Periodic update...")
                        new_data = await asyncio.wait_for(
                            asyncio.to_thread(fetch_latest_prices_optimized),
                            timeout=180.0
                        )
                        if new_data:
                            latest_data_cache = new_data
                            logger.info("✅ Cache updated")
                    await asyncio.sleep(300)
                except asyncio.CancelledError:
                    break
                except Exception as e:
                    logger.error(f"❌ Periodic update error: {e}")
                    await asyncio.sleep(300)
        
        task = asyncio.create_task(periodic_update())
        logger.info("🔄 Started periodic updates")
    
    yield
    
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
    return {
        "message": "Stock Market API with Research-Based Portfolio Analysis", 
        "version": "5.0.0",
        "features": {
            "pe_analysis": "PEG-adjusted with sector growth rates",
            "research_basis": "High P/E justified by growth + fundamentals",
            "ml_enabled": ml_analyzer.is_trained
        },
        "market_cap_source": "Excel File",
        "market_caps_loaded": len(market_cap_cache)
    }

@app.get("/health")
async def health_check():
    valid_prices = len([r for r in latest_data_cache if r.get("Last Price", 0) > 0])
    return {
        "status": "healthy",
        "cache_size": len(latest_data_cache),
        "valid_prices": valid_prices,
        "market_cap_cache_size": len(market_cap_cache),
        "market_status": "OPEN" if is_market_open() else "CLOSED",
        "ml_enabled": ml_analyzer.is_trained,
        "pe_methodology": "Research-based PEG-adjusted",
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

@app.get("/stock/{symbol}/analysis")
async def get_stock_analysis(symbol: str):
    """Get comprehensive stock analysis with research-based P/E valuation"""
    return await asyncio.to_thread(analyze_stock_comprehensive, symbol)

@app.post("/portfolio/analyze")
async def analyze_portfolio(request: PortfolioAnalysisRequest):
    """Portfolio analysis with research-based P/E scoring"""
    try:
        holdings_data = []
        
        for holding in request.holdings:
            symbol = holding.symbol
            yahoo_symbol = f"{symbol}.NS" if not symbol.endswith('.NS') else symbol
            
            stock_data = next((s for s in latest_data_cache if s['SYMBOL'] == symbol), None)
            
            if not stock_data:
                logger.warning(f"Stock {symbol} not found in cache")
                continue
            
            current_price = stock_data.get('Last Price', 0)
            if current_price == 0:
                logger.warning(f"No price data for {symbol}")
                continue
                
            current_value = current_price * holding.quantity
            
            try:
                ticker = yf.Ticker(yahoo_symbol)
                info = ticker.info
                
                sector = info.get('sector', 'Unknown')
                pe_ratio = info.get('trailingPE')
                beta = info.get('beta')
                revenue_growth = info.get('revenueGrowth')
                earnings_growth = info.get('earningsGrowth')
                profit_margin = info.get('profitMargins')
                roe = info.get('returnOnEquity')
                
                base_symbol = symbol.replace('.NS', '')
                market_cap = market_cap_cache.get(yahoo_symbol) or market_cap_cache.get(base_symbol)
                
                if market_cap and isinstance(market_cap, (int, float)):
                    market_cap_crores = market_cap / 10000000
                    market_cap_category = categorize_market_cap(market_cap_crores)
                else:
                    market_cap_category = 'Large'
                
                holdings_data.append({
                    'symbol': symbol,
                    'quantity': holding.quantity,
                    'invested_amount': holding.invested_amount,
                    'current_price': current_price,
                    'current_value': current_value,
                    'gain_loss': current_value - holding.invested_amount,
                    'gain_loss_pct': ((current_value - holding.invested_amount) / holding.invested_amount * 100) if holding.invested_amount > 0 else 0,
                    'sector': sector,
                    'pe_ratio': pe_ratio,
                    'beta': beta,
                    'revenue_growth': revenue_growth,
                    'earnings_growth': earnings_growth,
                    'profit_margin': profit_margin,
                    'roe': roe,
                    'market_cap_category': market_cap_category
                })
                
            except Exception as e:
                logger.warning(f"Could not fetch data for {symbol}: {e}")
                continue
        
        if not holdings_data:
            raise HTTPException(status_code=400, detail="Could not fetch data for any holdings")
        
        analysis = calculate_portfolio_metrics(holdings_data)
        analysis['holdings'] = holdings_data
        
        logger.info(f"✅ Standard analysis completed for {len(holdings_data)} holdings")
        return jsonable_encoder(analysis)
        
    except Exception as e:
        logger.error(f"Portfolio analysis error: {e}")
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

@app.post("/portfolio/analyze-enhanced")
async def analyze_portfolio_enhanced(request: PortfolioAnalysisRequest):
    """ML-enhanced portfolio analysis with risk prediction and anomaly detection"""
    try:
        holdings_data = []
        
        for holding in request.holdings:
            symbol = holding.symbol
            yahoo_symbol = f"{symbol}.NS" if not symbol.endswith('.NS') else symbol
            
            stock_data = next((s for s in latest_data_cache if s['SYMBOL'] == symbol), None)
            
            if not stock_data:
                logger.warning(f"Stock {symbol} not found in cache")
                continue
            
            current_price = stock_data.get('Last Price', 0)
            if current_price == 0:
                logger.warning(f"No price data for {symbol}")
                continue
                
            current_value = current_price * holding.quantity
            
            try:
                ticker = yf.Ticker(yahoo_symbol)
                info = ticker.info
                
                sector = info.get('sector', 'Unknown')
                pe_ratio = info.get('trailingPE')
                beta = info.get('beta')
                revenue_growth = info.get('revenueGrowth')
                earnings_growth = info.get('earningsGrowth')
                profit_margin = info.get('profitMargins')
                roe = info.get('returnOnEquity')
                
                base_symbol = symbol.replace('.NS', '')
                market_cap = market_cap_cache.get(yahoo_symbol) or market_cap_cache.get(base_symbol)
                
                if market_cap and isinstance(market_cap, (int, float)):
                    market_cap_crores = market_cap / 10000000
                    market_cap_category = categorize_market_cap(market_cap_crores)
                else:
                    market_cap_category = 'Large'
                
                holdings_data.append({
                    'symbol': symbol,
                    'quantity': holding.quantity,
                    'invested_amount': holding.invested_amount,
                    'current_price': current_price,
                    'current_value': current_value,
                    'gain_loss': current_value - holding.invested_amount,
                    'gain_loss_pct': ((current_value - holding.invested_amount) / holding.invested_amount * 100) if holding.invested_amount > 0 else 0,
                    'sector': sector,
                    'pe_ratio': pe_ratio,
                    'beta': beta,
                    'revenue_growth': revenue_growth,
                    'earnings_growth': earnings_growth,
                    'profit_margin': profit_margin,
                    'roe': roe,
                    'market_cap': market_cap,
                    'market_cap_category': market_cap_category
                })
                
            except Exception as e:
                logger.warning(f"Could not fetch data for {symbol}: {e}")
                continue
        
        if not holdings_data:
            raise HTTPException(status_code=400, detail="Could not fetch data for any holdings")
        
        basic_analysis = calculate_portfolio_metrics(holdings_data)
        
        try:
            if ml_analyzer.is_trained:
                logger.info("🤖 Applying ML enhancements...")
                enhanced = enhanced_portfolio_analysis(
                    holdings_data,
                    basic_analysis,
                    ml_analyzer
                )
                logger.info(f"✅ ML-enhanced analysis completed for {len(holdings_data)} holdings")
            else:
                logger.warning("⚠️ ML models not trained, returning standard analysis")
                enhanced = basic_analysis
                enhanced['ml_insights'] = None
        except Exception as ml_error:
            logger.error(f"❌ ML enhancement failed: {ml_error}, falling back to standard")
            enhanced = basic_analysis
            enhanced['ml_insights'] = None
        
        enhanced['holdings'] = holdings_data
        
        return jsonable_encoder(enhanced)
        
    except Exception as e:
        logger.error(f"Enhanced portfolio analysis error: {e}")
        raise HTTPException(status_code=500, detail=f"Analysis failed: {str(e)}")

@app.get("/portfolio/ml/status")
async def ml_status():
    """Check if ML models are loaded and ready"""
    return {
        "ml_enabled": ml_analyzer.is_trained,
        "risk_model_loaded": ml_analyzer.risk_model is not None,
        "anomaly_detector_loaded": ml_analyzer.anomaly_detector is not None,
        "feature_importance": ml_analyzer.get_feature_importance() if ml_analyzer.is_trained else {}
    }

@app.post("/portfolio/ml/load")
async def load_ml_models():
    """Load pre-trained ML models from disk"""
    try:
        ml_analyzer.load_models("ml_models/portfolio")
        logger.info("✅ ML models loaded successfully")
        
        return {
            "status": "success",
            "message": "ML models loaded successfully",
            "ml_enabled": ml_analyzer.is_trained
        }
    except FileNotFoundError:
        logger.warning("⚠️ ML model files not found")
        raise HTTPException(status_code=404, detail="ML models not found. Train models first.")
    except Exception as e:
        logger.error(f"❌ Failed to load ML models: {e}")
        raise HTTPException(status_code=500, detail=f"Failed to load models: {str(e)}")

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