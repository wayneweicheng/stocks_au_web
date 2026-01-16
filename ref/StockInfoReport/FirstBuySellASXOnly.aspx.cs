using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using DotNet.Highcharts.Helpers;
using DotNet.Highcharts.Options;
using System.Collections;
using DotNet.Highcharts.Enums;
using System.Drawing;
using System.Collections.Specialized;

namespace StockInfoReport
{
    public partial class FirstBuySellASXOnly : System.Web.UI.Page
    {
        DataSet dsCourseOfSale;
        DataSet dsStockListInfo;
        string stockCode = "";
        string numPrevDay = "";

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                if (Request.QueryString["StockCode"] != null)
                    stockCode = Convert.ToString(Request.QueryString["StockCode"]);
                if (Request.QueryString["NumPrevDay"] != null)
                    numPrevDay = Convert.ToString(Request.QueryString["NumPrevDay"]);

                GetStockListInfo();
                ddlStockList.DataSource = dsStockListInfo.Tables[0];
                ddlStockList.DataTextField = "CompanyName";
                ddlStockList.DataValueField = "ASXCode";
                ddlStockList.DataBind();
                ddlStockList.SelectedIndex = -1;
                //lblCourseOfSale.Visible = false;
                txtNumPrevDay.Text = "0";

                if (stockCode.Length > 0 && numPrevDay.Length > 0)
                {
                    int i = 0;
                    foreach (ListItem item in ddlStockList.Items)
                    {
                        if (item.Value == stockCode)
                            ddlStockList.SelectedIndex = i;
                        i++;
                    }
                    txtNumPrevDay.Text = numPrevDay;
                    if (ddlStockList.SelectedIndex > 0 && ddlStockList.SelectedValue != stockCode)
                        updateUrl();

                }

                if (ddlStockList.SelectedIndex > 0)
                {
                    string pvchStockCode = ddlStockList.SelectedValue;
                    GetCourseOfSale(pvchStockCode);
                    FillGridCOSVolume();
                    gvCOSVolume.DataBind();
                }
            }
            else
            {
                //lblCourseOfSale.Visible = true;
                lblCourseOfSalebyVolume.Visible = true;
            }
        }

        public void updateUrl()
        {
            stockCode = ddlStockList.SelectedValue;
            numPrevDay = txtNumPrevDay.Text;
            string url = HttpContext.Current.Request.Url.AbsoluteUri;
            string[] separateURL = url.Split('?');
            NameValueCollection queryString = System.Web.HttpUtility.ParseQueryString(separateURL[1]);
            if (queryString["StockCode"] != stockCode.ToString() || queryString["NumPrevDay"] != numPrevDay.ToString())
            {
                queryString["StockCode"] = stockCode.ToString();
                queryString["NumPrevDay"] = numPrevDay.ToString();
                url = separateURL[0] + "?" + queryString.ToString();
                Response.Redirect(url);
            }
        }

        public void FillGridCOSVolume()
        {
            string pvchStockCode = ddlStockList.SelectedValue;
            GetCourseOfSale(pvchStockCode);
            gvCOSVolume.DataSource = dsCourseOfSale.Tables[0];
        }
        public void GetCourseOfSale(string pvchStockCode)
        {
            int numPrevDay = Convert.ToInt32(txtNumPrevDay.Text);
            DataOperation doCourseOfSale = new DataOperation();
            dsCourseOfSale = doCourseOfSale.GetFirstBuySellASXOnly(pvchStockCode, numPrevDay);
        }

        public void GetStockListInfo()
        {
            DataOperation doStockListInfo = new DataOperation();
            dsStockListInfo = doStockListInfo.GetCOSMonitorStock();
        }
        
        protected void ddlStockList_SelectedIndexChanged(object sender, EventArgs e)
        {
            string pvchStockCode = ddlStockList.SelectedValue;
            updateUrl();
            //GetCourseOfSale(pvchStockCode);
            //FillGridCOSVolume();
            //gvCOSVolume.DataBind();
        }

        protected void gvCOSVolume_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            FillGridCOSVolume();
            gvCOSVolume.PageIndex = e.NewPageIndex;
            gvCOSVolume.DataBind();
        }

        protected void txtNumPrevDay_TextChanged(object sender, EventArgs e)
        {
            string pvchStockCode = ddlStockList.SelectedValue;
            updateUrl();
            //GetCourseOfSale(pvchStockCode);
            //FillGridCOSVolume();
            //gvCOSVolume.DataBind();
        }

        protected void gvCOSVolume_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                //e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                //e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                //e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                if (drv != null)
                {
                    if (drv["TransPrice"].ToString().Length > 0)
                    {
                        if (drv["ActBuySellInd"].ToString() == "B")
                        {
                            e.Row.BackColor = Color.FromName("#d5f5e3");
                        }
                        else if (drv["ActBuySellInd"].ToString() == "S")
                        {
                            e.Row.BackColor = Color.FromName("#fadbd8");
                        }
                        else if (drv["TransPrice"].ToString().Length > 0)
                        {
                            e.Row.BackColor = Color.FromName("#fcf3cf");
                        }
                    }

                    //if (drv["SearchTerm"].ToString().Length > 0)
                    //{

                    //    e.Row.BackColor = Color.FromName("#FADBD8");
                    //}

                    //string[] annKeyWords = new string[] { "ACQUISITION", "OFF TAKE", "OFF-TAKE", "OFF TAKE" };

                    //if (GetYahoo.StringExtensions.ContainsAny(drv["AnnDescr"].ToString().ToUpper(), annKeyWords))
                    //{
                    //    e.Row.Style.Add(HtmlTextWriterStyle.FontWeight, "Bold");
                    //}

                }

                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
                //if (drv != null)
                //    e.Row.Attributes.Add("onclick", String.Format("window.location='http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show='", drv["ASXCode"].ToString().Substring(0, 3)));
            }

        }
    }
}