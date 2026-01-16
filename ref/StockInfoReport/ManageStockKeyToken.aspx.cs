using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class ManageStockKeyToken : System.Web.UI.Page
    {
        DataSet dsSectorList;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                GetSectorList();
                ddlSectorList.DataSource = dsSectorList.Tables[0];
                ddlSectorList.DataTextField = "Token";
                ddlSectorList.DataValueField = "Token";
                ddlSectorList.DataBind();
                ddlSectorList.SelectedIndex = -1;
            }
        }
        private void GetStockKeyTokenList(string token)
        {
            DataTable dtStockKeyToken;
            DataOperation doStockKeyToken = new DataOperation();
            dtStockKeyToken = doStockKeyToken.GetStockKeyToken(token).Tables[0];
            DataListStockKeyToken.DataSource = dtStockKeyToken;
            DataListStockKeyToken.DataBind();
            
        }
        protected void btnSave_Click(object sender, EventArgs e)
        {
            string message = "";
            string token = ddlSectorList.SelectedValue;
            if (txtStockCode.Text.Length > 0)
            {
                DataOperation doAdd = new DataOperation();
                message = doAdd.AddStockKeyToken(txtStockCode.Text, token);
                Clear();
                Response.Write("<script type=\"text/javascript\">alert('" + message + "');</script>");
                GetStockKeyTokenList(token);
            }

        }
        void Clear()
        {
            txtStockCode.Text = String.Empty;
        }

        protected void DataListStockKeyToken_DeleteCommand(object source, DataListCommandEventArgs e)
        {
            string stockCode = DataListStockKeyToken.DataKeys[e.Item.ItemIndex].ToString();
            string token = ddlSectorList.SelectedValue;
            if (stockCode.Length > 0)
            {
                DataOperation doDelete = new DataOperation();
                doDelete.DeleteStockKeyToken(stockCode, token);
                //Clear();
                Response.Write("<script type=\"text/javascript\">alert('Record Deleted Successfully');</script>");
                GetStockKeyTokenList(token);
            }
            
        }
        protected void DataListStockKeyToken_EditCommand(object source, DataListCommandEventArgs e)
        {
            string token = ddlSectorList.SelectedValue;
            DataListStockKeyToken.EditItemIndex = e.Item.ItemIndex;
            GetStockKeyTokenList(token);
        }
        protected void DataListStockKeyToken_CancelCommand(object source, DataListCommandEventArgs e)
        {
            string token = ddlSectorList.SelectedValue;
            DataListStockKeyToken.EditItemIndex = -1;
            GetStockKeyTokenList(token);
        }
        protected void DataListStockKeyToken_UpdateCommand(object source, DataListCommandEventArgs e)
        {
            string stockCode = DataListStockKeyToken.DataKeys[e.Item.ItemIndex].ToString();
            TextBox txtUpdate = (TextBox)e.Item.FindControl("txtUpdateStockCode");
            string stockCodeNew = txtUpdate.Text;
            string message = "";

            if (stockCode.Length > 0 && stockCodeNew.Length > 0)
            {
                //DataOperation doUpdate = new DataOperation();
                //message = doUpdate.UpdateStockKeyToken(stockCode, stockCodeNew);
                //Clear();
                //Response.Write("<script type=\"text/javascript\">alert('" + message + "');</script>");
                //GetStockKeyTokenList();
                ;
            }
        }
        public void GetSectorList()
        {
            DataOperation doSectorList = new DataOperation();
            dsSectorList = doSectorList.GetSectorList();
        }
        protected void ddlSectorList_SelectedIndexChanged(object sender, EventArgs e)
        {
            string token = ddlSectorList.SelectedValue;
            GetStockKeyTokenList(token);
        }
    }
}