using GetYahoo;
using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Configuration;
using System.Collections.Specialized;

namespace StockInfoReport
{
    public partial class BrokerReport : System.Web.UI.Page
    {
        DataSet dsDataSet1;
        DataSet dsDataSet2;
        DataSet dsDataSet3;
        DataSet dsDataSet4;
        DataSet dsDataSet5;
        DataSet dsDataSet6;
        DataSet dsDataSet7;
        DataSet dsDataSet8;
        DataSet dsDataSet9;
        string stockCode;
        string observationDate;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                txtStockCode.Text = Convert.ToString(Request.QueryString["StockCode"]);
                txtObservationDate.Text = Convert.ToString(Request.QueryString["ObservationDate"]);
                
                if (txtStockCode.Text.Length > 0 && txtObservationDate.Text.Length > 0)
                {
                    stockCode = txtStockCode.Text;
                    observationDate = txtObservationDate.Text;
                    FillDataSet();
                }


            }
            //else
            //{
            //    lblLargeSale.Visible = true;
            //    lblLargeSalebyDate.Visible = true;
            //    lblLargeSalebyVolume.Visible = true;
            //}

        }

        public void FilldsDataSet1(string stockCode, string observationDate)
        {
            GetDataSet1(stockCode, observationDate);
            UpdateObservationDateValues();
            gvDataSet1.DataSource = dsDataSet1.Tables[0];
            gvDataSet1.DataBind();
        }

        public void UpdateObservationDateValues()
        {
            if (dsDataSet1.Tables[0].Rows.Count > 0)
            {
                if (dsDataSet1.Tables[0].Rows[0]["ObservationDate"] != null && observationDate == "2050-12-12")
                {
                    observationDate = dsDataSet1.Tables[0].Rows[0]["ObservationDate"].ToString();
                    txtObservationDate.Text = observationDate;
                    updateUrl();
                }
            }

        }

        public void updateUrl()
        {
            observationDate = txtObservationDate.Text;
            stockCode = txtStockCode.Text;
            string url = HttpContext.Current.Request.Url.AbsoluteUri;
            string[] separateURL = url.Split('?');
            NameValueCollection queryString = System.Web.HttpUtility.ParseQueryString(separateURL[1]);
            if (queryString["StockCode"] != stockCode.ToString() || queryString["ObservationDate"] != observationDate)
            {
                queryString["StockCode"] = stockCode.ToString();
                queryString["ObservationDate"] = observationDate;
                url = separateURL[0] + "?" + queryString.ToString();
                Response.Redirect(url);
            }
        }

        public void FilldsDataSet2(string stockCode, string observationDate)
        {
            DateTime dt = Convert.ToDateTime(observationDate);
            DateTime newDt = DateExtensions.AddBusinessDays(dt, -1);
            string newObservationDate = newDt.ToString("yyyy-MM-dd");
            GetDataSet2(stockCode, newObservationDate);
            gvDataSet2.DataSource = dsDataSet2.Tables[0];
            gvDataSet2.DataBind();
        }

        public void FilldsDataSet3(string stockCode, string observationDate)
        {
            DateTime dt = Convert.ToDateTime(observationDate);
            DateTime newDt = DateExtensions.AddBusinessDays(dt, -2);
            string newObservationDate = newDt.ToString("yyyy-MM-dd");
            GetDataSet3(stockCode, newObservationDate);
            gvDataSet3.DataSource = dsDataSet3.Tables[0];
            gvDataSet3.DataBind();
        }

        public void FilldsDataSet4(string stockCode, string observationDate)
        {
            DateTime dt = Convert.ToDateTime(observationDate);
            DateTime newDt = DateExtensions.AddBusinessDays(dt, -5);
            string newObservationDate = newDt.ToString("yyyy-MM-dd");
            GetDataSet4(stockCode, newObservationDate, observationDate);
            gvDataSet4.DataSource = dsDataSet4.Tables[0];
            gvDataSet4.DataBind();
        }

        public void FilldsDataSet5(string stockCode, string observationDate)
        {
            DateTime dt = Convert.ToDateTime(observationDate);
            DateTime newDt = DateExtensions.AddBusinessDays(dt, -10);
            string newObservationDate = newDt.ToString("yyyy-MM-dd");
            GetDataSet5(stockCode, newObservationDate, observationDate);
            gvDataSet5.DataSource = dsDataSet5.Tables[0];
            gvDataSet5.DataBind();
        }
        public void FilldsDataSet6(string stockCode, string observationDate)
        {
            DateTime dt = Convert.ToDateTime(observationDate);
            DateTime newDt = DateExtensions.AddBusinessDays(dt, -20);
            string newObservationDate = newDt.ToString("yyyy-MM-dd");
            GetDataSet6(stockCode, newObservationDate, observationDate);
            gvDataSet6.DataSource = dsDataSet6.Tables[0];
            gvDataSet6.DataBind();
        }
        public void FilldsDataSet7(string stockCode, string observationDate)
        {
            DateTime dt = Convert.ToDateTime(observationDate);
            DateTime newDt = DateExtensions.AddBusinessDays(dt, -60);
            string newObservationDate = newDt.ToString("yyyy-MM-dd");
            GetDataSet7(stockCode, newObservationDate, observationDate);
            gvDataSet7.DataSource = dsDataSet7.Tables[0];
            gvDataSet7.DataBind();
        }
        public void FilldsDataSet8(string stockCode, string observationDate)
        {
            DateTime dt = Convert.ToDateTime(observationDate);
            DateTime newDt = DateExtensions.AddBusinessDays(dt, -120);
            string newObservationDate = newDt.ToString("yyyy-MM-dd");
            GetDataSet8(stockCode, newObservationDate, observationDate);
            gvDataSet8.DataSource = dsDataSet8.Tables[0];
            gvDataSet8.DataBind();
        }
        public void FilldsDataSet9(string stockCode, string observationDate)
        {
            DateTime dt = Convert.ToDateTime(observationDate);
            DateTime newDt = DateExtensions.AddBusinessDays(dt, -240);
            string newObservationDate = newDt.ToString("yyyy-MM-dd");
            GetDataSet9(stockCode, newObservationDate, observationDate);
            gvDataSet9.DataSource = dsDataSet9.Tables[0];
            gvDataSet9.DataBind();
        }

        public void GetDataSet1(string stockCode, string observationDate)
        {
            DataOperation doDataSet1 = new DataOperation();
            dsDataSet1 = doDataSet1.GetBrokerReport(stockCode, observationDate);
        }

        public void GetDataSet2(string stockCode, string observationDate)
        {
            DataOperation doDataSet2 = new DataOperation();
            dsDataSet2 = doDataSet2.GetBrokerReport(stockCode, observationDate);
        }

        public void GetDataSet3(string stockCode, string observationDate)
        {
            DataOperation doDataSet3 = new DataOperation();
            dsDataSet3 = doDataSet3.GetBrokerReport(stockCode, observationDate);
        }

        public void GetDataSet4(string stockCode, string observationDate, string endObservationDate)
        {
            DataOperation doDataSet4 = new DataOperation();

            dsDataSet4 = doDataSet4.GetBrokerReportStartFrom(stockCode, observationDate, endObservationDate);
        }
        public void GetDataSet5(string stockCode, string observationDate, string endObservationDate)
        {
            DataOperation doDataSet5 = new DataOperation();
            dsDataSet5 = doDataSet5.GetBrokerReportStartFrom(stockCode, observationDate, endObservationDate);
        }
        public void GetDataSet6(string stockCode, string observationDate, string endObservationDate)
        {
            DataOperation doDataSet6 = new DataOperation();
            dsDataSet6 = doDataSet6.GetBrokerReportStartFrom(stockCode, observationDate, endObservationDate);
        }
        public void GetDataSet7(string stockCode, string observationDate, string endObservationDate)
        {
            DataOperation doDataSet7 = new DataOperation();
            dsDataSet7 = doDataSet7.GetBrokerReportStartFrom(stockCode, observationDate, endObservationDate);
        }
        public void GetDataSet8(string stockCode, string observationDate, string endObservationDate)
        {
            DataOperation doDataSet8 = new DataOperation();
            dsDataSet8 = doDataSet8.GetBrokerReportStartFrom(stockCode, observationDate, endObservationDate);
        }
        public void GetDataSet9(string stockCode, string observationDate, string endObservationDate)
        {
            DataOperation doDataSet9 = new DataOperation();
            dsDataSet9 = doDataSet9.GetBrokerReportStartFrom(stockCode, observationDate, endObservationDate);
        }

        protected void gvDataSet1_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            observationDate = txtObservationDate.Text;
            FilldsDataSet1(stockCode, observationDate);
            gvDataSet1.PageIndex = e.NewPageIndex;
            gvDataSet1.DataBind();
        }

        protected void gvDataSet1_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
            if (drv != null)
            {
                if (1 == 1)
                {
                    if (drv.Row.Table.Columns.Contains("PriceChangeVsPrevClose") && drv.Row.Table.Columns.Contains("VWAP") && drv.Row.Table.Columns.Contains("BuyPrice") && drv.Row.Table.Columns.Contains("SellPrice") && drv.Row.Table.Columns.Contains("NetVolume"))
                    {
                        if (drv["PriceChangeVsPrevClose"] != null & drv["VWAP"] != null && drv["BuyPrice"] != null && drv["SellPrice"] != null && drv["NetVolume"] != null)
                        {
                            if (drv["PriceChangeVsPrevClose"].ToString().Length > 0 && drv["VWAP"].ToString().Length > 0 && drv["BuyPrice"].ToString().Length > 0 && drv["SellPrice"].ToString().Length > 0 && drv["NetVolume"].ToString().Length > 0)
                            {
                                if (
                                    Convert.ToDecimal(drv["PriceChangeVsPrevClose"].ToString()) >= Convert.ToDecimal(3.0)
                                    && Convert.ToDecimal(drv["NetVolume"].ToString()) > Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["BuyPrice"].ToString()) > Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["BuyPrice"].ToString()) > Convert.ToDecimal(drv["VWAP"].ToString())
                                )
                                {
                                    e.Row.BackColor = Color.LightGreen;
                                }
                            }
                        }
                    }

                    if (drv.Row.Table.Columns.Contains("PriceChangeVsPrevClose") && drv.Row.Table.Columns.Contains("VWAP") && drv.Row.Table.Columns.Contains("BuyPrice") && drv.Row.Table.Columns.Contains("SellPrice") && drv.Row.Table.Columns.Contains("NetVolume"))
                    {
                        if (drv["PriceChangeVsPrevClose"] != null & drv["VWAP"] != null && drv["BuyPrice"] != null && drv["SellPrice"] != null && drv["NetVolume"] != null)
                        {
                            if (drv["PriceChangeVsPrevClose"].ToString().Length > 0 && drv["VWAP"].ToString().Length > 0 && drv["BuyPrice"].ToString().Length > 0 && drv["SellPrice"].ToString().Length > 0 && drv["NetVolume"].ToString().Length > 0)
                            {
                                if (
                                    Convert.ToDecimal(drv["PriceChangeVsPrevClose"].ToString()) <= Convert.ToDecimal(-3.0)
                                    && Convert.ToDecimal(drv["NetVolume"].ToString()) < Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["SellPrice"].ToString()) > Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["SellPrice"].ToString()) < Convert.ToDecimal(drv["VWAP"].ToString())
                                )
                                {
                                    e.Row.BackColor = Color.LightPink;
                                }
                            }
                        }
                    }

                }
            }

        }

        protected void gvDataSet1_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            if (e.CommandName == "ViewChart")
            {
                // Convert the row index stored in the CommandArgument
                // property to an Integer.
                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[0];
                string asxCode = tcASXCode.Text;

                string redirectURL;
                if (true || Request.Browser.IsMobileDevice)
                    redirectURL = String.Format("../IntegratedCharts.aspx?StockCode={0}", asxCode);
                else
                    redirectURL = String.Format("https://www.cmcmarketsstockbroking.com.au/net/UI/Chart/AdvancedChart.aspx?asxcode={0}", asxCode.Substring(0, 3));

                //string redirectURL = String.Format("http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show=", asxCode.Substring(0, 3));

                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);

                //Response.Redirect(redirectURL,false);
                //MsgBox(asxCode, this.Page, this);
            }

            //if (e.CommandName == "ViewHC")
            //{
            //    // Convert the row index stored in the CommandArgument
            //    // property to an Integer.
            //    int index = Convert.ToInt32(e.CommandArgument);

            //    GridViewRow selectedRow = gvDataSet1.Rows[index];
            //    TableCell tcASXCode = selectedRow.Cells[0];
            //    string asxCode = tcASXCode.Text;

            //    //string redirectURL = String.Format("../StockInsight.aspx?StockCode={0}", asxCode);
            //    //ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);

            //    DataOperation doGetSearchString = new DataOperation();
            //    string HCSearchString = doGetSearchString.GetHCSearchString(asxCode);

            //    string redirectURL = HCSearchString;
            //    ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);

            //}

            if (e.CommandName == "ViewTop20")
            {
                // Convert the row index stored in the CommandArgument
                // property to an Integer.
                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[0];
                string asxCode = tcASXCode.Text;

                string redirectURL = String.Format("https://scanner.daytradescans.com/share_holders?utf8=✓&Stock+Code_autocomplete_label={0}&Stock+Code=&share_holder_autocomplete_label=&share_holder=&commit=Search", asxCode.Substring(0, 3)); ;
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);
            }

            if (e.CommandName == "ViewBrokerData")
            {
                // Convert the row index stored in the CommandArgument
                // property to an Integer.
                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[0];
                string asxCode = tcASXCode.Text;
                string observationDate = txtObservationDate.Text;
                DateTime dt = Convert.ToDateTime(observationDate);
                DateTime newDt = DateExtensions.AddBusinessDays(dt, -1);
                string observationDateFrom = newDt.ToString("yyyy-MM-dd");

                string redirectURL = String.Format("https://scanner.daytradescans.com/brokers?utf8=%E2%9C%93&code_autocomplete_label={0}&code=&name_autocomplete_label=&name=&from={1}&to={2}&commit=Search", asxCode.Substring(0, 3), observationDateFrom, observationDate);
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);
            }

            if (e.CommandName == "ViewCourseOfSale")
            {
                // Convert the row index stored in the CommandArgument
                // property to an Integer.
                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[0];
                string asxCode = tcASXCode.Text;
                TableCell tcObservationDate = selectedRow.Cells[1];
                string observationDate = tcObservationDate.Text;
                DateTime dt = Convert.ToDateTime(observationDate);
                string stdObservationDate = dt.ToString("yyyy-MM-dd");
                string redirectURL = String.Format("../CourseOfSale.aspx?StockCode={0}&ObservationDate={1}", asxCode, stdObservationDate);
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);
            }

            if (e.CommandName == "ViewInsight")
            {

                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[0];
                string asxCode = tcASXCode.Text;

                string redirectURL = String.Format("../StockInsight.aspx?StockCode={0}", asxCode);
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);

            }

        }


        protected void gvDataSe1_RowCreated(object sender, GridViewRowEventArgs e)
        {
            GridViewRow row = e.Row;
            // Intitialize TableCell list
            List<TableCell> columns = new List<TableCell>();
            foreach (DataControlField column in gvDataSet1.Columns)
            {
                if (row.Cells.Count > 0)
                {
                    //Get the first Cell /Column
                    TableCell cell = row.Cells[0];
                    // Then Remove it after
                    row.Cells.Remove(cell);
                    //And Add it to the List Collections
                    columns.Add(cell);
                }
            }

            // Add cells
            row.Cells.AddRange(columns.ToArray());

        }

        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            //FilldsDataSet1(stockCode);
            //FilldsDataSet1(stockCode);
        }

        protected void gvDataSet2_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            observationDate = txtObservationDate.Text;
            FilldsDataSet2(stockCode, observationDate);
            gvDataSet2.PageIndex = e.NewPageIndex;
            gvDataSet2.DataBind();
        }

        protected void gvDataSet2_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet2_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
            if (drv != null)
            {
                if (1 == 1)
                {
                    if (drv.Row.Table.Columns.Contains("PriceChangeVsPrevClose") && drv.Row.Table.Columns.Contains("VWAP") && drv.Row.Table.Columns.Contains("BuyPrice") && drv.Row.Table.Columns.Contains("SellPrice") && drv.Row.Table.Columns.Contains("NetVolume"))
                    {
                        if (drv["PriceChangeVsPrevClose"] != null & drv["VWAP"] != null && drv["BuyPrice"] != null && drv["SellPrice"] != null && drv["NetVolume"] != null)
                        {
                            if (drv["PriceChangeVsPrevClose"].ToString().Length > 0 && drv["VWAP"].ToString().Length > 0 && drv["BuyPrice"].ToString().Length > 0 && drv["SellPrice"].ToString().Length > 0 && drv["NetVolume"].ToString().Length > 0)
                            {
                                if (
                                    Convert.ToDecimal(drv["PriceChangeVsPrevClose"].ToString()) >= Convert.ToDecimal(3.0)
                                    && Convert.ToDecimal(drv["NetVolume"].ToString()) > Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["BuyPrice"].ToString()) > Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["BuyPrice"].ToString()) > Convert.ToDecimal(drv["VWAP"].ToString())
                                )
                                {
                                    e.Row.BackColor = Color.LightGreen;
                                }
                            }
                        }
                    }

                    if (drv.Row.Table.Columns.Contains("PriceChangeVsPrevClose") && drv.Row.Table.Columns.Contains("VWAP") && drv.Row.Table.Columns.Contains("BuyPrice") && drv.Row.Table.Columns.Contains("SellPrice") && drv.Row.Table.Columns.Contains("NetVolume"))
                    {
                        if (drv["PriceChangeVsPrevClose"] != null & drv["VWAP"] != null && drv["BuyPrice"] != null && drv["SellPrice"] != null && drv["NetVolume"] != null)
                        {
                            if (drv["PriceChangeVsPrevClose"].ToString().Length > 0 && drv["VWAP"].ToString().Length > 0 && drv["BuyPrice"].ToString().Length > 0 && drv["SellPrice"].ToString().Length > 0 && drv["NetVolume"].ToString().Length > 0)
                            {
                                if (
                                    Convert.ToDecimal(drv["PriceChangeVsPrevClose"].ToString()) <= Convert.ToDecimal(-3.0)
                                    && Convert.ToDecimal(drv["NetVolume"].ToString()) < Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["SellPrice"].ToString()) > Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["SellPrice"].ToString()) < Convert.ToDecimal(drv["VWAP"].ToString())
                                )
                                {
                                    e.Row.BackColor = Color.LightPink;
                                }
                            }
                        }
                    }

                }
            }
        }

        protected void btnStockCode_Click(object sender, EventArgs e)
        {
            string redirectUrl = String.Format("BrokerReport.aspx?StockCode={0}&ObservationDate={1}", txtStockCode.Text, txtObservationDate.Text);
            Response.Redirect(redirectUrl);
        }

        public void FillDataSet()
        {
            FilldsDataSet1(stockCode, observationDate);
            FilldsDataSet2(stockCode, observationDate);
            FilldsDataSet3(stockCode, observationDate);
            FilldsDataSet4(stockCode, observationDate);
            FilldsDataSet5(stockCode, observationDate);
            FilldsDataSet6(stockCode, observationDate);
            FilldsDataSet7(stockCode, observationDate);
            FilldsDataSet8(stockCode, observationDate);
            FilldsDataSet9(stockCode, observationDate);
        }

        protected void gvDataSet3_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
            if (drv != null)
            {
                if (1 == 1)
                {
                    if (drv.Row.Table.Columns.Contains("PriceChangeVsPrevClose") && drv.Row.Table.Columns.Contains("VWAP") && drv.Row.Table.Columns.Contains("BuyPrice") && drv.Row.Table.Columns.Contains("SellPrice") && drv.Row.Table.Columns.Contains("NetVolume"))
                    {
                        if (drv["PriceChangeVsPrevClose"] != null & drv["VWAP"] != null && drv["BuyPrice"] != null && drv["SellPrice"] != null && drv["NetVolume"] != null)
                        {
                            if (drv["PriceChangeVsPrevClose"].ToString().Length > 0 && drv["VWAP"].ToString().Length > 0 && drv["BuyPrice"].ToString().Length > 0 && drv["SellPrice"].ToString().Length > 0 && drv["NetVolume"].ToString().Length > 0)
                            {
                                if (
                                    Convert.ToDecimal(drv["PriceChangeVsPrevClose"].ToString()) >= Convert.ToDecimal(1.0)
                                    && Convert.ToDecimal(drv["NetVolume"].ToString()) > Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["BuyPrice"].ToString()) > Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["BuyPrice"].ToString()) > Convert.ToDecimal(drv["VWAP"].ToString())
                                )
                                {
                                    e.Row.BackColor = Color.LightGreen;
                                }
                            }
                        }
                    }

                    if (drv.Row.Table.Columns.Contains("PriceChangeVsPrevClose") && drv.Row.Table.Columns.Contains("VWAP") && drv.Row.Table.Columns.Contains("BuyPrice") && drv.Row.Table.Columns.Contains("SellPrice") && drv.Row.Table.Columns.Contains("NetVolume"))
                    {
                        if (drv["PriceChangeVsPrevClose"] != null & drv["VWAP"] != null && drv["BuyPrice"] != null && drv["SellPrice"] != null && drv["NetVolume"] != null)
                        {
                            if (drv["PriceChangeVsPrevClose"].ToString().Length > 0 && drv["VWAP"].ToString().Length > 0 && drv["BuyPrice"].ToString().Length > 0 && drv["SellPrice"].ToString().Length > 0 && drv["NetVolume"].ToString().Length > 0)
                            {
                                if (
                                    Convert.ToDecimal(drv["PriceChangeVsPrevClose"].ToString()) <= Convert.ToDecimal(-1.0)
                                    && Convert.ToDecimal(drv["NetVolume"].ToString()) < Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["SellPrice"].ToString()) > Convert.ToDecimal(0)
                                    && Convert.ToDecimal(drv["SellPrice"].ToString()) < Convert.ToDecimal(drv["VWAP"].ToString())
                                )
                                {
                                    e.Row.BackColor = Color.LightPink;
                                }
                            }
                        }
                    }

                }
            }
        }

        protected void gvDataSet3_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet3_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            observationDate = txtObservationDate.Text;
            FilldsDataSet3(stockCode, observationDate);
            gvDataSet3.PageIndex = e.NewPageIndex;
            gvDataSet3.DataBind();
        }

        protected void gvDataSet4_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            observationDate = txtObservationDate.Text;
            FilldsDataSet4(stockCode, observationDate);
            gvDataSet4.PageIndex = e.NewPageIndex;
            gvDataSet4.DataBind();

        }

        protected void gvDataSet4_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
                //if (drv != null)
                //    e.Row.Attributes.Add("onclick", String.Format("window.location='http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show='", drv["ASXCode"].ToString().Substring(0, 3)));
                //if (drv != null)
                //{
                //    if (drv["IsPlacement"].ToString().Length > 0)
                //    {
                //        if (Convert.ToBoolean(drv["IsPlacement"].ToString()) == true)
                //        {
                //            e.Row.BackColor = Color.FromName("#D8FAEC");
                //        }
                //        //if (drv["XRefMarketCap"].ToString().Length > 0)
                //        //{
                //        //    if (Convert.ToDecimal(drv["XRefMarketCap"].ToString()) > 500)
                //        //    {
                //        //        e.Row.Style.Add(HtmlTextWriterStyle.FontWeight, "Bold");
                //        //    }
                //        //}


                //    }
                //}

            }
        }

        protected void gvDataSet4_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet5_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
                //if (drv != null)
                //    e.Row.Attributes.Add("onclick", String.Format("window.location='http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show='", drv["ASXCode"].ToString().Substring(0, 3)));
                //if (drv != null)
                //{
                //    if (drv["PercHolding"].ToString().Length > 0)
                //    {
                //        if (Convert.ToDecimal(drv["PercHolding"].ToString()) > 5)
                //        {
                //            e.Row.BackColor = Color.FromName("#D8FAEC");
                //        }

                //    }
                //}
            }
        }

        protected void gvDataSet5_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet5_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            observationDate = txtObservationDate.Text;
            FilldsDataSet5(stockCode, observationDate);
            gvDataSet5.PageIndex = e.NewPageIndex;
            gvDataSet5.DataBind();
        }


        protected void gvDataSet6_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
            }
        }

        protected void gvDataSet6_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet6_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            observationDate = txtObservationDate.Text;
            FilldsDataSet6(stockCode, observationDate);
            gvDataSet6.PageIndex = e.NewPageIndex;
            gvDataSet6.DataBind();
        }

        protected void gvDataSet7_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
            }
        }

        protected void gvDataSet7_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet7_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            observationDate = txtObservationDate.Text;
            FilldsDataSet7(stockCode, observationDate);
            gvDataSet7.PageIndex = e.NewPageIndex;
            gvDataSet7.DataBind();
        }

        protected void gvDataSet8_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
            }
        }

        protected void gvDataSet8_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet8_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            observationDate = txtObservationDate.Text;
            FilldsDataSet8(stockCode, observationDate);
            gvDataSet8.PageIndex = e.NewPageIndex;
            gvDataSet8.DataBind();
        }

        protected void gvDataSet9_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
            }
        }

        protected void gvDataSet9_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet9_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            observationDate = txtObservationDate.Text;
            FilldsDataSet9(stockCode, observationDate);
            gvDataSet9.PageIndex = e.NewPageIndex;
            gvDataSet9.DataBind();
        }

    }
}