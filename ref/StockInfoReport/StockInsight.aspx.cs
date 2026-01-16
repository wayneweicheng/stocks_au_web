using System;
using System.Collections.Generic;
using System.Data;
using System.Drawing;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class StockInsight : System.Web.UI.Page
    {
        DataSet dsDataSet1;
        DataSet dsDataSet2;
        DataSet dsDataSet3;
        DataSet dsDataSet4;
        DataSet dsDataSet5;
        DataSet dsDataSet6;
        string stockCode;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                txtStockCode.Text = Convert.ToString(Request.QueryString["StockCode"]);
                if (txtStockCode.Text.Length > 0)
                {
                    stockCode = txtStockCode.Text;
                    FillDataSet();
                }
            }
            
        }

        public void FilldsDataSet1(string stockCode)
        {
            GetDataSet1(stockCode);
            gvDataSet1.DataSource = dsDataSet1.Tables[0];
            gvDataSet1.DataBind();
        }

        public void FilldsDataSet2(string stockCode)
        {
            GetDataSet2(stockCode);
            gvDataSet2.DataSource = dsDataSet2.Tables[0];
            gvDataSet2.DataBind();
        }

        public void FilldsDataSet3(string stockCode)
        {
            GetDataSet3(stockCode);
            gvDataSet3.DataSource = dsDataSet3.Tables[0];
            gvDataSet3.DataBind();
        }

        public void FilldsDataSet4(string stockCode)
        {
            GetDataSet4(stockCode);
            gvDataSet4.DataSource = dsDataSet4.Tables[0];
            gvDataSet4.DataBind();
        }

        public void FilldsDataSet5(string stockCode)
        {
            GetDataSet5(stockCode);
            gvDataSet5.DataSource = dsDataSet5.Tables[0];
            gvDataSet5.DataBind();
        }

        public void FilldsDataSet6(string stockCode)
        {
            GetDataSet6(stockCode);
            gvDataSet6.DataSource = dsDataSet6.Tables[0];
            gvDataSet6.DataBind();
        }

        public void GetDataSet1(string stockCode)
        {
            DataOperation doDataSet1 = new DataOperation();
            dsDataSet1 = doDataSet1.GetMCvsCashPosition(stockCode);
        }

        public void GetDataSet2(string stockCode)
        {
            DataOperation doDataSet2 = new DataOperation();
            dsDataSet2 = doDataSet2.Top20Shareholder(stockCode);
        }

        public void GetDataSet6(string stockCode)
        {
            DataOperation doDataSet6 = new DataOperation();
            dsDataSet6 = doDataSet6.PlacementDetails(stockCode);
        }

        public void GetDataSet3(string stockCode)
        {
            DataOperation doDataSet3 = new DataOperation();
            dsDataSet3 = doDataSet3.CashflowDetails(stockCode);
        }

        public void GetDataSet4(string stockCode)
        {
            DataOperation doDataSet4 = new DataOperation();
            //dsDataSet4 = doDataSet4.Get3BDetails(stockCode);
            //dsDataSet4 = doDataSet4.GetChiXVolumeAnalysis(stockCode);
            dsDataSet4 = doDataSet4.GetInstituteParticipation(stockCode);
        }
        public void GetDataSet5(string stockCode)
        {
            DataOperation doDataSet5 = new DataOperation();
            //dsDataSet5 = doDataSet5.GetDirectorInterestDetails(stockCode);
            dsDataSet5 = doDataSet5.GetTweets(stockCode);
        }

        protected void gvDataSet1_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            FilldsDataSet1(stockCode);
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
                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);

                if (drv != null)
                    if (drv["FurtherDetails"].ToString().Length > 0)
                    {
                        string linkUrl = drv["FurtherDetails"].ToString();
                        e.Row.Attributes.Add("onclick", String.Format("window.location='{0}'", linkUrl));
                    }   
            }
        }

        protected void gvDataSe1_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            //FilldsDataSet1(stockCode);
            //FilldsDataSet1(stockCode);
        }

        protected void gvDataSet2_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            FilldsDataSet2(stockCode);
            gvDataSet2.PageIndex = e.NewPageIndex;
            gvDataSet2.DataBind();
        }

        protected void gvDataSet2_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet2_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            //if (e.Row.RowType == DataControlRowType.DataRow)
            //{
            //    int index = GetColumnIndexByName(e.Row, "ShareDiffPerc");
            //    if (index >= 0 && index < e.Row.Cells.Count)
            //    {
            //        string columnValue = e.Row.Cells[index].Text;

            //        if (columnValue.Length > 0)
            //        {
            //            if (Convert.ToDecimal(columnValue) > 0)
            //            {
            //                e.Row.Cells[index].BackColor = Color.FromName("#66ffcc");
            //            }

            //            if (Convert.ToDecimal(columnValue) < 0)
            //            {
            //                e.Row.Cells[index].BackColor = Color.FromName("#ff9999");
            //            }
            //        }
            //    }
            //}

            if (e.Row.RowType == DataControlRowType.DataRow)
            {

                //e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                //e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                //e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                if (drv != null)
                {
                    if (drv["CurrRank"].ToString().Length > 0)
                    {
                        if (Convert.ToInt16(drv["CurrRank"].ToString()) == 1)
                        {
                            e.Row.BackColor = Color.FromName("#D8FAEC");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 2)
                        {
                            e.Row.BackColor = Color.FromName("#FADBD8");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 3)
                        {
                            e.Row.BackColor = Color.FromName("#D8FAEC");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 4)
                        {
                            e.Row.BackColor = Color.FromName("#FADBD8");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 5)
                        {
                            e.Row.BackColor = Color.FromName("#D8FAEC");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 6)
                        {
                            e.Row.BackColor = Color.FromName("#FADBD8");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 7)
                        {
                            e.Row.BackColor = Color.FromName("#D8FAEC");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 8)
                        {
                            e.Row.BackColor = Color.FromName("#FADBD8");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 9)
                        {
                            e.Row.BackColor = Color.FromName("#D8FAEC");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 10)
                        {
                            e.Row.BackColor = Color.FromName("#FADBD8");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 11)
                        {
                            e.Row.BackColor = Color.FromName("#D8FAEC");
                        }
                        else if (Convert.ToInt16(drv["CurrRank"].ToString()) == 12)
                        {
                            e.Row.BackColor = Color.FromName("#FADBD8");
                        }

                        if (drv["LongTermPerformance"].ToString().Length > 0 && drv["LongTermNoStocks"].ToString().Length > 0)
                        {
                            if (Convert.ToDecimal(drv["LongTermPerformance"].ToString()) > 25 && Convert.ToInt16(drv["LongTermNoStocks"].ToString()) > 3)
                            {
                                e.Row.Style.Add(HtmlTextWriterStyle.FontWeight, "Bold");
                            }
                        }

                        if (drv["CurrRank"].ToString().Length > 0)
                        {
                            if (Convert.ToInt32(drv["CurrRank"].ToString()) == 999)
                            {
                                e.Row.BackColor = Color.FromName("#66ccff");
                                e.Row.Style.Add(HtmlTextWriterStyle.FontWeight, "Bold");
                            }
                        }
                    }
                }

                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
                //if (drv != null)
                //    e.Row.Attributes.Add("onclick", String.Format("window.location='http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show='", drv["ASXCode"].ToString().Substring(0, 3)));
            }
        }

        protected void btnStockCode_Click(object sender, EventArgs e)
        {
            Response.Redirect("StockInsight.aspx?StockCode=" + txtStockCode.Text);
        }

        public void FillDataSet()
        {
            FilldsDataSet1(stockCode);
            FilldsDataSet2(stockCode);
            FilldsDataSet3(stockCode);
            FilldsDataSet4(stockCode);
            FilldsDataSet5(stockCode);
            FilldsDataSet6(stockCode);
        }

        protected void gvDataSet3_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                //e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                //e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                //e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
                //if (drv != null)
                //    e.Row.Attributes.Add("onclick", String.Format("window.location='http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show='", drv["ASXCode"].ToString().Substring(0, 3)));
            }
        }

        protected void gvDataSet3_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet3_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            FilldsDataSet3(stockCode);
            gvDataSet3.PageIndex = e.NewPageIndex;
            gvDataSet3.DataBind();
        }

        protected void gvDataSet4_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            FilldsDataSet4(stockCode);
            gvDataSet4.PageIndex = e.NewPageIndex;
            gvDataSet4.DataBind();

        }

        protected void gvDataSet4_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                //e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                //e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                //e.Row.ToolTip = "Click to view total volume of the stock on CommSec";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
                //if (drv != null)
                //    e.Row.Attributes.Add("onclick", String.Format("window.location='https://www2.commsec.com.au/quotes/trade-history?stockCode={0}&exchangeCode=ASX'", drv["ASXCode"].ToString().Substring(0, 3)));
                if (drv != null)
                {
                    if (drv["InstituteBuy%"].ToString().Length > 0 && drv["RetailBuy%"].ToString().Length > 0)
                    {
                        if (Convert.ToDouble(drv["InstituteBuy%"].ToString()) > Convert.ToDouble(drv["RetailBuy%"].ToString()) * 0.95 && Convert.ToDouble(drv["InstituteBuy%"].ToString()) > 55)
                        {
                            e.Row.BackColor = Color.FromName("#D8FAEC");
                        }
                        if (drv["Value%"].ToString().Length > 0 && drv["AvgValue%"].ToString().Length > 0)
                        {
                            if (Convert.ToDouble(drv["Value%"].ToString()) > Convert.ToDouble(drv["AvgValue%"].ToString())*1.05)
                            {
                                e.Row.Style.Add(HtmlTextWriterStyle.FontWeight, "Bold");
                            }
                        }


                    }
                }
                
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
                e.Row.ToolTip = "Click to view tweets";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvDataSet5, "Select$" + e.Row.RowIndex);
                if (drv != null)
                    e.Row.Attributes.Add("onclick", String.Format("window.location='{0}'", drv["TweetUrl"].ToString()));
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

        protected void gvDataSet6_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                //e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                //e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                //e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
                //if (drv != null)
                //    e.Row.Attributes.Add("onclick", String.Format("window.location='http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show='", drv["ASXCode"].ToString().Substring(0, 3)));
                if (drv != null)
                {
                    if (drv["T30daysPlacementPerformance"].ToString().Length > 0)
                    {
                        if (Convert.ToDecimal(drv["T30daysPlacementPerformance"].ToString()) > 10)
                        {
                            e.Row.BackColor = Color.FromName("#66ffcc");
                        }

                        if (Convert.ToDecimal(drv["T30daysPlacementPerformance"].ToString()) < -10)
                        {
                            e.Row.BackColor = Color.FromName("#ff9999");
                        }
                    }
                }
            }
        }

        protected void gvDataSet5_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet5_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            FilldsDataSet5(stockCode);
            gvDataSet5.PageIndex = e.NewPageIndex;
            gvDataSet5.DataBind();
        }


        protected void gvDataSet6_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet6_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            stockCode = txtStockCode.Text;
            FilldsDataSet6(stockCode);
            gvDataSet6.PageIndex = e.NewPageIndex;
            gvDataSet6.DataBind();
        }

        int GetColumnIndexByName(GridViewRow row, string columnName)
        {
            int columnIndex = 0;
            foreach (DataControlFieldCell cell in row.Cells)
            {
                if (cell.ContainingField is BoundField)
                    if (((BoundField)cell.ContainingField).DataField.Equals(columnName))
                        break;
                columnIndex++; // keep adding 1 while we don't have the correct name
            }
            return columnIndex;
        }

        protected void gvDataSet4_RowCommand(object sender, GridViewCommandEventArgs e)
        {
            if (e.CommandName == "ViewBrokerData")
            {
                // Convert the row index stored in the CommandArgument
                // property to an Integer.
                int index = Convert.ToInt32(e.CommandArgument);
                GridViewRow selectedRow = gvDataSet4.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[1];
                TableCell tcObservationDate = selectedRow.Cells[2];
                string asxCode = tcASXCode.Text;
                string observationDate = tcObservationDate.Text;
                
                string redirectURL = String.Format("https://scanner.daytradescans.com/brokers?utf8=%E2%9C%93&code_autocomplete_label={0}&code=&name_autocomplete_label=&name=&from={1}&to={2}&commit=Search", asxCode.Substring(0, 3), observationDate, observationDate);
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);
                FilldsDataSet4(asxCode);
            }
        }

        protected void gvDataSet4_SelectedIndexChanged(object sender, EventArgs e)
        {

        }
    }
}