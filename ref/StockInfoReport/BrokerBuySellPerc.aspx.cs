using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class BrokerBuySellPerc: System.Web.UI.Page
    {
        DataSet dsDataSet1;
        DataSet dsDataSet2;
        DataSet dsBrokerCode;
        string sortBy;
        string brokerCode;
        protected void Page_Load(object sender, EventArgs e)
        {

            if (!Page.IsPostBack)
            {
                txtNumPrevDay.Text = "0";
                sortBy = ddlOrderBy.SelectedValue;

                GetBrokerList();
                ddlBrokerCode.DataSource = dsBrokerCode.Tables[0];
                ddlBrokerCode.DataTextField = "BrokerName";
                ddlBrokerCode.DataValueField = "BrokerCode";
                ddlBrokerCode.DataBind();
                ddlBrokerCode.SelectedIndex = 2;
                txtObservationEndDate.Text = "2050-12-12";
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

        public void GetBrokerList()
        {
            DataOperation doBrokerCode = new DataOperation();
            dsBrokerCode = doBrokerCode.GetBrokerCode();
        }

        public void FilldsDataSet1()
        {
            brokerCode = ddlBrokerCode.SelectedIndex == -1 ? "N/A" : ddlBrokerCode.SelectedValue;
            sortBy = ddlOrderBy.SelectedValue;
            GetDataSet1();
            hlBatchChart.NavigateUrl = BuildBatchChartLink(dsDataSet1.Tables[0]);
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
            dsDataSet1 = doDataSet1.GetBrokerBuySellPerc(sortBy, Convert.ToInt16(txtNumPrevDay.Text), brokerCode, txtObservationEndDate.Text);
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
                e.Row.ToolTip = "Click to view details";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);

                if (drv != null)
                {
                    string strDateEnd = drv["DateEnd"].ToString();
                    DateTime dtDateEnd = Convert.ToDateTime(strDateEnd);
                    string observationDate = dtDateEnd.ToString("yyyy-MM-dd");
                    string asxCode = drv["ASXCode"].ToString();
                    string redirectURL = String.Format("../BrokerReport.aspx?StockCode={0}&ObservationDate={1}", asxCode, observationDate);
                    //ScriptManager.RegisterStartupScript(Page, Page.GetType(), "popup", "window.open('" + redirectURL + "','_blank')", true);
                    e.Row.Attributes.Add("onclick", "window.location='" + redirectURL + "'");

                }

            }
        }

        protected void gvDataSe1_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            sortBy = ddlOrderBy.SelectedValue;
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

        protected void ddlBrokerCode_SelectedIndexChanged(object sender, EventArgs e)
        {
            brokerCode = ddlBrokerCode.SelectedValue;
            FilldsDataSet1();
        }

        protected void txtObservationEndDate_TextChanged(object sender, EventArgs e)
        {
            brokerCode = ddlBrokerCode.SelectedValue;
            FilldsDataSet1();
        }

        public string BuildBatchChartLink(DataTable dtTable)
        {
            string stockCodeList = "";
            int count = 0;
            foreach (DataRow dr in dsDataSet1.Tables[0].Rows)
            {
                string stockCode = dr["ASXCode"].ToString();
                bool display = true;
                count++;
                if (dr.Table.Columns.Contains("AlertTypeScore"))
                {
                    int alertyTypeScore = Convert.ToInt32(dr["AlertTypeScore"]);
                    if (alertyTypeScore < 20)
                        display = false;
                }
                if (display && !stockCodeList.Contains(stockCode) && count <= 50)
                    stockCodeList += stockCode + "|";
            }
            if (stockCodeList.Length > 0)
                stockCodeList = stockCodeList.Substring(0, stockCodeList.Length - 1);
            string batchChartLink = "../BatchDailyCharts.aspx?StockCodeList=" + stockCodeList;

            return batchChartLink;
        }
    }
}