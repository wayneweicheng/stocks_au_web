import streamlit as st
from st_aggrid import GridOptionsBuilder, AgGrid
from st_aggrid.shared import GridUpdateMode, DataReturnMode
import sys
sys.path.append('./Common')
from SQLServerHelper.SQLServerHelper import SQLServerModel
import pandas as pd
from LoginHelper.LoginHelper import sl_authenticate
from streamlit_js_eval import streamlit_js_eval
import logging
import json
import numpy as np

int_order_type_id = 0
aud_to_usd = 0.65
st.set_page_config(page_title="Dashboard!!!", page_icon=":bar_chart:",layout="wide")

def update_order_to_sql_server(pintOrderID, pdecOrderPrice, pdecOrderValue, pvchAdditionalSettings):
    try:
        obj_sql_server_model = SQLServerModel()
        output_message = ''
        obj_sql_server_model.execute_update_usp("exec [Order].[usp_UpdateOrder] @pintOrderID = ?, @pdecOrderPrice= ?, @pdecOrderValue = ?, @pvchAdditionalSettings = ?, @pvchMessage = ? output", (int(pintOrderID), pdecOrderPrice, pdecOrderValue, pvchAdditionalSettings, output_message))
        logging.info(f'Order is modified. pintOrderID - {pintOrderID}, pdecOrderPrice - {pdecOrderPrice}, pdecOrderValue - {pdecOrderValue}, pvchAdditionalSettings - {pvchAdditionalSettings}, output_message - {output_message}')
    except Exception as e:
        logging.error('Error in modify_trade_stock_to_sql_server, error - {}'.format(e))

def add_order_to_sql_server(pvchASXCode, pintUserID, pvchTradeAccountName, pintOrderTypeID, pvchOrderPriceType, pdecOrderPrice, pdecOrderValue, pvchAdditionalSettings):
    try:
        obj_sql_server_model = SQLServerModel()
        output_message = ''
        obj_sql_server_model.execute_update_usp("exec [Order].[usp_AddOrder] @pvchASXCode = ?, @pintUserID= ?, @pvchTradeAccountName =?, @pintOrderTypeID =?, @pvchOrderPriceType =?, @pdecOrderPrice= ?, @pdecOrderValue = ?, @pvchAdditionalSettings = ?, @pvchMessage = ? output", (pvchASXCode, pintUserID, pvchTradeAccountName, pintOrderTypeID, pvchOrderPriceType, pdecOrderPrice, pdecOrderValue, pvchAdditionalSettings, output_message))
        logging.info(f'Order is added. pdecOrderPrice - {pdecOrderPrice}, pdecOrderValue - {pdecOrderValue}, pvchAdditionalSettings - {pvchAdditionalSettings}, output_message - {output_message}')
    except Exception as e:
        logging.error('Error in add_order_to_sql_server, error - {}'.format(e))

def delete_order_from_sql_server(pintOrderID):
    try:
        obj_sql_server_model = SQLServerModel()
        obj_sql_server_model.execute_update_usp("exec [Order].[usp_DeleteOrder] @pintOrderID = ?", (int(pintOrderID)))
        logging.info(f'Order is deleted. pintOrderID - {pintOrderID}')
    except Exception as e:
        logging.error('Error in delete_order_from_sql_server, error - {}'.format(e))

