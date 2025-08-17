import numpy as np
import pandas as pd
def compute_features(df):
    df = df.copy()
    df = df[['Open','High','Low','Close','Volume']].astype(float)

    # returns
    df['return_1d'] = df['Close'].pct_change(1)
    df['return_3d'] = df['Close'].pct_change(3)
    df['return_5d'] = df['Close'].pct_change(5)
    df['lag_return_1d'] = df['return_1d'].shift(1)
    df['price_change_intraday'] = (df['Close'] - df['Open']) / df['Open']

    # moving averages & ratios
    df['ma_5'] = df['Close'].rolling(5).mean()
    df['ma_10'] = df['Close'].rolling(10).mean()
    df['ma_20'] = df['Close'].rolling(20).mean()
    df['ma_5_ratio'] = df['Close'] / df['ma_5'] - 1
    df['ma_10_ratio'] = df['Close'] / df['ma_10'] - 1
    df['ma_20_ratio'] = df['Close'] / df['ma_20'] - 1
    df['ma_crossover_5_10'] = (df['ma_5'] > df['ma_10']).astype(int)

    # Bollinger band position
    rolling20 = df['Close'].rolling(20)
    std20 = rolling20.std()
    sma20 = rolling20.mean()
    df['bb_upper'] = sma20 + 2*std20
    df['bb_lower'] = sma20 - 2*std20
    df['bb_pos'] = (df['Close'] - df['bb_lower']) / (df['bb_upper'] - df['bb_lower'])

    # RSI
    df['delta'] = df['Close'].diff()
    gain = df['delta'].where(df['delta'] > 0, 0)
    loss = -df['delta'].where(df['delta'] < 0, 0)
    df['rsi_14'] = gain.rolling(14).mean() / (gain.rolling(14).mean() + loss.rolling(14).mean())
    df['rsi_14'] = 100 - (100 / (1 + (gain.rolling(14).mean() / (loss.rolling(14).mean() + 1e-9))))
    # MACD
    ema12 = df['Close'].ewm(span=12, adjust=False).mean()
    ema26 = df['Close'].ewm(span=26, adjust=False).mean()
    df['macd'] = ema12 - ema26
    df['macd_signal'] = df['macd'].ewm(span=9, adjust=False).mean()
    df['macd_hist'] = df['macd'] - df['macd_signal']

    # Volume features
    df['vol_avg_10'] = df['Volume'].rolling(10).mean()
    df['vol_spike_ratio'] = df['Volume'] / (df['vol_avg_10'] + 1e-9)
    # OBV
    df['obv'] = (np.sign(df['Close'].diff()) * df['Volume']).fillna(0).cumsum()
    df['obv_change_5d'] = df['obv'] - df['obv'].shift(5)

    # Volatility
    df['daily_range'] = (df['High'] - df['Low']) / df['Close']
    tr1 = df['High'] - df['Low']
    tr2 = (df['High'] - df['Close'].shift()).abs()
    tr3 = (df['Low'] - df['Close'].shift()).abs()
    tr = pd.concat([tr1, tr2, tr3], axis=1).max(axis=1)
    df['atr_14'] = tr.rolling(14).mean()

    # Market context placeholders (user can compute & merge NIFTY externally)
    # Example: df['nifty_rel_3d'] = df['return_3d'] - nifty_return_3d

    # target: up in 5 trading days
    df['target'] = (df['Close'].shift(-5) > df['Close']).astype(int)

    # keep sensible columns
    keep = [
        'Close','Open','High','Low','Volume',
        'return_1d','return_3d','return_5d','lag_return_1d','price_change_intraday',
        'ma_5_ratio','ma_10_ratio','ma_20_ratio','ma_crossover_5_10','bb_pos',
        'rsi_14','macd_hist','vol_spike_ratio','obv_change_5d','atr_14','daily_range',
        'target'
    ]
    df = df[keep]
    df = df.dropna()
    return df

# Requires: yfinance, pandas, numpy, scipy

# pip install yfinance pandas numpy scipy
# Requires: yfinance, pandas, numpy, scipy

