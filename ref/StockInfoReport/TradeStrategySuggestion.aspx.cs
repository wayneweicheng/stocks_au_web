using GetYahoo;
using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class TradeStrategySuggestion : System.Web.UI.Page
    {
        DataSet dsDataSet1;
        DataSet dsDataSet2;
        string selectItem;
        int reportType;
        int numPrevDay;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                reportType = Convert.ToInt32(Request.QueryString["ReportType"]);
                numPrevDay = Convert.ToInt32(Request.QueryString["NumPrevDay"]);
                txtNumPrevDay.Text = numPrevDay.ToString();
                ddlOrderBy.SelectedIndex = reportType;
                selectItem = ddlOrderBy.SelectedValue;
                FilldsDataSet1();
            }
            else
            {
                updateUrl();
            }
        }

        public void updateUrl()
        {
            reportType = ddlOrderBy.SelectedIndex;
            numPrevDay = Convert.ToInt32(txtNumPrevDay.Text);
            string url = HttpContext.Current.Request.Url.AbsoluteUri;
            string[] separateURL = url.Split('?');
            NameValueCollection queryString = System.Web.HttpUtility.ParseQueryString(separateURL[1]);
            if (queryString["ReportType"] != reportType.ToString() || queryString["NumPrevDay"] != numPrevDay.ToString())
            {
                queryString["ReportType"] = reportType.ToString();
                queryString["NumPrevDay"] = numPrevDay.ToString();
                url = separateURL[0] + "?" + queryString.ToString();
                Response.Redirect(url);
            }
        }

        public void FilldsDataSet1()
        {
            GetDataSet1();

            hlBatchChart.NavigateUrl = BuildBatchChartLink(dsDataSet1.Tables[0]);
            gvDataSet1.DataSource = dsDataSet1.Tables[0];
            gvDataSet1.DataBind();
        }

        public string BuildBatchChartLink(DataTable dtTable)
        {
            string stockCodeList = "";
            foreach (DataRow dr in dsDataSet1.Tables[0].Rows)
            {
                string stockCode = dr["ASXCode"].ToString();
                bool display = true;
                if (dr.Table.Columns.Contains("AlertTypeScore"))
                {
                    int alertyTypeScore = Convert.ToInt32(dr["AlertTypeScore"]);
                    if (alertyTypeScore < 20)
                        display = false;
                }
                if (display && !stockCodeList.Contains(stockCode))
                    stockCodeList += stockCode + "|";
            }
            if (stockCodeList.Length > 0)
                stockCodeList = stockCodeList.Substring(0, stockCodeList.Length - 1);
            string batchChartLink = "../BatchDailyCharts.aspx?StockCodeList=" + stockCodeList;

            return batchChartLink;
        }

        //public void FilldsDataSet2()
        //{
        //    GetDataSet2();
        //    gvDataSet2.DataSource = dsDataSet2.Tables[0];
        //    gvDataSet2.DataBind();
        //}

        public void GetDataSet1()
        {
            DataOperation doDataSet1 = new DataOperation();
            dsDataSet1 = doDataSet1.GetTradeStrategySuggestion(selectItem, Convert.ToInt16(txtNumPrevDay.Text));
        }

        //public void GetDataSet2()
        //{
        //    DataOperation doDataSet2 = new DataOperation();
        //    dsDataSet2 = doDataSet2.GetCommonStockPlus(sortBy);
        //}

        protected void gvDataSet1_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            selectItem = ddlOrderBy.SelectedValue;
            FilldsDataSet1();
            gvDataSet1.PageIndex = e.NewPageIndex;
            gvDataSet1.DataBind();
        }

        protected void gvDataSet1_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;

                if (drv != null)
                {
                    if (selectItem.Contains("Broker Buy Retail Sell"))
                    {
                        if (drv.Row.Table.Columns.Contains("Close") && drv.Row.Table.Columns.Contains("BrokerBuyPrice"))
                        {
                            if (drv["Close"] != null & drv["BrokerBuyPrice"] != null)
                            {
                                if (Convert.ToDecimal(drv["BrokerBuyPrice"].ToString()) * Convert.ToDecimal(1.00) > Convert.ToDecimal(drv["Close"].ToString()))
                                    e.Row.BackColor = Color.FromName("#EEB866");
                                else if (Convert.ToDecimal(drv["BrokerBuyPrice"].ToString()) * Convert.ToDecimal(1.05) > Convert.ToDecimal(drv["Close"].ToString()))
                                    e.Row.BackColor = Color.FromName("#66EE7F");
                                else if (Convert.ToDecimal(drv["BrokerBuyPrice"].ToString()) * Convert.ToDecimal(1.10) > Convert.ToDecimal(drv["Close"].ToString()))
                                    e.Row.BackColor = Color.FromName("#28CA46");
                                else if (Convert.ToDecimal(drv["BrokerBuyPrice"].ToString())* Convert.ToDecimal(1.15) > Convert.ToDecimal(drv["Close"].ToString()))
                                    e.Row.BackColor = Color.FromName("#A3E4D7");
                                

                                //if (drv["AvgTradeValuePerc"].ToString().Length > 0 && drv["InstituteTradeValuePerc"].ToString().Length > 0 && drv["InstituteBuyPerc"].ToString().Length > 0 && drv["RetailBuyPerc"].ToString().Length > 0 && drv["InstituteBuyVWAP"].ToString().Length > 0 && drv["RetailBuyVWAP"].ToString().Length > 0 && drv["Close"].ToString().Length > 0)
                                //{
                                //    if (
                                //        Convert.ToDecimal(drv["InstituteTradeValuePerc"].ToString()) > Convert.ToDecimal(0.95) * Convert.ToDecimal(drv["AvgTradeValuePerc"].ToString())
                                //    )
                                //    {
                                //        e.Row.Font.Bold = true;
                                //    }
                                //    if (
                                //        Convert.ToDecimal(drv["InstituteBuyVWAP"].ToString()) > Convert.ToDecimal(drv["RetailBuyVWAP"].ToString())
                                //    )
                                //    {
                                //        e.Row.Font.Italic = true;
                                //    }
                                //    if (
                                //        Convert.ToDecimal(drv["InstituteBuyVWAP"].ToString()) < Convert.ToDecimal(drv["Close"].ToString()) && Convert.ToDecimal(drv["ChangePerc"].ToString()) > 0
                                //    )
                                //    {
                                //        ;
                                //    }
                                //    else
                                //    {
                                //        e.Row.BorderStyle = BorderStyle.Dotted;
                                //    }
                                //    if (Convert.ToDecimal(drv["InstituteBuyPerc"].ToString()) > Convert.ToDecimal(1.05) * Convert.ToDecimal(drv["RetailBuyPerc"].ToString()))
                                //    {
                                //        e.Row.BackColor = Color.FromName("#A3E4D7");
                                //    }


                                //}
                            }
                        }
                    }

                }
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

        protected void gvDataSet1_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            if (e.CommandName == "ViewChart")
            {
                // Convert the row index stored in the CommandArgument
                // property to an Integer.
                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[2];
                string asxCode = tcASXCode.Text;

                //string redirectURL = String.Format("https://www.cmcmarketsstockbroking.com.au/net/UI/Chart/AdvancedChart.aspx?asxcode={0}", asxCode.Substring(0, 3));
                //string redirectURL = String.Format("http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show=", asxCode.Substring(0, 3));
                string redirectURL;
                if (true || Request.Browser.IsMobileDevice)
                    redirectURL = String.Format("../IntegratedCharts.aspx?StockCode={0}", asxCode);
                else
                    redirectURL = String.Format("https://www.cmcmarketsstockbroking.com.au/net/UI/Chart/AdvancedChart.aspx?asxcode={0}", asxCode.Substring(0, 3));

                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);

                //Response.Redirect(redirectURL,false);
                //MsgBox(asxCode, this.Page, this);
            }

            if (e.CommandName == "ViewCourseOfSale")
            {
                // Convert the row index stored in the CommandArgument
                // property to an Integer.
                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[2];
                string asxCode = tcASXCode.Text;
                TableCell tcObservationDate = selectedRow.Cells[3];
                string observationDate = tcObservationDate.Text;
                DateTime dt = Convert.ToDateTime(observationDate);
                string stdObservationDate = dt.ToString("yyyy-MM-dd");
                string redirectURL = String.Format("../CourseOfSale.aspx?StockCode={0}&ObservationDate={1}", asxCode, stdObservationDate);
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);
            }

            if (e.CommandName == "ViewHC")
            {
                // Convert the row index stored in the CommandArgument
                // property to an Integer.
                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[2];
                string asxCode = tcASXCode.Text;

                //string redirectURL = String.Format("../StockInsight.aspx?StockCode={0}", asxCode);
                //ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);

                DataOperation doGetSearchString = new DataOperation();
                string HCSearchString = doGetSearchString.GetHCSearchString(asxCode);

                string redirectURL = HCSearchString;
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);

            }

            if (e.CommandName == "ViewTop20")
            {
                // Convert the row index stored in the CommandArgument
                // property to an Integer.
                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[2];
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
                TableCell tcASXCode = selectedRow.Cells[2];
                string asxCode = tcASXCode.Text;
                DateTime dt = DateTime.Now;
                DateTime newDt = DateExtensions.AddBusinessDays(dt, -3);
                string observationDate = newDt.ToString("yyyy-MM-dd"); ;
                string observationDateFrom = newDt.ToString("yyyy-MM-dd");
                string redirectURL = String.Format("../BrokerReport.aspx?StockCode={0}&ObservationDate=2050-12-12", asxCode);
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);
            }

            if (e.CommandName == "ViewInsight")
            {

                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[2];
                string asxCode = tcASXCode.Text;

                string redirectURL = String.Format("../StockInsight.aspx?StockCode={0}", asxCode);
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);

            }

            selectItem = ddlOrderBy.SelectedValue;
            FilldsDataSet1();
        }


        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            selectItem = ddlOrderBy.SelectedValue;
            FilldsDataSet1();
            FilldsDataSet1();
        }

        //protected void gvDataSet2_PageIndexChanging(object sender, GridViewPageEventArgs e)
        //{
        //    sortBy = ddlOrderBy.SelectedValue;
        //    FilldsDataSet2();
        //    gvDataSet2.PageIndex = e.NewPageIndex;
        //    gvDataSet2.DataBind();
        //}

        //protected void gvDataSet2_RowCreated(object sender, GridViewRowEventArgs e)
        //{

        //}

        //protected void gvDataSet2_RowDataBound(object sender, GridViewRowEventArgs e)
        //{
        //    if (e.Row.RowType == DataControlRowType.DataRow)
        //    {
        //        e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
        //        e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
        //        e.Row.ToolTip = "Click to view stock chart";
        //        System.Data.DataRowView drv2 = e.Row.DataItem as System.Data.DataRowView;
        //        //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
        //        if (drv2 != null)
        //            e.Row.Attributes.Add("onclick", String.Format("window.location='http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show='", drv2["ASXCode"].ToString().Substring(0, 3)));
        //    }
        //}

        protected void ddlOrderBy_SelectedIndexChanged(object sender, EventArgs e)
        {
            selectItem = ddlOrderBy.SelectedValue;
            FilldsDataSet1();
            //FilldsDataSet2();
        }

        protected void txtNumPrevDay_TextChanged(object sender, EventArgs e)
        {
            selectItem = ddlOrderBy.SelectedValue;
            FilldsDataSet1();
        }
    }
}