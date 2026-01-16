<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="IntegratedCharts.aspx.cs" Inherits="StockInfoReport.IntegratedCharts" Title="Integrated Charts"%>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
        <div><a href="Default.aspx">Click to go to the main page</a><br /><br /></div>
        <div align="center">
            <div id="bigchart_images" class="">
                <h5>Daily 6 Months Moving Average 5, 10</h5>
                <asp:Image ID="imgDaily6MonthSMA204060" runat="server"/>
                <br />
                
                <h5>Daily 1 Year Moving Average 20, 40, 60</h5>
                <asp:Image ID="imgDaily1YearSMA51015" runat="server"/>
                <br />

                <h5>Weekly 1 Year Moving Average 5, 10</h5>
                <asp:Image ID="imgWeekly1YearSMA51015" runat="server"/>
                <br />

                <h5>Weekly 3 Year Moving Average 5, 10</h5>
                <asp:Image ID="imgWeekly3YearSMA51015" runat="server"/>
                <br />
                
                <h5>Monthly 5 Year Moving Average 5, 10</h5>
                <asp:Image ID="imgMonthly5YearSMA51015" runat="server"/>
                <br />            
            
                <h5>Hourly 10 Days Moving Average 5, 10</h5>
                <asp:Image ID="imgHourly10day51015" runat="server"/>
                <br />



            </div>

        </div>
    </form>
</body>
</html>
