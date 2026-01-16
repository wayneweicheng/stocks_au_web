using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class BatchDailyCharts : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            Page.Server.ScriptTimeout = 600;
            string stockCodeList = "";
            if (Request.QueryString["StockCodeList"] != null)
            {
                stockCodeList = Convert.ToString(Request.QueryString["StockCodeList"]);

                string[] tokens = stockCodeList.Split('|');
                List<string> lisStockCode = new List<string>(tokens);

                foreach (string item in lisStockCode)
                {
                    string searchItem = "";
                    if (item.IndexOf('.') > -1)
                        searchItem = "AU%3a" + item.Substring(0, item.IndexOf('.'));
                    else
                        searchItem = item;
                    Load_BigChartImages(searchItem, item);
                    Thread.Sleep(1000);
                }

            }

        }

        public void Load_BigChartImages(string stockCode, string displayStockCode)
        {
            Label lblSeparator = new Label();
            lblSeparator.Text = "<br />" + "<br />" + "---------- " + displayStockCode + " ----------" + "<br />" + "<br />";
            lblSeparator.Font.Size = 10;
            lblSeparator.Font.Bold = true;
            panel.Controls.Add(lblSeparator);

            Image image1 = new Image();
            image1.ImageUrl = "https://api.wsj.net/api/kaavio/charts/big.chart?nosettings=1&symb=" + stockCode + "&uf=32&type=4&size=4&style=320&freq=1&entitlementtoken=0c33378313484ba9b46b8e24ded87dd6&time=7&rand=1673808026&compidx=aaaaa%3a0&ma=3&maval=10&lf=268435456&lf2=4&lf3=32&height=981&width=1045&mocktick=1";
            panel.Controls.Add(image1);

            Thread.Sleep(1000);

            Image image2 = new Image();
            image2.ImageUrl = "https://api.wsj.net/api/kaavio/charts/big.chart?nosettings=1&symb=" + stockCode + "&uf=32&type=4&size=4&style=320&freq=2&entitlementtoken=0c33378313484ba9b46b8e24ded87dd6&time=9&rand=1673808026&compidx=aaaaa%3a0&ma=3&maval=5&lf=268435456&lf2=4&lf3=32&height=981&width=1045&mocktick=1";
            panel.Controls.Add(image2);

        }
    }
}