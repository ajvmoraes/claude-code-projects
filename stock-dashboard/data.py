import streamlit as st
import yfinance as yf
import pandas as pd

TICKERS = {
    "Petrobras": "PETR4.SA",
    "Itaú": "ITUB4.SA",
    "Vale": "VALE3.SA",
}

COLORS = {
    "Petrobras": "#009B3A",
    "Itaú": "#EC7000",
    "Vale": "#005FAD",
}


@st.cache_data(ttl=3600)
def fetch_data(selected: list[str], start: str, end: str) -> dict[str, pd.DataFrame]:
    result = {}
    for name in selected:
        ticker = TICKERS[name]
        df = yf.download(ticker, start=start, end=end, auto_adjust=True, progress=False)
        if not df.empty:
            df.columns = [col[0] if isinstance(col, tuple) else col for col in df.columns]
            result[name] = df
    return result
