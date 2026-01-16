using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace StockInfoReport
{
    public partial class IntegratedCharts : System.Web.UI.Page
    {
        protected void Page_Load(object sender, EventArgs e)
        {
            string stockCode = "";
            if (Request.QueryString["StockCode"] != null)
            {
                stockCode = Convert.ToString(Request.QueryString["StockCode"]);
                if (stockCode.IndexOf('.') > -1)
                    stockCode = "AU%3a" + stockCode.Substring(0, stockCode.IndexOf('.'));
                //else
                //    stockCode = stockCode;
            }
                

            Load_BigChartImages(stockCode);
        }

        public void Load_BigChartImages(string stockCode)
        {
            imgDaily6MonthSMA204060.ImageUrl = "https://api.wsj.net/api/kaavio/charts/big.chart?nosettings=1&symb=" + stockCode + "&uf=32&type=4&size=4&style=320&freq=1&entitlementtoken=0c33378313484ba9b46b8e24ded87dd6&time=7&rand=1673808026&compidx=aaaaa%3a0&ma=3&maval=5&lf=268435456&lf2=4&lf3=32&height=981&width=1045&mocktick=1";
            Thread.Sleep(1000);
            imgDaily1YearSMA51015.ImageUrl = "https://api.wsj.net/api/kaavio/charts/big.chart?nosettings=1&symb=" + stockCode + "&uf=32&type=4&size=4&style=320&freq=1&entitlementtoken=0c33378313484ba9b46b8e24ded87dd6&time=8&rand=1673808026&compidx=aaaaa%3a0&ma=4&maval=20&lf=268435456&lf2=4&lf3=32&height=981&width=1045&mocktick=1";
            Thread.Sleep(1000);
            imgWeekly1YearSMA51015.ImageUrl = "https://api.wsj.net/api/kaavio/charts/big.chart?nosettings=1&symb=" + stockCode + "&uf=32&type=4&size=4&style=320&freq=2&entitlementtoken=0c33378313484ba9b46b8e24ded87dd6&time=8&rand=1673808026&compidx=aaaaa%3a0&ma=3&maval=5&lf=268435456&lf2=4&lf3=32&height=981&width=1045&mocktick=1";
            Thread.Sleep(1000);
            imgWeekly3YearSMA51015.ImageUrl = "https://api.wsj.net/api/kaavio/charts/big.chart?nosettings=1&symb=" + stockCode + "&uf=32&type=4&size=4&style=320&freq=2&entitlementtoken=0c33378313484ba9b46b8e24ded87dd6&time=10&rand=1673808026&compidx=aaaaa%3a0&ma=3&maval=5&lf=268435456&lf2=4&lf3=32&height=981&width=1045&mocktick=1";
            Thread.Sleep(1000);
            imgMonthly5YearSMA51015.ImageUrl = "https://api.wsj.net/api/kaavio/charts/big.chart?nosettings=1&symb=" + stockCode + "&uf=32&type=4&size=4&style=320&freq=3&entitlementtoken=0c33378313484ba9b46b8e24ded87dd6&time=12&rand=1673808026&compidx=aaaaa%3a0&ma=3&maval=5&lf=268435456&lf2=4&lf3=32&height=981&width=1045&mocktick=1";
            Thread.Sleep(1000);
            imgHourly10day51015.ImageUrl = "https://api.wsj.net/api/kaavio/charts/big.chart?nosettings=1&symb=" + stockCode + "&uf=32&type=4&size=4&style=320&freq=8&entitlementtoken=0c33378313484ba9b46b8e24ded87dd6&time=18&rand=1673808026&compidx=aaaaa%3a0&ma=3&maval=5&lf=268435456&lf2=4&lf3=32&height=981&width=1045&mocktick=1";

        }
    }
}