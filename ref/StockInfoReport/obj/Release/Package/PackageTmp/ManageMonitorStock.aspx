<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="ManageMonitorStock.aspx.cs" Inherits="StockInfoReport.ManageMonitorStock" Title="Manage Monitor Stock"%>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
<div><a href="Default.aspx">Click to go to the main page</a><br /><br /></div>
<div>  
        <fieldset style="width: 426px" ><legend><b>Add Monitor Stock</b></legend>  
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
    <fieldset style="width: 800px"><legend><b>Monitored Stock List</b></legend>  
    <div style="background-color: #a5bde5">  
    <asp:DataList ID="DataListMonitorStock" runat="server"   
             DataKeyField="ASXCode"   
             OnDeleteCommand="DataListMonitorStock_DeleteCommand"   
             OnEditCommand="DataListMonitorStock_EditCommand"  
             OnUpdateCommand="DataListMonitorStock_UpdateCommand"   
             OnCancelCommand="DataListMonitorStock_CancelCommand" 
             Width ="790px" >  
            <HeaderTemplate>  
            <table>
                <tr style="background-color: White; color: #284775">  
                    <th>ASX Code</th>
                    <th>Company Name</th>
                    <th>Create Date</th>
                    <th>Last Update Date</th>
                    <th>Update Status</th>
                    <th>Priority Level</th>
                    <th>Notes</th>
                </tr>  
            </HeaderTemplate>  
            <ItemTemplate>  
            <tr > 
            <td ="130px"><%# DataBinder.Eval(Container.DataItem, "ASXCode")%></td>  
            <td ="400px"><%# DataBinder.Eval(Container.DataItem,"CompanyName")%></td>
            <td ="200px"><%# DataBinder.Eval(Container.DataItem,"CreateDate")%></td>  
            <td ="200px"><%# DataBinder.Eval(Container.DataItem, "LastUpdateDate")%></td>
            <td ="100px"><%# DataBinder.Eval(Container.DataItem, "UpdateStatus")%></td>   
            <td ="100px"><%# DataBinder.Eval(Container.DataItem, "PriorityLevel")%></td>
            <td ="180px"><%# DataBinder.Eval(Container.DataItem, "Notes")%></td>
            <td ="70px"><asp:Button ID="imgbtnedit" runat="server" Text="Edit"  ToolTip="Edit" CommandName="Edit"/></td>  
            <td ="100px"><asp:Button ID="btndelete" runat="server" Text="Delete" CommandName="Delete" ToolTip="Delete"/></td>  
            </tr>            
            </ItemTemplate>  
            <EditItemTemplate>             
            <tr>  
             <td><asp:TextBox BackColor="Yellow" Font-Bold="true" ID="txtUpdateStockCode" runat="server" Text='<%# Eval("ASXCode") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtUpdateCompanyName" runat="server" Text='<%# Eval("CompanyName") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtUpdateCreateDate" runat="server" Text='<%# Eval("CreateDate") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtUpdateLastUpdateDate" runat="server" Text='<%# Eval("LastUpdateDate") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Gray" Font-Bold="true" ID="txtUpdateUpdateStatus" runat="server" Text='<%# Eval("UpdateStatus") %>'></asp:TextBox></td>   
             <td><asp:TextBox BackColor="Yellow" Font-Bold="true" ID="txtUpdatePriorityLevel" runat="server" Text='<%# Eval("PriorityLevel") %>'></asp:TextBox></td>
             <td><asp:TextBox BackColor="Yellow" Font-Bold="true" ID="txtUpdateNotes" runat="server" TextMode="MultiLine" Text='<%# Eval("Notes") %>'></asp:TextBox></td>
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
