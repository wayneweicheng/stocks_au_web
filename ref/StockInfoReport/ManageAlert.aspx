<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="ManageAlert.aspx.cs" Inherits="StockInfoReport.ManageAlert" Title="Manage Alert" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
<div><a href="Default.aspx">Click to go to the main page</a><br /><br /></div>
<hr />
    Choose Alert Type:&nbsp;&nbsp; </strong>
    <asp:DropDownList ID="ddlItemCategory" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlItemCategory_SelectedIndexChanged" Width="251px">
    </asp:DropDownList>

<hr />
<div>  
        <fieldset style="width: 750px" ><legend><b>Add Trading Alert: </b></legend>  
            <div style="width: 100%; background-color: #a5bde5">  
        <asp:Table runat="server" Font-Size="Small" Width="745px">  
            <asp:TableRow>  
                <asp:TableCell>Stock Code</asp:TableCell><asp:TableCell><asp:TextBox ID="txtStockCode" runat="server"></asp:TextBox ></asp:TableCell>
            </asp:TableRow> 
            <asp:TableRow> 
                <asp:TableCell>User ID</asp:TableCell><asp:TableCell><asp:TextBox ID="txtUserID" runat="server"></asp:TextBox ></asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell>Alert Price</asp:TableCell><asp:TableCell><asp:TextBox ID="txtAlertPrice" runat="server"></asp:TextBox ></asp:TableCell>
            </asp:TableRow>
            <asp:TableRow>  
                <asp:TableCell>Alert Price Type</asp:TableCell>
                <asp:TableCell>
                    <asp:DropDownList ID ="ddlAlertPriceType" runat="server">
                        <asp:ListItem>Price</asp:ListItem>
                        <asp:ListItem>SMA</asp:ListItem>
                        <asp:ListItem>EMA</asp:ListItem>
                    </asp:DropDownList>
                </asp:TableCell>
                <asp:TableCell>* For Price type, enter the actual price. For SMA type, enter the SMA number in Alert Price field. e.g. 20 for SMA20. Available SMA 5, 10, 20, 30, 60, 135, 200</asp:TableCell>
            </asp:TableRow>            
            <asp:TableRow>  
                <asp:TableCell>Boost</asp:TableCell><asp:TableCell><asp:TextBox ID="txtBoost" runat="server"></asp:TextBox ></asp:TableCell>
                <asp:TableCell>* An integer representing the number of percentage added to the alert price to give some lead time. e.g. 3 for 3% + the alert price.</asp:TableCell>
            </asp:TableRow>
            <asp:TableRow> 
                <asp:TableCell>Alert Volume</asp:TableCell><asp:TableCell><asp:TextBox ID="txtAlertVolume" runat="server"></asp:TextBox ></asp:TableCell>  
            </asp:TableRow>  
            <asp:TableRow>  
                <asp:TableCell></asp:TableCell><asp:TableCell><asp:Button ID="btnSave" Text="Add Record" runat="server" OnClick="btnSave_Click" /></asp:TableCell>  
            </asp:TableRow>  
        </asp:Table>  
        </div>  
        </fieldset>  
        <br />  
    <fieldset style="width: 800px"><legend><b>Trading Alerts: </b></legend>  
    <div style="background-color: #a5bde5">  
    <asp:DataList ID="DataListManageItem" runat="server"   
             DataKeyField="TradingAlertID"   
             OnDeleteCommand="DataListManageItem_DeleteCommand"   
             OnEditCommand="DataListManageItem_EditCommand"  
             OnUpdateCommand="DataListManageItem_UpdateCommand"   
             OnCancelCommand="DataListManageItem_CancelCommand" 
             Width ="790px" Font-Size ="Small" >  
            <HeaderTemplate>  
            <table>
                <tr style="background-color: White; color: #284775">  
                    <th>TradingAlertID</th>
                    <th>Stock Code</th>
                    <th>UserID</th>
                    <th>TradingAlertTypeID</th>
                    <th>TradingAlertType</th>
                    <th>AlertPrice</th>
                    <th>AlertVolume</th>
                    <th>ActualPrice</th>
                    <th>ActualVolume</th>
                    <th>AlertPriceType</th>
                    <th>Boost</th>
                    <th>CreateDate</th>
                    <th>AlertTriggerDate</th>
                    <th>NotificationSentDate</th>
                </tr>  
            </HeaderTemplate>  
            <ItemTemplate>  
            <tr > 
            <td ="50px"><%# DataBinder.Eval(Container.DataItem, "TradingAlertID")%></td>
            <td ="130px"><%# DataBinder.Eval(Container.DataItem, "ASXCode")%></td> 
            <td ="50px"><%# DataBinder.Eval(Container.DataItem, "UserID")%></td>   
            <td ="50px"><%# DataBinder.Eval(Container.DataItem, "TradingAlertTypeID")%></td>
            <td ="50px"><%# DataBinder.Eval(Container.DataItem, "TradingAlertType")%></td>          
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"AlertPrice")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"AlertVolume")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"ActualPrice")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"ActualVolume")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"AlertPriceType")%></td>
            <td ="80px"><%# DataBinder.Eval(Container.DataItem,"Boost")%></td>                
            <td ="100px"><%# DataBinder.Eval(Container.DataItem, "CreateDate")%></td>
            <td ="100px"><%# DataBinder.Eval(Container.DataItem, "AlertTriggerDate")%></td>   
            <td ="100px"><%# DataBinder.Eval(Container.DataItem, "NotificationSentDate")%></td>                  
            <td ="70px"><asp:Button ID="imgbtnedit" runat="server" Text="Edit"  ToolTip="Edit" CommandName="Edit"/></td>  
            <td ="100px"><asp:Button ID="btndelete" runat="server" Text="Delete" CommandName="Delete" ToolTip="Delete"/></td>  
            </tr>            
            </ItemTemplate>  
            <EditItemTemplate>             
            <tr>  
             <td><asp:TextBox BackColor="Silver" Font-Bold="true" ID="txtUpdateStockCode" runat="server" Text='<%# Eval("TradingAlertID") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtASXCode" runat="server" Text='<%# Eval("ASXCode") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtUserID" runat="server" Text='<%# Eval("UserID") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtTradingAlertTypeID" runat="server" Text='<%# Eval("TradingAlertTypeID") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtTradingAlertType" runat="server" Text='<%# Eval("TradingAlertType") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Yellow" Font-Bold="true" ID="txtAlertPrice" runat="server" Text='<%# Eval("AlertPrice") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Yellow" Font-Bold="true" ID="txtAlertVolume" runat="server" Text='<%# Eval("AlertVolume") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtActualPrice" runat="server" Text='<%# Eval("ActualPrice") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtActualVolume" runat="server" Text='<%# Eval("ActualVolume") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtCreateDate" runat="server" Text='<%# Eval("CreateDate") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtAlertTriggerDate" runat="server" Text='<%# Eval("AlertTriggerDate") %>'></asp:TextBox></td>   
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtNotificationSentDate" runat="server" Text='<%# Eval("NotificationSentDate") %>'></asp:TextBox></td>  
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
