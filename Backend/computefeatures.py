import numpy as np
import pandas as pd

def compute_features(df):
    print("✅ Using Backend/computefeatures.py")

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
    
    # Fix: Use .values or ensure single column assignment
    df['ma_5_ratio'] = (df['Close'] / df['ma_5'] - 1).values
    df['ma_10_ratio'] = (df['Close'] / df['ma_10'] - 1).values
    df['ma_20_ratio'] = (df['Close'] / df['ma_20'] - 1).values
    df['ma_crossover_5_10'] = (df['ma_5'] > df['ma_10']).astype(int)

    # Bollinger band position
    rolling20 = df['Close'].rolling(20)
    std20 = rolling20.std()
    sma20 = rolling20.mean()
    df['bb_upper'] = sma20 + 2*std20
    df['bb_lower'] = sma20 - 2*std20
    
    # Fix: Ensure proper calculation and single column assignment
    bb_range = df['bb_upper'] - df['bb_lower']
    df['bb_pos'] = ((df['Close'] - df['bb_lower']) / bb_range).fillna(0.5)

    # RSI - Fix the calculation
    df['delta'] = df['Close'].diff()
    gain = df['delta'].where(df['delta'] > 0, 0)
    loss = -df['delta'].where(df['delta'] < 0, 0)
    
    # Use exponential moving average for RSI (more standard)
    avg_gain = gain.ewm(span=14, adjust=False).mean()
    avg_loss = loss.ewm(span=14, adjust=False).mean()
    rs = avg_gain / (avg_loss + 1e-9)
    df['rsi_14'] = 100 - (100 / (1 + rs))
    
    # MACD
    ema12 = df['Close'].ewm(span=12, adjust=False).mean()
    ema26 = df['Close'].ewm(span=26, adjust=False).mean()
    df['macd'] = ema12 - ema26
    df['macd_signal'] = df['macd'].ewm(span=9, adjust=False).mean()
    df['macd_hist'] = df['macd'] - df['macd_signal']

    # Volume features
    df['vol_avg_10'] = df['Volume'].rolling(10).mean()
    df['vol_spike_ratio'] = df['Volume'] / (df['vol_avg_10'] + 1e-9)
    
    # OBV - Fix the calculation
    price_change_sign = np.sign(df['Close'].diff()).fillna(0)
    df['obv'] = (price_change_sign * df['Volume']).cumsum()
    df['obv_change_5d'] = df['obv'] - df['obv'].shift(5)

    # Volatility
    df['daily_range'] = (df['High'] - df['Low']) / df['Close']
    
    # True Range calculation
    prev_close = df['Close'].shift(1)
    tr1 = df['High'] - df['Low']
    tr2 = (df['High'] - prev_close).abs()
    tr3 = (df['Low'] - prev_close).abs()
    
    # Fix: Use pd.DataFrame constructor instead of concat for max operation
    true_range = pd.DataFrame({
        'tr1': tr1,
        'tr2': tr2,
        'tr3': tr3
    }).max(axis=1)
    
    df['atr_14'] = true_range.rolling(14).mean()

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
    
    # Ensure all columns exist before selection
    available_cols = [col for col in keep if col in df.columns]
    missing_cols = [col for col in keep if col not in df.columns]
    
    if missing_cols:
        print(f"Warning: Missing columns: {missing_cols}")
    
    df = df[available_cols]
    
    
    # Drop rows with NaN values
    df_clean = df.dropna()
    
    print(f"DataFrame shape after dropna: {df_clean.shape}")
    
    # Ensure we have at least some data
    if df_clean.empty:
        raise ValueError("No valid data remaining after feature computation and NaN removal")
    
    return df_clean
# Requires: yfinance, pandas, numpy, scipy

# pip install yfinance pandas numpy scipy
# Requires: yfinance, pandas, numpy, scipy

# pip install yfinance pandas numpy scipy
