
import streamlit as st
import plotly.express as px
import pandas as pd
import os
import warnings
import datetime
import json
import logging
import sys
import random
import pickle
import plotly.express as px
from plotly.subplots import make_subplots
sys.path.append('./Common')
from SQLServerHelper.SQLServerHelper import SQLServerModel
from LogHelper.LogHelper import LogHelper
from LoginHelper.LoginHelper import sl_authenticate
from st_aggrid import AgGrid, GridOptionsBuilder, GridUpdateMode, JsCode
import streamlit_authenticator as stauth  # pip install streamlit-authenticator
warnings.filterwarnings('ignore')

def initialize_session_state():
    if 'name' not in st.session_state:
        st.session_state['name'] = None
    if 'authentication_status' not in st.session_state:
        st.session_state['authentication_status'] = None
    if 'username' not in st.session_state:
        st.session_state['username'] = None

initialize_session_state()

st.set_page_config(page_title="Stock Dashboard for ASX", page_icon=":flag-au:", layout="wide")

@st.cache_data(ttl=90)
def get_report_data():
    obj_sql_server_model = SQLServerModel()
    sql_data = obj_sql_server_model.execute_read_usp(f"exec [Report].[usp_Dashboard_GetDarkPoolIndex]", ())
    df = pd.DataFrame(sql_data)
    return df

name, authentication_status, username, authenticator = sl_authenticate()

st.session_state['name'] = name
st.session_state['authentication_status'] = authentication_status
st.session_state['username'] = username

if authentication_status == False:
    st.error("Username/password is incorrect")

if authentication_status == None:
    st.warning("Please enter your username and password")

if authentication_status:
    st.sidebar.header(f"User name: {name}")
    authenticator.logout("Logout", "sidebar")
    st.title(":flag-au: Stock Dashboard for ASX")
    st.markdown('<style>div.block-container{padding-top:1rem;}</style>',unsafe_allow_html=True)

    st.subheader('Welcome to stock dashboard for ASX')

    st.write("""
    The ASX Stock Dashboard provides a comprehensive, real-time overview of Australian stock market performance. Key features include:

    Market Summary: Displays key indices like the ASX 200, All Ordinaries, and sector indices, highlighting daily performance.
    Top Movers: Lists the day’s top gainers, losers, and most active stocks by volume.
    Custom Watchlist: Enables users to track selected ASX stocks with real-time prices, percentage changes, and volume.
    Charting Tools: Offers interactive price and volume charts for individual stocks or indices, with technical indicators.
    Sector Analysis: Breaks down performance by sectors (e.g., financials, mining, healthcare) to identify trends.
    Market News: Features the latest ASX announcements, corporate actions, and economic updates.
    Performance Metrics: Includes tools for analyzing dividend yields, price-to-earnings ratios, and other financial metrics.
    This dashboard is ideal for traders, investors, and analysts seeking actionable insights into the Australian stock market.    
    """)    


