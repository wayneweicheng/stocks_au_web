<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="ManageStockKeyToken.aspx.cs" Inherits="StockInfoReport.ManageStockKeyToken" Title="Manage Stock Key Token"%>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
<div><a href="Default.aspx">Click to go to the main page</a><br /><br /></div>
<hr />
    Choose Sector:&nbsp;&nbsp; </strong>
    <asp:DropDownList ID="ddlSectorList" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlSectorList_SelectedIndexChanged" Width="251px">
    </asp:DropDownList>

<hr />
<div>  
        <fieldset style="width: 426px" ><legend><b>Add Stock Key Token</b></legend>  
            <div style="width: 100%; background-color: #a5bde5">  
        <asp:Table runat="server">  
            <asp:TableRow>  
                <asp:TableCell>Stock Code</asp:TableCell><asp:TableCell><asp:TextBox ID="txtStockCode" runat="server"></asp:TextBox ></asp:TableCell>  
            </asp:TableRow>  
            <asp:TableRow>  
                <asp:TableCell></asp:TableCell><asp:TableCell><asp:Button ID="btnSave" Text="Add Record" runat="server" OnClick="btnSave_Click" /></asp:TableCell>  
            </asp:TableRow>  
        </asp:Table>  
        </div>  
        </fieldset>  
        <br />  
    <fieldset style="width: 800px"><legend><b>Stock Key Token List</b></legend>  
    <div style="background-color: #a5bde5">  
    <asp:DataList ID="DataListStockKeyToken" runat="server"   
             DataKeyField="ASXCode"   
             OnDeleteCommand="DataListStockKeyToken_DeleteCommand"   
             OnEditCommand="DataListStockKeyToken_EditCommand"  
             OnCancelCommand="DataListStockKeyToken_CancelCommand" 
             Width ="790px" >  
            <HeaderTemplate>  
            <table>
            <tr style="background-color: White; color: #284775">  
                <th>StockKeyTokenID</th>
                <th>Token</th>
                <th>ASX Code</th>
                <th>Create Date</th>
                <th>Open Price</th>
                <th>Last Price</th>
                <th>Last Close Price</th>
                <th>Change Percentage</th>
            </tr>  
            </HeaderTemplate>  
            <ItemTemplate>  
            <tr > 
            <td ="130px"><%# DataBinder.Eval(Container.DataItem, "StockKeyTokenID")%></td>  
            <td ="200px"><%# DataBinder.Eval(Container.DataItem,"Token")%></td>
            <td ="100px"><%# DataBinder.Eval(Container.DataItem,"ASXCode")%></td>  
            <td ="200px"><%# DataBinder.Eval(Container.DataItem, "CreateDate")%></td>
            <td ="100px"><%# DataBinder.Eval(Container.DataItem, "Open")%></td>
            <td ="100px"><%# DataBinder.Eval(Container.DataItem, "Last")%></td>
            <td ="100px"><%# DataBinder.Eval(Container.DataItem, "Close")%></td>
            <td ="100px"><%# DataBinder.Eval(Container.DataItem, "ChangePerc")%></td>
            <%--<td ="70px"><asp:Button ID="imgbtnedit" runat="server" Text="Edit"  ToolTip="Edit" CommandName="Edit"/></td>--%>  
            <td ="100px"><asp:Button ID="btndelete" runat="server" Text="Delete" CommandName="Delete" ToolTip="Delete"/></td>  
            </tr>            
            </ItemTemplate>  
            <EditItemTemplate>             
            <tr>  
             <td><asp:TextBox BackColor="Yellow" Font-Bold="true" ID="txtUpdateStockCode" runat="server" Text='<%# Eval("ASXCode") %>'></asp:TextBox></td>  
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
