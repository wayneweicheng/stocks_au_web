using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class LargeSale : System.Web.UI.Page
    {
        DataSet dsLargeSale;
        DataSet dsLineWipe;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                txtNumPrevDay.Text = "0";
                FillLargeSale();
                FillLineWipe();
            }
            //else
            //{
            //    lblLargeSale.Visible = true;
            //    lblLargeSalebyDate.Visible = true;
            //    lblLargeSalebyVolume.Visible = true;
            //}

        }

        public void FillLargeSale()
        {
            GetLargeSale();
            gvLargeSale.DataSource = dsLargeSale.Tables[0];
            gvLargeSale.DataBind();
        }

        public void FillLineWipe()
        {
            GetLineWipe();
            gvLineWipe.DataSource = dsLineWipe.Tables[0];
            gvLineWipe.DataBind();
        }
        
        public void GetLargeSale()
        {
            int numPrevDay = Convert.ToInt32(txtNumPrevDay.Text);
            DataOperation doLargeSale = new DataOperation();
            dsLargeSale = doLargeSale.GetLargeSale(numPrevDay);
        }

        public void GetLineWipe()
        {
            int numPrevDay = Convert.ToInt32(txtNumPrevDay.Text);
            DataOperation doLineWipe = new DataOperation();
            dsLineWipe = doLineWipe.GetLineWipe(numPrevDay);
        }

        protected void gvCOSLatest_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            FillLargeSale();
            gvLargeSale.PageIndex = e.NewPageIndex;
            gvLargeSale.DataBind();
        }

        protected void gvCOSLatest_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            //if (e.Row.RowType == DataControlRowType.DataRow)
            //{
            //    e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
            //    e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
            //    e.Row.ToolTip = "Click to view related market depth changes";
            //    System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
            //    //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
            //    e.Row.Attributes.Add("onclick", String.Format("window.location='MarketDepth.aspx?LargeSaleID={0}'", drv["LargeSaleID"]));
            //}
        }

        protected void gvCOSLatest_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void btnSubmit_Click(object sender, EventArgs e)
        {
            FillLargeSale();
            FillLineWipe();
        }

        protected void gvLineWipe_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            FillLineWipe();
            gvLineWipe.PageIndex = e.NewPageIndex;
            gvLineWipe.DataBind();
        }

        protected void gvLineWipe_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvLineWipe_RowDataBound(object sender, GridViewRowEventArgs e)
        {

        }

    }
}