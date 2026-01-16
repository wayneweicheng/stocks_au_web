using DotNet.Highcharts.Enums;
using DotNet.Highcharts.Helpers;
using DotNet.Highcharts.Options;
using System;
using System.Collections;
using System.Collections.Specialized;
using System.Data;
using System.Drawing;
using System.Web;
using System.Web.UI;
using System.Web.UI.WebControls;
using GetYahoo;

namespace StockInfoReport
{
    public partial class CourseOfSale : System.Web.UI.Page
    {
        DataSet dsCourseOfSale;
        DataSet dsStockListInfo;
        DataSet dsMoneyFlow;
        DataSet dsCustomFilter;
        DataSet dsBrokerCode;
        Decimal priceMin = 999;
        Decimal priceMax = 0;
        Decimal priceIntraDayMin = 999;
        Decimal priceIntraDayMin1M = 999;
        Decimal moneyFlowAmountMin = 99999999;
        Decimal moneyFlowAmountMax = 0;
        string brokerCode;

        ArrayList valueMoneyFlowAmount = new ArrayList();
        ArrayList valueMoneyFlowAmountIn = new ArrayList();
        ArrayList valueClose = new ArrayList();
        ArrayList valueDayVWAP = new ArrayList();
        ArrayList valueMoneyFlowAmountOut = new ArrayList();
        ArrayList valueVolume = new ArrayList();
        ArrayList hidXCategories11 = new ArrayList();
        ArrayList alMoneyAuctionValue = new ArrayList();
        ArrayList alMoneyInIntraDay = new ArrayList();
        ArrayList alMoneyOutIntraDay = new ArrayList();
        ArrayList alVWAPIn = new ArrayList();
        ArrayList alVWAPOut = new ArrayList();
        ArrayList alVWAP = new ArrayList();
        ArrayList alClosePrice = new ArrayList();
        ArrayList alPreviousClose = new ArrayList();
        ArrayList alNetVolume = new ArrayList();
        ArrayList alXAxis = new ArrayList();

        ArrayList alXAxisIntraDay = new ArrayList();
        ArrayList alVolumeIntraDay = new ArrayList();
        ArrayList alClosePriceIntraDay = new ArrayList();
        ArrayList alPreviousCloseIntraDay = new ArrayList();
        ArrayList alTodayOpenIntraDay = new ArrayList();
        ArrayList alVWAPIntraDay = new ArrayList();

        ArrayList alStrongBrokerNet = new ArrayList();
        ArrayList alWeakBrokerNet = new ArrayList();
        ArrayList alRetailNet = new ArrayList();
        ArrayList alFlipperBrokerNet = new ArrayList();
        ArrayList alComSec = new ArrayList();

        object[] yValuesMoneyFlowAmount;
        object[] yValuesMoneyFlowAmountIn;
        object[] yValuesClose;
        object[] yValuesDayVWAP;
        object[] yValuesMoneyFlowAmountOut;
        object[] yValuesVolume;
        //object[] yValuesMoneyAuctionValue;
        object[] yValuesMoneyInIntraDay;
        object[] yValuesMoneyOutIntraDay;
        object[] yValuesVWAPIn;
        object[] yValuesVWAPOut;
        object[] yValuesVWAP;
        object[] yValuesClosePrice;
        object[] yValuesPreviousClose;
        object[] yValuesNetVolume;

        object[] yValuesVolumeIntraDay;
        object[] yValuesClosePriceIntraDay;
        object[] yValuesPreviousCloseIntraDay;
        object[] yValuesTodayOpenIntraDay;
        object[] yValueVWAPIntraDay;

        object[] yValuesStrongBrokerNet;
        object[] yValuesWeakBrokerNet;
        object[] yValuesRetailNet;
        object[] yValuesFlipperBrokerNet;
        object[] yValuesComSec;
        string stockCode = "";
        string numPrevDay = "";
        string observationDate = "";
        int customFilterID = 0;
        int brokerCodeIndex = 0;

