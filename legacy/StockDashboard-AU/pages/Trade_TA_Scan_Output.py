import streamlit as st
import pandas as pd
import warnings
import sys
sys.path.append('./Common')
from SQLServerHelper.SQLServerHelper import SQLServerModel
from LoginHelper.LoginHelper import sl_authenticate
from st_aggrid import AgGrid, GridOptionsBuilder
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import numpy as np
warnings.filterwarnings('ignore')

st.set_page_config(page_title="Stock Scan Results", page_icon=":bar_chart:", layout="wide")

name, authentication_status, username, authenticator = sl_authenticate()

if authentication_status == False:
    st.error("Username/password is incorrect")

if authentication_status == None:
    st.warning("Please enter your username and password")

if authentication_status:
    st.sidebar.header(f"User name: {name}")    
    authenticator.logout("Logout", "sidebar")
    st.title("Stock Scan Results")
    st.markdown('<style>div.block-container{padding-top:1rem;}</style>', unsafe_allow_html=True)

    # Sort options
    sort_options = [
        "Price Changes",
        "Alert CreateDate",
        "Alert Occurrence",
        "Alert Type Name",
        "Market Cap",
        "Value Over MC"
    ]
    
    # Create row for sort selection
    st.write("### Select Sort Option")
    selected_sort = st.selectbox("Choose a sort option", sort_options, index=0)  # Set "Price Changes" as default

    # Create columns for date inputs and arrow buttons
    col1, col2, col3, col4 = st.columns([1, 4, 4, 1])

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
        if 'date_from' not in st.session_state:
            st.session_state.date_from = pd.Timestamp.now().date()
        date_from = st.date_input("Date From", value=st.session_state.date_from)
        st.session_state.date_from = date_from

    with col3:
        if 'date_to' not in st.session_state:
            st.session_state.date_to = pd.Timestamp.now().date()
        date_to = st.date_input("Date To", value=st.session_state.date_to)
        st.session_state.date_to = date_to

    with col4:
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

    if date_from:  # Only date_from is used, date_to is not used in SQL query
        obj_sql_server_model = SQLServerModel()
        
        # Call the stored procedure with date and sort option
        sql = """
        exec [Report].[usp_GetStockScanResult_By_Date]
        @pvchSortBy = ?,
        @pdtObservationDate = ?
        """
        sql_data = obj_sql_server_model.execute_read_query(sql, (selected_sort, date_from))
        result_df = pd.DataFrame(sql_data)

        if not result_df.empty:
            st.write(f"### Scan Results - Sorted by: {selected_sort}")
            
            # Configure the grid display
            gb_result = GridOptionsBuilder.from_dataframe(result_df)
            gb_result.configure_default_column(editable=False, wrapText=True, autoHeight=True)
            gb_result.configure_pagination(paginationAutoPageSize=False, paginationPageSize=30)
            grid_options_result = gb_result.build()
            AgGrid(result_df, gridOptions=grid_options_result, theme="streamlit", enable_enterprise_modules=False)

            # Determine if we should show visualizations based on the data structure
            has_trading_columns = all(col in result_df.columns for col in ['ASXCode', 'inb_FormatSaleValue', 'ins_FormatSaleValue', 'reb_FormatSaleValue', 'res_FormatSaleValue'])
            has_price_changes = all(col in result_df.columns for col in ['ASXCode', 'TomorrowChange', 'Next2DaysChange'])
            
            if has_trading_columns and has_price_changes:
                # Create two columns for the charts
                col_left, col_right = st.columns([0.7, 0.3])

                with col_left:
                    # Convert format values to numeric by removing commas and converting to float
                    for field in ['inb_FormatSaleValue', 'ins_FormatSaleValue', 'reb_FormatSaleValue', 'res_FormatSaleValue']:
                        result_df[f'{field}_numeric'] = result_df[field].str.replace(',', '').astype(float)

                    # Calculate total for each stock
                    result_df['total_value'] = (result_df['inb_FormatSaleValue_numeric'] + 
                                              result_df['ins_FormatSaleValue_numeric'] + 
                                              result_df['reb_FormatSaleValue_numeric'] + 
                                              result_df['res_FormatSaleValue_numeric'])

                    # Calculate percentages
                    for field in ['inb_FormatSaleValue', 'ins_FormatSaleValue', 'reb_FormatSaleValue', 'res_FormatSaleValue']:
                        result_df[f'{field}_pct'] = result_df[f'{field}_numeric'] * 100 / result_df['total_value']

                    # Sort the DataFrame by Institute Buy value
                    result_df = result_df.sort_values('inb_FormatSaleValue_numeric', ascending=False).reset_index(drop=True)

                    # Create better legend labels mapping
                    legend_labels = {
                        'inb_FormatSaleValue': 'Institute_Buy_%',
                        'ins_FormatSaleValue': 'Institute_Sell_%',
                        'reb_FormatSaleValue': 'Retail_Buy_%',
                        'res_FormatSaleValue': 'Retail_Sell_%'
                    }

                    # Trading values chart
                    fig1 = make_subplots()

                    # Add bars for each of the specified fields - using percentage values
                    for field in ['inb_FormatSaleValue', 'ins_FormatSaleValue', 'reb_FormatSaleValue', 'res_FormatSaleValue']:
                        fig1.add_trace(
                            go.Bar(
                                x=result_df[f'{field}_pct'],
                                y=result_df['ASXCode'],
                                name=legend_labels[field],
                                text=result_df[f'{field}_pct'].round(1).astype(str) + '%',
                                textposition='auto',
                                orientation='h',
                                textfont=dict(size=14),
                                hovertemplate="<b>%{y}</b><br>" +
                                            f"{legend_labels[field]}<br>" +
                                            "Percentage: %{x:.1f}%<br>" +
                                            "Value: %{customdata}<br>" +
                                            "<extra></extra>",
                                customdata=result_df[field]
                            )
                        )

                    # Update layout for the trading values figure
                    fig1.update_layout(
                        title_text="Trading Distribution by ASX Code",
                        barmode='group',
                        xaxis_title="Percentage of Total Value",
                        yaxis_title="ASX Code",
                        legend_title="Type",
                        height=max(800, len(result_df) * 50),
                        width=800,
                        yaxis={
                            'categoryorder': 'array',
                            'categoryarray': result_df['ASXCode'].tolist()[::-1],
                            'tickfont': {'size': 14},
                            'showgrid': False,
                        },
                        xaxis={
                            'range': [0, 100],
                            'tickfont': {'size': 14}
                        },
                        legend={
                            'font': {'size': 14},
                            'orientation': 'h',
                            'yanchor': 'bottom',
                            'y': 1.1,
                            'xanchor': 'right',
                            'x': 1
                        },
                        margin=dict(l=200, r=100, t=100, b=50),
                        plot_bgcolor='white'
                    )

                    # Calculate line positions once for both charts
                    line_positions = [(i + 0.5) for i in range(len(result_df) - 1)]

                    # Add horizontal lines between stocks for fig1
                    for y_position in line_positions:
                        fig1.add_shape(
                            type="line",
                            x0=0,
                            x1=100,
                            y0=y_position,
                            y1=y_position,
                            line=dict(color="lightgray", width=1)
                        )

                    st.plotly_chart(fig1, use_container_width=True)

                with col_right:
                    # Create price changes chart
                    fig2 = make_subplots()

                    # Fill NA/None values with 0 for color mapping and convert to float
                    tomorrow_changes = result_df['TomorrowChange'].fillna(0).astype(float)
                    next2days_changes = result_df['Next2DaysChange'].fillna(0).astype(float)

                    # Add bars for tomorrow change
                    fig2.add_trace(
                        go.Bar(
                            x=tomorrow_changes,
                            y=result_df['ASXCode'],
                            name='Tomorrow',
                            text=[f"{x:+.1f}%" if pd.notnull(x) else "N/A" for x in result_df['TomorrowChange']],
                            textposition='auto',
                            orientation='h',
                            marker_color=['red' if x < 0 else 'green' if x > 0 else 'gray' for x in tomorrow_changes],
                            hovertemplate="<b>%{y}</b><br>" +
                                        "Tomorrow Change: %{text}<br>" +
                                        "<extra></extra>"
                        )
                    )

                    # Add bars for next 2 days change with striped pattern
                    fig2.add_trace(
                        go.Bar(
                            x=next2days_changes,
                            y=result_df['ASXCode'],
                            name='Next 2 Days',
                            text=[f"{x:+.1f}%" if pd.notnull(x) else "N/A" for x in result_df['Next2DaysChange']],
                            textposition='auto',
                            orientation='h',
                            marker=dict(
                                color=['red' if x < 0 else 'green' if x > 0 else 'gray' for x in next2days_changes],
                                pattern=dict(
                                    shape="/",
                                    solidity=0.5
                                )
                            ),
                            hovertemplate="<b>%{y}</b><br>" +
                                        "Next 2 Days Change: %{text}<br>" +
                                        "<extra></extra>"
                        )
                    )

                    # Calculate min and max changes after converting to float
                    min_change = min(min(tomorrow_changes), min(next2days_changes)) * 1.1  # Add 10% padding
                    max_change = max(max(tomorrow_changes), max(next2days_changes)) * 1.1  # Add 10% padding
                    
                    # Add horizontal lines between stocks for fig2 using the same positions
                    for y_position in line_positions:
                        fig2.add_shape(
                            type="line",
                            x0=min_change,
                            x1=max_change,
                            y0=y_position,
                            y1=y_position,
                            line=dict(color="lightgray", width=1)
                        )

                    # Update xaxis range after adding the lines
                    fig2.update_layout(
                        title_text="Price Changes",
                        barmode='group',
                        xaxis_title="Percentage Change",
                        yaxis_title="",
                        height=max(800, len(result_df) * 50),
                        width=400,
                        yaxis={
                            'categoryorder': 'array',
                            'categoryarray': result_df['ASXCode'].tolist()[::-1],
                            'tickfont': {'size': 14},
                            'showticklabels': False,
                            'showgrid': False,
                        },
                        xaxis={
                            'tickfont': {'size': 14},
                            'zeroline': True,
                            'zerolinewidth': 2,
                            'zerolinecolor': 'black'
                        },
                        legend={
                            'font': {'size': 14},
                            'orientation': 'h',
                            'yanchor': 'bottom',
                            'y': 1.1,
                            'xanchor': 'right',
                            'x': 1
                        },
                        margin=dict(l=0, r=100, t=100, b=50),
                        plot_bgcolor='white',
                        xaxis_range=[min_change, max_change]
                    )

                    st.plotly_chart(fig2, use_container_width=True)
        else:
            st.warning(f"No scan results found with sort option '{selected_sort}' on the selected date.")