# pip install yfinance pandas numpy scipy

import yfinance as yf
import pandas as pd
import numpy as np
from scipy.signal import argrelextrema
from datetime import datetime, timedelta

def zscore(x):
    return (x - np.nanmean(x)) / (np.nanstd(x) + 1e-9)

def percentile_rank(arr, value):
    arr = np.array(arr[~np.isnan(arr)])
    if len(arr) == 0:
        return 0.5
    # Modified to handle ties properly, averaging ranks for equals
    lt_count = (arr < value).sum()
    eq_count = (arr == value).sum()
    return float( (lt_count + 0.5 * eq_count) / len(arr) )

def detect_local_minima(series, order=3):
    # returns indices of local minima
    if len(series) < (2*order + 1):
        return np.array([], dtype=int)
    try:
        minima_idx = argrelextrema(np.array(series), np.less, order=order)[0]
        return minima_idx
    except Exception:
        return np.array([], dtype=int)

def normalize_to_0_1(x, low, high):
    if np.isnan(x):
        return 0.5
    return float(np.clip((x - low) / (high - low + 1e-9), 0.0, 1.0))

def safe_get(d, key, default=np.nan):
    return d.get(key, default) if isinstance(d, dict) else default

def fetch_basic_fundamentals(ticker_obj):
    info = {}
    try:
        info_raw = ticker_obj.info
    except Exception:
        info_raw = {}
    info['currentPrice'] = safe_get(info_raw, 'currentPrice', np.nan)
    info['trailingPE'] = safe_get(info_raw, 'trailingPE', np.nan)
    info['forwardPE'] = safe_get(info_raw, 'forwardPE', np.nan)
    info['priceToBook'] = safe_get(info_raw, 'priceToBook', np.nan)
    info['debtToEquity'] = safe_get(info_raw, 'debtToEquity', np.nan) or safe_get(info_raw, 'totalDebt', np.nan)
    info['returnOnEquity'] = safe_get(info_raw, 'returnOnEquity', np.nan) or safe_get(info_raw, 'returnOnAssets', np.nan)
    info['marketCap'] = safe_get(info_raw, 'marketCap', np.nan)
    info['sharesOutstanding'] = safe_get(info_raw, 'sharesOutstanding', np.nan)
    return info

def build_pe_series(ticker_obj, price_hist):
    """
    Try to build a PE time-series using available historical EPS / earnings data.
    Fallback: return array of current PE repeated to match price history length.
    """
    # Attempt 1: use ticker.quarterly_financials / earnings if present (annual)
    try:
        earnings = ticker_obj.earnings # annual earnings -> DataFrame with 'Earnings' column, index is Year
        # earnings is yearly net income (not EPS). We need EPS -> try to compute EPS using sharesOutstanding if available
        if isinstance(earnings, pd.DataFrame) and 'Earnings' in earnings.columns and len(earnings) >= 2:
            shares = safe_get(ticker_obj.info, 'sharesOutstanding', np.nan)
            if not np.isnan(shares) and shares > 0:
                # build approximate EPS per year = earnings / shares
                eps_years = earnings['Earnings'] / shares
                # Expand to price_hist index by forward-filling last known EPS
                eps_series = pd.Series(index=price_hist.index, dtype=float)
                years = earnings.index.astype(int)
                # Align eps by year -> naive approach: for each price date, pick eps of the most recent reported year
                eps_values_by_year = {int(y): float(eps_years.loc[y]) for y in years}
                price_years = price_hist.index.year
                eps_series = price_hist.index.to_series().apply(
                    lambda dt: eps_values_by_year.get(dt.year, list(eps_values_by_year.values())[-1] if len(eps_values_by_year)>0 else np.nan)
                )
                pe_series = price_hist['Close'] / (eps_series + 1e-9)
                return pe_series.clip(0, 1e6)
    except Exception:
        pass

    # If we couldn't build a historical PE series, fallback to current trailing PE repeated
    try:
        current_pe = float(safe_get(ticker_obj.info, 'trailingPE', np.nan))
    except Exception:
        current_pe = np.nan
    if np.isnan(current_pe):
        # ultimate fallback: NaNs
        return pd.Series(index=price_hist.index, data=np.nan)
    return pd.Series(index=price_hist.index, data=current_pe)