        protected void Page_Load(object sender, EventArgs e)
        {
            
            if (!Page.IsPostBack)
            {
                if (Request.QueryString["StockCode"] != null)
                    stockCode = Convert.ToString(Request.QueryString["StockCode"]);
                if (Request.QueryString["NumPrevDay"] != null)
                    numPrevDay = Convert.ToString(Request.QueryString["NumPrevDay"]);
                if (Request.QueryString["ObservationDate"] != null)
                    observationDate = Convert.ToString(Request.QueryString["ObservationDate"]);
                if (Request.QueryString["CustomFilterID"] != null)
                    customFilterID = Convert.ToInt32(Request.QueryString["CustomFilterID"]);
                if (Request.QueryString["BrokerCodeIndex"] != null)
                    brokerCodeIndex = Convert.ToInt32(Request.QueryString["BrokerCodeIndex"]);

                txtNumPrevDay.Text = numPrevDay;
                txtObservationDate.Text = observationDate;

                GetCustomFilter();
                ddlCustomFilter.DataSource = dsCustomFilter.Tables[0];
                ddlCustomFilter.DataTextField = "CustomFilter";
                ddlCustomFilter.DataValueField = "CustomFilterID";
                ddlCustomFilter.DataBind();
                ddlCustomFilter.SelectedValue = customFilterID.ToString();

                GetStockListInfo(customFilterID);
                ddlStockList.DataSource = dsStockListInfo.Tables[0];
                ddlStockList.DataTextField = "CompanyName";
                ddlStockList.DataValueField = "ASXCode";
                ddlStockList.DataBind();
                ddlStockList.SelectedIndex = 0;

                GetBrokerList();
                ddlBrokerCode.DataSource = dsBrokerCode.Tables[0];
                ddlBrokerCode.DataTextField = "BrokerName";
                ddlBrokerCode.DataValueField = "BrokerCode";
                ddlBrokerCode.DataBind();
                ddlBrokerCode.SelectedIndex = brokerCodeIndex;

                if (stockCode.Length > 0 && (txtObservationDate.Text.Length > 0 || txtNumPrevDay.Text.Length > 0))
                {
                    observationDate = txtObservationDate.Text;
                    int i = 0;
                    foreach (ListItem item in ddlStockList.Items)
                    {
                        if (item.Value == stockCode)
                            ddlStockList.SelectedIndex = i;
                        i++;
                    }

                    //if (dsStockListInfo.Tables[0].Rows.Count > 0 && ddlStockList.SelectedIndex == -1)
                    //    ddlStockList.SelectedIndex = 0;
                    //else
                    //    ddlStockList.SelectedIndex = -1;

                    if (ddlStockList.SelectedIndex >= 0 && ddlStockList.SelectedValue != stockCode)
                        updateUrl();

                    GetCourseOfSale(stockCode);
                    FillGridSummaryByHour();
                    gvSummaryByHour.DataBind();
                    FillGridCOSLatest();
                    gvCOSLatest.DataBind();
                    FillGridCOSVolume();
                    //gvCOSVolume.DataBind();
                    
                }

                //lblCourseOfSale.Visible = false;
                lblCourseOfSalebyDate.Visible = false;
                lblCourseOfSalebyVolume.Visible = false;
                
                if (txtObservationDate.Text == "")
                    txtObservationDate.Text = "2050-12-12";
                if (txtNumPrevDay.Text == "")
                    txtNumPrevDay.Text = "0";
                GetMoneyFlowReport();
                GetMoneyFlowReportIntraDay();
                //GetIntraDay();
                BindChart();
            }
            else
            {
                updateUrl();
                //lblCourseOfSale.Visible = true;
                lblCourseOfSalebyDate.Visible = true;
                lblCourseOfSalebyVolume.Visible = true;
            }
        }

        public void GetBrokerList()
        {
            DataOperation doBrokerCode = new DataOperation();
            dsBrokerCode = doBrokerCode.GetBrokerCode();
        }

        public void ClearBrokerNetList()
        {
            alStrongBrokerNet.Clear();
            alWeakBrokerNet.Clear();
            alRetailNet.Clear();
            alFlipperBrokerNet.Clear();
            alComSec.Clear();

        }

        public void updateUrl()
        {
            observationDate = txtObservationDate.Text;
            stockCode = ddlStockList.SelectedValue;
            numPrevDay = txtNumPrevDay.Text;
            customFilterID = Convert.ToInt32(ddlCustomFilter.SelectedValue);
            brokerCodeIndex = Convert.ToInt32(ddlBrokerCode.SelectedIndex);
            string url = HttpContext.Current.Request.Url.AbsoluteUri;
            string[] separateURL = url.Split('?');
            NameValueCollection queryString = System.Web.HttpUtility.ParseQueryString(separateURL[1]);
            if (queryString["StockCode"] != stockCode.ToString() || queryString["NumPrevDay"] != numPrevDay.ToString() || queryString["ObservationDate"] != observationDate || queryString["CustomFilterID"] != customFilterID.ToString() || queryString["brokerCodeIndex"] != brokerCodeIndex.ToString())
            {
                queryString["StockCode"] = stockCode.ToString();
                queryString["NumPrevDay"] = numPrevDay.ToString();
                queryString["ObservationDate"] = observationDate;
                queryString["CustomFilterID"] = customFilterID.ToString();
                queryString["BrokerCodeIndex"] = brokerCodeIndex.ToString();
                url = separateURL[0] + "?" + queryString.ToString();
                Response.Redirect(url);
            }
        }

