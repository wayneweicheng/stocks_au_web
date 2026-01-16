<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="StockWatchList.aspx.cs" Inherits="StockInfoReport.StockWatchList" EnableEventValidation="false" Title="Stock WatchList"%>

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
            <asp:ListItem>Current Watches</asp:ListItem>
            <asp:ListItem>Most Traded SmallCap</asp:ListItem>
            <asp:ListItem>Most Traded MidLargeCap</asp:ListItem>
            <asp:ListItem>Buy Close Sell Open</asp:ListItem>
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
