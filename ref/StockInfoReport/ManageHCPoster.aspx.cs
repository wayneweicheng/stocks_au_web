using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class ManageHCPoster : System.Web.UI.Page
    {
        DataSet dsStaticDataList;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                GetStaticDataList();
                ddlStaticDataList.DataSource = dsStaticDataList.Tables[0];
                ddlStaticDataList.DataTextField = "PosterType";
                ddlStaticDataList.DataValueField = "PosterType";
                ddlStaticDataList.DataBind();
                ddlStaticDataList.SelectedIndex = 0;
                string token = ddlStaticDataList.SelectedValue;
                GetList(token);
            }
        }
        private void GetList(string token)
        {
            DataTable dtList;
            DataOperation doList = new DataOperation();
            dtList = doList.GetHCQualityPoster(token).Tables[0];
            DataListStaticDataToken.DataSource = dtList;
            DataListStaticDataToken.DataBind();
            
        }
        protected void btnSave_Click(object sender, EventArgs e)
        {
            string message = "";
            string token = ddlStaticDataList.SelectedValue;
            if (txtStaticDataItem.Text.Length > 0)
            {
                DataOperation doAdd = new DataOperation();
                message = doAdd.AddHCQualityPoster(token, txtStaticDataItem.Text, Convert.ToInt16(txtStaticDataItem2.Text));
                Clear();
                Response.Write("<script type=\"text/javascript\">alert('" + message + "');</script>");
                GetList(token);
            }

        }
        void Clear()
        {
            txtStaticDataItem.Text = String.Empty;
            txtStaticDataItem2.Text = String.Empty;
        }

        protected void DataListStaticDataToken_DeleteCommand(object source, DataListCommandEventArgs e)
        {
            string dataListItem = DataListStaticDataToken.DataKeys[e.Item.ItemIndex].ToString();
            string token = ddlStaticDataList.SelectedValue;
            if (dataListItem.Length > 0)
            {
                DataOperation doDelete = new DataOperation();
                doDelete.DeleteQualityPoster(dataListItem, token);
                //Clear();
                Response.Write("<script type=\"text/javascript\">alert('Record Deleted Successfully');</script>");
                GetList(token);
            }
            
        }
        protected void DataListStockKeyToken_EditCommand(object source, DataListCommandEventArgs e)
        {
            string token = ddlStaticDataList.SelectedValue;
            DataListStaticDataToken.EditItemIndex = e.Item.ItemIndex;
            GetList(token);
        }
        protected void DataListStockKeyToken_CancelCommand(object source, DataListCommandEventArgs e)
        {
            string token = ddlStaticDataList.SelectedValue;
            DataListStaticDataToken.EditItemIndex = -1;
            GetList(token);
        }
        //protected void DataListStaticDataToken_UpdateCommand(object source, DataListCommandEventArgs e)
        //{
        //    string stockCode = DataListStaticDataToken.DataKeys[e.Item.ItemIndex].ToString();
        //    TextBox txtUpdate = (TextBox)e.Item.FindControl("txtUpdateStockCode");
        //    string stockCodeNew = txtUpdate.Text;
        //    string message = "";

        //    if (stockCode.Length > 0 && stockCodeNew.Length > 0)
        //    {
        //        //DataOperation doUpdate = new DataOperation();
        //        //message = doUpdate.UpdateStockKeyToken(stockCode, stockCodeNew);
        //        //Clear();
        //        //Response.Write("<script type=\"text/javascript\">alert('" + message + "');</script>");
        //        //GetStockKeyTokenList();
        //        ;
        //    }
        //}
        public void GetStaticDataList()
        {
            DataOperation doStaticDataList = new DataOperation();
            dsStaticDataList = doStaticDataList.GetHCQualityPosterType();
        }
        protected void ddlStaticDataList_SelectedIndexChanged(object sender, EventArgs e)
        {
            string token = ddlStaticDataList.SelectedValue;
            GetList(token);
        }
        
    }
}