        public void GetMoneyFlowReport()
        {
            ClearBrokerNetList();

            bool isMobile = false;
            if (WebRequestUtility.isMobileBrowser())
                isMobile = true;

            string pvchStockCode = ddlStockList.SelectedValue;
            brokerCode = ddlBrokerCode.SelectedIndex == -1 ? "All" : ddlBrokerCode.SelectedValue;
            DataOperation doMoneyFlow = new DataOperation();
            DataSet dsMoneyFlow;
            DataTable dtMoneyFlow;
            if (pvchStockCode.Contains(".US"))
            {
                dsMoneyFlow = doMoneyFlow.GetMoneyFlowReport(pvchStockCode, brokerCode, isMobile, txtObservationDate.Text);
                dtMoneyFlow = dsMoneyFlow.Tables[0];
            }
            else
            {
                dsMoneyFlow = doMoneyFlow.GetMoneyFlowReportFilter(pvchStockCode, isMobile);
                dtMoneyFlow = dsMoneyFlow.Tables[0];
            }

            foreach (DataRow dr in dtMoneyFlow.Rows)
            {
                hidXCategories11.Add(Convert.ToString(dr["MarketDate"]));
            }

            foreach (DataRow dr in dtMoneyFlow.Rows)
            {
                if (String.IsNullOrEmpty(dr["MoneyFlowAmount"].ToString()))
                    valueClose.Add(null);
                else
                {
                    valueMoneyFlowAmount.Add(Convert.ToDecimal(dr["MoneyFlowAmount"]));
                    if (moneyFlowAmountMin > Convert.ToDecimal(dr["MoneyFlowAmount"]))
                        moneyFlowAmountMin = Convert.ToDecimal(dr["MoneyFlowAmount"]);
                    if (moneyFlowAmountMax < Convert.ToDecimal(dr["MoneyFlowAmount"]))
                        moneyFlowAmountMax = Convert.ToDecimal(dr["MoneyFlowAmount"]);
                }
                
                alStrongBrokerNet.Add(Convert.ToDecimal(dr["StrongBrokerNet"]));
                alWeakBrokerNet.Add(Convert.ToDecimal(dr["WeakBrokerNet"]));
                alRetailNet.Add(Convert.ToDecimal(dr["OtherRetailNet"]));
                alFlipperBrokerNet.Add(Convert.ToDecimal(dr["FlipperBrokerNet"]));
                alComSec.Add(Convert.ToDecimal(dr["ComSecNet"]));

                yValuesMoneyFlowAmount = valueMoneyFlowAmount.ToArray(typeof(object)) as object[];
                
                yValuesStrongBrokerNet = alStrongBrokerNet.ToArray(typeof(object)) as object[];
                yValuesWeakBrokerNet = alWeakBrokerNet.ToArray(typeof(object)) as object[];
                yValuesRetailNet = alRetailNet.ToArray(typeof(object)) as object[];
                yValuesFlipperBrokerNet = alFlipperBrokerNet.ToArray(typeof(object)) as object[];
                yValuesComSec = alComSec.ToArray(typeof(object)) as object[];

                if (String.IsNullOrEmpty(dr["Close"].ToString()))
                    valueClose.Add(null);
                else
                {
                    valueClose.Add(Convert.ToDecimal(dr["Close"]));
                    if (priceMin > Convert.ToDecimal(dr["Close"]))
                        priceMin = Convert.ToDecimal(dr["Close"]);
                    if (priceMax < Convert.ToDecimal(dr["Close"]))
                        priceMax = Convert.ToDecimal(dr["Close"]);
                }
                    
                yValuesClose = valueClose.ToArray(typeof(object)) as object[];

                if (String.IsNullOrEmpty(dr["VWAP"].ToString()))
                    valueDayVWAP.Add(null);
                else
                    valueDayVWAP.Add(Convert.ToDecimal(dr["VWAP"]));
                yValuesDayVWAP = valueDayVWAP.ToArray(typeof(object)) as object[];

                if (String.IsNullOrEmpty(dr["NetVolume"].ToString()))
                    alNetVolume.Add(null);
                else
                    alNetVolume.Add(Convert.ToDecimal(dr["NetVolume"]));
                yValuesNetVolume = alNetVolume.ToArray(typeof(object)) as object[];

                if (String.IsNullOrEmpty(dr["Value"].ToString()))
                    valueVolume.Add(null);
                else
                    valueVolume.Add(Convert.ToDecimal(dr["Value"]));
                yValuesVolume = valueVolume.ToArray(typeof(object)) as object[];

            }

        }

