using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Data.SqlClient;
using GetYahoo;
using System.Data;


namespace StockInfoReport
{
    public class DataOperation
    {
        public DataSet GetCourseOfSale(string pvchStockCode, string observationDate, bool isMobile)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetCourseOfSale";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;

            cmdGenericiQuery.Parameters.Add("@pvchObservationDate", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchObservationDate"].Value = observationDate;

            cmdGenericiQuery.Parameters.Add("@pbitIsMobile", SqlDbType.Bit);
            cmdGenericiQuery.Parameters["@pbitIsMobile"].Value = isMobile;
            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetFirstBuySell(string pvchStockCode, int numPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetFirstBuySell";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;

            cmdGenericiQuery.Parameters.Add("@intNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@intNumPrevDay"].Value = numPrevDay;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetFirstBuySellASXOnly(string pvchStockCode, int numPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetFirstBuySellASXOnly";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;

            cmdGenericiQuery.Parameters.Add("@intNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@intNumPrevDay"].Value = numPrevDay;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public string GetHCSearchString(string pvchStockCode)
        {
            string HCSearchString;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "HC.usp_GetQualityPosterSearchString";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchASXCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchASXCode"].Value = pvchStockCode;

            var outParamSearchString = new SqlParameter("@pvchHCSearchString", SqlDbType.VarChar);
            outParamSearchString.Direction = ParameterDirection.Output;
            outParamSearchString.Size = 200000;
            cmdGenericiQuery.Parameters.Add(outParamSearchString);

            try
            {
                DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
                HCSearchString = (string)cmdGenericiQuery.Parameters["@pvchHCSearchString"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return HCSearchString;
        }

        public DataSet GetLargeSale(int numPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetLargeSale";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@intNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@intNumPrevDay"].Value = numPrevDay;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetStockKeyToken(string token)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetStokeTokenList";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchToken", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchToken"].Value = token;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }
        public DataSet GetLineWipe(int numPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetLineWipe";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@intNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@intNumPrevDay"].Value = numPrevDay;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetMarketDepth(int pintCourseOfSaleID)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetMarketDepth";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;
            
            cmdGenericiQuery.Parameters.Add("@pintCourseOfSaleID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintCourseOfSaleID"].Value = pintCourseOfSaleID;
            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }
        
        public DataSet GetMonitorStock()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetMonitorStockList";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetCOSMonitorStock()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetCOSStockList";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetFirstBuySellStock()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "[StockData].[usp_GetFirstBuySellStockList]";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetTradingAlert(int pintTradingAlertTypeID)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "[Alert].[usp_GetTradingAlert]";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintTradingAlertTypeID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintTradingAlertTypeID"].Value = pintTradingAlertTypeID;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetOrder(int pintOrderTypeID)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "[Order].[usp_GetOrder]";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintOrderTypeID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintOrderTypeID"].Value = pintOrderTypeID;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetPriceSummaryStock()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetPriceSummaryStockList";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }
        public DataSet GetPriceSummaryStock(int customFilterID)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetPriceSummaryStockList";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                cmdGenericiQuery.Parameters.Add("@pintCustomFilterID", SqlDbType.Int);
                cmdGenericiQuery.Parameters["@pintCustomFilterID"].Value = customFilterID;
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetBrokerReportStartFrom(string pvchStockCode, string observationStartDate, string observationEndDate)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_Get_BrokerReportStartFrom";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchASXCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchASXCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pvchObservationStartDate", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchObservationStartDate"].Value = observationStartDate;
            cmdGenericiQuery.Parameters.Add("@pvchObservationEndDate", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchObservationEndDate"].Value = observationEndDate;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }


        public DataSet GetStockBuyvsSell(string pvchSortBy, int pintNumPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetTodayTradeBuyvsSell";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pintNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintNumPrevDay"].Value = pintNumPrevDay;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetMoneyFlowReport_InstituteRetail(string pvchStockCode, string pvchBrokerCode, bool isMobile)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_MoneyFlowReport_InstituteRetail";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;

            cmdGenericiQuery.Parameters.Add("@pvchBrokerCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchBrokerCode"].Value = pvchBrokerCode;

            cmdGenericiQuery.Parameters.Add("@pbitIsMobile", SqlDbType.Bit);
            if (isMobile)
                cmdGenericiQuery.Parameters["@pbitIsMobile"].Value = 1;
            else
                cmdGenericiQuery.Parameters["@pbitIsMobile"].Value = 0;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetMoneyFlowReportFilter(string pvchStockCode, bool isMobile)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_MoneyFlowReport_Sector";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchTokenID", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchTokenID"].Value = pvchStockCode;

            cmdGenericiQuery.Parameters.Add("@pbitIsMobile", SqlDbType.Bit);
            if (isMobile)
                cmdGenericiQuery.Parameters["@pbitIsMobile"].Value = 1;
            else
                cmdGenericiQuery.Parameters["@pbitIsMobile"].Value = 0;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetMoneyFlowReport(string pvchStockCode, string pvchBrokerCode, bool isMobile, string observationDate)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_MoneyFlowReport";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;

            cmdGenericiQuery.Parameters.Add("@pvchObservationDate", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchObservationDate"].Value = observationDate;

            cmdGenericiQuery.Parameters.Add("@pvchBrokerCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchBrokerCode"].Value = pvchBrokerCode;

            cmdGenericiQuery.Parameters.Add("@pbitIsMobile", SqlDbType.Bit);
            if (isMobile)
                cmdGenericiQuery.Parameters["@pbitIsMobile"].Value = 1;
            else
                cmdGenericiQuery.Parameters["@pbitIsMobile"].Value = 0;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetMoneyFlowReportIntraDay(string pvchStockCode, string observationDate)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_MoneyFlowReportIntraDay";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pvchObservationDate", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchObservationDate"].Value = observationDate;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetMoneyFlowReportInstituteIntraDay(string pvchStockCode, string observationDate)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_MoneyFlowReportInstituteIntraday";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pvchObservationDate", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchObservationDate"].Value = observationDate;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetIntraDay(string pvchStockCode, string observationDate)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_Intraday1M";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pvchObservationDate", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchObservationDate"].Value = observationDate;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetSectorPerformance(string pvchToken)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetSectorPerformance";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchToken", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchToken"].Value = pvchToken;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetStockListInfo()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetMonitorStock";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetCustomFilter()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetCustomFilter";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetSectorList()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetSectorList";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetTradingAlertType()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "[Alert].[usp_GetTradingAlertType]";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetOrderType()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "[Order].[usp_GetOrderType]";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }


        public DataSet GetHCQualityPosterType()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "HC.usp_GetPosterType";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetHCQualityPoster(string pvchPosterType)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "HC.usp_GetPoster";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchPosterType", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchPosterType"].Value = pvchPosterType;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public string AddHCQualityPoster(string pvchPosterType, string pvchPoster, int pintRating)
        {

            int errorNumber = 0;
            string pvchMessage = "";
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "HC.usp_AddPoster";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchPosterType", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchPosterType"].Value = pvchPosterType;

            cmdGenericiQuery.Parameters.Add("@pvchPoster", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchPoster"].Value = pvchPoster;

            cmdGenericiQuery.Parameters.Add("@pintRating", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintRating"].Value = pintRating;

            var outParamMessage = new SqlParameter("@pvchMessage", SqlDbType.VarChar);
            outParamMessage.Direction = ParameterDirection.Output;
            outParamMessage.Size = 200;
            cmdGenericiQuery.Parameters.Add(outParamMessage);

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
                pvchMessage = (string)cmdGenericiQuery.Parameters["@pvchMessage"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }

            return pvchMessage;
        }

        public string AddMonitorStock(string pvchStockCode)
        {

            int errorNumber = 0;
            string pvchMessage = "";
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_AddMonitorStock";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;

            var outParamMessage = new SqlParameter("@pvchMessage", SqlDbType.VarChar);
            outParamMessage.Direction = ParameterDirection.Output;
            outParamMessage.Size = 200;
            cmdGenericiQuery.Parameters.Add(outParamMessage);

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
                pvchMessage = (string)cmdGenericiQuery.Parameters["@pvchMessage"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }

            return pvchMessage;
        }

        public string AddTradingAlert(string pvchStockCode, int pintUserID, int pintTradingAlertTypeID, decimal pdecAlertPrice, int @pintAlertVolume, string alertPriceType, int boost)
        {

            int errorNumber = 0;
            string pvchMessage = "";
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Alert.usp_AddTradingAlert";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchASXCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchASXCode"].Value = pvchStockCode;

            cmdGenericiQuery.Parameters.Add("@pintUserID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintUserID"].Value = pintUserID;

            cmdGenericiQuery.Parameters.Add("@pintTradingAlertTypeID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintTradingAlertTypeID"].Value = pintTradingAlertTypeID;

            cmdGenericiQuery.Parameters.Add("@pdecAlertPrice", SqlDbType.Decimal);
            cmdGenericiQuery.Parameters["@pdecAlertPrice"].Value = pdecAlertPrice;

            cmdGenericiQuery.Parameters.Add("@pintAlertVolume", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintAlertVolume"].Value = @pintAlertVolume;

            cmdGenericiQuery.Parameters.Add("@pvchAlertPriceType", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchAlertPriceType"].Value = alertPriceType;

            cmdGenericiQuery.Parameters.Add("@pintboost", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintboost"].Value = boost;

            var outParamMessage = new SqlParameter("@pvchMessage", SqlDbType.VarChar);
            outParamMessage.Direction = ParameterDirection.Output;
            outParamMessage.Size = 200;
            cmdGenericiQuery.Parameters.Add(outParamMessage);

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
                pvchMessage = (string)cmdGenericiQuery.Parameters["@pvchMessage"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }

            return pvchMessage;
        }

        public string AddOrder(string pvchStockCode, int pintUserID, string tradeAccountName, int pintOrderTypeID, decimal pdecOrderPrice, int pintVolumeGT, int pintOrderVolume, string pvchValidUntil, string pvchOrderPriceType, decimal pdecOrderValue, int pintOrderPriceBufferNumberOfTick, string pvchAdditionalSettings)
        {

            int errorNumber = 0;
            string pvchMessage = "";
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Order.usp_AddOrder";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchASXCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchASXCode"].Value = pvchStockCode;

            cmdGenericiQuery.Parameters.Add("@pintUserID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintUserID"].Value = pintUserID;

            cmdGenericiQuery.Parameters.Add("@pvchTradeAccountName", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchTradeAccountName"].Value = tradeAccountName;

            cmdGenericiQuery.Parameters.Add("@pintOrderTypeID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintOrderTypeID"].Value = pintOrderTypeID;

            cmdGenericiQuery.Parameters.Add("@pdecOrderPrice", SqlDbType.Decimal);
            cmdGenericiQuery.Parameters["@pdecOrderPrice"].Value = pdecOrderPrice;

            cmdGenericiQuery.Parameters.Add("@pintVolumeGT", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintVolumeGT"].Value = pintVolumeGT;

            cmdGenericiQuery.Parameters.Add("@pintOrderVolume", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintOrderVolume"].Value = pintOrderVolume;

            cmdGenericiQuery.Parameters.Add("@pvchValidUntil", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchValidUntil"].Value = pvchValidUntil;

            cmdGenericiQuery.Parameters.Add("@pvchAdditionalSettings", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchAdditionalSettings"].Value = pvchAdditionalSettings;

            if (pdecOrderValue >= 0)
            {
                cmdGenericiQuery.Parameters.Add("@pdecOrderValue", SqlDbType.Decimal);
                cmdGenericiQuery.Parameters["@pdecOrderValue"].Value = pdecOrderValue;
            }

            cmdGenericiQuery.Parameters.Add("@pintOrderPriceBufferNumberOfTick", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintOrderPriceBufferNumberOfTick"].Value = pintOrderPriceBufferNumberOfTick;

            cmdGenericiQuery.Parameters.Add("@pvchOrderPriceType", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchOrderPriceType"].Value = pvchOrderPriceType;


            var outParamMessage = new SqlParameter("@pvchMessage", SqlDbType.VarChar);
            outParamMessage.Direction = ParameterDirection.Output;
            outParamMessage.Size = 200;
            cmdGenericiQuery.Parameters.Add(outParamMessage);

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
                pvchMessage = (string)cmdGenericiQuery.Parameters["@pvchMessage"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }

            return pvchMessage;
        }

        public string AddMonitorStockFromReport(string pvchStockCode, int pintPriorityLevel, int pintSMSAlert)
        {

            int errorNumber = 0;
            string pvchMessage = "";
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_AddMonitorStockFromReport";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pintPriorityLevel", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintPriorityLevel"].Value = pintPriorityLevel;
            cmdGenericiQuery.Parameters.Add("@pintSMSAlert", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintSMSAlert"].Value = pintSMSAlert;

            var outParamMessage = new SqlParameter("@pvchMessage", SqlDbType.VarChar);
            outParamMessage.Direction = ParameterDirection.Output;
            outParamMessage.Size = 200;
            cmdGenericiQuery.Parameters.Add(outParamMessage);

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
                pvchMessage = (string)cmdGenericiQuery.Parameters["@pvchMessage"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }

            return pvchMessage;
        }

        public string AddStockKeyToken(string pvchStockCode, string token)
        {

            int errorNumber = 0;
            string pvchMessage = "";
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_AddStockKeyToken";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;

            cmdGenericiQuery.Parameters.Add("@pvchToken", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchToken"].Value = token;

            var outParamMessage = new SqlParameter("@pvchMessage", SqlDbType.VarChar);
            outParamMessage.Direction = ParameterDirection.Output;
            outParamMessage.Size = 200;
            cmdGenericiQuery.Parameters.Add(outParamMessage);

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
                pvchMessage = (string)cmdGenericiQuery.Parameters["@pvchMessage"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }

            return pvchMessage;
        }

        public void DeleteMonitorStock(string pvchStockCode)
        {

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_DeleteMonitorStock";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
        }

        public void DeleteTradingAlert(int tradingAlertID)
        {

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "[Alert].[usp_DeleteTradingAlert]";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pintTradingAlertID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintTradingAlertID"].Value = tradingAlertID;

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
        }

        public void DeleteOrder(int orderID)
        {

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "[Order].[usp_DeleteOrder]";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pintOrderID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintOrderID"].Value = orderID;

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
        }
        public void DeleteStockKeyToken(string pvchStockCode, string token)
        {

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_DeleteStockKeyToken";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;

            cmdGenericiQuery.Parameters.Add("@pvchToken", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchToken"].Value = token;

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
        }

        public void DeleteQualityPoster(string pvchPoster, string pvchPosterType)
        {

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "HC.usp_DeletePoster";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchPoster", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchPoster"].Value = pvchPoster;

            cmdGenericiQuery.Parameters.Add("@pvchPosterType", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchPosterType"].Value = pvchPosterType;

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
        }

        public string UpdateMonitorStock(string pvchStockCode, string pvchStockCodeNew, int priorityLevel, string pvchNotes)
        {

            int errorNumber = 0;
            string pvchMessage = "";
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_UpdateMonitorStock";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pvchStockCodeNew", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCodeNew"].Value = pvchStockCodeNew;
            cmdGenericiQuery.Parameters.Add("@pintPriorityLevel", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintPriorityLevel"].Value = priorityLevel;
            cmdGenericiQuery.Parameters.Add("@pvchNotes", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchNotes"].Value = pvchNotes;

            var outParamMessage = new SqlParameter("@pvchMessage", SqlDbType.VarChar);
            outParamMessage.Direction = ParameterDirection.Output;
            outParamMessage.Size = 200;
            cmdGenericiQuery.Parameters.Add(outParamMessage);

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
                pvchMessage = (string)cmdGenericiQuery.Parameters["@pvchMessage"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return pvchMessage;
        }
        public string UpdateTradingAlert(int pintTradingAlertID, decimal pdecAlertPrice, int pintAlertVolume)
        {

            int errorNumber = 0;
            string pvchMessage = "";
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "[Alert].[usp_UpdateTradingAlert]";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pintTradingAlertID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintTradingAlertID"].Value = pintTradingAlertID;
            cmdGenericiQuery.Parameters.Add("@pdecAlertPrice", SqlDbType.Decimal);
            cmdGenericiQuery.Parameters["@pdecAlertPrice"].Value = pdecAlertPrice;
            cmdGenericiQuery.Parameters.Add("@pintAlertVolume", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintAlertVolume"].Value = pintAlertVolume;

            var outParamMessage = new SqlParameter("@pvchMessage", SqlDbType.VarChar);
            outParamMessage.Direction = ParameterDirection.Output;
            outParamMessage.Size = 200;
            cmdGenericiQuery.Parameters.Add(outParamMessage);

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
                pvchMessage = (string)cmdGenericiQuery.Parameters["@pvchMessage"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return pvchMessage;
        }

        public string UpdateOrder(int pintOrderID, decimal pdecOrderPrice, int pintVolumeGt, int pintOrderVolume, string pvchValidUntil, decimal pdecOrderValue, int pintOrderPriceBufferNumberOfTick, string pvchAdditionalSettings)
        {

            int errorNumber = 0;
            string pvchMessage = "";
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "[Order].[usp_UpdateOrder]";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            cmdGenericiQuery.Parameters.Add("@pintOrderID", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintOrderID"].Value = pintOrderID;
            cmdGenericiQuery.Parameters.Add("@pdecOrderPrice", SqlDbType.Decimal);
            cmdGenericiQuery.Parameters["@pdecOrderPrice"].Value = pdecOrderPrice;

            cmdGenericiQuery.Parameters.Add("@pintVolumeGt", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintVolumeGt"].Value = pintVolumeGt;

            cmdGenericiQuery.Parameters.Add("@pintOrderVolume", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintOrderVolume"].Value = pintOrderVolume;

            cmdGenericiQuery.Parameters.Add("@pvchValidUntil", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchValidUntil"].Value = pvchValidUntil;

            cmdGenericiQuery.Parameters.Add("@pvchAdditionalSettings", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchAdditionalSettings"].Value = pvchAdditionalSettings;

            cmdGenericiQuery.Parameters.Add("@pdecOrderValue", SqlDbType.Decimal);
            cmdGenericiQuery.Parameters["@pdecOrderValue"].Value = pdecOrderValue;

            cmdGenericiQuery.Parameters.Add("@pintOrderPriceBufferNumberOfTick", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintOrderPriceBufferNumberOfTick"].Value = pintOrderPriceBufferNumberOfTick;

            var outParamMessage = new SqlParameter("@pvchMessage", SqlDbType.VarChar);
            outParamMessage.Direction = ParameterDirection.Output;
            outParamMessage.Size = 200;
            cmdGenericiQuery.Parameters.Add(outParamMessage);

            try
            {
                DBAccess.LoadData(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
                pvchMessage = (string)cmdGenericiQuery.Parameters["@pvchMessage"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return pvchMessage;
        }

        public DataSet GetCommonStock(string pvchSortBy)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "HC.usp_GetCommonStock";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;
            
            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetCommonStockPlus(string pvchSortBy)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "HC.usp_GetCommonStockPlus";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;


            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetMCvsCashPosition(string pvchStockCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetMCvsCashPosition";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pbitUseCache", SqlDbType.Bit);
            cmdGenericiQuery.Parameters["@pbitUseCache"].Value = 1;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }


        public DataSet GetBrokerReport(string pvchStockCode, string observationDate)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_Get_BrokerReport";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchASXCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchASXCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pvchObservationDate", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchObservationDate"].Value = observationDate;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet Top20Shareholder(string pvchStockCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_Top20Shareholder";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet PlacementDetails(string pvchStockCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetPlacementDetails";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet DirectorandMajorShareholder(string pvchStockCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_DirectorandMajorShareholder";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet CashflowDetails(string pvchStockCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetCashflowDetails";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet Get3BDetails(string pvchStockCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_Get3BDetails";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetChiXVolumeAnalysis(string pvchStockCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetChixVolumePerc";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetInstituteParticipation(string pvchStockCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_Get_InstituteParticipation";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetCurrentHoldings()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetCurrentHoldings";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetHeartBeat()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockAPI.usp_GetHeartBeat";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetCurrentWatchs()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetCurrentWatchs";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetDirectorInterestDetails(string pvchStockCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetDirectorInterestDetails";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetTweets(string pvchStockCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "StockData.usp_GetTweets";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchStockCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchStockCode"].Value = pvchStockCode;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet CheckAnnouncementKeyword(string pvchKeyword)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_CheckAnnouncementKeyword";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchKeyword", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchKeyword"].Value = pvchKeyword;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetTopNTradeRequest(int topN)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "AutoTrade.usp_GetTopNTradeRequest";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintTopN", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintTopN"].Value = topN;
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetStockScreening(string pvchSortBy)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetStockScreening";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetStockAnnouncement(string pvchSortBy, int pintNumPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetStockAnnouncement";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pintNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintNumPrevDay"].Value = pintNumPrevDay;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetASX300StockSectorPerformance(string pvchSortBy, int pintNumPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetASX300SectorTodayPerformance";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pintNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintNumPrevDay"].Value = pintNumPrevDay;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetStockSectorPerformance(string pvchSortBy, int pintNumPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetSectorTodayPerformance";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pintNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintNumPrevDay"].Value = pintNumPrevDay;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }
        public DataSet GetStockScanResult(string pvchSortBy, int pintNumPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetStockScanResult";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pintNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintNumPrevDay"].Value = pintNumPrevDay;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetBrokerAnalysis(string pvchSortBy, int pintNumPrevDay, string pvchbrokerCode)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_Get_BrokerBuySuggestion";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pvchbrokerCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchbrokerCode"].Value = pvchbrokerCode;

            cmdGenericiQuery.Parameters.Add("@pintNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintNumPrevDay"].Value = pintNumPrevDay;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetBrokerBuySellPerc(string pvchSortBy, int pintNumPrevDay, string pvchbrokerCode, string pdtObservationDateEnd)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetBrokerBuySellPerc";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pvchbrokerCode", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchbrokerCode"].Value = pvchbrokerCode;

            cmdGenericiQuery.Parameters.Add("@pintNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintNumPrevDay"].Value = pintNumPrevDay;

            cmdGenericiQuery.Parameters.Add("@pdtObservationDateEnd", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pdtObservationDateEnd"].Value = pdtObservationDateEnd;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }
        public DataSet GetBrokerCode()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetBrokerCode";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetTradeStrategySuggestion(string pvchSelectItem, int pintNumPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;

            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_Get_StrategySuggestion";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSelectItem", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSelectItem"].Value = pvchSelectItem;

            cmdGenericiQuery.Parameters.Add("@pintNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintNumPrevDay"].Value = pintNumPrevDay;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetStockWatchList(string pvchSelectItem, int pintNumPrevDay)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_Get_StockWatchList";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSelectItem", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSelectItem"].Value = pvchSelectItem;

            cmdGenericiQuery.Parameters.Add("@pintNumPrevDay", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintNumPrevDay"].Value = pintNumPrevDay;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetDirectorBuy(string pvchSortBy)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetDirectorBuy";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetASXIndexReport()
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_ASXIndexReport";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;
            
            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
            {
                dsReturnedData = DBAccess.LoadDataSetLong(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }

        public DataSet GetTradingHaltReport(string pvchSortBy)
        {
            DataSet dsReturnedData;

            int errorNumber = 0;
            SqlCommand cmdGenericiQuery = new SqlCommand();
            cmdGenericiQuery.CommandText = "Report.usp_GetTradingHalt";
            cmdGenericiQuery.CommandType = CommandType.StoredProcedure;

            cmdGenericiQuery.Parameters.Add("@pvchSortBy", SqlDbType.VarChar);
            cmdGenericiQuery.Parameters["@pvchSortBy"].Value = pvchSortBy;

            cmdGenericiQuery.Parameters.Add("@pintErrorNumber", SqlDbType.Int);
            cmdGenericiQuery.Parameters["@pintErrorNumber"].Direction = ParameterDirection.Output;

            try
           {
                dsReturnedData = DBAccess.LoadDataSet(cmdGenericiQuery);
                errorNumber = (int)cmdGenericiQuery.Parameters["@pintErrorNumber"].Value;
            }
            catch (Exception err)
            {
                throw (new Exception(err.Message));
            }
            return dsReturnedData;
        }


    }
}