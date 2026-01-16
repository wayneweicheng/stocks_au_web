using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class TradeRequest : System.Web.UI.Page
    {
        DataSet dsDataSet1;
        DataSet dsDataSet2;
        int topN;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                txtTopNRecords.Text = "100";
                topN = Convert.ToInt32(txtTopNRecords.Text);
                FilldsDataSet1(topN);
            }
            //else
            //{
            //    lblLargeSale.Visible = true;
            //    lblLargeSalebyDate.Visible = true;
            //    lblLargeSalebyVolume.Visible = true;
            //}

        }

        public void FilldsDataSet1(int topN)
        {
            GetDataSet1(topN);
            gvDataSet1.DataSource = dsDataSet1.Tables[0];
            gvDataSet1.DataBind();
        }

        public void FilldsDataSet2(string stockCode)
        {
            GetDataSet2(stockCode);
            gvDataSet2.DataSource = dsDataSet2.Tables[0];
            gvDataSet2.DataBind();
        }

        public void GetDataSet1(int topN)
        {
            DataOperation doDataSet1 = new DataOperation();
            dsDataSet1 = doDataSet1.GetTopNTradeRequest(topN);
        }

        public void GetDataSet2(string stockCode)
        {
            DataOperation doDataSet2 = new DataOperation();
            //dsDataSet2 = doDataSet2.DirectorandMajorShareholder(stockCode);
        }

        protected void gvDataSet1_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            topN = Convert.ToInt32(txtTopNRecords.Text);
            FilldsDataSet1(topN);
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
                    e.Row.Attributes.Add("onclick", String.Format("window.location='http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show='", drv["ASXCode"].ToString().Substring(0, 3)));
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
            //stockCode = txtTopNRecords.Text;
            //FilldsDataSet2(stockCode);
            //gvDataSet2.PageIndex = e.NewPageIndex;
            //gvDataSet2.DataBind();
        }

        protected void gvDataSet2_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet2_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                e.Row.ToolTip = "Click to view stock chart";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
                if (drv != null)
                    e.Row.Attributes.Add("onclick", String.Format("window.location='http://bigcharts.marketwatch.com/quickchart/quickchart.asp?symb=AU%3A{0}&insttype=&freq=&show='", drv["ASXCode"].ToString().Substring(0, 3)));
            }
        }

        protected void btnTopNRecords_Click(object sender, EventArgs e)
        {
            topN = Convert.ToInt32(txtTopNRecords.Text);
            FilldsDataSet1(topN);
            //FilldsDataSet2(stockCode);
        }
    }
}