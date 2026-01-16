<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="BrokerReport.aspx.cs" Inherits="StockInfoReport.BrokerReport" EnableEventValidation="false" Title="Broker Report"%>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
    <div><a href="Default.aspx">Click to go to the main page</a><br /><br /></div>
        <table>
            <tr>
                <td>
                    Stock Codes:&nbsp;
                </td>
                <td>
                    <asp:TextBox ID="txtStockCode" Text="" runat="server"></asp:TextBox>&nbsp;
                </td>
            </tr>
            <tr>
                <td>
                    Observation Date:&nbsp;
                </td>
                <td>
                    <asp:TextBox ID="txtObservationDate" Text="" runat="server"></asp:TextBox>&nbsp;
                </td>
            </tr>
        </table>
        <br />

        <asp:Button ID="btnStockCode" Text="Submit" runat="server" OnClick="btnStockCode_Click" />
        <br />
        <br />
        Broker Report Current Day:
        <asp:GridView ID="gvDataSet1" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet1_PageIndexChanging" OnRowDataBound="gvDataSet1_RowDataBound" OnRowCreated="gvDataSe1_RowCreated" PageSize="50" Font-Size="X-Small" OnRowCommand="gvDataSet1_RowCommand">
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
                <asp:buttonfield buttontype="Button" commandname="ViewChart" headertext="View Chart" text="View Chart"/>
                <asp:buttonfield buttontype="Button" commandname="ViewCourseOfSale" headertext="View CourseOfSale" text="View CourseOfSale"/>
                <%--<asp:buttonfield buttontype="Button" commandname="ViewHC" headertext="View HC" text="View HC"/>--%>
                <asp:buttonfield buttontype="Button" commandname="ViewTop20" headertext="View Top 20" text="View Top 20"/>    
                <asp:buttonfield buttontype="Button" commandname="ViewBrokerData" headertext="View Broker Data" text="View Broker Data"/>
                <asp:buttonfield buttontype="Button" commandname="ViewInsight" headertext="View Insight" text="View Insight"/>
            </Columns>
        </asp:GridView>
        <br />
        <br />
        Broker Report Previous Day 1:
        <asp:GridView ID="gvDataSet2" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet2_PageIndexChanging" OnRowDataBound="gvDataSet2_RowCreated" OnRowCreated="gvDataSet2_RowDataBound" PageSize="50" Font-Size="X-Small">
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
        Broker Report Previous Day 2:
        <asp:GridView ID="gvDataSet3" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet3_PageIndexChanging" OnRowDataBound="gvDataSet3_RowCreated" OnRowCreated="gvDataSet3_RowDataBound" PageSize="50" Font-Size="X-Small" BorderStyle="Solid">
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
        Broker Report Last 5 trading days:
        <asp:GridView ID="gvDataSet4" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet4_PageIndexChanging" OnRowDataBound="gvDataSet4_RowCreated" OnRowCreated="gvDataSet4_RowDataBound" PageSize="50" Font-Size="X-Small" BorderStyle="Solid">
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
        Broker Report Last 10 trading days:
        <asp:GridView ID="gvDataSet5" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet5_PageIndexChanging" OnRowDataBound="gvDataSet5_RowCreated" OnRowCreated="gvDataSet5_RowDataBound" PageSize="50" Font-Size="X-Small" BorderStyle="Solid">
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
        Broker Report Last 20 trading days:
        <asp:GridView ID="gvDataSet6" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet6_PageIndexChanging" OnRowDataBound="gvDataSet6_RowCreated" OnRowCreated="gvDataSet6_RowDataBound" PageSize="50" Font-Size="X-Small" BorderStyle="Solid">
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
        Broker Report Last 60 trading days:
        <asp:GridView ID="gvDataSet7" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet7_PageIndexChanging" OnRowDataBound="gvDataSet7_RowCreated" OnRowCreated="gvDataSet7_RowDataBound" PageSize="50" Font-Size="X-Small" BorderStyle="Solid">
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
        Broker Report Last 120 trading days:
        <asp:GridView ID="gvDataSet8" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet8_PageIndexChanging" OnRowDataBound="gvDataSet8_RowCreated" OnRowCreated="gvDataSet8_RowDataBound" PageSize="50" Font-Size="X-Small" BorderStyle="Solid">
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
        Broker Report Last 240 trading days:
        <asp:GridView ID="gvDataSet9" runat="server" AllowPaging="True" CellPadding="4" ForeColor="#333333" OnPageIndexChanging="gvDataSet9_PageIndexChanging" OnRowDataBound="gvDataSet9_RowCreated" OnRowCreated="gvDataSet9_RowDataBound" PageSize="50" Font-Size="X-Small" BorderStyle="Solid">
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
