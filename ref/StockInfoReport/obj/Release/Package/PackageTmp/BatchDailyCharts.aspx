<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="BatchDailyCharts.aspx.cs" Inherits="StockInfoReport.BatchDailyCharts" Title="Batch Daily Charts"%>

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
                <asp:Panel ID="panel" runat="server"></asp:Panel>
            </div>

        </div>
    </form>
</body>
</html>
