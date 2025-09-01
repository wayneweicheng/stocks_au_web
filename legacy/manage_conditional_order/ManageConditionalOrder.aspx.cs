using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class ManageConditionalOrder: System.Web.UI.Page
    {
        DataSet dsItemCategory;
        int orderTypeID;
        string asxCode;
        string orderPriceType;
        decimal orderPrice;
        int priceBufferNumberOfTick;
        int orderVolume;
        decimal orderValue;
        int volumeGt;
        string validUntil;
        string additionalSettings;
        string tradeAccountName;
        bool failValidation = false;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack)
            {
                GetItemCategory();
                ddlItemCategory.DataSource = dsItemCategory.Tables[0];
                ddlItemCategory.DataTextField = "OrderType";
                ddlItemCategory.DataValueField = "OrderTypeID";
                ddlItemCategory.DataBind();
                ddlItemCategory.SelectedIndex = 0;
                ddlTradeAccountName.SelectedIndex = 1;
                orderTypeID = Convert.ToInt32(ddlItemCategory.SelectedValue);
                GetManageItem(orderTypeID);
                Toggle_Order_Volume_Value();
                Toggle_Order_Price_Type();
                Clear();
            }
            else
            {
                orderTypeID = Convert.ToInt32(ddlItemCategory.SelectedValue);
                //GetManageItem(orderTypeID);
                Toggle_Order_Volume_Value();
                Toggle_Order_Price_Type();

            }
            RefreshCustomIntegerValue();
        }

        public void RefreshCustomIntegerValue()
        {
            if (ddlItemCategory.SelectedItem.ToString().ToUpper() == "Buy Close Price Advantage".ToUpper())
            {
                tcCustomIntegerValue.Text = "Custom Integer Value";
                tcCustomIntegerValueDescr.Text = "Set the value to 99, if want to skip the closing window check, therefore the order will be placed before 16:10:00. Set the value to 98 to retry place order after 2 seconds if placed order is canceled.";
            }
            else if (ddlItemCategory.SelectedItem.ToString().ToUpper() == "Buy at ask above".ToUpper())
            {
                tcCustomIntegerValue.Text = "No of times to order volume";
                tcCustomIntegerValueDescr.Text = "An integer value, when the ask price equals the buy price and ask volume is less than No of times to order volume x order volume, place the buy order. The default value is 3.";
            }
            else if (ddlItemCategory.SelectedItem.ToString().ToUpper().StartsWith("Strategy Stock".ToUpper()))
            {
                tcCustomIntegerValue.Text = "Custom Integer Value";
                tcCustomIntegerValueDescr.Text = "Default value 0 means placed order price will be dynamic based on the algo, set value to 99 to use a fixed price for the buy/sell order.";
            }
            else
            {
                tcCustomIntegerValue.Text = "Custom Integer Value";
                tcCustomIntegerValueDescr.Text = "* A custom integer value that can be used for different purposes for different types of orders. e.g. For strategy trigger by price following SMA, this value represents the time frame of minutes being used. e.g. 5, 15, 60, 240(4h), 1440(1d) etc.";
            }
        }

        public void GetItemCategory()
        {
            DataOperation doItemCategory = new DataOperation();
            dsItemCategory = doItemCategory.GetOrderType();
        }

        private void GetManageItem(int orderTypeID)
        {
            DataTable dtManageItem;
            DataOperation doManageItem = new DataOperation();
            dtManageItem = doManageItem.GetOrder(orderTypeID).Tables[0];
            DataListManageItem.DataSource = dtManageItem;
            DataListManageItem.DataBind();          
        }

        protected void btnSave_Click(object sender, EventArgs e)
        {
            string message = "";
            if(txtStockCode.Text.Length > 0)
            {
                DataOperation doAdd = new DataOperation();
                asxCode = txtStockCode.Text;
                orderPriceType = ddlOrderPriceType.SelectedValue;
                orderPrice = -1;
                if (txtOrderPrice.Text.Length > 0)
                    orderPrice = Convert.ToDecimal(txtOrderPrice.Text);
                priceBufferNumberOfTick = -1;
                if (txtPriceBufferNumberOfTick.Text.Length > 0)
                    priceBufferNumberOfTick = Convert.ToInt32(txtPriceBufferNumberOfTick.Text);

                orderVolume = -1;
                if (txtOrderVolume.Text.Length > 0)
                    orderVolume = Convert.ToInt32(txtOrderVolume.Text);
                orderValue = -1;
                if (txtOrderValue.Text.Length > 0)
                    orderValue = Convert.ToInt32(txtOrderValue.Text);

                volumeGt = -1;
                if (txtVolumeGt.Text.Length > 0)
                    volumeGt = Convert.ToInt32(txtVolumeGt.Text);
                validUntil = "";
                if (txtValidUntil.Text.Length > 0)
                    validUntil = txtValidUntil.Text;
                additionalSettings = "";
                if (txtAdditionalSettings.Text.Length > 0)
                    additionalSettings = txtAdditionalSettings.Text;

                tradeAccountName = "";
                if (ddlTradeAccountName.SelectedIndex > 0)
                    tradeAccountName = ddlTradeAccountName.SelectedValue;

                orderTypeID = Convert.ToInt32(ddlItemCategory.SelectedValue);
                Validate_Filled_Data();

                if (!failValidation)
                {
                    orderTypeID = Convert.ToInt32(ddlItemCategory.SelectedValue);
                    message = doAdd.AddOrder(asxCode, 1, tradeAccountName, orderTypeID, orderPrice, volumeGt, orderVolume, validUntil, orderPriceType, orderValue, priceBufferNumberOfTick, additionalSettings);
                    //Response.Write("<script type=\"text/javascript\">alert('" + message + "');</script>");
                    lblMessage.Text = message;
                    GetManageItem(orderTypeID);
                }
            }

        }
        void Clear()
        {
            ddlOrderPriceType.SelectedIndex = 0;
            txtStockCode.Text = String.Empty;
            txtPriceBufferNumberOfTick.Text = "0";
            txtOrderPrice.Text = String.Empty; 
            txtVolumeGt.Text = "0";
            txtOrderVolume.Text = String.Empty;
            txtOrderValue.Text = String.Empty;
            var today = DateTime.Today;
            var endDate = today.AddDays(60);
            var strEndDate = endDate.ToString("yyyy-MM-dd");
            txtValidUntil.Text = strEndDate;
            txtAdditionalSettings.Text = "{}";
        }

        protected void DataListManageItem_DeleteCommand(object source, DataListCommandEventArgs e)
        {
            int orderID = Convert.ToInt32(DataListManageItem.DataKeys[e.Item.ItemIndex].ToString());

            if (orderID > 0)
            {
                DataOperation doDelete = new DataOperation();
                doDelete.DeleteOrder(orderID);
                DataListManageItem.EditItemIndex = -1;
                GetManageItem(orderTypeID);
            }
            
        }
        protected void DataListManageItem_EditCommand(object source, DataListCommandEventArgs e)
        {
            DataListManageItem.EditItemIndex = e.Item.ItemIndex;
            GetManageItem(orderTypeID);
        }
        protected void DataListManageItem_CancelCommand(object source, DataListCommandEventArgs e)
        {
            DataListManageItem.EditItemIndex = -1;
            GetManageItem(orderTypeID);
        }
        protected void DataListManageItem_UpdateCommand(object source, DataListCommandEventArgs e)
        {
            int orderID = Convert.ToInt32(DataListManageItem.DataKeys[e.Item.ItemIndex].ToString());
            TextBox txtOrderPrice = (TextBox)e.Item.FindControl("txtOrderPrice");
            TextBox txtVolumeGt = (TextBox)e.Item.FindControl("txtVolumeGt");
            TextBox txtOrderVolume = (TextBox)e.Item.FindControl("txtOrderVolume");
            TextBox txtValidUntil = (TextBox)e.Item.FindControl("txtValidUntil");
            TextBox txtAdditionalSettings = (TextBox)e.Item.FindControl("txtAdditionalSettings");
            TextBox txtOrderValue = (TextBox)e.Item.FindControl("txtOrderValue");
            TextBox txtPriceBufferNumberOfTick = (TextBox)e.Item.FindControl("txtPriceBufferNumberOfTick");

            orderPrice = -1;
            if (txtOrderPrice.Text.Length > 0)
                orderPrice = Convert.ToDecimal(txtOrderPrice.Text);
            priceBufferNumberOfTick = -1;
            if (txtPriceBufferNumberOfTick.Text.Length > 0)
                priceBufferNumberOfTick = Convert.ToInt32(txtPriceBufferNumberOfTick.Text);
            orderVolume = -1;
            if (txtOrderVolume.Text.Length > 0)
                orderVolume = Convert.ToInt32(txtOrderVolume.Text);
            orderValue = -1;
            if (txtOrderValue.Text.Length > 0)
                orderValue = Convert.ToDecimal(txtOrderValue.Text);
            volumeGt = -1;
            if (txtVolumeGt.Text.Length > 0)
                volumeGt = Convert.ToInt32(txtVolumeGt.Text);
            validUntil = "";
            if (txtValidUntil.Text.Length > 0)
                validUntil = txtValidUntil.Text;
            additionalSettings = "";
            if (txtAdditionalSettings.Text.Length > 0)
                additionalSettings = txtAdditionalSettings.Text;

            Validate_Filled_Update_Data();

            string message = "";

            if (!failValidation)
            {
                DataOperation doUpdate = new DataOperation();
                message = doUpdate.UpdateOrder(orderID, orderPrice, volumeGt, orderVolume, validUntil, orderValue, priceBufferNumberOfTick, additionalSettings);
                lblMessage.Text = "OrderID " + orderID.ToString() + " is updated.";
                DataListManageItem.EditItemIndex = -1;
                GetManageItem(orderTypeID);
            }
        }

        protected void Toggle_Order_Volume_Value()
        {
            if (ddlItemCategory.SelectedItem.ToString().Contains("Buy") || ddlItemCategory.SelectedItem.ToString().Contains("Strategy"))
            {
                txtOrderVolume.Enabled = false;
                txtOrderValue.Enabled = true;
            }
            else if (ddlItemCategory.SelectedItem.ToString().Contains("Sell"))
            {
                txtOrderVolume.Enabled = true;
                txtOrderValue.Enabled = false;
            }
        }

        protected void Validate_Filled_Data()
        {
            if (ddlItemCategory.SelectedItem.ToString() == "Sell at bid above")
            {
                if (ddlTradeAccountName.SelectedIndex == 0 || orderPrice == -1 || orderVolume == -1 || volumeGt == -1 || validUntil == "" || priceBufferNumberOfTick == -1)
                {
                    //Response.Write("<script type=\"text/javascript\">alert('" + "Please enter trade account name, order price, price buffer number of tick, order volume, volume greater than and valid until." + "');</script>");
                    lblMessage.Text = "Please enter trade account name, order price, price buffer number of tick, order volume, volume greater than and valid until.";
                    failValidation = true;
                }
            }

            if (ddlItemCategory.SelectedItem.ToString() == "Buy at ask under")
            {
                if (ddlTradeAccountName.SelectedIndex == 0 || orderPrice == -1 || orderValue == -1 || volumeGt == -1 || validUntil == "" || priceBufferNumberOfTick == -1)
                {
                    //Response.Write("<script type=\"text/javascript\">alert('" + "Please enter trade account name, order price, order value, volume greater than and valid until." + "');</script>");
                    lblMessage.Text = "Please enter trade account name, order price, order value, volume greater than and valid until.";
                    failValidation = true;
                }
            }

            if (ddlItemCategory.SelectedItem.ToString() == "Sell at SMA")
            {
                if (ddlTradeAccountName.SelectedIndex == 0 || !(new List<decimal>{5,10,20}).Contains(orderPrice) || orderVolume == -1 || volumeGt == -1 || validUntil == "" || priceBufferNumberOfTick == -1)
                {
                    //Response.Write("<script type=\"text/javascript\">alert('" + "Please enter trade account name, order price, price buffer number of tick, order volume, volume greater than and valid until." + "');</script>");
                    lblMessage.Text = "Please enter trade account name, order price, price buffer number of tick, order volume, volume greater than and valid until.";
                    failValidation = true;
                }
            }

            if (ddlItemCategory.SelectedItem.ToString() == "Buy at SMA")
            {
                if (ddlTradeAccountName.SelectedIndex == 0 || !(new List<decimal> { 3, 5, 10, 20 }).Contains(orderPrice) || orderValue == -1 || volumeGt == -1 || validUntil == "" || priceBufferNumberOfTick == -1)
                {
                    //Response.Write("<script type=\"text/javascript\">alert('" + "Please enter trade account name, order price, price buffer number of tick, order value, volume greater than and valid until." + "');</script>");
                    lblMessage.Text = "Please enter trade account name, order price, price buffer number of tick, order value, volume greater than and valid until.";
                    failValidation = true;
                }
            }

            if (1 == 1)
            {
                if (orderValue > 50000)
                {
                    //Response.Write("<script type=\"text/javascript\">alert('" + "Please check entered value, the maximum value accepted is 50,000." + "');</script>");
                    lblMessage.Text = "Please check entered value, the maximum value accepted is 50,000.";
                    failValidation = true;
                }
            }

        }

        protected void Validate_Filled_Update_Data()
        {
            if (ddlItemCategory.SelectedItem.ToString() == "Sell at bid above")
            {
                if (orderPrice == -1 || orderVolume == -1 || volumeGt == -1 || validUntil == "" || priceBufferNumberOfTick == -1)
                {
                    //Response.Write("<script type=\"text/javascript\">alert('" + "Please enter trade account name, order price, price buffer number of tick, order volume, volume greater than and valid until." + "');</script>");
                    lblMessage.Text = "Please enter trade account name, order price, price buffer number of tick, order volume, volume greater than and valid until.";
                    failValidation = true;
                }
            }

            if (ddlItemCategory.SelectedItem.ToString() == "Buy at ask under")
            {
                if (orderPrice == -1 || orderValue == -1 || volumeGt == -1 || validUntil == "" || priceBufferNumberOfTick == -1)
                {
                    //Response.Write("<script type=\"text/javascript\">alert('" + "Please enter trade account name, order price, order value, volume greater than and valid until." + "');</script>");
                    lblMessage.Text = "Please enter trade account name, order price, order value, volume greater than and valid until.";
                    failValidation = true;
                }
            }

            if (ddlItemCategory.SelectedItem.ToString() == "Sell at SMA")
            {
                if (!(new List<decimal> { 3, 5, 10, 20 }).Contains(orderPrice) || orderVolume == -1 || volumeGt == -1 || validUntil == "" || priceBufferNumberOfTick == -1)
                {
                    //Response.Write("<script type=\"text/javascript\">alert('" + "Please enter trade account name, order price, price buffer number of tick, order volume, volume greater than and valid until." + "');</script>");
                    lblMessage.Text = "Please enter trade account name, order price, price buffer number of tick, order volume, volume greater than and valid until.";
                    failValidation = true;
                }
            }

            if (ddlItemCategory.SelectedItem.ToString() == "Buy at SMA")
            {
                if (!(new List<decimal> { 3, 5, 10, 20 }).Contains(orderPrice) || orderValue == -1 || volumeGt == -1 || validUntil == "" || priceBufferNumberOfTick == -1)
                {
                    //Response.Write("<script type=\"text/javascript\">alert('" + "Please enter trade account name, order price, price buffer number of tick, order value, volume greater than and valid until." + "');</script>");
                    lblMessage.Text = "Please enter trade account name, order price, price buffer number of tick, order value, volume greater than and valid until.";
                    failValidation = true;
                }
            }

            if (1 == 1)
            {
                if (orderValue> 50000)
                {
                    //Response.Write("<script type=\"text/javascript\">alert('" + "Please check entered value, the maximum value accepted is 50,000." + "');</script>");
                    lblMessage.Text = "Please check entered value, the maximum value accepted is 50,000.";
                    failValidation = true;
                }
            }

        }

        protected void Toggle_Order_Price_Type()
        {
            if (ddlItemCategory.SelectedItem.ToString() == "Buy at SMA" || ddlItemCategory.SelectedItem.ToString() == "Sell at SMA")
            {
                //ddlOrderPriceType.SelectedValue = "SMA";
                ;
            }
            else
            {
                ddlOrderPriceType.SelectedValue = "Price";
            }
        }

        protected void ddlItemCategory_SelectedIndexChanged(object sender, EventArgs e)
        {
            orderTypeID = Convert.ToInt32(ddlItemCategory.SelectedValue);
            GetManageItem(orderTypeID);
            Toggle_Order_Volume_Value();
            Toggle_Order_Price_Type();
            Clear();
            RefreshCustomIntegerValue();
        }
    }
}