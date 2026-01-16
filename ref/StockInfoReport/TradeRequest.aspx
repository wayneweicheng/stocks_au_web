<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="TradeRequest.aspx.cs" Inherits="StockInfoReport.TradeRequest" EnableEventValidation="false" Title="Trade Request"%>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
    <div><a href="Default.aspx">Click to go to the main page</a><br /><br /></div>
        Enter the number of records of trade requests to view:&nbsp;
        <asp:TextBox ID="txtTopNRecords" Text="" runat="server"></asp:TextBox>&nbsp;
        <asp:Button ID="btnTopNRecords" Text="Submit" runat="server" OnClick="btnTopNRecords_Click" />
        <br />
        <br />
        Top N Trade Request:
        <asp:GridView ID="gvDataSet1" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet1_PageIndexChanging" OnRowDataBound="gvDataSet1_RowDataBound" OnRowCreated="gvDataSe1_RowCreated" PageSize="20" Font-Size="X-Small">
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
        <asp:GridView ID="gvDataSet2" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" GridLines="None" OnPageIndexChanging="gvDataSet2_PageIndexChanging" OnRowDataBound="gvDataSet2_RowCreated" OnRowCreated="gvDataSet2_RowDataBound" PageSize="20" Font-Size="Small">
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
    </form>
</body>
</html>
