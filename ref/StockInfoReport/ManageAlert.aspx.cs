using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class ManageAlert : System.Web.UI.Page
    {
        DataSet dsItemCategory;
        int tradingAlertTypeID;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                GetItemCategory();
                ddlItemCategory.DataSource = dsItemCategory.Tables[0];
                ddlItemCategory.DataTextField = "TradingAlertType";
                ddlItemCategory.DataValueField = "TradingAlertTypeID";
                ddlItemCategory.DataBind();
                ddlItemCategory.SelectedIndex = -1;
                //GetManageItem();
            }
            tradingAlertTypeID = Convert.ToInt32(ddlItemCategory.SelectedValue);
        }

        public void GetItemCategory()
        {
            DataOperation doItemCategory = new DataOperation();
            dsItemCategory = doItemCategory.GetTradingAlertType();
        }

        private void GetManageItem(int tradingAlertTypeID)
        {
            DataTable dtManageItem;
            DataOperation doManageItem = new DataOperation();
            dtManageItem = doManageItem.GetTradingAlert(tradingAlertTypeID).Tables[0];
            DataListManageItem.DataSource = dtManageItem;
            DataListManageItem.DataBind();          
        }

        protected void btnSave_Click(object sender, EventArgs e)
        {
            string message = "";
            if(txtStockCode.Text.Length > 0)
            {
                DataOperation doAdd = new DataOperation();
                string asxCode = txtStockCode.Text;
                int userID = Convert.ToInt32(txtUserID.Text);
                decimal alertPrice = -1;
                if (txtAlertPrice.Text.Length > 0)
                    alertPrice = Convert.ToDecimal(txtAlertPrice.Text);
                int alertVolume = -1;
                if (txtAlertVolume.Text.Length > 0)
                    alertVolume = Convert.ToInt32(txtAlertVolume.Text);
                int boost = 0;
                if (txtBoost.Text.Length > 0)
                    boost = Convert.ToInt32(txtBoost.Text);
                string alertPriceType = ddlAlertPriceType.SelectedValue;

                if (alertPrice == -1 && alertVolume == -1)
                    Response.Write("<script type=\"text/javascript\">alert('" + "Please enter alert price or alert volume" + "');</script>");
                tradingAlertTypeID = Convert.ToInt32(ddlItemCategory.SelectedValue);
                message = doAdd.AddTradingAlert(asxCode, userID, tradingAlertTypeID, alertPrice, alertVolume, alertPriceType, boost);
                Clear();
                Response.Write("<script type=\"text/javascript\">alert('" + message + "');</script>");
                GetManageItem(tradingAlertTypeID);
            }

        }
        void Clear()
        {
            txtStockCode.Text = String.Empty;
            txtUserID.Text = String.Empty;
            txtAlertPrice.Text = String.Empty; 
            txtAlertVolume.Text = String.Empty;
        }

        protected void DataListManageItem_DeleteCommand(object source, DataListCommandEventArgs e)
        {
            int tradingAlertID = Convert.ToInt32(DataListManageItem.DataKeys[e.Item.ItemIndex].ToString());

            if (tradingAlertID > 0)
            {
                DataOperation doDelete = new DataOperation();
                doDelete.DeleteTradingAlert(tradingAlertID);
                //Clear();
                Response.Write("<script type=\"text/javascript\">alert('Record Deleted Successfully');</script>");
                GetManageItem(tradingAlertTypeID);
            }
            
        }
        protected void DataListManageItem_EditCommand(object source, DataListCommandEventArgs e)
        {
            DataListManageItem.EditItemIndex = e.Item.ItemIndex;
            GetManageItem(tradingAlertTypeID);
        }
        protected void DataListManageItem_CancelCommand(object source, DataListCommandEventArgs e)
        {
            DataListManageItem.EditItemIndex = -1;
            GetManageItem(tradingAlertTypeID);
        }
        protected void DataListManageItem_UpdateCommand(object source, DataListCommandEventArgs e)
        {
            int tradingAlertID = Convert.ToInt32(DataListManageItem.DataKeys[e.Item.ItemIndex].ToString());
            TextBox txtAlertPrice = (TextBox)e.Item.FindControl("txtAlertPrice");
            TextBox txtAlertVolume = (TextBox)e.Item.FindControl("txtAlertVolume");

            decimal alertPrice = -1;
            if (txtAlertPrice.Text.Length > 0)
                alertPrice = Convert.ToDecimal(txtAlertPrice.Text);
            int alertVolume = -1;
            if (txtAlertVolume.Text.Length > 0)
                alertVolume = Convert.ToInt32(txtAlertVolume.Text);
            if (alertPrice == -1 && alertVolume == -1)
                Response.Write("<script type=\"text/javascript\">alert('" + "Please enter alert price or alert volume" + "');</script>");
            //message = doAdd.AddTradingAlert(asxCode, userID, tradingAlertTypeID, alertPrice, alertVolume);

            string message = "";

            if (alertPrice > 0 || alertVolume > 0)
            {
                DataOperation doUpdate = new DataOperation();
                message = doUpdate.UpdateTradingAlert(tradingAlertID, alertPrice, alertVolume);
                Clear();
                Response.Write("<script type=\"text/javascript\">alert('" + message + "');</script>");
                GetManageItem(tradingAlertTypeID);
            }
        }

        protected void ddlItemCategory_SelectedIndexChanged(object sender, EventArgs e)
        {
            tradingAlertTypeID = Convert.ToInt32(ddlItemCategory.SelectedValue);
            GetManageItem(tradingAlertTypeID);
        }
    }
}