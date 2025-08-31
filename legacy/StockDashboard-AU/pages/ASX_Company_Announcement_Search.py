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
import streamlit.components.v1 as components

int_order_type_id = 0
aud_to_usd = 0.65
st.set_page_config(page_title="Dashboard!!!", page_icon=":flag-au:",layout="wide")


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

        st.title(" :bar_chart: Announcement search")
        st.markdown('<style>div.block-container{padding-top:1rem;}</style>',unsafe_allow_html=True)    

        # HTML and JavaScript for the widget integration
        html_code = """
<!-- Widget JavaScript bundle -->
<script src="https://cloud.google.com/ai/gen-app-builder/client?hl=en_US"></script>

<!-- Search widget element (hidden by default) -->
<gen-search-widget
  configId="fd7242ce-805c-4166-8a8d-681dd4e41273"
  triggerId="searchWidgetTrigger">
</gen-search-widget>

<!-- Element that opens the widget on click -->
<input placeholder="Search here" id="searchWidgetTrigger" style="margin: 20px; padding: 10px; width: 90%;" />

<script>
// Set authorization token (replace with dynamic JWT/OAuth token fetching in production)
const searchWidget = document.querySelector('gen-search-widget');
searchWidget.authToken = "gen-ai-ann-search";
</script>
        """

        # Embed the HTML and JavaScript into the Streamlit app
        components.html(html_code, height=600, scrolling=True)