def update_edit_rows(edited_rows, edited_df):
    for k, v in edited_rows.items():
        edit_item = edited_df.iloc[k]
        print(edit_item['OrderID'])
        print(edit_item['EntryPrice'])
        order_id = edit_item['OrderID']
        asx_code = edit_item['ASXCode']
        trade_account_name = edit_item['TradeAccountName']
        order_type_id = edit_item['OrderTypeID']
        order_type = edit_item['OrderType']
        order_price = edit_item['EntryPrice']
        volume_gt = 0
        order_value = 5000
        order_price_buffer_num_of_ticks = 0
        additional_settings = { 
            "TriggerPrice":edit_item['TriggerPrice'], 
            "TotalVolume": int(edit_item['TotalVolume']), 
            "Entry1Price": edit_item['EntryPrice'], 
            "Entry2Price": -1, 
            "StopLossPrice": edit_item['StopLossPrice'], 
            "ExitStrategy": "SmartExit", 
            "Exit1Price": edit_item['ExitPrice'], 
            "Exit2Price": -1,
            "OptionSymbol": edit_item['OptionSymbol'],
            "OptionBuySell": edit_item['OptionBuySell'],
            "BarCompletedInMin": edit_item['BarCompletedInMin']         
            }
        
        json_additional_settings = json.dumps(additional_settings)
        update_order_to_sql_server(pintOrderID = order_id, pdecOrderPrice = order_price, pdecOrderValue = order_value, pvchAdditionalSettings = json_additional_settings)
        st.write(f'Order - {order_id} is updated successfully')

def delete_rows(deleted_rows, edited_df):
    for delete in deleted_rows:
        delete_item = edited_df.iloc[delete]
    
        print(delete_item['OrderID'])
        order_id = delete_item['OrderID']
        delete_order_from_sql_server(order_id)
        st.write(f'Order - {order_id} is updated successfully')

def add_new_rows(added_rows, edited_df):
    for index, row in edited_df.iterrows():
        if row['OrderID'] > 0:
            continue
    
        print(row['OrderID'])
        print(row['EntryPrice'])
        order_id = row['OrderID']
        asx_code = row['ASXCode']
        user_id = 1
        trade_account_name = 'huanw2114'
        order_type_id = int_order_type_id
        order_price_type = 'Price'
        order_type = row['OrderType']
        order_price = row['EntryPrice']
        volume_gt = 0
        order_value = 5000
        order_price_buffer_num_of_ticks = 0
        additional_settings = { 
            "TriggerPrice":row['TriggerPrice'], 
            "TotalVolume": int(row['TotalVolume']), 
            "Entry1Price": row['EntryPrice'], 
            "Entry2Price": -1, 
            "StopLossPrice": row['StopLossPrice'], 
            "ExitStrategy": "SmartExit", 
            "Exit1Price": row['ExitPrice'], 
            "Exit2Price": -1,
            "BarCompletedInMin": bar_completed_in_min
            }
        
        json_additional_settings = json.dumps(additional_settings)
        add_order_to_sql_server(pvchASXCode = asx_code, pintUserID = user_id, pvchTradeAccountName = trade_account_name, pintOrderTypeID = order_type_id, pvchOrderPriceType = order_price_type, pdecOrderPrice = order_price, pdecOrderValue = order_value, pvchAdditionalSettings = json_additional_settings)
        st.write(f'Order - {order_id} is updated successfully')

def add_new_strategy_order(asx_code, trigger_price, total_volume, entry_price, stop_loss_price, exit_price, option_symbol, option_buy_sell, bar_completed_in_min):
    user_id = 1
    trade_account_name = 'huanw2114'
    order_type_id = int_order_type_id
    order_price_type = 'Price'
    order_value = 5000
    order_price = entry_price
    additional_settings = { 
        "TriggerPrice":trigger_price, 
        "TotalVolume": int(total_volume), 
        "Entry1Price": entry_price, 
        "Entry2Price": -1, 
        "StopLossPrice": stop_loss_price, 
        "ExitStrategy": "SmartExit", 
        "Exit1Price": exit_price, 
        "Exit2Price": -1,
        "OptionSymbol": option_symbol,
        "OptionBuySell": option_buy_sell,
        "BarCompletedInMin": bar_completed_in_min
        }
    
    json_additional_settings = json.dumps(additional_settings)
    add_order_to_sql_server(pvchASXCode = asx_code, pintUserID = user_id, pvchTradeAccountName = trade_account_name, pintOrderTypeID = order_type_id, pvchOrderPriceType = order_price_type, pdecOrderPrice = order_price, pdecOrderValue = order_value, pvchAdditionalSettings = json_additional_settings)

