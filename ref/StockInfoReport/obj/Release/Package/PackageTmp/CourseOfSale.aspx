<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="CourseOfSale.aspx.cs" Inherits="StockInfoReport.CourseOfSale" EnableEventValidation="false" Title="Course Of Sale"%>
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
    <div style="width:100%">
    
        <strong>Course of Sale<br />
        <br />
        Choose stock code:&nbsp;&nbsp; </strong>
        <asp:DropDownList ID="ddlStockList" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlStockList_SelectedIndexChanged" Width="251px">
        </asp:DropDownList>
        <%--&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <strong>Number of Previous Days from Today:  </strong>&nbsp--%>
        <asp:TextBox ID="txtNumPrevDay" Visible="false" runat="server" Width="90px" TextMode="Number" AutoPostBack="True" OnTextChanged="txtNumPrevDay_TextChanged"></asp:TextBox>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <strong>Observation Date:  </strong>&nbsp
        <asp:TextBox ID="txtObservationDate" runat="server" Width="90px" AutoPostBack="True" OnTextChanged="txtNumObservationDate_TextChanged"></asp:TextBox>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; <strong>Custom Filter:  </strong>&nbsp
        <asp:DropDownList ID="ddlCustomFilter" runat="server" AutoPostBack="True" Width="251px" OnSelectedIndexChanged="ddlCustomFilter_SelectedIndexChanged">
        </asp:DropDownList>
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp; 
        BrokerCode: <asp:DropDownList ID ="ddlBrokerCode" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlBrokerCode_SelectedIndexChanged">
        </asp:DropDownList>
        
        <p></p>
        <br />
        <br />
    </div>
    <div style="width:100%">
        <asp:Literal ID="ltrChartMoneyFlowAmount" runat="server"></asp:Literal>
    </div>
    <div  style="width:100%">
        <asp:Literal ID="ltrChartMoneyFlowAmountIntraDay" runat="server"></asp:Literal>
    </div>
    <div  style="width:100%">
        <asp:Literal ID="ltrChartIntraDay" runat="server"></asp:Literal>
    </div>
    <%--<div>
        <asp:Literal ID="ltrChartVolume" runat="server"></asp:Literal>
    </div>--%>
        <%--<asp:Label ID="lblCourseOfSale" runat="server" Text="Course of Sale by Hour" Visible="False"></asp:Label>
        <br />--%>

        <asp:GridView ID="gvSummaryByHour" runat="server" CellPadding="4" ForeColor="#333333" OnSelectedIndexChanged="gvSummaryByHour_SelectedIndexChanged" Visible="False" PageSize="20" Font-Size="Smaller">
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
        <asp:Label ID="lblCourseOfSalebyDate" runat="server" Text="Course of Sale by Date"></asp:Label>
        <br />
        <asp:GridView ID="gvCOSLatest" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvCOSLatest_PageIndexChanging" OnRowDataBound="gvCOSLatest_RowDataBound" OnRowCreated="gvCOSLatest_RowCreated" PageSize="20" Font-Size="Smaller">
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
        <asp:Label ID="lblCourseOfSalebyVolume" runat="server" Text="Course of Sale by Volume"></asp:Label>
        <br />
<%--        <asp:GridView ID="gvCOSVolume" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvCOSVolume_PageIndexChanging" OnRowDataBound="gvCOSVolume_RowDataBound" Font-Size="Smaller">
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
    </form>
</body>
</html>
