<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="ManageHCPoster.aspx.cs" Inherits="StockInfoReport.ManageHCPoster" Title="Manage HC Poster"%>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
    <title></title>
</head>
<body>
    <form id="form1" runat="server">
<div><a href="Default.aspx">Click to go to the main page</a><br /><br /></div>
<hr />
    Choose Static Data:&nbsp;&nbsp; </strong>
    <asp:DropDownList ID="ddlStaticDataList" runat="server" AutoPostBack="True" OnSelectedIndexChanged="ddlStaticDataList_SelectedIndexChanged" Width="251px">
    </asp:DropDownList>

<hr />
<div>  
        <fieldset style="width: 722px" ><legend><b>Add HC Quality Poster</b></legend>  
            <div style="width: 100%; background-color: #a5bde5">  
        <asp:Table runat="server" Width="722px">  
            <asp:TableRow>  
                <asp:TableCell>Quality Poster</asp:TableCell><asp:TableCell>
                    <asp:TextBox ID="txtStaticDataItem" runat="server"></asp:TextBox >
            </asp:TableCell>  
            </asp:TableRow>  
            <asp:TableRow>  
                <asp:TableCell>Rating</asp:TableCell><asp:TableCell>
                    <asp:TextBox ID="txtStaticDataItem2" runat="server"></asp:TextBox >
                </asp:TableCell>  
            </asp:TableRow>  
            <asp:TableRow>  
                <asp:TableCell></asp:TableCell><asp:TableCell><asp:Button ID="btnSave" Text="Add Record" runat="server" OnClick="btnSave_Click" /></asp:TableCell>  
            </asp:TableRow>  
        </asp:Table>  
        </div>  
        </fieldset>  
        <br />  
    <fieldset style="width: 800px"><legend><b>HC Quality Poster List</b></legend>  
    <div style="background-color: #a5bde5">  
    <asp:DataList ID="DataListStaticDataToken" runat="server"   
             DataKeyField="Poster"   
             OnDeleteCommand="DataListStaticDataToken_DeleteCommand"   
             Width ="790px" >  
            <HeaderTemplate>  
            <table>
                <tr style="background-color: White; color: #284775">  
                    <th>Poster</th>
                    <th>Rating</th>
                </tr>  
            </HeaderTemplate>  
            <ItemTemplate>  
            <tr > 
            <td style="width: 400px"><%# DataBinder.Eval(Container.DataItem,"Poster")%></td>
            <td style="width: 100px"><%# DataBinder.Eval(Container.DataItem,"Rating")%></td>
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