def build_pb_series(ticker_obj, price_hist):
    """
    Build PB (price/book) series using balance sheet totalStockholderEquity / sharesOutstanding, when possible.
    """
    try:
        bs = ticker_obj.balance_sheet # columns are dates
        if isinstance(bs, pd.DataFrame) and 'Total Stockholder Equity' in bs.index.get_level_values(0).tolist() or 'TotalStockholderEquity' in bs.index:
            # yfinance's keys vary, try common names
            tkeys = list(bs.index)
            # Try some known labels:
            equity_labels = [lab for lab in tkeys if 'Equity' in str(lab) or 'stockholder' in str(lab).lower()]
        else:
            equity_labels = [lab for lab in bs.index if 'Equity' in str(lab) or 'stockholder' in str(lab).lower()]
        # fallback to looking for 'Total Stockholders' or 'totalStockholdersEquity'
        all_eq = None
        for label in bs.index:
            if 'equity' in str(label).lower():
                all_eq = bs.loc[label]
                break
        if all_eq is not None:
            # all_eq is Series with column dates; compute book value per share
            shares = safe_get(ticker_obj.info, 'sharesOutstanding', np.nan)
            if not np.isnan(shares) and shares > 0:
                # Reindex to price_hist by forward filling latest book values
                bv = all_eq.replace(0, np.nan).ffill().bfill()
                # make a series aligned to price_hist
                bv_series = price_hist.index.to_series().apply(lambda dt: bv[bv.index <= dt].iloc[0] if (bv.index <= dt).any() else bv.iloc[0])
                bv_per_share = bv_series / shares
                pb_series = price_hist['Close'] / (bv_per_share + 1e-9)
                return pb_series.clip(0, 1e6)
    except Exception:
        pass
    # fallback: use current priceToBook
    try:
        current_pb = float(safe_get(ticker_obj.info, 'priceToBook', np.nan))
    except Exception:
        current_pb = np.nan
    return pd.Series(index=price_hist.index, data=current_pb)

def compute_technical_scores(price_hist):
    """
    Short term technical features and normalized scores:
    - 3-month return
    - 1-month return
    - 50/200 MA gap
    - simple RSI approximation
    Returns score between 0-1 (higher = bullish)
    """
    close = price_hist['Close'].astype(float)
    # returns
    ret_1m = (close[-22:].iloc[-1] / close[-22:].iloc[0] - 1) if len(close) >= 22 else np.nan
    ret_3m = (close[-66:].iloc[-1] / close[-66:].iloc[0] - 1) if len(close) >= 66 else np.nan

    ma50 = close.rolling(window=50, min_periods=1).mean().iloc[-1]
    ma200 = close.rolling(window=200, min_periods=1).mean().iloc[-1]
    ma_gap = (ma50 - ma200) / (ma200 + 1e-9)

    # simple RSI (14)
    delta = close.diff().fillna(0)
    up = delta.clip(lower=0).rolling(14).mean()
    down = -delta.clip(upper=0).rolling(14).mean()
    rs = (up / (down + 1e-9)).replace([np.inf, -np.inf], np.nan)
    rsi = 100 - (100 / (1 + rs))
    rsi_latest = float(rsi.iloc[-1]) if not np.isnan(rsi.iloc[-1]) else np.nan

    # normalize to 0..1 roughly
    score_ret = normalize_to_0_1(ret_3m if not np.isnan(ret_3m) else (ret_1m if not np.isnan(ret_1m) else 0), -0.5, 0.5)
    score_ma = normalize_to_0_1(ma_gap, -0.2, 0.2)
    score_rsi = normalize_to_0_1(50 - (rsi_latest - 50) if not np.isnan(rsi_latest) else 0, -50, 50) # RSI close to 50 neutral

    tech_score = 0.5 * score_ret + 0.3 * score_ma + 0.2 * score_rsi
    return float(np.clip(tech_score, 0, 1)), {
        '3m_return': ret_3m, 'ma_gap': ma_gap, 'rsi': rsi_latest,
        'score_ret': score_ret, 'score_ma': score_ma, 'score_rsi': score_rsi
    }

