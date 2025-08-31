import streamlit as st
import pandas as pd
import warnings
import sys
sys.path.append('./Common')
from SQLServerHelper.SQLServerHelper import SQLServerModel
from LoginHelper.LoginHelper import sl_authenticate
from st_aggrid import AgGrid, GridOptionsBuilder, JsCode, GridUpdateMode
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import numpy as np
warnings.filterwarnings('ignore')

st.set_page_config(page_title="Order Book and Transaction History", page_icon=":bar_chart:", layout="wide")

name, authentication_status, username, authenticator = sl_authenticate()

if authentication_status == False:
    st.error("Username/password is incorrect")

if authentication_status == None:
    st.warning("Please enter your username and password")

if authentication_status:
    st.sidebar.header(f"User name: {name}")    
    authenticator.logout("Logout", "sidebar")
    st.title("Order Book and Transaction History")
    st.markdown('<style>div.block-container{padding-top:1rem;}</style>', unsafe_allow_html=True)

    # Add custom CSS for grid styling with dynamic classes for TransValue
    st.markdown("""
    <style>
    .cell-bid { background-color: rgba(0, 128, 0, 0.2) !important; }
    .cell-ask { background-color: rgba(255, 0, 0, 0.2) !important; }
    .cell-buy { background-color: rgba(0, 200, 0, 0.3) !important; }
    .cell-sell { background-color: rgba(255, 0, 0, 0.3) !important; }
    
    /* Center align date picker */
    div[data-testid="stDateInput"] {
        display: flex;
        justify-content: center;
    }
    div[data-testid="stDateInput"] > div {
        width: 300px;
    }
    
    /* Fix for AgGrid pagination issues */
    .ag-paging-panel {
        z-index: 10 !important;
    }
    .ag-overlay {
        z-index: 1 !important; 
    }
    
    /* TransValue background bars */
    .transvalue-bar-buy-10 { background: linear-gradient(to right, rgba(0, 128, 0, 0.7) 10%, transparent 10%) !important; }
    .transvalue-bar-buy-20 { background: linear-gradient(to right, rgba(0, 128, 0, 0.7) 20%, transparent 20%) !important; }
    .transvalue-bar-buy-30 { background: linear-gradient(to right, rgba(0, 128, 0, 0.7) 30%, transparent 30%) !important; }
    .transvalue-bar-buy-40 { background: linear-gradient(to right, rgba(0, 128, 0, 0.7) 40%, transparent 40%) !important; }
    .transvalue-bar-buy-50 { background: linear-gradient(to right, rgba(0, 128, 0, 0.7) 50%, transparent 50%) !important; }
    .transvalue-bar-buy-60 { background: linear-gradient(to right, rgba(0, 128, 0, 0.7) 60%, transparent 60%) !important; }
    .transvalue-bar-buy-70 { background: linear-gradient(to right, rgba(0, 128, 0, 0.7) 70%, transparent 70%) !important; }
    .transvalue-bar-buy-80 { background: linear-gradient(to right, rgba(0, 128, 0, 0.7) 80%, transparent 80%) !important; }
    .transvalue-bar-buy-90 { background: linear-gradient(to right, rgba(0, 128, 0, 0.7) 90%, transparent 90%) !important; }
    .transvalue-bar-buy-100 { background: linear-gradient(to right, rgba(0, 128, 0, 0.7) 100%, transparent 100%) !important; }
    
    .transvalue-bar-sell-10 { background: linear-gradient(to right, rgba(255, 0, 0, 0.7) 10%, transparent 10%) !important; }
    .transvalue-bar-sell-20 { background: linear-gradient(to right, rgba(255, 0, 0, 0.7) 20%, transparent 20%) !important; }
    .transvalue-bar-sell-30 { background: linear-gradient(to right, rgba(255, 0, 0, 0.7) 30%, transparent 30%) !important; }
    .transvalue-bar-sell-40 { background: linear-gradient(to right, rgba(255, 0, 0, 0.7) 40%, transparent 40%) !important; }
    .transvalue-bar-sell-50 { background: linear-gradient(to right, rgba(255, 0, 0, 0.7) 50%, transparent 50%) !important; }
    .transvalue-bar-sell-60 { background: linear-gradient(to right, rgba(255, 0, 0, 0.7) 60%, transparent 60%) !important; }
    .transvalue-bar-sell-70 { background: linear-gradient(to right, rgba(255, 0, 0, 0.7) 70%, transparent 70%) !important; }
    .transvalue-bar-sell-80 { background: linear-gradient(to right, rgba(255, 0, 0, 0.7) 80%, transparent 80%) !important; }
    .transvalue-bar-sell-90 { background: linear-gradient(to right, rgba(255, 0, 0, 0.7) 90%, transparent 90%) !important; }
    .transvalue-bar-sell-100 { background: linear-gradient(to right, rgba(255, 0, 0, 0.7) 100%, transparent 100%) !important; }
    </style>
    """, unsafe_allow_html=True)

    # Create columns for date inputs and arrow buttons
    col1, col2, col3 = st.columns([1, 10, 1])

    with col1:
        st.write("")  # Add some spacing
        st.write("")  # Add some spacing
        if st.button("←"):  # Left arrow
            if 'date_from' in st.session_state:
                # Shift dates back by one workday
                new_date = st.session_state.date_from - pd.Timedelta(days=1)
                # Keep shifting back until we find a weekday
                while new_date.weekday() >= 5:  # 5 is Saturday, 6 is Sunday
                    new_date -= pd.Timedelta(days=1)
                st.session_state.date_from = new_date
                st.session_state.date_to = new_date

    with col2:
        st.write("<div style='text-align: center;'>Date</div>", unsafe_allow_html=True)
        if 'date_from' not in st.session_state:
            st.session_state.date_from = pd.Timestamp.now().date()
        date_from = st.date_input(" ", value=st.session_state.date_from, label_visibility="collapsed")
        st.session_state.date_from = date_from

    with col3:
        st.write("")  # Add some spacing
        st.write("")  # Add some spacing
        if st.button("→"):  # Right arrow
            if 'date_to' in st.session_state:
                # Shift dates forward by one workday
                new_date = st.session_state.date_to + pd.Timedelta(days=1)
                # Keep shifting forward until we find a weekday
                while new_date.weekday() >= 5:  # 5 is Saturday, 6 is Sunday
                    new_date += pd.Timedelta(days=1)
                st.session_state.date_from = new_date
                st.session_state.date_to = new_date

    if date_from:  # Use date_from for queries
        obj_sql_server_model = SQLServerModel()
        
        # Get stock list from the first stored procedure
        stock_list_sql = """
        exec [StockData].[usp_GetFirstBuySellStockList]
        """
        stock_list_data = obj_sql_server_model.execute_read_query(stock_list_sql, ())
        stock_list_df = pd.DataFrame(stock_list_data)
        
        if not stock_list_df.empty:
            st.write("### Select Stock")
            
            # Format for display in selectbox: "ASXCode - CompanyName"
            if 'CompanyName' in stock_list_df.columns:
                stock_options = [f"{code} - {name}" for code, name in zip(stock_list_df['ASXCode'], stock_list_df['CompanyName'])]
            else:
                stock_options = stock_list_df['ASXCode'].tolist()
            
            # Store just the ASXCode part for use in the next query
            stock_codes = stock_list_df['ASXCode'].tolist()
            
            selected_stock_option = st.selectbox("Choose a stock", stock_options, index=0)
            # Extract just the stock code (before the dash and space)
            selected_stock_code = selected_stock_option.split(' - ')[0] if ' - ' in selected_stock_option else selected_stock_option
            
            # Call the second stored procedure with date and selected stock code
            transaction_sql = """
            exec [StockData].[usp_GetFirstBuySell]
            @pdtObservationDate = ?,
            @pvchStockCode = ?
            """
            transaction_data = obj_sql_server_model.execute_read_query(transaction_sql, (date_from, selected_stock_code))
            transaction_df = pd.DataFrame(transaction_data)
            
            if not transaction_df.empty:
                # Format ObservationDateTime to show only time with seconds
                if 'ObservationDateTime' in transaction_df.columns:
                    transaction_df['ObservationDateTime'] = pd.to_datetime(transaction_df['ObservationDateTime']).dt.strftime('%H:%M:%S')
                st.write(f"### Transaction History for {selected_stock_option}")
                
                # Store data in session state to maintain state between rerenders
                if 'transaction_data' not in st.session_state:
                    st.session_state.transaction_data = transaction_df
                
                # Configure the grid display
                gb_result = GridOptionsBuilder.from_dataframe(transaction_df)
                gb_result.configure_default_column(editable=False, wrapText=False, autoHeight=False)
                
                # Set up pagination properly
                gb_result.configure_pagination(enabled=True, paginationAutoPageSize=False, paginationPageSize=300)
                gb_result.configure_grid_options(domLayout='normal')
                
                # Center-align date columns
                date_columns = [col for col in transaction_df.columns if 'Date' in col or 'Time' in col]
                for col in date_columns:
                    gb_result.configure_column(col, cellStyle={'textAlign': 'center'})
                
                # Format columns for better display
                if 'ActBuySellInd' in transaction_df.columns:
                    # Color the buy/sell indicator
                    gb_result.configure_column('ActBuySellInd', 
                                             cellStyle=JsCode("""
                                             function(params) {
                                                 if (params.value === 'B') {
                                                     return {'backgroundColor': 'rgba(0, 200, 0, 0.3)', 'textAlign': 'center'};
                                                 } else if (params.value === 'S') {
                                                     return {'backgroundColor': 'rgba(255, 0, 0, 0.3)', 'textAlign': 'center'};
                                                 }
                                                 return {'textAlign': 'center'};
                                             }
                                             """))
                
                # Add the numeric columns for volume calculations if not already present
                for col in ['FormatBid1Volume', 'FormatAsk1Volume', 'TransValue']:
                    if col in transaction_df.columns:
                        try:
                            # First check if it's already numeric
                            if pd.api.types.is_numeric_dtype(transaction_df[col]):
                                transaction_df[f'{col}_numeric'] = transaction_df[col]
                            else:
                                # It's a string, try to convert from string format
                                transaction_df[f'{col}_numeric'] = transaction_df[col].str.replace(',', '').astype(float)
                        except Exception as e:
                            st.warning(f"Could not convert {col} to numeric: {str(e)}")
                            # Initialize with zeros to prevent further errors
                            transaction_df[f'{col}_numeric'] = 0
                
                # Calculate max values safely
                max_bid_volume = transaction_df['FormatBid1Volume_numeric'].max() if 'FormatBid1Volume_numeric' in transaction_df.columns else 1
                max_ask_volume = transaction_df['FormatAsk1Volume_numeric'].max() if 'FormatAsk1Volume_numeric' in transaction_df.columns else 1
                max_trans_value = transaction_df['TransValue_numeric'].max() if 'TransValue_numeric' in transaction_df.columns else 1
                
                # Apply simple cell styles without HTML injection
                gb_result.configure_column('FormatBid1Volume', cellStyle=JsCode("""
                function(params) {
                    return { 'textAlign': 'right' };
                }
                """))
                
                gb_result.configure_column('FormatAsk1Volume', cellStyle=JsCode("""
                function(params) {
                    return { 'textAlign': 'right' };
                }
                """))
                
                # Apply simple row styling
                gb_result.configure_grid_options(
                    getRowStyle=JsCode("""
                    function(params) {
                        if (params.data && params.data.ActBuySellInd === 'B') {
                            return {'backgroundColor': 'rgba(0, 200, 0, 0.1)'};
                        } else if (params.data && params.data.ActBuySellInd === 'S') {
                            return {'backgroundColor': 'rgba(255, 0, 0, 0.1)'};
                        }
                        return null;
                    }
                    """)
                )
                
                # Add TransValue styling if the column exists
                if 'TransValue' in transaction_df.columns:
                    # Apply dynamic color coding to TransValue based on volume and buy/sell indicator
                    gb_result.configure_column('TransValue', 
                                             cellStyle=JsCode("""
                                             function(params) {
                                                 if (!params.data) return { 'textAlign': 'right' };
                                                 
                                                 const value = params.data.TransValue_numeric || 0;
                                                 const max_value = """ + str(max_trans_value) + """;
                                                 const opacity = Math.min(0.8, Math.max(0.1, value / max_value));
                                                 
                                                 if (params.data.ActBuySellInd === 'B') {
                                                     return {
                                                         'backgroundColor': `rgba(0, 128, 0, ${opacity})`,
                                                         'textAlign': 'right'
                                                     };
                                                 } else if (params.data.ActBuySellInd === 'S') {
                                                     return {
                                                         'backgroundColor': `rgba(255, 0, 0, ${opacity})`,
                                                         'textAlign': 'right'
                                                     };
                                                 }
                                                 return { 'textAlign': 'right' };
                                             }
                                             """),
                                             suppressMenu=True,
                                             width=150)
                
                grid_options_result = gb_result.build()
                
                # Display the grid with customizations
                AgGrid(
                    transaction_df, 
                    gridOptions=grid_options_result, 
                    theme="streamlit", 
                    enable_enterprise_modules=False,
                    fit_columns_on_grid_load=True,
                    allow_unsafe_jscode=True,
                    update_mode=GridUpdateMode.MODEL_CHANGED,
                    key=f"grid_{selected_stock_code}_{date_from}"
                )
            else:
                st.warning(f"No transaction data found for {selected_stock_code} on the selected date.")
        else:
            st.warning("No stock list data available. Please try another date.")
