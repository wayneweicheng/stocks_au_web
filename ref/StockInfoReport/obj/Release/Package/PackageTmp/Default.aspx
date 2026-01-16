    <%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Default.aspx.cs" Inherits="StockInfoReport.Default" Title="Default Page" %>
<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js" type="text/javascript"></script>
<script src="https://code.highcharts.com/highcharts.js" type="text/javascript"></script>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">    
    <div>
        <h3>Please choose the followings options:</h3>
    </div>
    <div>
        <table style="width: 900px; cellspacing="15" cellpadding="5">
            <tr style="height: 30px">
                <td>
                    <a href="BrokerAnalysis.aspx">To view the analysis on main brokers</a>
                </td>
                <td>
                    <a href="BrokerReport.aspx?StockCode=PLS.AX&ObservationDate=2050-12-12">To view the broker report</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="BrokerBuySellPerc.aspx">To view the broker buy sell percentage</a>
                </td>
                <td>
                    <a href="IntegratedCharts.aspx?StockCode=PLS.AX">To view the Integrated Chart</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="CourseOfSaleInstitute.aspx?StockCode=PLS.AX&ObservationDate=2050-12-12&NumPrevDay=0&CustomFilterID=0&BrokerCodeIndex=0">To view the course of sale Institute on stocks</a>
                </td>
                <td>
                    <a href="CourseOfSale.aspx?StockCode=PLS.AX&ObservationDate=2050-12-12&NumPrevDay=0&CustomFilterID=0&BrokerCodeIndex=0">To view the course of sale on stocks</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="FirstBuySellASXOnly.aspx?StockCode=PLS.AX&NumPrevDay=0">To view the ASX only first buy sell order on monitored stocks</a>
                </td>
                <td>
                    <a href="FirstBuySell.aspx?StockCode=PLS.AX&NumPrevDay=0">To view the first buy sell order on monitored stocks</a>
                </td>
            </tr>

            <tr style="height: 30px">
                <td>
                    <a href="StockBuyvsSell.aspx?ReportType=0&NumPrevDay=0">To view the stock buy vs sell</a>
                </td>
                <td>
                    <a href="ManageMonitorStock.aspx">To manage the list of monitored stocks</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="ManageStockKeyToken.aspx">To manage the list of stock key tokens</a>
                </td>
                <td>
                    <a href="ManageHCPoster.aspx">To manage the HC Poster</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="ManageAlert.aspx">To manage the Trading Alert</a>
                </td>
                <td>
                    <a href="ManageConditionalOrder.aspx">To manage the Conditional Order</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="ASX300StockSectorPerformance.aspx">To view ASX300 Sector Performance</a>
                </td>
                <td>
                    <a href="StockInsight.aspx">To view Stock Insight</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="StockScreening.aspx">To view Stock Screening</a>
                </td>
                <td>
                    <a href="StockScanResult.aspx?ReportType=0&NumPrevDay=0">To view Stock Scan Result</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="StockSectorPerformanceToday.aspx">To view Sector Performance</a>
                </td>
                <td>
                    <a href="StockAnnouncementToday.aspx">To view Today Stock Announcement</a>
                </td>

            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="StockDirectorBuy.aspx">To view Director Buy on market</a>
                </td>
                <td>
                    <a href="TradingHalt.aspx">To view the Trading Halt Report</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="TradeRequest.aspx">To view Trade Request</a>
                </td>
                <td>
                    <a href="ASXIndexReport.aspx">To view the ASX Index Report</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="TradeStrategySuggestion.aspx?ReportType=0&NumPrevDay=0">To view Trade Strategy Suggestions</a>
                </td>
                <td>
                    <a href="LargeSale.aspx">To view the large sale orders executed & line wipe</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="EnteryMyTrade.aspx">To enter your trade so your held stocks can be alerted</a>
                </td>
                <td>
                    <a href="SearchAnn.html">Semantics search stock announcements</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="AccountBalance.aspx">Account Balance</a>
                </td>
                <td>
                    <a href="AccountHoldings.aspx">Account Holdings</a>
                </td>
            </tr>
            <tr style="height: 30px">
                <td>
                    <a href="CurrentHoldings.aspx">To view Current Holdings</a>
                </td>
                <td>
                    <a href="StockWatchList.aspx?ReportType=0&NumPrevDay=0">To view Stock WatchLists</a>
                </td>
            </tr>
        </table>
        </div>
    <hr />
    <div>
        <h3>External links:</h3>
    </div>
    <div>
        <table style="width: 900px;" cellspacing="15" cellpadding="5">
            <tr>
                <td>
                    <a href="https://tradingeconomics.com/commodities">tradingeconomics</a>
                </td>
                <td>
                    <a href="https://www.mining.com/markets/">mining commsodities</a>
                </td>
<%--                <td>
                    <a href="https://www.mining.com/markets/commodity/nickel/">Nickel</a>
                </td>
                <td>
                    <a href="https://www.mining.com/markets/commodity/copper/">Copper</a>
                </td>
                <td>
                    <a href="https://www.mining.com/markets/commodity/nickel/">Nickel</a>
                </td>
                <td>
                    <a href="https://www.mining.com/markets/commodity/copper/">Copper</a>
                </td>--%>

                
            </tr>
        </table>
    </div>
    <hr />
        <div class="height: 620px">
            IB HeartBeat:
            <asp:GridView ID="gvDataSet4" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet4_PageIndexChanging" OnRowDataBound="gvDataSet4_RowCreated" OnRowCreated="gvDataSet4_RowDataBound" PageSize="40" Font-Size="Small" BorderStyle="Solid" OnSelectedIndexChanged="gvDataSet4_SelectedIndexChanged">
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
            </asp:GridView>
            <br />
            <br />            
        </div>
    <hr />

    <hr />
        Choose Sector:&nbsp;&nbsp; </strong>
        <asp:DropDownList ID="ddlSectorList" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlSectorList_SelectedIndexChanged" Width="251px">
        </asp:DropDownList>

    <hr />
        <div class="height: 620px">
            <asp:Literal ID="ltrSectorPerformance" runat="server"></asp:Literal>
        </div>
    </form>
</body>
</html>
