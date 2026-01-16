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
    public partial class CurrentWatchs: System.Web.UI.Page
    {
        DataSet dsDataSet4;
        string stockCode;

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                FilldsDataSet4();
            }
            
        }

        public void FilldsDataSet4()
        {
            GetDataSet4();
            gvDataSet4.DataSource = dsDataSet4.Tables[0];
            gvDataSet4.DataBind();
        }

        public void GetDataSet4()
        {
            DataOperation doDataSet4 = new DataOperation();
            //dsDataSet4 = doDataSet4.Get3BDetails(stockCode);
            //dsDataSet4 = doDataSet4.GetChiXVolumeAnalysis(stockCode);
            dsDataSet4 = doDataSet4.GetCurrentWatchs();
        }
        
        public void FillDataSet()
        {
            FilldsDataSet4();
        }

        protected void gvDataSet4_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            FilldsDataSet4();
            gvDataSet4.PageIndex = e.NewPageIndex;
            gvDataSet4.DataBind();

        }

        protected void gvDataSet4_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                if (drv != null)
                {
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
                }

            }
        }

        protected void gvDataSet4_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvDataSet4_SelectedIndexChanged(object sender, EventArgs e)
        {

        }
    }
}