def create_empty_df():
    df = pd.DataFrame(columns=['OrderID', 'BarCompletedInMin', 'ASXCode', 'TradeAccountName', 'OrderTypeID', 'TriggerPrice', 'TotalVolume', 'EntryPrice', 'StopLossPrice', 'ExitStrategy', 'ExitPrice', 'PotentialLoss', 'PotentialProfit', 'ProfitLossRatio', 'OrderType', 'CreateDate'])
    df = df.astype({
        'OrderID': np.int64, 
        'OrderTypeID': np.int64, 
        'TriggerPrice': np.float64, 
        'TotalVolume': np.int64, 
        'EntryPrice': np.float64, 
        'StopLossPrice': np.float64, 
        'ExitPrice': np.float64, 
        'PotentialLoss': np.float64, 
        'PotentialProfit': np.float64, 
        'ProfitLossRatio': np.float64, 
        'CreateDate': np.datetime64
    })
    return df

debug = False
if debug == True:
    pass
else:
    name, authentication_status, username, authenticator = sl_authenticate()

    if authentication_status == False:
        st.error("Username/password is incorrect")

    if authentication_status == None:
        st.warning("Please enter your username and password")

if debug or authentication_status:
    if not debug:
        st.sidebar.header(f"User name: {name}")    
        authenticator.logout("Logout", "sidebar")

    if username not in ['waynecheng']:
        st.markdown(f'Hi {name}, your role does not have permission to this page.')
    else:        

        st.title(" :bar_chart: Strategy Order")
        st.markdown('<style>div.block-container{padding-top:1rem;}</style>',unsafe_allow_html=True)    

        obj_sql_server_model = SQLServerModel()
        sql_order_type = obj_sql_server_model.execute_read_usp(f"exec [Order].[usp_GetStrategyOrderType] @pbitDebug = ?", (0))
        df_order_type = pd.DataFrame(sql_order_type)
        
        order_type_id = st.selectbox(
            "Choose the equity code:",
            options=df_order_type
        )
        int_order_type_id = int(order_type_id.split(': ')[0])

        sql_data_pre = obj_sql_server_model.execute_read_usp(f"exec [Order].[usp_GetStrategyOrder] @pintOrderTypeID = ?", (int_order_type_id))
        df = pd.DataFrame(sql_data_pre)
        if len(df) > 0:
            df[['TriggerPrice', 'EntryPrice', 'StopLossPrice', 'ExitPrice']] = df[['TriggerPrice', 'EntryPrice', 'StopLossPrice', 'ExitPrice']].apply(pd.to_numeric)

        original_df = df.copy(deep=True)
        edited_df = st.data_editor(
            df, 
            column_config={
                "OrderID": st.column_config.NumberColumn(disabled=True),
                # "ASXCode": st.column_config.TextColumn(disabled=True),
                "TradeAccountName": st.column_config.TextColumn(disabled=True),
                "OrderTypeID": st.column_config.NumberColumn(disabled=True),
                "OrderType": st.column_config.TextColumn(disabled=True),
                "ExitStrategy": st.column_config.TextColumn(disabled=True),
                "TriggerPrice": st.column_config.NumberColumn(
                    "TriggerPrice",
                    help="The price above which order can be triggered",
                    min_value=0.0,
                    max_value=10000.0
                )
            },
            num_rows="dynamic", key="OrderId", hide_index = False, use_container_width=True
        )
        submit_button = st.button("Submit")

        st.markdown("""---""")

        col1, col2 = st.columns([1, 2])
        sql_trade_symbol = obj_sql_server_model.execute_read_usp(f"exec [StockAPI].[usp_GetUSTradeSymbol]", ())
        df_trade_symbol = pd.DataFrame(sql_trade_symbol)   

        trade_symbol = df_trade_symbol["ASXCode"].unique()
        # sorted_equity_code_options = sorted(equity_code_options) 
        select_trade_symbol = col1.selectbox(
            "Choose the trade symbol:",
            options=trade_symbol,
            index=0
        )     

        asx_code = select_trade_symbol

        select_option_buy_sell = col1.selectbox(
            "Buy or sell an option:",
            options=['N/A', 'SELL', 'BUY'],
            index=0
        )     

        if select_option_buy_sell in ('SELL', 'BUY'):
            sql_option_symbol = obj_sql_server_model.execute_read_usp(f"exec [StockAPI].[usp_GetUSOptionSymbol] @pvchASXCode = ?", (asx_code))
            df_option_symbol = pd.DataFrame(sql_option_symbol)   

            select_option_symbol = col1.selectbox(
                "Choose the option symbol:",
                options=df_option_symbol['OptionSymbol'].unique(),
                index=0
            )  
            option_symbol = select_option_symbol
        else:
            option_symbol = None

        trigger_price = col1.number_input('TriggerPrice')
        total_volume = col1.number_input('OrderVolume')
        entry_price = col1.number_input('EntryPrice')
        stop_loss_price = col1.number_input('StopLossPrice')
        exit_price = col1.number_input('ExitPrice')
        bar_completed_in_min = col1.selectbox(
            "Bar Complete In Mins:",
            options=['5 mins', '15 mins', '30 mins', '1 hour'],
            index=2
        )
        validate_order = col1.button('Validate Order')
        add_order = col1.button('Add Order')
        
        if add_order:
            if int_order_type_id == -1:
                st.markdown('Please choose an order type.')            
            else:        
                add_new_strategy_order(asx_code, trigger_price, total_volume, entry_price, stop_loss_price, exit_price, option_symbol, select_option_buy_sell, bar_completed_in_min)
                col2.write(f'Order is added successfully')
                streamlit_js_eval(js_expressions="parent.window.location.reload()") 

        if validate_order:
            if not '.US' in asx_code:
                col2.warning('Stock code name is invalid.')
            if not trigger_price > 0:
                col2.warning('Please provide trigger price.')
            if not total_volume > 0:
                col2.warning('Please provide order volume.')
            if not entry_price > 0:
                col2.warning('Please provide entry price.')
            if not stop_loss_price > 0:
                col2.warning('Please provide stop loss price.')
            if not exit_price > 0:
                col2.warning('Please provide exit price.')
            if '.US' in asx_code and trigger_price > 0 and total_volume > 0 and entry_price > 0 and stop_loss_price > 0 and exit_price > 0:
                if '_' in asx_code: 
                    potential_loss = (entry_price - stop_loss_price)*total_volume*5
                else:
                    potential_loss = (entry_price - stop_loss_price)*total_volume
                if '_' in asx_code: 
                    potential_profit = (exit_price - entry_price)*total_volume*5
                else:
                    potential_profit = (exit_price - entry_price)*total_volume
                profit_loss_ratio = potential_profit/potential_loss if potential_loss > 0 else None
                perc_change_win = abs((exit_price - entry_price)*100/entry_price)
                perc_change_loss = abs((entry_price - stop_loss_price)*100/entry_price)
                
                trade_value = entry_price*total_volume
                st.info(f'Trade value: {int(trade_value/aud_to_usd):,} aud, Potential loss: {int(potential_loss/aud_to_usd):,} aud ({perc_change_loss:.2f}%), Potential profit: {int(potential_profit/aud_to_usd):,} aud ({perc_change_win:.2f}%), profit_loss_ratio: {profit_loss_ratio:.2f}')

        st.markdown("""---""")

        st.write(st.session_state)

        if submit_button:
            edited_rows = st.session_state.OrderId['edited_rows']
            if edited_rows:
                update_edit_rows(edited_rows, edited_df)
            deleted_rows = st.session_state.OrderId['deleted_rows']
            if deleted_rows:
                delete_rows(deleted_rows, original_df)

            streamlit_js_eval(js_expressions="parent.window.location.reload()") 

            added_rows = st.session_state.OrderId['added_rows']
            if added_rows:
                st.markdown('Please use the form to add strategy order.')                                    
                # if int_order_type_id == -1:
                #     st.markdown('Please choose an order type.')            
                # else:        
                #     add_new_rows(added_rows, edited_df)
            