        public void GetMoneyFlowReportIntraDay()
        {
            string pvchStockCode = ddlStockList.SelectedValue;
            DataOperation doMoneyFlowIntraDay = new DataOperation();
            DataSet dsMoneyFlowIntraDay = doMoneyFlowIntraDay.GetMoneyFlowReportIntraDay(pvchStockCode, txtObservationDate.Text);
            DataTable dtMoneyFlowIntraDay = dsMoneyFlowIntraDay.Tables[0];

            foreach (DataRow dr in dtMoneyFlowIntraDay.Rows)
            {
                alXAxis.Add(Convert.ToString(dr["TimeLabel"]));
            }

            foreach (DataRow drIntraDay in dtMoneyFlowIntraDay.Rows)
            {
                //alMoneyAuctionValue.Add(Convert.ToDecimal(drIntraDay["AuctionValue"]));
                alMoneyInIntraDay.Add(Convert.ToDecimal(drIntraDay["Buy Sale Value"]));
                alMoneyOutIntraDay.Add(Convert.ToDecimal(drIntraDay["Sell Sale Value"]));
                alVWAPIn.Add(Convert.ToDecimal(drIntraDay["Buy VWAP"]));
                alVWAPOut.Add(Convert.ToDecimal(drIntraDay["Sell VWAP"]));
                //alVWAP.Add(Convert.ToDecimal(drIntraDay["VWAP"]));

                if (String.IsNullOrEmpty(drIntraDay["VWAP"].ToString())|| Convert.ToDecimal(drIntraDay["VWAP"])==0)
                    alVWAP.Add(null);
                else
                {
                    alVWAP.Add(Convert.ToDecimal(drIntraDay["VWAP"]));
                    if (priceIntraDayMin > Convert.ToDecimal(drIntraDay["VWAP"]))
                        priceIntraDayMin = Convert.ToDecimal(drIntraDay["VWAP"]);
                }

                alClosePrice.Add(Convert.ToDecimal(drIntraDay["CumulativeVWAP"]));
                alPreviousClose.Add(Convert.ToDecimal(drIntraDay["ClosePrice"]));

                //yValuesMoneyAuctionValue = alMoneyAuctionValue.ToArray(typeof(object)) as object[];
                yValuesMoneyInIntraDay = alMoneyInIntraDay.ToArray(typeof(object)) as object[];
                yValuesMoneyOutIntraDay = alMoneyOutIntraDay.ToArray(typeof(object)) as object[];
                yValuesVWAPIn = alVWAPIn.ToArray(typeof(object)) as object[];
                yValuesVWAPOut = alVWAPOut.ToArray(typeof(object)) as object[];
                yValuesVWAP = alVWAP.ToArray(typeof(object)) as object[];
                yValuesClosePrice = alClosePrice.ToArray(typeof(object)) as object[];
                yValuesPreviousClose = alPreviousClose.ToArray(typeof(object)) as object[];
            }
        }

