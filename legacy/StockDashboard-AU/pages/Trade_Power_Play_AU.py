import streamlit as st
import pandas as pd
import warnings
import sys
from copy import deepcopy
sys.path.append('./Common')
from SQLServerHelper.SQLServerHelper import SQLServerModel
from LoginHelper.LoginHelper import sl_authenticate
from st_aggrid import AgGrid, GridOptionsBuilder
import plotly.graph_objects as go
from plotly.subplots import make_subplots
warnings.filterwarnings('ignore')

st.set_page_config(page_title="Trade Power Play AU", page_icon=":bar_chart:", layout="wide")

@st.cache_data(ttl=90)
def get_tick_data(stock_code, date_from, date_to):
    obj_sql_server_model = SQLServerModel()
    sql = """
    select top 3 
        ASXCode,
        SaleDateTime,
        ObservationDate,
        Price,
        Quantity,
        SaleValue,
        FormatedSaleValue,
        PriceBid,
        SizeBid,
        PriceAsk,
        SizeAsk,
        DateFrom,
        DateTo
    from Transform.StockTickSaleVsBidAsk with(nolock)
    where ASXCode = ?
    and ObservationDate >= ?
    and ObservationDate <= ?
    order by SaleDateTime desc
    """
    sql_data = obj_sql_server_model.execute_read_query(sql, (stock_code, date_from, date_to))
    return pd.DataFrame(sql_data)

@st.cache_data(ttl=90)
def get_institute_summary(stock_code, date_from, date_to):
    obj_sql_server_model = SQLServerModel()
    sql = """
    select 
        DerivedInstitute, 
        DerivedBuySellInd, 
        count(*) as NumTrades, 
        format(sum(Quantity), 'N0') as Quantity, 
        format(sum(SaleValue), 'N0') as SaleValue, 
        cast(sum(SaleValue)*1.0/sum(Quantity) as decimal(10,3)) as VWAP
    from Transform.StockTickSaleVsBidAsk
    where ASXCode = ?
    and ObservationDate >= ?
    and ObservationDate <= ?
    group by DerivedBuySellInd, DerivedInstitute
    order by DerivedInstitute, DerivedBuySellInd
    """
    sql_data = obj_sql_server_model.execute_read_query(sql, (stock_code, date_from, date_to))
    return pd.DataFrame(sql_data)

name, authentication_status, username, authenticator = sl_authenticate()

if authentication_status == False:
    st.error("Username/password is incorrect")

if authentication_status == None:
    st.warning("Please enter your username and password")

