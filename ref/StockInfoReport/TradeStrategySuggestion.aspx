<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="TradeStrategySuggestion.aspx.cs" Inherits="StockInfoReport.TradeStrategySuggestion" EnableEventValidation="false" Title="Trade Strategy Suggestion"%>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
    <div><a href="Default.aspx">Click to go to the main page</a><br /><br /></div>
        <br />
        Select Item: <asp:DropDownList ID ="ddlOrderBy" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlOrderBy_SelectedIndexChanged">          
            <%--<asp:ListItem>Norm MF Rank Long</asp:ListItem>
            <asp:ListItem>Norm MF Rank Short</asp:ListItem>
            <asp:ListItem>Weekly Top 1to50</asp:ListItem>
            <asp:ListItem>Weekly Top 51to100</asp:ListItem>

            --%>

            <asp:ListItem>Tree Shake Morning Market</asp:ListItem>
            <asp:ListItem>Break Out Retrace</asp:ListItem>
            <asp:ListItem>Retreat To Weekly MA10</asp:ListItem>
            <asp:ListItem>Broker Buy Retail Sell</asp:ListItem>
            <asp:ListItem>Broker Buy Retail Sell - 3 Days</asp:ListItem>
            <asp:ListItem>Broker Buy Retail Sell - 5 Days</asp:ListItem>
            <asp:ListItem>Broker Buy Retail Sell - 10 Days</asp:ListItem>
            <asp:ListItem>Heavy Retail Sell</asp:ListItem>
            <asp:ListItem>Heavy Retail Sell - 3 Days</asp:ListItem>
            <asp:ListItem>Heavy Retail Sell - 5 Days</asp:ListItem>
            <asp:ListItem>Broker Buy Price (recent 1, 3, 5, 10 days)</asp:ListItem>
            <asp:ListItem>High Buy vs Sell</asp:ListItem>
            <asp:ListItem>Today Close Cross Over VWAP</asp:ListItem>
            <asp:ListItem>Broker New Buy Report (Today only)</asp:ListItem>
            <asp:ListItem>Director Subscribe SPP</asp:ListItem>
            <asp:ListItem>Gold Interception</asp:ListItem>
            <asp:ListItem>Top 20 Holder Stocks</asp:ListItem>
            <asp:ListItem>Price Swing Stocks</asp:ListItem>
            <asp:ListItem>Break Through Previous Break Through High</asp:ListItem>
            <asp:ListItem>Long Bullish Bar</asp:ListItem>
            <asp:ListItem>Volume Volatility Contraction</asp:ListItem>
            <asp:ListItem>High Probability Pair Broker Setup</asp:ListItem>
            <asp:ListItem>Price Break Through Placement Price</asp:ListItem>
            <asp:ListItem>Monitor Stocks Price Retrace</asp:ListItem>   
            <asp:ListItem>Advanced FRCS</asp:ListItem>
            <asp:ListItem>Advanced HBXF</asp:ListItem>
            <asp:ListItem>New High Minor Retrace</asp:ListItem>
            <asp:ListItem>Most Recent Tweet</asp:ListItem>
            <asp:ListItem>ChiX Analysis</asp:ListItem>
            <asp:ListItem>Final Institute Dump</asp:ListItem>
            <asp:ListItem>Bullish Bar Cross MA</asp:ListItem>
            <asp:ListItem>Institute Performance High Buy</asp:ListItem>
            <asp:ListItem>Institute Performance High Participation</asp:ListItem>
            <asp:ListItem>Low Market Cap</asp:ListItem>
            <asp:ListItem>Announcement Search Result</asp:ListItem>
            <asp:ListItem>Breakaway Gap</asp:ListItem>
            <asp:ListItem>Sign of Bull Run</asp:ListItem>
            <asp:ListItem>Break Last 3d VWAP</asp:ListItem>
            <asp:ListItem>Today Market Scan</asp:ListItem>
            <asp:ListItem>Stock Strong Buys</asp:ListItem>
            <asp:ListItem>Tip System</asp:ListItem>
            <asp:ListItem>Trace Momentum Stock (Today Only)</asp:ListItem>            
        </asp:DropDownList>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; Number of Previous Days from Today:  &nbsp
        <asp:TextBox ID="txtNumPrevDay" runat="server" Width="90px" TextMode="Number" AutoPostBack="True" OnTextChanged="txtNumPrevDay_TextChanged"></asp:TextBox>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 
        <asp:HyperLink id="hlBatchChart" NavigateUrl="#" Text="Click to view batch stock charts" runat="server"/> 
        <p></p>

        Trade Strategy Result<br />
        <asp:GridView ID="gvDataSet1" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet1_PageIndexChanging" OnRowDataBound="gvDataSet1_RowDataBound" OnRowCreated="gvDataSe1_RowCreated" OnRowCommand="gvDataSet1_RowCommand" PageSize="100" Font-Size="X-Small" PagerSettings-PageButtonCount="20">
            <AlternatingRowStyle BackColor="White" ForeColor="#284775" />
            <EditRowStyle BackColor="#999999" />
            <FooterStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
            <HeaderStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
            <PagerStyle BackColor="#284775" ForeColor="White" HorizontalAlign="Center" />
            <RowStyle BackColor="#F7F6F3" ForeColor="#333333" />
            <SelectedRowStyle BackColor="#E2DED6" Font-Bold="True" ForeColor="#333333" />
            <SortedAscendingCellStyle BackColor="#E9E7E2" />
            <SortedAscendingHeaderStyle BackColor="#506C8C" />
            <SortedDescendingCellStyle BackColor="#FFFDF8" />
            <SortedDescendingHeaderStyle BackColor="#6F8DAE" />
            <Columns>
                <asp:buttonfield buttontype="Button" commandname="ViewChart" headertext="View in HC" text="View Chart"/>
                <asp:buttonfield buttontype="Button" commandname="ViewCourseOfSale" headertext="View CourseOfSale" text="View CourseOfSale"/>
                <%--<asp:buttonfield buttontype="Button" commandname="ViewHC" headertext="View HC" text="View HC"/>--%>
                <%--<asp:buttonfield buttontype="Button" commandname="ViewTop20" headertext="View Top 20" text="View Top 20"/>--%>    
                <asp:buttonfield buttontype="Button" commandname="ViewBrokerData" headertext="View Broker Data" text="View Broker Data"/>
                <asp:buttonfield buttontype="Button" commandname="ViewInsight" headertext="View Insight" text="View Insight"/>
            </Columns>
        </asp:GridView>
        <br />
        <%--Common Stock Plus<br />
        <asp:GridView ID="gvDataSet2" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" GridLines="None" OnPageIndexChanging="gvDataSet2_PageIndexChanging" OnRowDataBound="gvDataSet2_RowCreated" OnRowCreated="gvDataSet2_RowDataBound" PageSize="20" Font-Size="Small" PagerSettings-PageButtonCount="20">
            <AlternatingRowStyle BackColor="White" ForeColor="#284775" />
            <EditRowStyle BackColor="#999999" />
            <FooterStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
            <HeaderStyle BackColor="#5D7B9D" Font-Bold="True" ForeColor="White" />
            <PagerStyle BackColor="#284775" ForeColor="White" HorizontalAlign="Center" />
            <RowStyle BackColor="#F7F6F3" ForeColor="#333333" />
            <SelectedRowStyle BackColor="#E2DED6" Font-Bold="True" ForeColor="#333333" />
            <SortedAscendingCellStyle BackColor="#E9E7E2" />
            <SortedAscendingHeaderStyle BackColor="#506C8C" />
            <SortedDescendingCellStyle BackColor="#FFFDF8" />
            <SortedDescendingHeaderStyle BackColor="#6F8DAE" />
        </asp:GridView>--%>
        <br />
        <br />
    </form>
</body>
</html>
