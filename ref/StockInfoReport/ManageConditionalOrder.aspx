<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="ManageConditionalOrder.aspx.cs" Inherits="StockInfoReport.ManageConditionalOrder" Title="Manage Conditional Order" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
<div><a href="Default.aspx">Click to go to the main page</a><br /><br /></div>
<hr />
    Choose Order Type:&nbsp;&nbsp; </strong>
    <asp:DropDownList ID="ddlItemCategory" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlItemCategory_SelectedIndexChanged" Width="251px">
    </asp:DropDownList>

<hr />
<div>  
        <fieldset style="width: 800px" ><legend><b>Add Conditional Order: </b></legend>  
            <div style="width: 100%; background-color: #a5bde5">  
        <asp:Table runat="server">  
            <asp:TableRow>  
                <asp:TableCell Width="100px">Stock Code</asp:TableCell><asp:TableCell Width="100px"><asp:TextBox ID="txtStockCode" runat="server"></asp:TextBox ></asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell Width="100px" ColumnSpan="3">--------------------------------------------------------------------------------------------------------------------------------------------------</asp:TableCell>
            </asp:TableRow>            
            <asp:TableRow>  
                <asp:TableCell>Trade Account Name</asp:TableCell>
                <asp:TableCell>
                    <asp:DropDownList ID ="ddlTradeAccountName" runat="server">
                        <asp:ListItem>N/A</asp:ListItem>
                        <asp:ListItem>huanw2114</asp:ListItem>
                        <asp:ListItem>CHENGWA</asp:ListItem>
                        <asp:ListItem>huanwang</asp:ListItem>
                        <asp:ListItem>zhenqiucheng</asp:ListItem>
                        <asp:ListItem>BoziLiu</asp:ListItem>
                    </asp:DropDownList>
                </asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell Width="100px" ColumnSpan="3">--------------------------------------------------------------------------------------------------------------------------------------------------</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell>Order Price Type</asp:TableCell>
                <asp:TableCell>
                    <asp:DropDownList ID ="ddlOrderPriceType" Width="150px" runat="server">
                        <asp:ListItem>Price</asp:ListItem>
                        <asp:ListItem>SMA</asp:ListItem>
                        <asp:ListItem>SMAWK</asp:ListItem>
                    </asp:DropDownList>
                </asp:TableCell>
                <asp:TableCell>* For Price type, enter the actual price. For SMA/SMAWK type, enter the SMA number in Order Price field. e.g. 20 for SMA20. Available SMA 3, 5, 10, 20</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell Width="100px" ColumnSpan="3">--------------------------------------------------------------------------------------------------------------------------------------------------</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell>Order Price</asp:TableCell><asp:TableCell><asp:TextBox ID="txtOrderPrice" runat="server"></asp:TextBox ></asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell Width="100px" ColumnSpan="3">--------------------------------------------------------------------------------------------------------------------------------------------------</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell>Price Buffer Number Of Tick</asp:TableCell><asp:TableCell><asp:TextBox ID="txtPriceBufferNumberOfTick" runat="server"></asp:TextBox ></asp:TableCell>
                <asp:TableCell>* An integer representing the number of ticked added/substracted to the order price to give some lead time. e.g. 1 for a buy order is 1 tick + the order price. Default value is 0</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell Width="100px" ColumnSpan="3">--------------------------------------------------------------------------------------------------------------------------------------------------</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow> 
                <asp:TableCell runat="server" ID="tcCustomIntegerValue">Custom Integer Value</asp:TableCell><asp:TableCell><asp:TextBox ID="txtVolumeGt" runat="server"></asp:TextBox ></asp:TableCell>  
                <asp:TableCell runat="server" ID="tcCustomIntegerValueDescr">* A custom integer value that can be used for different purposes for different types of orders. e.g. For strategy trigger by price following SMA, this value represents the time frame of minutes being used. e.g. 5, 15, 60, 240(4h), 1440(1d) etc.</asp:TableCell>
            </asp:TableRow>  
            <asp:TableRow>  
                <asp:TableCell Width="100px" ColumnSpan="3">--------------------------------------------------------------------------------------------------------------------------------------------------</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow> 
                <asp:TableCell>Order Volume</asp:TableCell><asp:TableCell><asp:TextBox ID="txtOrderVolume" runat="server"></asp:TextBox ></asp:TableCell>  
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell Width="100px" ColumnSpan="3">--------------------------------------------------------------------------------------------------------------------------------------------------</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow> 
                <asp:TableCell>Order Value</asp:TableCell><asp:TableCell><asp:TextBox ID="txtOrderValue" runat="server"></asp:TextBox ></asp:TableCell>  
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell Width="100px" ColumnSpan="3">--------------------------------------------------------------------------------------------------------------------------------------------------</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow> 
                <asp:TableCell>Valid Until</asp:TableCell><asp:TableCell><asp:TextBox ID="txtValidUntil" runat="server"></asp:TextBox ></asp:TableCell>  
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell Width="100px" ColumnSpan="3">--------------------------------------------------------------------------------------------------------------------------------------------------</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow> 
                <asp:TableCell>AdditionalSettings</asp:TableCell><asp:TableCell><asp:TextBox ID="txtAdditionalSettings" TextMode="MultiLine" runat="server" Width="350" Height="300"></asp:TextBox ></asp:TableCell>  
                <asp:TableCell runat="server" ID="tcAdditionalSettingsDescr">
{
"TriggerPrice":313.20,
"TotalVolume": 1,
"Entry1Price": 313.20,
"Entry2Price": -1,
"StopLossPrice": 308.87,
"ExitStrategy": "SmartExit",
"Exit1Price": 328.20,
"Exit2Price": -1
}
                </asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell Width="100px" ColumnSpan="3">--------------------------------------------------------------------------------------------------------------------------------------------------</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell></asp:TableCell><asp:TableCell><asp:Button ID="btnSave" Text="Add Record" runat="server" OnClick="btnSave_Click" /></asp:TableCell>  
            </asp:TableRow>  
        </asp:Table>  
        </div>  
        </fieldset>
        <br />
        <br />  
        <asp:Label ID="lblMessage" runat="server"></asp:Label>
    <fieldset style="width: 800px"><legend><b>Conditional Orders: </b></legend>  
    <div style="background-color: #a5bde5">  
    <asp:DataList ID="DataListManageItem" runat="server"   
             DataKeyField="OrderID"   
             OnDeleteCommand="DataListManageItem_DeleteCommand"   
             OnEditCommand="DataListManageItem_EditCommand"  
             OnUpdateCommand="DataListManageItem_UpdateCommand"   
             OnCancelCommand="DataListManageItem_CancelCommand" 
             Width ="790px" Font-Size ="X-Small" >  
            <HeaderTemplate>  
            <table>
                <tr style="background-color: White; color: #284775">  
                    <th>OrderID</th>
                    <th>Stock Code</th>
                    <th>TradeAccountName</th>
                    <th>OrderTypeID</th>
                    <th>OrderType</th>
                    <th>OrderPriceType</th>
                    <th>OrderPrice</th>
                    <th>AdjustedOrderPrice</th>
                    <th>CurrentPrice</th>
                    <th>DifferenceToCurrentPrice</th>
                    <th>PriceBufferNumberOfTick</th>
                    <th>CustomIntegerValue</th>
                    <th>OrderVolume</th>
                    <th>OrderValue</th>
                    <th>ValidUntil</th>
                    <th>AdditionalSettings<th>
                    <th>CreateDate</th>
                    <th>OrderTriggerDate</th>
                </tr>  
            </HeaderTemplate>  
            <ItemTemplate>  
            <tr > 
            <td ="50px"><%# DataBinder.Eval(Container.DataItem, "OrderID")%></td>
            <td ="130px"><%# DataBinder.Eval(Container.DataItem, "ASXCode")%></td> 
            <td ="50px"><%# DataBinder.Eval(Container.DataItem, "TradeAccountName")%></td>                
            <td ="50px"><%# DataBinder.Eval(Container.DataItem, "OrderTypeID")%></td>
            <td ="50px"><%# DataBinder.Eval(Container.DataItem, "OrderType")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"OrderPriceType")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"OrderPrice")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"AdjustedOrderPrice")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"CurrentPrice")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"DifferenceToCurrentPrice")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"PriceBufferNumberOfTick")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"CustomIntegerValue")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"OrderVolume")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"OrderValue")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"ValidUntil")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"AdditionalSettings")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"CreateDate")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"OrderTriggerDate")%></td>                        
            <td ="70px"><asp:Button ID="imgbtnedit" runat="server" Text="Edit"  ToolTip="Edit" CommandName="Edit"/></td>  
            <td ="100px"><asp:Button ID="btndelete" runat="server" Text="Delete" CommandName="Delete" ToolTip="Delete"/></td>  
            </tr>            
            </ItemTemplate>  
            <EditItemTemplate>             
            <tr>  
             <td><asp:TextBox Width="50px" BackColor="Silver" Font-Bold="true" ID="txtUpdateStockCode" runat="server" Text='<%# Eval("OrderID") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="50px" BackColor="Gray" Font-Bold="true" ID="txtASXCode" runat="server" Text='<%# Eval("ASXCode") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="50px" BackColor="Gray" Font-Bold="true" ID="TextTradeAccountName" runat="server" Text='<%# Eval("TradeAccountName") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="50px" BackColor="Gray" Font-Bold="true" ID="txtOrderTypeID" runat="server" Text='<%# Eval("OrderTypeID") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="50px" BackColor="Gray" Font-Bold="true" ID="txtOrderType" runat="server" Text='<%# Eval("OrderType") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Gray" Font-Bold="true" ID="txtOrderPriceType" runat="server" Text='<%# Eval("OrderPriceType") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Yellow" Font-Bold="true" ID="txtOrderPrice" runat="server" Text='<%# Eval("OrderPrice") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Gray" Font-Bold="true" ID="txtAdjustedOrderPrice" runat="server" Text='<%# Eval("AdjustedOrderPrice") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Gray" Font-Bold="true" ID="txtCurrentPrice" runat="server" Text='<%# Eval("CurrentPrice") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Gray" Font-Bold="true" ID="txtDifferenceToCurrentPrice" runat="server" Text='<%# Eval("DifferenceToCurrentPrice") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Yellow" Font-Bold="true" ID="txtPriceBufferNumberOfTick" runat="server" Text='<%# Eval("PriceBufferNumberOfTick") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="50px" BackColor="Yellow" Font-Bold="true" ID="txtVolumeGt" runat="server" Text='<%# Eval("CustomIntegerValue") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Yellow" Font-Bold="true" ID="txtOrderVolume" runat="server" Text='<%# Eval("OrderVolume") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Yellow" Font-Bold="true" ID="txtOrderValue" runat="server" Text='<%# Eval("OrderValue") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Yellow" Font-Bold="true" ID="txtValidUntil" runat="server" Text='<%# Eval("ValidUntil") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="350px" Height="300px" BackColor="Yellow" Font-Bold="true" ID="txtAdditionalSettings" TextMode="MultiLine" runat="server" Text='<%# Eval("AdditionalSettings") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Gray" Font-Bold="true" ID="txtCreateDate" runat="server" Text='<%# Eval("CreateDate") %>'></asp:TextBox></td>
             <td><asp:TextBox Width="80px" BackColor="Gray" Font-Bold="true" ID="txtOrderTriggerDate" runat="server" Text='<%# Eval("OrderTriggerDate") %>'></asp:TextBox></td>   
             <td><asp:Button ID="btnupdate" runat="server"  ToolTip="Update" Text="Update" CommandName="Update" /></td>  
             <td><asp:Button ID="btncancel" runat="server"  ToolTip="Cancel" Text="Cancel" CommandName="Cancel" /></td>  
            </tr>  
            </EditItemTemplate> 
        </asp:DataList>  
        </div>  
        </fieldset>  
        </div> 
    </form>
</body>
</html>
