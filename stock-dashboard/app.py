import streamlit as st
import pandas as pd
from datetime import date
from data import fetch_data, TICKERS
from charts import plot_price_history, plot_cumulative_return, plot_candlestick, plot_volume

st.set_page_config(page_title="Dashboard de Ações 2025", page_icon="📈", layout="wide")
st.title("📈 Dashboard de Performance de Ações — 2025")

# --- Sidebar ---
with st.sidebar:
    st.header("Filtros")
    selected = st.multiselect(
        "Ações",
        options=list(TICKERS.keys()),
        default=list(TICKERS.keys()),
    )
    col_start, col_end = st.columns(2)
    with col_start:
        start_date = st.date_input("Início", value=date(2025, 1, 1), min_value=date(2025, 1, 1), max_value=date(2025, 12, 31))
    with col_end:
        end_date = st.date_input("Fim", value=min(date.today(), date(2025, 12, 31)), min_value=date(2025, 1, 1), max_value=date(2025, 12, 31))

if not selected:
    st.warning("Selecione ao menos uma ação no painel lateral.")
    st.stop()

if start_date >= end_date:
    st.error("A data de início deve ser anterior à data de fim.")
    st.stop()

# --- Busca de dados ---
with st.spinner("Buscando dados..."):
    data = fetch_data(selected, str(start_date), str(end_date))

if not data:
    st.error("Não foi possível carregar os dados. Verifique sua conexão.")
    st.stop()

# --- Cards de métricas ---
st.subheader("Resumo de Performance")
cols = st.columns(len(data))
for col, (name, df) in zip(cols, data.items()):
    first = df["Close"].iloc[0]
    last = df["Close"].iloc[-1]
    change_pct = (last / first - 1) * 100
    change_val = last - first
    low = df["Close"].min()
    high = df["Close"].max()
    with col:
        st.markdown(f"**{name}**")
        st.metric(
            label=f"Fechamento ({df.index[-1].strftime('%d/%m/%Y')})",
            value=f"R$ {last:.2f}",
            delta=f"{change_pct:+.2f}% (R$ {change_val:+.2f})",
        )
        st.caption(f"Mín: R$ {low:.2f} | Máx: R$ {high:.2f}")

st.divider()

# --- Gráficos comparativos ---
tab1, tab2 = st.tabs(["Histórico de Preços", "Retorno Acumulado (%)"])
with tab1:
    st.plotly_chart(plot_price_history(data), use_container_width=True)
with tab2:
    st.plotly_chart(plot_cumulative_return(data), use_container_width=True)

st.divider()

# --- Gráficos individuais ---
st.subheader("Análise Individual")
selected_stock = st.selectbox("Selecione a ação para análise detalhada:", options=list(data.keys()))
df_stock = data[selected_stock]

tab3, tab4 = st.tabs(["Candlestick", "Volume Negociado"])
with tab3:
    st.plotly_chart(plot_candlestick(df_stock, selected_stock), use_container_width=True)
with tab4:
    st.plotly_chart(plot_volume(df_stock, selected_stock), use_container_width=True)
