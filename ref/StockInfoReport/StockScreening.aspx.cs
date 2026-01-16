using GetYahoo;
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
    public partial class StockScreening : System.Web.UI.Page
    {
        DataSet dsDataSet1;
        DataSet dsDataSet2;
        string sortBy;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                sortBy = ddlOrderBy.SelectedValue;
                FilldsDataSet1();
                //FilldsDataSet2();
            }
            //else
            //{
            //    lblLargeSale.Visible = true;
            //    lblLargeSalebyDate.Visible = true;
            //    lblLargeSalebyVolume.Visible = true;
            //}

        }

        public void FilldsDataSet1()
        {
            GetDataSet1();
            gvDataSet1.DataSource = dsDataSet1.Tables[0];
            gvDataSet1.DataBind();
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
            dsDataSet1 = doDataSet1.GetStockScreening(sortBy);
        }

        //public void GetDataSet2()
        //{
        //    DataOperation doDataSet2 = new DataOperation();
        //    dsDataSet2 = doDataSet2.GetCommonStockPlus(sortBy);
        //}

        protected void gvDataSet1_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            sortBy = ddlOrderBy.SelectedValue;
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
                    if (drv["MC"].ToString().Length > 0)
                    {
                        if (Convert.ToDecimal(drv["MC"].ToString()) < 10)
                        {
                            e.Row.BackColor = Color.FromName("#A3E4D7");
                        }
                        else if (Convert.ToDecimal(drv["MC"].ToString()) < 20)
                        {
                            e.Row.BackColor = Color.FromName("#AED6F1");
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
            sortBy = ddlOrderBy.SelectedValue;
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
            sortBy = ddlOrderBy.SelectedValue;
            FilldsDataSet1();
            //FilldsDataSet2();
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
                TableCell tcASXCode = selectedRow.Cells[0];
                string asxCode = tcASXCode.Text;
                string stdObservationDate = "2050-12-12";
                string redirectURL = String.Format("../CourseOfSale.aspx?StockCode={0}&ObservationDate={1}", asxCode, stdObservationDate);
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);
            }

            if (e.CommandName == "ViewHC")
            {
                // Convert the row index stored in the CommandArgument
                // property to an Integer.
                int index = Convert.ToInt32(e.CommandArgument);

                GridViewRow selectedRow = gvDataSet1.Rows[index];
                TableCell tcASXCode = selectedRow.Cells[0];
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
                TableCell tcASXCode = selectedRow.Cells[0];
                string asxCode = tcASXCode.Text;

                string redirectURL = String.Format("../StockInsight.aspx?StockCode={0}", asxCode);
                ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);

            }

            sortBy = ddlOrderBy.SelectedValue;
            FilldsDataSet1();
        }

        public void MsgBox(String ex, Page pg, Object obj)
        {
            string s = "<SCRIPT language='javascript'>alert('" + ex.Replace("\r\n", "\\n").Replace("'", "") + "'); </SCRIPT>";
            Type cstype = obj.GetType();
            ClientScriptManager cs = pg.ClientScript;
            cs.RegisterClientScriptBlock(cstype, s, s.ToString());
        }
    }
}