def compute_fundamental_scores(info, pe_series, pb_series):
    """
    Compute fundamentals-based normalized scores (0..1)
    - PE score: lower PE better (we'll compare current PE to historical PE distribution)
    - PB score: lower PB better (same logic)
    - ROE: higher better
    - Debt: lower better
    - Earnings growth: not available reliably via yfinance here -> use nan-safe default
    We weight PE and PB more heavily.
    """
    # Current metrics
    current_pe = float(info.get('trailingPE', np.nan))
    current_pb = float(info.get('priceToBook', np.nan))
    roE = float(info.get('returnOnEquity', np.nan)) if info.get('returnOnEquity') is not None else np.nan
    debt = float(info.get('debtToEquity', np.nan)) if info.get('debtToEquity') is not None else np.nan

    # PE percentile vs history (lower percentile => cheap)
    pe_hist = np.array(pe_series.dropna())
    pb_hist = np.array(pb_series.dropna())
    pe_pct = percentile_rank(pe_hist, current_pe) if not np.isnan(current_pe) and len(pe_hist)>0 else 0.5
    pb_pct = percentile_rank(pb_hist, current_pb) if not np.isnan(current_pb) and len(pb_hist)>0 else 0.5

    # Convert percentiles to scores where lower percentile -> higher score
    pe_score = 1 - pe_pct
    pb_score = 1 - pb_pct

    # ROE: normalize between -0.2 to 0.5 (i.e. -20% -> 50%)
    roe_score = normalize_to_0_1(roE, -0.2, 0.5)

    # Debt: lower is better; normalize assuming 0..200 (200% debt/equity very high)
    debt_score = 1 - normalize_to_0_1(debt, 0, 200)

    # Aggregate with weights (PE & PB dominant)
    # weights: PE 0.35, PB 0.30, ROE 0.2, Debt 0.15
    weights = {'pe': 0.35, 'pb': 0.30, 'roe': 0.20, 'debt': 0.15}
    # fill nan with neutral 0.5
    pe_score = 0.5 if np.isnan(pe_score) else pe_score
    pb_score = 0.5 if np.isnan(pb_score) else pb_score
    roe_score = 0.5 if np.isnan(roe_score) else roe_score
    debt_score = 0.5 if np.isnan(debt_score) else debt_score

    fund_score = (weights['pe'] * pe_score +
                  weights['pb'] * pb_score +
                  weights['roe'] * roe_score +
                  weights['debt'] * debt_score)

    return float(np.clip(fund_score, 0, 1)), {
        'current_pe': current_pe, 'pe_pct': pe_pct, 'pe_score': pe_score,
        'current_pb': current_pb, 'pb_pct': pb_pct, 'pb_score': pb_score,
        'roe_score': roe_score, 'debt_score': debt_score
    }

def rate_from_score(score):
    # score 0..1 -> rating
    if score >= 0.8:
        return 'STRONG BUY'
    elif score >= 0.65:
        return 'BUY'
    elif score >= 0.4:
        return 'HOLD'
    elif score >= 0.2:
        return 'WEAK SELL'
    else:
        return 'SELL'
def create_summary_dict(symbol, fund_score, tech_score, short_score, short_rating, long_score, long_rating, metadata):
    summary = {
        "Symbol": symbol,
        "Fundamental score (0-1)": fund_score,
        "Technical score (0-1)": tech_score,
        "Short-term score (0-1)": short_score,
        "Short-term rating": short_rating,
        "Long-term score (0-1)": long_score,
        "Long-term rating": long_rating,
        "Metadata": metadata
    }
    return summary

