<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="FirstBuySellASXOnly.aspx.cs" Inherits="StockInfoReport.FirstBuySellASXOnly" EnableEventValidation="false" Title="First Buy Sell ASX Only"%>
<script src="https://ajax.googleapis.com/ajax/libs/jquery/1.8.2/jquery.min.js" type="text/javascript"></script>
<script src="https://code.highcharts.com/highcharts.js" type="text/javascript"></script>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
    <div><a href="Default.aspx">Click to go to the main page</a><br /><br /></div>
    <div>
    
        <strong>Course of Sale<br />
        <br />
        Choose stock code:&nbsp;&nbsp; </strong>
        <asp:DropDownList ID="ddlStockList" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlStockList_SelectedIndexChanged" Width="251px">
        </asp:DropDownList>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <strong>Number of Previous Days from Today:  </strong>&nbsp
        <asp:TextBox ID="txtNumPrevDay" runat="server" Width="90px" TextMode="Number" AutoPostBack="True" OnTextChanged="txtNumPrevDay_TextChanged"></asp:TextBox>
        <p></p>
        <br />
        <br />
    </div>
    <div class="height: 620px">
        <asp:Literal ID="ltrChartMoneyFlowAmount" runat="server"></asp:Literal>
    </div>
    <div  class="height: 620px">
        <asp:Literal ID="ltrChartMoneyFlowAmountIntraDay" runat="server"></asp:Literal>
    </div>
    <%--<div>
        <asp:Literal ID="ltrChartVolume" runat="server"></asp:Literal>
    </div>--%>
        <%--<asp:Label ID="lblCourseOfSale" runat="server" Text="Course of Sale by Hour" Visible="False"></asp:Label>
        <br />--%>

        <br />
        <asp:Label ID="lblCourseOfSalebyVolume" runat="server" Text="Details of first buy sell order"></asp:Label>
        <br />
        <asp:GridView ID="gvCOSVolume" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" GridLines="None" OnPageIndexChanging="gvCOSVolume_PageIndexChanging" PageSize="800" Font-Size="Smaller" PagerSettings-PageButtonCount="20" OnRowDataBound="gvCOSVolume_RowDataBound" >
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
    </form>
</body>
</html>