if authentication_status:
    st.sidebar.header(f"User name: {name}")    
    authenticator.logout("Logout", "sidebar")
    st.title("Trade Power Play AU")
    st.markdown('<style>div.block-container{padding-top:1rem;}</style>', unsafe_allow_html=True)

    # Input parameters
    col1, col2, col3 = st.columns(3)
    
    with col1:
        stock_code = st.text_input("Stock Code", value="MEK.AX")
    
    # Initialize dates in session state if not present
    if 'date_from' not in st.session_state:
        st.session_state.date_from = pd.Timestamp.now().date()
    if 'date_to' not in st.session_state:
        st.session_state.date_to = pd.Timestamp.now().date()
    
    with col2:
        left_col, date_col, right_col = st.columns([1,4,1])
        
        with left_col:
            if st.button("←"):
                # Move to previous business day
                prev_day = pd.Timestamp(st.session_state.date_from) - pd.Timedelta(days=1)
                while prev_day.weekday() > 4:  # Skip weekends
                    prev_day -= pd.Timedelta(days=1)
                st.session_state.date_from = prev_day.date()
                st.session_state.date_to = prev_day.date()
                st.rerun()
                
        with date_col:
            date_from = st.date_input("Date From", value=st.session_state.date_from)
    
    with col3:
        left_col, date_col, right_col = st.columns([1,4,1])
        
        with date_col:
            date_to = st.date_input("Date To", value=st.session_state.date_to)
            
        with right_col:
            if st.button("→"):
                # Move to next business day
                next_day = pd.Timestamp(st.session_state.date_from) + pd.Timedelta(days=1)
                while next_day.weekday() > 4:  # Skip weekends
                    next_day += pd.Timedelta(days=1)
                st.session_state.date_from = next_day.date()
                st.session_state.date_to = next_day.date()
                st.rerun()

    # Store the dates in session state
    st.session_state.date_from = date_from
    st.session_state.date_to = date_to

    if stock_code and date_from and date_to:
        # Get and display tick data
        st.subheader("Recent Trades")
        tick_df = get_tick_data(stock_code, date_from, date_to)
        
        if not tick_df.empty:
            gb_tick = GridOptionsBuilder.from_dataframe(tick_df)
            gb_tick.configure_default_column(editable=False, wrapText=True, autoHeight=True)
            gb_tick.configure_pagination(paginationAutoPageSize=False, paginationPageSize=10)
            grid_options_tick = gb_tick.build()
            AgGrid(tick_df, gridOptions=grid_options_tick, theme="streamlit", enable_enterprise_modules=False)
        else:
            st.warning("No recent trades found for the selected date.")

        # Get and display institute summary
        st.subheader("Institute Trading Summary")
        summary_df = get_institute_summary(stock_code, date_from, date_to)
        
        if not summary_df.empty:
            # Display the grid
            gb_summary = GridOptionsBuilder.from_dataframe(summary_df)
            gb_summary.configure_default_column(editable=False, wrapText=True, autoHeight=True)
            gb_summary.configure_pagination(paginationAutoPageSize=False, paginationPageSize=10)
            grid_options_summary = gb_summary.build()
            AgGrid(summary_df, gridOptions=grid_options_summary, theme="streamlit", enable_enterprise_modules=False)

            # Create the visualization
            st.subheader("Institute Trading Analysis")
            
            # Convert SaleValue from formatted string to numeric
            summary_df['SaleValue_Numeric'] = summary_df['SaleValue'].str.replace(',', '').astype(float)
            
            # Replace values in DerivedInstitute and DerivedBuySellInd
            summary_df['DerivedInstitute'] = summary_df['DerivedInstitute'].replace({
                None: 'Unknown',
                False: 'Retail',
                True: 'Institute'
            })
            
            summary_df['DerivedBuySellInd'] = summary_df['DerivedBuySellInd'].replace({
                None: 'Unknown',
                'S': 'Sell',
                'B': 'Buy'
            })
            
            # Filter out Unknown (Unknown) entries
            summary_df = summary_df[~((summary_df['DerivedInstitute'] == 'Unknown') & 
                                    (summary_df['DerivedBuySellInd'] == 'Unknown'))]
            
            # Create figure with secondary y-axis
            fig = make_subplots(specs=[[{"secondary_y": True}]])

            # Sort the dataframe to ensure consistent ordering
            summary_df = summary_df.sort_values(['DerivedInstitute', 'DerivedBuySellInd'])
            
            # Add bars for each row
            for _, row in summary_df.iterrows():
                pattern_shape = {
                    'Institute': '',      # solid fill for Institute
                    'Retail': '/',        # diagonal stripes for Retail
                    'Unknown': '.'        # dots for Unknown
                }[row['DerivedInstitute']]
                
                color = 'rgb(0, 128, 0)' if row['DerivedBuySellInd'] == 'Buy' else 'rgb(255, 0, 0)'
                
                fig.add_trace(
                    go.Bar(
                        x=[f"{row['DerivedInstitute']} ({row['DerivedBuySellInd']})"],
                        y=[row['SaleValue_Numeric']],
                        name=f"{row['DerivedInstitute']} ({row['DerivedBuySellInd']})",
                        text=[f"${row['SaleValue']}"],
                        textposition='outside',
                        textfont=dict(
                            color='black',
                            size=12
                        ),
                        marker=dict(
                            color=color,
                            pattern_shape=pattern_shape,
                            pattern=dict(
                                solidity=0.7  # Make the pattern less dense
                            ) if pattern_shape else None
                        ),
                        showlegend=False
                    ),
                    secondary_y=False,
                )

            # Add VWAP line after sorting to maintain consistent order
            fig.add_trace(
                go.Scatter(
                    x=[f"{row['DerivedInstitute']} ({row['DerivedBuySellInd']})" for _, row in summary_df.iterrows()],
                    y=summary_df['VWAP'],
                    name="VWAP",
                    line=dict(color='rgb(0, 0, 255)', width=2)
                ),
                secondary_y=True,
            )

            # Create custom legend
            for institute in ['Institute', 'Retail', 'Unknown']:
                pattern = {
                    'Institute': '',      # solid fill for Institute
                    'Retail': '/',        # diagonal stripes for Retail
                    'Unknown': '.'        # dots for Unknown
                }[institute]
                
                # Add invisible bar just for legend
                fig.add_trace(
                    go.Bar(
                        x=[None],
                        y=[None],
                        name=institute,
                        marker=dict(
                            pattern_shape=pattern,
                            pattern=dict(
                                solidity=0.7  # Make the pattern less dense
                            ) if pattern else None,
                            color='rgba(0,0,0,0.5)'
                        )
                    ),
                    secondary_y=False
                )

            # Add Buy/Sell to legend
            fig.add_trace(
                go.Bar(
                    x=[None],
                    y=[None],
                    name='Buy',
                    marker_color='rgb(0, 128, 0)',
                    showlegend=True
                ),
                secondary_y=False
            )
            
            fig.add_trace(
                go.Bar(
                    x=[None],
                    y=[None],
                    name='Sell',
                    marker_color='rgb(255, 0, 0)',
                    showlegend=True
                ),
                secondary_y=False
            )

            # Add figure title
            fig.update_layout(
                title_text=f"Institute Trading Analysis for {stock_code}",
                barmode='stack',
                xaxis=dict(
                    title="Institute (Buy/Sell)",
                    categoryorder='array',
                    categoryarray=[f"{row['DerivedInstitute']} ({row['DerivedBuySellInd']})" for _, row in summary_df.iterrows()]
                ),
                height=600,
                # Update legend
                showlegend=True,
                legend=dict(
                    orientation="h",
                    yanchor="bottom",
                    y=1.02,
                    xanchor="right",
                    x=1
                )
            )

            # Set y-axes titles
            fig.update_yaxes(title_text="Sale Value", secondary_y=False)
            fig.update_yaxes(title_text="VWAP", secondary_y=True)

            st.plotly_chart(fig, use_container_width=True)
        else:
            st.warning("No trading summary data found for the selected date range.")