def rate_stock(symbol, short_months=3, long_years=2):
    """
    Main function:
    - symbol: e.g. 'AAPL' or 'AAPL.NS'
    - returns dict with short_term and long_term scores and ratings + explanations
    """
    ticker = yf.Ticker(symbol)
    end = datetime.today()
    start = end - timedelta(days=365 * max(3, long_years+1)) # fetch 3+ years for history
    price_hist = ticker.history(start=start.strftime("%Y-%m-%d"), end=end.strftime("%Y-%m-%d"), auto_adjust=False)
    if price_hist is None or price_hist.empty:
        raise ValueError("No price history available for " + symbol)

    info = fetch_basic_fundamentals(ticker)

    # Build PE and PB series (best-effort)
    pe_series = build_pe_series(ticker, price_hist)
    pb_series = build_pb_series(ticker, price_hist)

    # detect minima for PE and PB
    pe_minima_idx = detect_local_minima(pe_series.fillna(method='ffill').values, order=5)
    pb_minima_idx = detect_local_minima(pb_series.fillna(method='ffill').values, order=5)

    # last values
    last_pe = float(pe_series.dropna().iloc[-1]) if len(pe_series.dropna())>0 else np.nan
    last_pb = float(pb_series.dropna().iloc[-1]) if len(pb_series.dropna())>0 else np.nan

    # Are we near a historical low? (global bottom quantile & local minima check)
    pe_global_low = False
    pb_global_low = False
    if not np.isnan(last_pe) and len(pe_series.dropna())>0:
        pe_q10 = np.nanpercentile(pe_series.dropna(), 10)
        pe_global_low = last_pe <= pe_q10 or (len(pe_minima_idx) > 0 and pe_minima_idx[-1] == len(pe_series)-1)
    if not np.isnan(last_pb) and len(pb_series.dropna())>0:
        pb_q10 = np.nanpercentile(pb_series.dropna(), 10)
        pb_global_low = last_pb <= pb_q10 or (len(pb_minima_idx) > 0 and pb_minima_idx[-1] == len(pb_series)-1)

    # compute fundamental and technical scores
    fund_score, fund_details = compute_fundamental_scores(info, pe_series, pb_series)
    tech_score, tech_details = compute_technical_scores(price_hist)

    # Short term (2-3 months) = weigh fundamentals but add more weight to technicals
    short_weight_fund = 0.55
    short_weight_tech = 0.45

    # if near PE/PB global minima, slightly boost short-term confidence
    minima_boost = 0.06 if (pe_global_low or pb_global_low) else 0.0

    short_score = np.clip(short_weight_fund * fund_score + short_weight_tech * tech_score + minima_boost, 0, 1)

    # Long term (2-3 years) = fundamentals heavy
    long_weight_fund = 0.85
    long_weight_tech = 0.15

    long_score = np.clip(long_weight_fund * fund_score + long_weight_tech * tech_score + (0.08 if (pe_global_low or pb_global_low) else 0.0), 0, 1)

    short_rating = rate_from_score(short_score)
    long_rating = rate_from_score(long_score)

    result = {
        'symbol': symbol,
        'short': {
            'months': short_months,
            'score_0_1': short_score,
            'score_0_100': round(short_score * 100, 1),
            'rating': short_rating
        },
        'long': {
            'years': long_years,
            'score_0_1': long_score,
            'score_0_100': round(long_score * 100, 1),
            'rating': long_rating
        },
        'fundamentals': fund_details,
        'technical': tech_details,
        'metadata': {
            'last_pe': last_pe,
            'last_pb': last_pb,
            'pe_global_low': pe_global_low,
            'pb_global_low': pb_global_low,
            'pe_minima_count': len(pe_minima_idx),
            'pb_minima_count': len(pb_minima_idx)
        }
    }


        
    summary_dict = create_summary_dict(symbol, fund_score, tech_score, short_score, short_rating, long_score, long_rating, result['metadata'])


    return summary_dict

    

# Example usage (uncomment to run):
# out = rate_stock("AAPL", short_months=3, long_years=2, verbose=True)
# print(out)

