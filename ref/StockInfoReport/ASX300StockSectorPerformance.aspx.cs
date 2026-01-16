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
    public partial class ASX300StockSectorPerformance : System.Web.UI.Page
    {
        DataSet dsDataSet1;
        DataSet dsDataSet2;
        string sortBy;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                txtNumPrevDay.Text = "0";
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
            dsDataSet1 = doDataSet1.GetASX300StockSectorPerformance(sortBy, Convert.ToInt16(txtNumPrevDay.Text));
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
                    if (drv["Last"].ToString().Length > 0 && drv["VWAP"].ToString().Length > 0)
                    {
                        if (Convert.ToDecimal(drv["Last"].ToString()) > Convert.ToDecimal(drv["VWAP"].ToString()) && Convert.ToDecimal(drv["VWAP"].ToString()) > 0)
                        {
                            e.Row.Font.Bold = true;
                            //e.Row.Font.Italic = true;
                            e.Row.BorderStyle = BorderStyle.Dotted;
                        }   
                    }

                    if (drv["ChangePerc"].ToString().Length > 0)
                    {
                        if (Convert.ToDecimal(drv["ChangePerc"].ToString()) > 50)
                        {
                            e.Row.BackColor = Color.FromName("#28B463");
                        }
                        else if (Convert.ToDecimal(drv["ChangePerc"].ToString()) > 25)
                        {
                            e.Row.BackColor = Color.FromName("#58D68D");
                        }
                        else if (Convert.ToDecimal(drv["ChangePerc"].ToString()) > 15)
                        {
                            e.Row.BackColor = Color.FromName("#82E0AA");
                        }
                        else if (Convert.ToDecimal(drv["ChangePerc"].ToString()) > 5)
                        {
                            e.Row.BackColor = Color.FromName("#ABEBC6");
                        }
                        else if (Convert.ToDecimal(drv["ChangePerc"].ToString()) > 0)
                        {
                            e.Row.BackColor = Color.FromName("#EAFAF1");
                        }
                        else if (Convert.ToDecimal(drv["ChangePerc"].ToString()) == 0)
                        {
                            e.Row.BackColor = Color.FromName("#FFFFFF");
                        }
                        else if (Convert.ToDecimal(drv["ChangePerc"].ToString()) > -5)
                        {
                            e.Row.BackColor = Color.FromName("#FDEDEC");
                        }
                        else if (Convert.ToDecimal(drv["ChangePerc"].ToString()) > -15)
                        {
                            e.Row.BackColor = Color.FromName("#F5B7B1");
                        }
                        else if (Convert.ToDecimal(drv["ChangePerc"].ToString()) > -25)
                        {
                            e.Row.BackColor = Color.FromName("#F1948A");
                        }
                        else if (Convert.ToDecimal(drv["ChangePerc"].ToString()) > -50)
                        {
                            e.Row.BackColor = Color.FromName("#EC7063");
                        }
                        else if (Convert.ToDecimal(drv["ChangePerc"].ToString()) <= -50)
                        {
                            e.Row.BackColor = Color.FromName("#E74C3C");
                        }
                    }

                    if (drv["Sector"].ToString().Length > 0)
                    {
                        if(drv["Sector"].ToString() == "N/A")
                        {
                            e.Row.BackColor = Color.FromName("#616A6B");
                        }
                    }

                    //if (drv["SearchTerm"].ToString().Length > 0)
                    //{
                        
                    //    e.Row.BackColor = Color.FromName("#FADBD8");                        
                    //}

                    //string[] annKeyWords = new string[] { "ACQUISITION", "OFF TAKE", "OFF-TAKE", "OFF TAKE"};

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

        protected void txtNumPrevDay_TextChanged(object sender, EventArgs e)
        {
            sortBy = ddlOrderBy.SelectedValue;
            FilldsDataSet1();
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

            //if (e.CommandName == "ViewInsight")
            //{
            //    // Convert the row index stored in the CommandArgument
            //    // property to an Integer.
            //    int index = Convert.ToInt32(e.CommandArgument);

            //    GridViewRow selectedRow = gvDataSet1.Rows[index];
            //    TableCell tcASXCode = selectedRow.Cells[4];
            //    string asxCode = tcASXCode.Text;

            //    string redirectURL = String.Format("../StockInsight.aspx?StockCode={0}", asxCode);
            //    ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);

            //    //Response.Redirect(redirectURL,false);
            //    //MsgBox(asxCode, this.Page, this);
            //}

            //if (e.CommandName == "AddAlert")
            //{
            //    // Convert the row index stored in the CommandArgument
            //    // property to an Integer.
            //    int index = Convert.ToInt32(e.CommandArgument);

            //    GridViewRow selectedRow = gvDataSet1.Rows[index];
            //    TableCell tcASXCode = selectedRow.Cells[4];
            //    string asxCode = tcASXCode.Text;

            //    DataOperation doAddMonitorStockFromReport = new DataOperation();
            //    string message = doAddMonitorStockFromReport.AddMonitorStockFromReport(asxCode, 10, 1);
            //    MsgBox(message, this.Page, this);
            //}

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