using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using System.Collections;
using DotNet.Highcharts.Enums;
using DotNet.Highcharts.Options;
using System.Drawing;
using DotNet.Highcharts.Helpers;

namespace StockInfoReport
{
    public partial class Default : System.Web.UI.Page
    {
        DataSet dsSectorList;
        DataSet dsSectorPerformance;
        DataSet dsDataSet4;

        //DataSet dsSectorPerformance;
        ArrayList alObDate = new ArrayList();
        ArrayList alSMA0 = new ArrayList();
        ArrayList alSMA3 = new ArrayList();
        ArrayList alSMA5 = new ArrayList();
        ArrayList alSMA10 = new ArrayList();
        ArrayList alSMA20 = new ArrayList();
        ArrayList alSMA30 = new ArrayList();
        ArrayList alTradeValue = new ArrayList();
        
        object[] objArrSMA0;
        object[] objArrSMA3;
        object[] objArrSMA5;
        object[] objArrSMA10;
        object[] objArrSMA20;
        object[] objArrSMA30;
        object[] objArrTradeValue;
        protected void Page_Load(object sender, EventArgs e)
        {
            if (!Page.IsPostBack)
            {
                //GetStockListInfo();
                //ddlStockList.DataSource = dsStockListInfo.Tables[0];
                //ddlStockList.DataTextField = "CompanyName";
                //ddlStockList.DataValueField = "ASXCode";
                //ddlStockList.DataBind();
                //ddlStockList.SelectedIndex = -1;
                //lblCourseOfSale.Visible = false;
                GetSectorList();
                ddlSectorList.DataSource = dsSectorList.Tables[0];
                ddlSectorList.DataTextField = "Token";
                ddlSectorList.DataValueField = "Token";
                ddlSectorList.DataBind();
                ddlSectorList.SelectedIndex = -1;

                //GetSectorPerformance("LITHIUM");
                BindChart();
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
            dsDataSet4 = doDataSet4.GetHeartBeat();
        }

        public void GetSectorPerformance(string token)
        {
            DataOperation doSectorPerformance = new DataOperation();
            DataSet dsSectorPerformance = doSectorPerformance.GetSectorPerformance(token);
            DataTable dtSectorPerformance = dsSectorPerformance.Tables[0];

            foreach (DataRow dr in dtSectorPerformance.Rows)
            {
                alObDate.Add(Convert.ToString(dr["ObservationDate"]));

                alSMA0.Add(Convert.ToDecimal(dr["SMA0"]));
                objArrSMA0 = alSMA0.ToArray(typeof(object)) as object[];

                alSMA3.Add(Convert.ToDecimal(dr["SMA3"]));
                objArrSMA3 = alSMA3.ToArray(typeof(object)) as object[];

                alSMA5.Add(Convert.ToDecimal(dr["SMA5"]));
                objArrSMA5 = alSMA5.ToArray(typeof(object)) as object[];

                alSMA10.Add(Convert.ToDecimal(dr["SMA10"]));
                objArrSMA10 = alSMA10.ToArray(typeof(object)) as object[];

                alSMA20.Add(Convert.ToDecimal(dr["SMA20"]));
                objArrSMA20 = alSMA20.ToArray(typeof(object)) as object[];

                alSMA30.Add(Convert.ToDecimal(dr["SMA30"]));
                objArrSMA30 = alSMA30.ToArray(typeof(object)) as object[];

                alTradeValue.Add(Convert.ToDecimal(dr["TradeValue"]));
                objArrTradeValue = alTradeValue.ToArray(typeof(object)) as object[];

            }

        }
        public void BindChart()
        {
            DotNet.Highcharts.Highcharts chartSectorPerformance = new DotNet.Highcharts.Highcharts("chart")
            .SetTitle(new Title { Text = "Sector Performance Trend" })
            .InitChart(new Chart { ZoomType = ZoomTypes.Xy, Height = 600 })
            .SetXAxis(new XAxis
            {
                Categories = alObDate.ToArray(typeof(string)) as string[],
            })
            .SetYAxis(new[]
                {
                    new YAxis
                    {
                        GridLineWidth = 0,
                        Labels = new YAxisLabels
                        {
                            Formatter = "function() { return '$' + this.value; }",
                            Style = "color: '#89A54E'"
                        },
                        Title = new YAxisTitle
                        {
                            Text = "Money Flow Amount (000 AUD)",
                            Style = "color: '#89A54E'"
                        },

                    }
                    ,
                    new YAxis
                    {
                        GridLineWidth = 0,
                        Labels = new YAxisLabels
                        {
                            Formatter = "function() { return '$' + this.value; }",
                            Style = "color: '#4572A7'"
                        },
                        Title = new YAxisTitle
                        {
                            Text = "Hold Value",
                            Style = "color: '#4572A7'"
                        },
                        Opposite = true,
                        Min = 30000
                    }
                })
                .SetTooltip(new Tooltip
                {
                    Formatter = "function() { return ''+ this.x +': '+ this.y + (this.series.name == 'Sector Performance' ? '' : ''); }"
                })
            //.SetLegend(new Legend
            //{
            //    Layout = Layouts.Vertical,
            //    Align = HorizontalAligns.Left,
            //    X = 120,
            //    VerticalAlign = VerticalAligns.Top,
            //    Y = 100,
            //    Floating = true,
            //    BackgroundColor = new BackColorOrGradient(ColorTranslator.FromHtml("#FFFFFF"))
            //})
            .SetSeries(new[]
            {
                new Series
                {
                    Name = "SMA0",
                    //Color = ColorTranslator.FromHtml("#4572A7"),
                    Type = ChartTypes.Spline,
                    YAxis = "1",
                    Data = new Data(objArrSMA0)
                },
                new Series
                {
                    Name = "SMA5",
                    //Color = ColorTranslator.FromHtml("#4572A7"),
                    Type = ChartTypes.Spline,
                    YAxis = "1",
                    Data = new Data(objArrSMA5)
                },
                new Series
                {
                    Name = "SMA10",
                    //Color = ColorTranslator.FromHtml("#4572A7"),
                    Type = ChartTypes.Spline,
                    YAxis = "1",
                    Data = new Data(objArrSMA10)
                },
                new Series
                {
                    Name = "SMA30",
                    //Color = ColorTranslator.FromHtml("#4572A7"),
                    Type = ChartTypes.Spline,
                    YAxis = "1",
                    Data = new Data(objArrSMA30)
                },
                new Series
                {
                    Name = "Trade Value",
                    //Color = ColorTranslator.FromHtml("#89A54E"),
                    Type = ChartTypes.Column,
                    Data = new Data(objArrTradeValue)
                }
            }

            );

            ltrSectorPerformance.Text = chartSectorPerformance.ToHtmlString();
            
        }
        public void GetSectorList()
        {
            DataOperation doSectorList = new DataOperation();
            dsSectorList = doSectorList.GetSectorList();
        }
        protected void ddlSectorList_SelectedIndexChanged(object sender, EventArgs e)
        {
            string token = ddlSectorList.SelectedValue;
            GetSectorPerformance(token);
            BindChart();
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
                    if (drv["HeartBeatStatus"].ToString().Length > 0)
                    {
                        if (Convert.ToBoolean(drv["HeartBeatStatus"].ToString()))
                        {
                            e.Row.BackColor = Color.FromName("#ABEBC6");
                        }
                        else
                        {
                            e.Row.BackColor = Color.FromName("#FDEDEC");
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