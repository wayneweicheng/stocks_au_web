using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class MarketDepth : System.Web.UI.Page
    {
        DataSet dsMarketDepth;
        int courseOfSaleID;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                courseOfSaleID = Convert.ToInt32(Request.QueryString["CourseOfSaleID"]);
                if (courseOfSaleID > 0)
                {
                    FillMarketDepth(courseOfSaleID);
                }
                
            }
            //Response.Write(Request.QueryString["CourseOfSaleID"]);
        }

        public void FillMarketDepth(int courseOfSaleID)
        {
            DataOperation doMarketDepth = new DataOperation();
            dsMarketDepth = doMarketDepth.GetMarketDepth(courseOfSaleID);
            gvMinus60s.DataSource = dsMarketDepth.Tables[0];
            gvMinus30s.DataSource = dsMarketDepth.Tables[1];
            gvMinus0s.DataSource = dsMarketDepth.Tables[2];
            gvPlus30s.DataSource = dsMarketDepth.Tables[3];
            gvPlus60s.DataSource = dsMarketDepth.Tables[4];
            gvMinus60s.DataBind();
            gvMinus30s.DataBind();
            gvMinus0s.DataBind();
            gvPlus30s.DataBind();
            gvPlus60s.DataBind();

        }

        protected void gvMinus30s0_SelectedIndexChanged(object sender, EventArgs e)
        {

        }
    }
}