import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from data import COLORS


def plot_price_history(data: dict[str, pd.DataFrame]) -> go.Figure:
    fig = go.Figure()
    for name, df in data.items():
        fig.add_trace(go.Scatter(
            x=df.index,
            y=df["Close"],
            name=name,
            line=dict(color=COLORS[name], width=2),
            hovertemplate="%{x|%d/%m/%Y}<br>R$ %{y:.2f}<extra>" + name + "</extra>",
        ))
    fig.update_layout(
        title="Histórico de Preços de Fechamento",
        xaxis_title="Data",
        yaxis_title="Preço (R$)",
        hovermode="x unified",
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
    )
    return fig


def plot_cumulative_return(data: dict[str, pd.DataFrame]) -> go.Figure:
    fig = go.Figure()
    for name, df in data.items():
        base = df["Close"].iloc[0]
        cumret = (df["Close"] / base - 1) * 100
        fig.add_trace(go.Scatter(
            x=df.index,
            y=cumret,
            name=name,
            line=dict(color=COLORS[name], width=2),
            hovertemplate="%{x|%d/%m/%Y}<br>%{y:.2f}%<extra>" + name + "</extra>",
        ))
    fig.add_hline(y=0, line_dash="dash", line_color="gray", opacity=0.5)
    fig.update_layout(
        title="Retorno Acumulado no Período (%)",
        xaxis_title="Data",
        yaxis_title="Retorno (%)",
        hovermode="x unified",
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
    )
    return fig


def plot_candlestick(df: pd.DataFrame, name: str) -> go.Figure:
    fig = go.Figure(go.Candlestick(
        x=df.index,
        open=df["Open"],
        high=df["High"],
        low=df["Low"],
        close=df["Close"],
        name=name,
        increasing_line_color="#26a69a",
        decreasing_line_color="#ef5350",
    ))
    fig.update_layout(
        title=f"Candlestick — {name}",
        xaxis_title="Data",
        yaxis_title="Preço (R$)",
        xaxis_rangeslider_visible=False,
    )
    return fig


def plot_volume(df: pd.DataFrame, name: str) -> go.Figure:
    fig = go.Figure(go.Bar(
        x=df.index,
        y=df["Volume"],
        name=name,
        marker_color=COLORS[name],
        opacity=0.7,
        hovertemplate="%{x|%d/%m/%Y}<br>Volume: %{y:,.0f}<extra></extra>",
    ))
    fig.update_layout(
        title=f"Volume Negociado — {name}",
        xaxis_title="Data",
        yaxis_title="Volume",
    )
    return fig