        public void BindChart()
        {
            Decimal yAxisStart = priceMin * Convert.ToDecimal(0.8);
            Decimal yAxisEnd = priceMax;
            Decimal yAxisAltStart = 0;
            Decimal yAxisAltEnd = moneyFlowAmountMax * Convert.ToDecimal(2.0);
            DotNet.Highcharts.Highcharts chartMoneyFlowAmount = new DotNet.Highcharts.Highcharts("chart1")
            .SetTitle(new Title { Text = "Capital Flow on Stock" })
            //.InitChart(new Chart { DefaultSeriesType= DotNet.Highcharts.Enums.ChartTypes.Column })
            .InitChart(new Chart { ZoomType = ZoomTypes.Xy, Height = 600 })
            .SetXAxis(new XAxis
            {
                //Categories = new[] { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
                Categories = hidXCategories11.ToArray(typeof(string)) as string[],
            })
            .SetYAxis(new[]
            {
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
                        Text = "Close Price",
                        Style = "color: '#89A54E'"
                    },
                    Min = (double)yAxisStart,
                    Max = (double)yAxisEnd
                },
                new YAxis
                {
                    GridLineWidth = 0,
                    Labels = new YAxisLabels
                    {
                        Formatter = "function() { return '$' + this.value + 'K'; }",
                        Style = "color: '#4572A7'"
                    },
                    Title = new YAxisTitle
                    {
                        Text = "Capital Flow Amount",
                        Style = "color: '#4572A7'"
                    },
                    Opposite = true,
                    Min = (double)yAxisAltStart,
                    Max = (double)yAxisAltEnd
                },
                new YAxis
                {
                    GridLineWidth = 0,
                    Labels = new YAxisLabels
                    {
                        Formatter = "function() { return '$' + this.value + 'K'; }",
                        Style = "color: '#4572A7'",
                        Enabled = false
                    },
                    //Title = new YAxisTitle
                    //{
                    //    Text = "Broker Retail Net Amount",
                    //    Style = "color: '#4572A7'"
                    //},
                    Opposite = true,
                },
                new YAxis
                {
                    GridLineWidth = 0,
                    Labels = new YAxisLabels
                    {
                        Formatter = "function() { return '$' + this.value + 'K'; }",
                        Style = "color: '#4572A7'",
                        Enabled = false
                    },
                    //Title = new YAxisTitle
                    //{
                    //    Text = "Net Trade Volume",
                    //    Style = "color: '#4572A7'"
                    //},
                    Opposite = true
                }
            })
            .SetTooltip(new Tooltip
            {
                Formatter = "function() { return ''+ this.x +': '+ this.y + (this.series.name == 'MoneyFlowAmount' ? '' : ''); }"
            })
            .SetPlotOptions(new PlotOptions
            {
                Area = new PlotOptionsArea
                {
                    ConnectNulls = true
                },
                Column = new PlotOptionsColumn
                {
                    Stacking = Stackings.Normal
                }
            }
            )
            .SetOptions(new GlobalOptions
            {
                Lang = new DotNet.Highcharts.Helpers.Lang
                {
                    ThousandsSep = ","
                }
            }
            )
            .SetCredits(new Credits
            {
                Enabled = true
            }
            )
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
                    Name = "Capital Flow Amount",
                    Color = ColorTranslator.FromHtml("#4572A7"),
                    Type = ChartTypes.Column,
                    YAxis = "1",
                    Data = new Data(yValuesMoneyFlowAmount),
                    Stack = "MF",
                    ZIndex = 2,
                    PlotOptionsSeries = new PlotOptionsSeries(){Visible = true}
                },
                new Series
                {
                    Name = "Close Price",
                    Color = ColorTranslator.FromHtml("#00b300"),
                    Type = ChartTypes.Spline,
                    //Type = ChartTypes.Line,
                    Data = new Data(yValuesClose),
                    ZIndex = 9,
                    PlotOptionsSeries = new PlotOptionsSeries(){Visible = true}
                },
                new Series
                {
                    Name = "VWAP",
                    Color = ColorTranslator.FromHtml("#000000"),
                    Type = ChartTypes.Line,
                    //Type = ChartTypes.Line,
                    Data = new Data(yValuesDayVWAP),
                    ZIndex = 10,
                    //PlotOptionsSeries = new PlotOptionsSeries(){Visible = false}
                },
                new Series
                {
                    Name = "NetVolume",
                    Color = ColorTranslator.FromHtml("#cc33ff"),
                    Type = ChartTypes.Spline,
                    //Type = ChartTypes.Line,
                    YAxis = "3",
                    Data = new Data(yValuesNetVolume),
                    ZIndex = 5,
                    PlotOptionsSeries = new PlotOptionsSeries(){Visible = false}
                },
                new Series
                {
                    Name = "Strong Broker Net",
                    Color = ColorTranslator.FromHtml("#3352FF"),
                    //Type = ChartTypes.Spline,
                    YAxis = "2",
                    Type = ChartTypes.Column,
                    Data = new Data(yValuesStrongBrokerNet),
                    Stack = "BRN",
                    ZIndex = 3
                },
                new Series
                {
                    Name = "Weak Broker Net",
                    Color = ColorTranslator.FromHtml("#33FF46"),
                    //Type = ChartTypes.Spline,
                    YAxis = "2",
                    Type = ChartTypes.Column,
                    Data = new Data(yValuesWeakBrokerNet),
                    Stack = "BRN",
                    ZIndex = 3
                },
                new Series
                {
                    Name = "Other Retail Net",
                    Color = ColorTranslator.FromHtml("#ff9933"),
                    //Type = ChartTypes.Spline,
                    YAxis = "2",
                    Type = ChartTypes.Column,
                    Data = new Data(yValuesRetailNet),
                    Stack = "BRN",
                    ZIndex = 3
                },
                new Series
                {
                    Name = "Flipper Broker Net",
                    Color = ColorTranslator.FromHtml("#663300"),
                    //Type = ChartTypes.Spline,
                    YAxis = "2",
                    Type = ChartTypes.Column,
                    Data = new Data(yValuesFlipperBrokerNet),
                    Stack = "BRN",
                    ZIndex = 3
                },
                new Series
                {
                    Name = "Comsec Net",
                    Color = ColorTranslator.FromHtml("#FF3F33"),
                    //Type = ChartTypes.Spline,
                    YAxis = "2",
                    Type = ChartTypes.Column,
                    Data = new Data(yValuesComSec),
                    Stack = "BRN",
                    ZIndex = 3
                }
            }
            );

            ltrChartMoneyFlowAmount.Text = chartMoneyFlowAmount.ToHtmlString();
            Decimal yIntraDayAxisStart = priceIntraDayMin / Convert.ToDecimal(2.0000);

            DotNet.Highcharts.Highcharts chartMoneyFlowAmountIntraDay = new DotNet.Highcharts.Highcharts("chart")
                .SetTitle(new Title { Text = "Capital Flow Intraday" })
                //.InitChart(new Chart { DefaultSeriesType= DotNet.Highcharts.Enums.ChartTypes.Column })
                .InitChart(new Chart { ZoomType = ZoomTypes.Xy, Height = 600 })
                .SetXAxis(new XAxis
                {
                    //Categories = new[] { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" }
                    Categories = alXAxis.ToArray(typeof(string)) as string[],
                    Labels = new XAxisLabels {Rotation = 90}
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
                                        Text = "Close Price",
                                        Style = "color: '#89A54E'"
                                    },
                                    Min = Number.GetNumber(yIntraDayAxisStart)
                                },
                                new YAxis
                                {
                                    GridLineWidth = 0,
                                    Labels = new YAxisLabels
                                    {
                                        Formatter = "function() { return '$' + this.value + 'K'; }",
                                        Style = "color: '#4572A7'"
                                    },
                                    Title = new YAxisTitle
                                    {
                                        Text = "Capital Flow Amount",
                                        Style = "color: '#4572A7'"
                                    },
                                    Opposite = true
                                }
                })
                .SetTooltip(new Tooltip
                {
                    Formatter = "function() { return ''+ this.x +': '+ this.y + (this.series.name == 'MoneyFlowAmountIntraDay' ? '' : ''); }"
                })
                .SetPlotOptions(new PlotOptions
                {
                    Column = new PlotOptionsColumn
                    {
                        Stacking = Stackings.Normal
                    }
                }
                )
            .SetSeries(new[]
            {
                //new Series
                //{
                //    Name = "Auction Value",
                //    Color = ColorTranslator.FromHtml("#ff9933"),
                //    //Type = ChartTypes.Spline,
                //    YAxis = "1",
                //    Type = ChartTypes.Column,
                //    Data = new Data(yValuesMoneyAuctionValue),
                //    Stack = "MFI",
                //    ZIndex = 2,
                //    PlotOptionsSeries = new PlotOptionsSeries(){Visible = true}
                //},
                new Series
                {
                    Name = "Capital Flow Intra Day In",
                    Color = ColorTranslator.FromHtml("#4572A7"),
                    Type = ChartTypes.Column,
                    YAxis = "1",
                    Data = new Data(yValuesMoneyInIntraDay),
                    Stack = "MFI",
                    ZIndex = 2,
                    PlotOptionsSeries = new PlotOptionsSeries(){Visible = true}
                },
                new Series
                {
                    Name = "Cumulative VWAP",
                    Color = ColorTranslator.FromHtml("#40ff00"),
                    Type = ChartTypes.Spline,
                    //YAxis = "1",
                    ZIndex = 90,
                    Data = new Data(yValuesClosePrice)
                },
                new Series
                {
                    Name = "VWAP",
                    Color = ColorTranslator.FromHtml("#000000"),
                    Type = ChartTypes.Spline,
                    //YAxis = "1",
                    ZIndex = 99,
                    Data = new Data(yValuesVWAP)
                },
                new Series
                {
                    Name = "Capital Flow Intra Day Out",
                    Color = ColorTranslator.FromHtml("#F442B0"),
                    //Type = ChartTypes.Spline,
                    YAxis = "1",
                    Type = ChartTypes.Column,
                    Data = new Data(yValuesMoneyOutIntraDay),
                    Stack = "MFI",
                    ZIndex = 2,
                    PlotOptionsSeries = new PlotOptionsSeries(){Visible = true}
                },
                new Series
                {
                    Name = "Previous Close",
                    Color = ColorTranslator.FromHtml("#99d6ff"),
                    Type = ChartTypes.Line,
                    //YAxis = "1",
                    ZIndex = 50,
                    Data = new Data(yValuesPreviousClose)
                }
            }
            );

            ltrChartMoneyFlowAmountIntraDay.Text = chartMoneyFlowAmountIntraDay.ToHtmlString();


            //Decimal yIntraDayAxisStart1M = priceIntraDayMin1M / Convert.ToDecimal(2.0000);
            //DotNet.Highcharts.Highcharts chartIntraDay = new DotNet.Highcharts.Highcharts("chartIntraDay")
            //    .SetTitle(new Title { Text = "Intraday 1min" })
            //    .InitChart(new Chart { ZoomType = ZoomTypes.Xy, Height = 600 })
            //    .SetXAxis(new XAxis
            //    {
            //        Categories = alXAxisIntraDay.ToArray(typeof(string)) as string[],
            //        Labels = new XAxisLabels { Rotation = 90 }
            //    })
            //    .SetYAxis(new[]
            //                    {
            //                    new YAxis
            //                    {
            //                        GridLineWidth = 0,
            //                        Labels = new YAxisLabels
            //                        {
            //                            Formatter = "function() { return '$' + this.value; }",
            //                            Style = "color: '#89A54E'"
            //                        },
            //                        Title = new YAxisTitle
            //                        {
            //                            Text = "Close Price",
            //                            Style = "color: '#89A54E'"
            //                        },
            //                        Min = Number.GetNumber(yIntraDayAxisStart1M)
            //                    },
            //                    new YAxis
            //                    {
            //                        GridLineWidth = 0,
            //                        Labels = new YAxisLabels
            //                        {
            //                            Formatter = "function() { return '$' + this.value + 'K'; }",
            //                            Style = "color: '#4572A7'"
            //                        },
            //                        Title = new YAxisTitle
            //                        {
            //                            Text = "Volume",
            //                            Style = "color: '#4572A7'"
            //                        },
            //                        Opposite = true
            //                    }
            //    })
            //    .SetTooltip(new Tooltip
            //    {
            //        Formatter = "function() { return ''+ this.x +': '+ this.y + (this.series.name == 'VolumeIntraDay' ? '' : ''); }"
            //    })
            //    .SetPlotOptions(new PlotOptions
            //    {
            //        Area = new PlotOptionsArea
            //        {
            //            ConnectNulls = true
            //        }
            //    }
            //    )
            //.SetSeries(new[]
            //{
            //    new Series
            //    {
            //        Name = "Volume",
            //        Color = ColorTranslator.FromHtml("#4572A7"),
            //        Type = ChartTypes.Column,
            //        YAxis = "1",
            //        Data = new Data(yValuesVolumeIntraDay)
            //    },
            //    new Series
            //    {
            //        Name = "Close",
            //        Color = ColorTranslator.FromHtml("#000000"),
            //        Type = ChartTypes.Spline,
            //        //YAxis = "1",
            //        Data = new Data(yValuesClosePriceIntraDay)
            //    },
            //    new Series
            //    {
            //        Name = "Previous Close",
            //        Color = ColorTranslator.FromHtml("#99d6ff"),
            //        Type = ChartTypes.Line,
            //        //YAxis = "1",
            //        Data = new Data(yValuesPreviousCloseIntraDay)
            //    },
            //    //new Series
            //    //{
            //    //    Name = "Today Open",
            //    //    Color = ColorTranslator.FromHtml("#F442B0"),
            //    //    Type = ChartTypes.Line,
            //    //    //YAxis = "1",
            //    //    Data = new Data(yValuesTodayOpenIntraDay)
            //    //},
            //    new Series
            //    {
            //        Name = "VWAP",
            //        Color = ColorTranslator.FromHtml("#40ff00"),
            //        Type = ChartTypes.Spline,
            //        //YAxis = "1",
            //        Data = new Data(yValueVWAPIntraDay)
            //    }

            //}
            //.SetSeries(new Series
            //{
            //    //name = "MoneyFlow", Data = new Data(new object[] { 29.9, 71.5, 106.4, 129.2, -144.0, 176.0, 135.6, -148.5, 216.4, 194.1, 95.6, 54.4 })
            //    Name = "Money Flow Amount(Buy amount - Sell amount)",
            //    Data = new Data(yValuesMoneyFlowAmount)
            //}
            //);

            //ltrChartIntraDay.Text = chartIntraDay.ToHtmlString();


        }

        public void FillGridSummaryByHour()
        {
            gvSummaryByHour.DataSource = dsCourseOfSale.Tables[0];
        }

        public void FillGridCOSLatest()
        {
            string pvchStockCode = ddlStockList.SelectedValue;
            GetCourseOfSale(pvchStockCode);
            gvCOSLatest.DataSource = dsCourseOfSale.Tables[1];
        }
        public void FillGridCOSVolume()
        {
            string pvchStockCode = ddlStockList.SelectedValue;
            GetCourseOfSale(pvchStockCode);
            //gvCOSVolume.DataSource = dsCourseOfSale.Tables[2];
        }
        public void GetCourseOfSale(string pvchStockCode)
        {
            bool isMobile = false;
            if (WebRequestUtility.isMobileBrowser())
                isMobile = true;
            DataOperation doCourseOfSale = new DataOperation();
            dsCourseOfSale = doCourseOfSale.GetCourseOfSale(pvchStockCode, txtObservationDate.Text, isMobile);
        }
        public void GetStockListInfo()
        {
            DataOperation doStockListInfo = new DataOperation();
            dsStockListInfo = doStockListInfo.GetPriceSummaryStock();
        }
        public void GetStockListInfo(int customFilterID)
        {
            DataOperation doStockListInfo = new DataOperation();
            dsStockListInfo = doStockListInfo.GetPriceSummaryStock(customFilterID);
        }

        public void GetCustomFilter()
        {
            DataOperation doCustomFilter = new DataOperation();
            dsCustomFilter = doCustomFilter.GetCustomFilter();
        }

        protected void gvSummaryByHour_SelectedIndexChanged(object sender, EventArgs e)
        {

        }

        protected void gvCOSLatest_PageIndexChanging(object sender, GridViewPageEventArgs e)
        {
            FillGridCOSLatest();
            gvCOSLatest.PageIndex = e.NewPageIndex;
            gvCOSLatest.DataBind();
            FillGridCOSVolume();
            //gvCOSVolume.PageIndex = e.NewPageIndex;
            //gvCOSVolume.DataBind();
        }

        protected void ddlStockList_SelectedIndexChanged(object sender, EventArgs e)
        {
            string pvchStockCode = ddlStockList.SelectedValue;

            GetCourseOfSale(pvchStockCode);
            FillGridSummaryByHour();
            gvSummaryByHour.DataBind();
            FillGridCOSLatest();
            gvCOSLatest.DataBind();
            FillGridCOSVolume();
            //gvCOSVolume.DataBind();
            GetMoneyFlowReport();
            GetMoneyFlowReportIntraDay();
            //GetIntraDay();
            BindChart();
        }

        //protected void gvCOSVolume_PageIndexChanging(object sender, GridViewPageEventArgs e)
        //{
        //    FillGridCOSVolume();
        //    //gvCOSVolume.PageIndex = e.NewPageIndex;
        //    //gvCOSVolume.DataBind();
        //}

        protected void gvCOSLatest_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                //e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                //e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                //e.Row.ToolTip = "Click to view related market depth changes";
                //System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                //e.Row.Attributes.Add("onclick", String.Format("window.location='MarketDepth.aspx?CourseOfSaleID={0}'", drv["ID"]));
                ;

            }
        }

        protected void gvCOSLatest_RowCreated(object sender, GridViewRowEventArgs e)
        {

        }

        protected void gvCOSVolume_RowDataBound(object sender, GridViewRowEventArgs e)
        {
            if (e.Row.RowType == DataControlRowType.DataRow)
            {
                e.Row.Attributes["onmouseover"] = "this.style.cursor='pointer';this.style.textDecoration='underline';";
                e.Row.Attributes["onmouseout"] = "this.style.textDecoration='none';";
                e.Row.ToolTip = "Click to view related market depth changes";
                System.Data.DataRowView drv = e.Row.DataItem as System.Data.DataRowView;
                //e.Row.Attributes["onclick"] = this.Page.ClientScript.GetPostBackClientHyperlink(this.gvCOSLatest, "Select$" + e.Row.RowIndex);
                e.Row.Attributes.Add("onclick", String.Format("window.location='MarketDepth.aspx?CourseOfSaleID={0}'", drv["ID"]));

            }
        }

        protected void txtNumPrevDay_TextChanged(object sender, EventArgs e)
        {
            string pvchStockCode = ddlStockList.SelectedValue;
            GetCourseOfSale(pvchStockCode);
            FillGridSummaryByHour();
            gvSummaryByHour.DataBind();
            FillGridCOSLatest();
            gvCOSLatest.DataBind();
            FillGridCOSVolume();
            //gvCOSVolume.DataBind();
            GetMoneyFlowReport();
            GetMoneyFlowReportIntraDay();
            //GetIntraDay();
            BindChart();
        }

        protected void txtNumObservationDate_TextChanged(object sender, EventArgs e)
        {
            string pvchStockCode = ddlStockList.SelectedValue;
            GetCourseOfSale(pvchStockCode);
            FillGridSummaryByHour();
            gvSummaryByHour.DataBind();
            FillGridCOSLatest();
            gvCOSLatest.DataBind();
            FillGridCOSVolume();
            //gvCOSVolume.DataBind();
            GetMoneyFlowReport();
            GetMoneyFlowReportIntraDay();
            //GetIntraDay();
            BindChart();
        }

        //protected void chkMonitorStockOnly_CheckedChanged(object sender, EventArgs e)
        //{
        //    if (chkMonitorStockOnly.Checked)
        //    {
        //        GetStockListInfo(true);
        //        ddlStockList.DataSource = dsStockListInfo.Tables[0];
        //        ddlStockList.DataTextField = "CompanyName";
        //        ddlStockList.DataValueField = "ASXCode";
        //        ddlStockList.DataBind();
        //        ddlStockList.SelectedIndex = -1;

        //    }
        //    else
        //    {
        //        GetStockListInfo();
        //        ddlStockList.DataSource = dsStockListInfo.Tables[0];
        //        ddlStockList.DataTextField = "CompanyName";
        //        ddlStockList.DataValueField = "ASXCode";
        //        ddlStockList.DataBind();
        //        ddlStockList.SelectedIndex = -1;
        //    }

        //    string stockCode = "";
        //    string numPrevDay = "";
        //    string observationDate = "";
        //    if (Request.QueryString["StockCode"] != null)
        //        stockCode = Convert.ToString(Request.QueryString["StockCode"]);
        //    if (Request.QueryString["NumPrevDay"] != null)
        //        numPrevDay = Convert.ToString(Request.QueryString["NumPrevDay"]);
        //    if (Request.QueryString["ObservationDate"] != null)
        //        observationDate = Convert.ToString(Request.QueryString["ObservationDate"]);

        //    txtNumPrevDay.Text = numPrevDay;
        //    txtObservationDate.Text = observationDate;

        //    if (stockCode.Length > 0 && (txtObservationDate.Text.Length > 0 || txtNumPrevDay.Text.Length > 0))
        //    {
        //        observationDate = txtObservationDate.Text;
        //        int i = 0;
        //        foreach (ListItem item in ddlStockList.Items)
        //        {
        //            if (item.Value == stockCode)
        //                ddlStockList.SelectedIndex = i;
        //            i++;
        //        }

        //        GetCourseOfSale(stockCode);
        //        FillGridSummaryByHour();
        //        gvSummaryByHour.DataBind();
        //        FillGridCOSLatest();
        //        gvCOSLatest.DataBind();
        //        FillGridCOSVolume();
        //        gvCOSVolume.DataBind();

        //    }
        
        //}

        protected void ddlFilter_SelectedIndexChanged(object sender, EventArgs e)
        {

        }

        protected void ddlCustomFilter_SelectedIndexChanged(object sender, EventArgs e)
        {
            GetStockListInfo(customFilterID);
            ddlStockList.DataSource = dsStockListInfo.Tables[0];
            ddlStockList.DataTextField = "CompanyName";
            ddlStockList.DataValueField = "ASXCode";
            if (dsStockListInfo.Tables[0].Rows.Count > 0)
                ddlStockList.SelectedIndex = 0;
            else
                ddlStockList.SelectedIndex = -1;
            updateUrl();            
        }

        protected void ddlBrokerCode_SelectedIndexChanged(object sender, EventArgs e)
        {
            GetMoneyFlowReport();
            BindChart();
            updateUrl();
        }
    }
}