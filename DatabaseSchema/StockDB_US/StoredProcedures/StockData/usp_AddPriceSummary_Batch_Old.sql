-- Stored procedure: [StockData].[usp_AddPriceSummary_Batch_Old]






CREATE PROCEDURE [StockData].[usp_AddPriceSummary_Batch_Old]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchPriceSummaryJson as varchar(max)
AS
/******************************************************************************
File: usp_AddPriceSummary_Batch.sql
Stored Procedure Name: usp_AddPriceSummary_Batch
Overview
-----------------
usp_AddPriceSummary_Batch

Input Parameters
-----------------
@pbitDebug		-- Set to 1 to force the display of debugging information

Output Parameters
-----------------
@pintErrorNumber		-- Contains 0 if no error, or ERROR_NUMBER() on error

Example of use
-----------------
*******************************************************************************
Change History - (copy and repeat section below)
*******************************************************************************
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
Date:		2019-10-07
Author:		WAYNE CHENG
Description: Initial Version
-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-
*******************************************************************************/

SET NOCOUNT ON

BEGIN --Proc

	IF @pintErrorNumber <> 0
	BEGIN
		-- Assume the application is in an error state, so get out quickly
		-- Remove this check if this stored procedure should run regardless of a previous error
		RETURN @pintErrorNumber
	END

	BEGIN TRY

		-- Error variable declarations
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_AddPriceSummary_Batch'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'StockData'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--begin transaction
		
		--@pxmlMarketDepth
		--declare @pvchQuoteTime as varchar(100) = '06/13/2018 23:04:46'		

		if object_id(N'Tempdb.dbo.#TempPriceSummaryRaw') is not null
			drop table #TempPriceSummaryRaw

declare @pvchPriceSummaryJsonTest as varchar(max) = 
'
{
  "EvId": "7F89EADB",
  "Success": true,
  "PackageStatus": "Completed",
  "Responses": [
    {
      "TId": "5",
      "RequestStatus": "Completed",
      "ModelStatus": "New",
      "PollFreq": 1500,
      "Model": {
        "Quotes": [
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "PEET LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 1.15,
            "BestSellPrice": 1.16,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 1.17,
            "Hash": "7336787678758713976",
            "HasValidPricing": true,
            "HighSalePrice": 1.17,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 1.15,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "XD",
                "Name": "",
                "Description": "Ex Dividend"
              }
            ],
            "MatchVolume": 156,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 1.17,
            "OpenInterest": 0,
            "VWapPrice": 1.1563686878533827256775199844,
            "TotalVolumeTraded": 5129,
            "TotalValueTraded": 5931.0,
            "TotalNumberOfTrades": 45,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Ex Dividend",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "PPC",
            "LastPrice": 1.155,
            "DisplayPrice": 1.155,
            "DisplayPriceType": "Last",
            "PriceChange": -0.015,
            "PriceChangePercent": -0.0128205128205128205128205128,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "TANGA RESOURCES LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.002,
            "BestSellPrice": 0.003,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.003,
            "Hash": "2949036644650784884",
            "HasValidPricing": true,
            "HighSalePrice": 0.003,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "NoChange",
            "LastYield": 0.0,
            "LowSalePrice": 0.003,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NL",
                "Name": "",
                "Description": "Notice Received after 4pm previous day"
              }
            ],
            "MatchVolume": 8000000,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.003,
            "OpenInterest": 0,
            "VWapPrice": 0.003,
            "TotalVolumeTraded": 8000000,
            "TotalValueTraded": 24000.0,
            "TotalNumberOfTrades": 7,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received after 4pm previous day",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "TRL",
            "LastPrice": 0.003,
            "DisplayPrice": 0.003,
            "DisplayPriceType": "Last",
            "PriceChange": 0.000,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "INVESTIGATOR RESOURCES LTD",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.019,
            "BestSellPrice": 0.02,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.019,
            "Hash": "-3213223640403246712",
            "HasValidPricing": true,
            "HighSalePrice": 0.019,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.019,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.019,
            "OpenInterest": 0,
            "VWapPrice": 0.019,
            "TotalVolumeTraded": 88000,
            "TotalValueTraded": 1672.0,
            "TotalNumberOfTrades": 1,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "IVR",
            "LastPrice": 0.019,
            "DisplayPrice": 0.019,
            "DisplayPriceType": "Last",
            "PriceChange": 0.000,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "MYER HOLDINGS LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.59,
            "BestSellPrice": 0.595,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.585,
            "Hash": "-769013487419405220",
            "HasValidPricing": true,
            "HighSalePrice": 0.595,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.585,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 14884,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.59,
            "OpenInterest": 0,
            "VWapPrice": 0.590325082224965325180322687,
            "TotalVolumeTraded": 366981,
            "TotalValueTraded": 216638.0,
            "TotalNumberOfTrades": 430,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "MYR",
            "LastPrice": 0.595,
            "DisplayPrice": 0.595,
            "DisplayPriceType": "Last",
            "PriceChange": 0.010,
            "PriceChangePercent": 0.0170940170940170940170940171,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "OOH!MEDIA LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 2.82,
            "BestSellPrice": 2.83,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 2.79,
            "Hash": "1091135174361815372",
            "HasValidPricing": true,
            "HighSalePrice": 2.84,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 2.745,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 2443,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 2.79,
            "OpenInterest": 0,
            "VWapPrice": 2.7926773132408343287696407241,
            "TotalVolumeTraded": 272075,
            "TotalValueTraded": 759817.0,
            "TotalNumberOfTrades": 1087,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "OML",
            "LastPrice": 2.825,
            "DisplayPrice": 2.825,
            "DisplayPriceType": "Last",
            "PriceChange": 0.035,
            "PriceChangePercent": 0.0125448028673835125448028674,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "PLATO INCOME MAXIMISER LIMITED.",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 1.135,
            "BestSellPrice": 1.14,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 1.14,
            "Hash": "1141747835464891116",
            "HasValidPricing": true,
            "HighSalePrice": 1.14,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 1.135,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NL",
                "Name": "",
                "Description": "Notice Received after 4pm previous day"
              }
            ],
            "MatchVolume": 10000,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 1.135,
            "OpenInterest": 0,
            "VWapPrice": 1.1394652406417112299465240642,
            "TotalVolumeTraded": 93500,
            "TotalValueTraded": 106540.0,
            "TotalNumberOfTrades": 9,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received after 4pm previous day",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "PL8",
            "LastPrice": 1.14,
            "DisplayPrice": 1.14,
            "DisplayPriceType": "Last",
            "PriceChange": 0.00,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "AUSTIN ENGINEERING LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.175,
            "BestSellPrice": 0.185,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.18,
            "Hash": "-8797128807203709381",
            "HasValidPricing": true,
            "HighSalePrice": 0.0,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.0,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.0,
            "OpenInterest": 0,
            "VWapPrice": 0.0,
            "TotalVolumeTraded": 0,
            "TotalValueTraded": 0.0,
            "TotalNumberOfTrades": 0,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Close\" class=pricetype></sup>",
            "StockCode": "ANG",
            "LastPrice": 0.0,
            "DisplayPrice": 0.18,
            "DisplayPriceType": "Close",
            "PriceChange": 0.0,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "GALENA MINING LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.335,
            "BestSellPrice": 0.34,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.35,
            "Hash": "-2539302468775520126",
            "HasValidPricing": true,
            "HighSalePrice": 0.34,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.34,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NL",
                "Name": "",
                "Description": "Notice Received after 4pm previous day"
              }
            ],
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.34,
            "OpenInterest": 0,
            "VWapPrice": 0.34,
            "TotalVolumeTraded": 50000,
            "TotalValueTraded": 17000.0,
            "TotalNumberOfTrades": 1,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received after 4pm previous day",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "G1A",
            "LastPrice": 0.34,
            "DisplayPrice": 0.34,
            "DisplayPriceType": "Last",
            "PriceChange": -0.01,
            "PriceChangePercent": -0.0285714285714285714285714286,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "NORTHERN STAR RESOURCES LTD",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 11.94,
            "BestSellPrice": 11.95,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 11.7,
            "Hash": "-177874426403466660",
            "HasValidPricing": true,
            "HighSalePrice": 11.955,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 11.645,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NR",
                "Name": "",
                "Description": "Notice Received"
              }
            ],
            "MatchVolume": 10934,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 11.75,
            "OpenInterest": 0,
            "VWapPrice": 11.837812549599637476968516163,
            "TotalVolumeTraded": 869462,
            "TotalValueTraded": 10292528.0,
            "TotalNumberOfTrades": 5366,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "NST",
            "LastPrice": 11.95,
            "DisplayPrice": 11.95,
            "DisplayPriceType": "Last",
            "PriceChange": 0.25,
            "PriceChangePercent": 0.0213675213675213675213675214,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "EVOLUTION MINING LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 4.72,
            "BestSellPrice": 4.73,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 4.61,
            "Hash": "-2707682994197843057",
            "HasValidPricing": true,
            "HighSalePrice": 4.73,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 4.61,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 25201,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 4.64,
            "OpenInterest": 0,
            "VWapPrice": 4.6881504562857046149448846734,
            "TotalVolumeTraded": 2127176,
            "TotalValueTraded": 9972521.0,
            "TotalNumberOfTrades": 3874,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "EVN",
            "LastPrice": 4.72,
            "DisplayPrice": 4.72,
            "DisplayPriceType": "Last",
            "PriceChange": 0.11,
            "PriceChangePercent": 0.0238611713665943600867678959,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "POSEIDON NICKEL LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.052,
            "BestSellPrice": 0.053,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.052,
            "Hash": "1708298179174917282",
            "HasValidPricing": true,
            "HighSalePrice": 0.053,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.052,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 25000,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.052,
            "OpenInterest": 0,
            "VWapPrice": 0.0527930431453302772704460438,
            "TotalVolumeTraded": 193277,
            "TotalValueTraded": 10203.0,
            "TotalNumberOfTrades": 9,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "POS",
            "LastPrice": 0.053,
            "DisplayPrice": 0.053,
            "DisplayPriceType": "Last",
            "PriceChange": 0.001,
            "PriceChangePercent": 0.0192307692307692307692307692,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "LYNAS CORPORATION LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 2.59,
            "BestSellPrice": 2.6,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 2.58,
            "Hash": "5815323477409564292",
            "HasValidPricing": true,
            "HighSalePrice": 2.61,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 2.57,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 56350,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 2.58,
            "OpenInterest": 0,
            "VWapPrice": 2.5883969899732389581179702304,
            "TotalVolumeTraded": 550427,
            "TotalValueTraded": 1424723.0,
            "TotalNumberOfTrades": 737,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "LYC",
            "LastPrice": 2.595,
            "DisplayPrice": 2.595,
            "DisplayPriceType": "Last",
            "PriceChange": 0.015,
            "PriceChangePercent": 0.005813953488372093023255814,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "CORE LITHIUM LTD",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.038,
            "BestSellPrice": 0.039,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.039,
            "Hash": "-601931567931919107",
            "HasValidPricing": true,
            "HighSalePrice": 0.039,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.039,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.039,
            "OpenInterest": 0,
            "VWapPrice": 0.039,
            "TotalVolumeTraded": 14262,
            "TotalValueTraded": 556.0,
            "TotalNumberOfTrades": 4,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "CXO",
            "LastPrice": 0.039,
            "DisplayPrice": 0.039,
            "DisplayPriceType": "Last",
            "PriceChange": 0.000,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "INVEX THERAPEUTICS LTD",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.605,
            "BestSellPrice": 0.65,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.62,
            "Hash": "-3989303023079041503",
            "HasValidPricing": true,
            "HighSalePrice": 0.65,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.65,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NR",
                "Name": "",
                "Description": "Notice Received"
              }
            ],
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.65,
            "OpenInterest": 0,
            "VWapPrice": 0.65,
            "TotalVolumeTraded": 295,
            "TotalValueTraded": 191.0,
            "TotalNumberOfTrades": 1,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "IXC",
            "LastPrice": 0.65,
            "DisplayPrice": 0.65,
            "DisplayPriceType": "Last",
            "PriceChange": 0.03,
            "PriceChangePercent": 0.0483870967741935483870967742,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "BOSS RESOURCES LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.062,
            "BestSellPrice": 0.063,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.063,
            "Hash": "1366091218985267227",
            "HasValidPricing": true,
            "HighSalePrice": 0.062,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.06,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 366080,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.061,
            "OpenInterest": 0,
            "VWapPrice": 0.0605061016590042329440604368,
            "TotalVolumeTraded": 1755752,
            "TotalValueTraded": 106233.0,
            "TotalNumberOfTrades": 16,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "BOE",
            "LastPrice": 0.062,
            "DisplayPrice": 0.062,
            "DisplayPriceType": "Last",
            "PriceChange": -0.001,
            "PriceChangePercent": -0.0158730158730158730158730159,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "DIMERIX LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.1,
            "BestSellPrice": 0.105,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.105,
            "Hash": "6132140907453616119",
            "HasValidPricing": true,
            "HighSalePrice": 0.0,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.0,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.0,
            "OpenInterest": 0,
            "VWapPrice": 0.0,
            "TotalVolumeTraded": 0,
            "TotalValueTraded": 0.0,
            "TotalNumberOfTrades": 0,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Close\" class=pricetype></sup>",
            "StockCode": "DXB",
            "LastPrice": 0.0,
            "DisplayPrice": 0.105,
            "DisplayPriceType": "Close",
            "PriceChange": 0.0,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "INDEPENDENCE GROUP NL",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 6.26,
            "BestSellPrice": 6.27,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 6.18,
            "Hash": "-3868116425673474113",
            "HasValidPricing": true,
            "HighSalePrice": 6.28,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 6.2,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 14571,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 6.2,
            "OpenInterest": 0,
            "VWapPrice": 6.2420702299211295000500053454,
            "TotalVolumeTraded": 579938,
            "TotalValueTraded": 3620013.0,
            "TotalNumberOfTrades": 2135,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "IGO",
            "LastPrice": 6.26,
            "DisplayPrice": 6.26,
            "DisplayPriceType": "Last",
            "PriceChange": 0.08,
            "PriceChangePercent": 0.0129449838187702265372168285,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "OM HOLDINGS LIMITED",
            "CompanyDescription": "10C ORDINARY FULLY PAID",
            "BestBuyPrice": 0.425,
            "BestSellPrice": 0.43,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.43,
            "Hash": "5102029502524695877",
            "HasValidPricing": true,
            "HighSalePrice": 0.455,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.42,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.455,
            "OpenInterest": 0,
            "VWapPrice": 0.4322558140381534876947720984,
            "TotalVolumeTraded": 274680,
            "TotalValueTraded": 118732.0,
            "TotalNumberOfTrades": 85,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "OMH",
            "LastPrice": 0.43,
            "DisplayPrice": 0.43,
            "DisplayPriceType": "Last",
            "PriceChange": 0.00,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "ALTECH CHEMICALS LTD",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.12,
            "BestSellPrice": 0.125,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.125,
            "Hash": "-2171240675619873417",
            "HasValidPricing": true,
            "HighSalePrice": 0.125,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.125,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 135755,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.125,
            "OpenInterest": 0,
            "VWapPrice": 0.125,
            "TotalVolumeTraded": 288433,
            "TotalValueTraded": 36054.0,
            "TotalNumberOfTrades": 9,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "ATC",
            "LastPrice": 0.125,
            "DisplayPrice": 0.125,
            "DisplayPriceType": "Last",
            "PriceChange": 0.000,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "AVZ MINERALS LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.043,
            "BestSellPrice": 0.044,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.043,
            "Hash": "6703477417827446100",
            "HasValidPricing": true,
            "HighSalePrice": 0.045,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.043,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 598468,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.044,
            "OpenInterest": 0,
            "VWapPrice": 0.0438049117765811824939112028,
            "TotalVolumeTraded": 1929363,
            "TotalValueTraded": 84515.0,
            "TotalNumberOfTrades": 27,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "AVZ",
            "LastPrice": 0.044,
            "DisplayPrice": 0.044,
            "DisplayPriceType": "Last",
            "PriceChange": 0.001,
            "PriceChangePercent": 0.0232558139534883720930232558,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "PARKWAY MINERALS NL",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.005,
            "BestSellPrice": 0.007,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.006,
            "Hash": "-6642544047492212554",
            "HasValidPricing": true,
            "HighSalePrice": 0.006,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.006,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.006,
            "OpenInterest": 0,
            "VWapPrice": 0.006,
            "TotalVolumeTraded": 160000,
            "TotalValueTraded": 960.0,
            "TotalNumberOfTrades": 1,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "PWN",
            "LastPrice": 0.006,
            "DisplayPrice": 0.006,
            "DisplayPriceType": "Last",
            "PriceChange": 0.000,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "ARDENT LEISURE GROUP LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.95,
            "BestSellPrice": 0.955,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.96,
            "Hash": "-6276812608888940440",
            "HasValidPricing": true,
            "HighSalePrice": 0.97,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.95,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 12025,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.97,
            "OpenInterest": 0,
            "VWapPrice": 0.9578579145355213661196584701,
            "TotalVolumeTraded": 97561,
            "TotalValueTraded": 93449.0,
            "TotalNumberOfTrades": 106,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "ALG",
            "LastPrice": 0.95,
            "DisplayPrice": 0.95,
            "DisplayPriceType": "Last",
            "PriceChange": -0.01,
            "PriceChangePercent": -0.0104166666666666666666666667,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "AUSTRALIAN FINANCE GROUP LTD",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 2.23,
            "BestSellPrice": 2.25,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 2.29,
            "Hash": "2622048637158629109",
            "HasValidPricing": true,
            "HighSalePrice": 2.29,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 2.19,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NL",
                "Name": "",
                "Description": "Notice Received after 4pm previous day"
              }
            ],
            "MatchVolume": 80,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 2.29,
            "OpenInterest": 0,
            "VWapPrice": 2.240412511332728921124206709,
            "TotalVolumeTraded": 11030,
            "TotalValueTraded": 24711.0,
            "TotalNumberOfTrades": 54,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received after 4pm previous day",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "AFG",
            "LastPrice": 2.25,
            "DisplayPrice": 2.25,
            "DisplayPriceType": "Last",
            "PriceChange": -0.04,
            "PriceChangePercent": -0.017467248908296943231441048,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "RMA GLOBAL LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.23,
            "BestSellPrice": 0.24,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.24,
            "Hash": "617121129555094986",
            "HasValidPricing": true,
            "HighSalePrice": 0.245,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.24,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.24,
            "OpenInterest": 0,
            "VWapPrice": 0.2411099474895274057466517199,
            "TotalVolumeTraded": 67796,
            "TotalValueTraded": 16346.0,
            "TotalNumberOfTrades": 4,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "RMY",
            "LastPrice": 0.24,
            "DisplayPrice": 0.24,
            "DisplayPriceType": "Last",
            "PriceChange": 0.00,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "GI DYNAMICS, INC",
            "CompanyDescription": "CHESS DEPOSITARY INTERESTS US PROHIBITED 50:1",
            "BestBuyPrice": 0.044,
            "BestSellPrice": 0.05,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.046,
            "Hash": "3662641313758939079",
            "HasValidPricing": true,
            "HighSalePrice": 0.046,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.044,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NR",
                "Name": "",
                "Description": "Notice Received"
              }
            ],
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.046,
            "OpenInterest": 0,
            "VWapPrice": 0.0447147442916585022879470718,
            "TotalVolumeTraded": 173518,
            "TotalValueTraded": 7758.0,
            "TotalNumberOfTrades": 3,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "GID",
            "LastPrice": 0.044,
            "DisplayPrice": 0.044,
            "DisplayPriceType": "Last",
            "PriceChange": -0.002,
            "PriceChangePercent": -0.0434782608695652173913043478,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "VILLA WORLD LIMITED.",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 2.33,
            "BestSellPrice": 2.34,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 2.34,
            "Hash": "1323683787176356414",
            "HasValidPricing": true,
            "HighSalePrice": 2.34,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 2.33,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 2.33,
            "OpenInterest": 0,
            "VWapPrice": 2.3343348006325056626351553485,
            "TotalVolumeTraded": 23399,
            "TotalValueTraded": 54621.0,
            "TotalNumberOfTrades": 13,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "VLW",
            "LastPrice": 2.33,
            "DisplayPrice": 2.33,
            "DisplayPriceType": "Last",
            "PriceChange": -0.01,
            "PriceChangePercent": -0.0042735042735042735042735043,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "AUSTRALIAN AGRICULTURAL COMPANY LIMITED.",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 1.005,
            "BestSellPrice": 1.01,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 1.0,
            "Hash": "-8434466692157221635",
            "HasValidPricing": true,
            "HighSalePrice": 1.01,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 1.0,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 182,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 1.0,
            "OpenInterest": 0,
            "VWapPrice": 1.0026445882269044471384608633,
            "TotalVolumeTraded": 364594,
            "TotalValueTraded": 365558.0,
            "TotalNumberOfTrades": 209,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "AAC",
            "LastPrice": 1.007,
            "DisplayPrice": 1.007,
            "DisplayPriceType": "Last",
            "PriceChange": 0.007,
            "PriceChangePercent": 0.007,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "CLEANAWAY WASTE MANAGEMENT LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 1.91,
            "BestSellPrice": 1.915,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 1.89,
            "Hash": "-1610920747835151600",
            "HasValidPricing": true,
            "HighSalePrice": 1.925,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 1.89,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 94525,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 1.905,
            "OpenInterest": 0,
            "VWapPrice": 1.9072209030969659155404471414,
            "TotalVolumeTraded": 1844741,
            "TotalValueTraded": 3518328.0,
            "TotalNumberOfTrades": 1288,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "CWY",
            "LastPrice": 1.912,
            "DisplayPrice": 1.912,
            "DisplayPriceType": "Last",
            "PriceChange": 0.022,
            "PriceChangePercent": 0.0116402116402116402116402116,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "ALLIANCE AVIATION SERVICES LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 2.32,
            "BestSellPrice": 2.33,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 2.3,
            "Hash": "2240493407908589047",
            "HasValidPricing": true,
            "HighSalePrice": 0.0,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.0,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "XD",
                "Name": "",
                "Description": "Ex Dividend"
              }
            ],
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.0,
            "OpenInterest": 0,
            "VWapPrice": 0.0,
            "TotalVolumeTraded": 0,
            "TotalValueTraded": 0.0,
            "TotalNumberOfTrades": 0,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Ex Dividend",
            "DisplayPriceTypeUi": "<sup title=\"Close\" class=pricetype></sup>",
            "StockCode": "AQZ",
            "LastPrice": 0.0,
            "DisplayPrice": 2.3,
            "DisplayPriceType": "Close",
            "PriceChange": 0.0,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "CYBG PLC",
            "CompanyDescription": "CDI 1:1 FOREIGN EXEMPT LSE",
            "BestBuyPrice": 1.94,
            "BestSellPrice": 1.945,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 2.01,
            "Hash": "-6478764235787030104",
            "HasValidPricing": true,
            "HighSalePrice": 1.985,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 1.94,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 205118,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 1.985,
            "OpenInterest": 0,
            "VWapPrice": 1.957490226987602896469454899,
            "TotalVolumeTraded": 4704486,
            "TotalValueTraded": 9208985.0,
            "TotalNumberOfTrades": 1661,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "CYB",
            "LastPrice": 1.942,
            "DisplayPrice": 1.942,
            "DisplayPriceType": "Last",
            "PriceChange": -0.068,
            "PriceChangePercent": -0.0338308457711442786069651741,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "DICKER DATA LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 7.85,
            "BestSellPrice": 7.87,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 7.86,
            "Hash": "-4220904233952810824",
            "HasValidPricing": true,
            "HighSalePrice": 7.9,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 7.66,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 6272,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 7.78,
            "OpenInterest": 0,
            "VWapPrice": 7.8560074947079352365695978031,
            "TotalVolumeTraded": 87395,
            "TotalValueTraded": 686575.0,
            "TotalNumberOfTrades": 359,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "DDR",
            "LastPrice": 7.88,
            "DisplayPrice": 7.88,
            "DisplayPriceType": "Last",
            "PriceChange": 0.02,
            "PriceChangePercent": 0.0025445292620865139949109415,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "PRESCIENT THERAPEUTICS LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.056,
            "BestSellPrice": 0.057,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.055,
            "Hash": "4310974090391045433",
            "HasValidPricing": true,
            "HighSalePrice": 0.056,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.056,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 20000,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.056,
            "OpenInterest": 0,
            "VWapPrice": 0.056,
            "TotalVolumeTraded": 515503,
            "TotalValueTraded": 28868.0,
            "TotalNumberOfTrades": 13,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "PTX",
            "LastPrice": 0.056,
            "DisplayPrice": 0.056,
            "DisplayPriceType": "Last",
            "PriceChange": 0.001,
            "PriceChangePercent": 0.0181818181818181818181818182,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "KINGSROSE MINING LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.03,
            "BestSellPrice": 0.031,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.03,
            "Hash": "-3309958163785722524",
            "HasValidPricing": true,
            "HighSalePrice": 0.03,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Unknown",
            "LastYield": 0.0,
            "LowSalePrice": 0.03,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.03,
            "OpenInterest": 0,
            "VWapPrice": 0.03,
            "TotalVolumeTraded": 8955,
            "TotalValueTraded": 268.0,
            "TotalNumberOfTrades": 1,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "KRM",
            "LastPrice": 0.03,
            "DisplayPrice": 0.03,
            "DisplayPriceType": "Last",
            "PriceChange": 0.00,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "ALTIUM LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 32.29,
            "BestSellPrice": 32.31,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 32.34,
            "Hash": "1755026517502272171",
            "HasValidPricing": true,
            "HighSalePrice": 32.65,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 32.04,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 4027,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 32.4,
            "OpenInterest": 0,
            "VWapPrice": 32.328938314553274844885494773,
            "TotalVolumeTraded": 216453,
            "TotalValueTraded": 6997695.0,
            "TotalNumberOfTrades": 5090,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "ALU",
            "LastPrice": 32.31,
            "DisplayPrice": 32.31,
            "DisplayPriceType": "Last",
            "PriceChange": -0.03,
            "PriceChangePercent": -0.0009276437847866419294990724,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "JUPITER MINES LIMITED.",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.375,
            "BestSellPrice": 0.38,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.375,
            "Hash": "4040182992335641029",
            "HasValidPricing": true,
            "HighSalePrice": 0.38,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.375,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 143900,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.375,
            "OpenInterest": 0,
            "VWapPrice": 0.3762043488979655234381561207,
            "TotalVolumeTraded": 1107361,
            "TotalValueTraded": 416594.0,
            "TotalNumberOfTrades": 113,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "JMS",
            "LastPrice": 0.38,
            "DisplayPrice": 0.38,
            "DisplayPriceType": "Last",
            "PriceChange": 0.005,
            "PriceChangePercent": 0.0133333333333333333333333333,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "GRAPHEX MINING LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.175,
            "BestSellPrice": 0.18,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.17,
            "Hash": "2871055791047068334",
            "HasValidPricing": true,
            "HighSalePrice": 0.18,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.175,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 10000,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.18,
            "OpenInterest": 0,
            "VWapPrice": 0.1798971596474045053868756121,
            "TotalVolumeTraded": 10210,
            "TotalValueTraded": 1836.0,
            "TotalNumberOfTrades": 3,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "GPX",
            "LastPrice": 0.175,
            "DisplayPrice": 0.175,
            "DisplayPriceType": "Last",
            "PriceChange": 0.005,
            "PriceChangePercent": 0.0294117647058823529411764706,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "ONCOSIL MEDICAL LTD",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.067,
            "BestSellPrice": 0.069,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.068,
            "Hash": "3229537441635282958",
            "HasValidPricing": true,
            "HighSalePrice": 0.069,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.067,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 9285,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.069,
            "OpenInterest": 0,
            "VWapPrice": 0.0688830862794721483356144927,
            "TotalVolumeTraded": 309784,
            "TotalValueTraded": 21338.0,
            "TotalNumberOfTrades": 13,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "OSL",
            "LastPrice": 0.069,
            "DisplayPrice": 0.069,
            "DisplayPriceType": "Last",
            "PriceChange": 0.001,
            "PriceChangePercent": 0.0147058823529411764705882353,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "TROY RESOURCES LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.115,
            "BestSellPrice": 0.12,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.12,
            "Hash": "-6089769140924580862",
            "HasValidPricing": true,
            "HighSalePrice": 0.12,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.115,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 5000,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.115,
            "OpenInterest": 0,
            "VWapPrice": 0.1152751089947019024225140663,
            "TotalVolumeTraded": 298409,
            "TotalValueTraded": 34399.0,
            "TotalNumberOfTrades": 19,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "TRY",
            "LastPrice": 0.12,
            "DisplayPrice": 0.12,
            "DisplayPriceType": "Last",
            "PriceChange": 0.00,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "LINCOLN MINERALS LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.006,
            "BestSellPrice": 0.007,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.006,
            "Hash": "-9175643810287638136",
            "HasValidPricing": true,
            "HighSalePrice": 0.0,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.0,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.0,
            "OpenInterest": 0,
            "VWapPrice": 0.0,
            "TotalVolumeTraded": 0,
            "TotalValueTraded": 0.0,
            "TotalNumberOfTrades": 0,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Close\" class=pricetype></sup>",
            "StockCode": "LML",
            "LastPrice": 0.0,
            "DisplayPrice": 0.006,
            "DisplayPriceType": "Close",
            "PriceChange": 0.0,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "MARQUEE RESOURCES LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.075,
            "BestSellPrice": 0.079,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.075,
            "Hash": "-6264137837806372309",
            "HasValidPricing": true,
            "HighSalePrice": 0.0,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.0,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.0,
            "OpenInterest": 0,
            "VWapPrice": 0.0,
            "TotalVolumeTraded": 0,
            "TotalValueTraded": 0.0,
            "TotalNumberOfTrades": 0,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Close\" class=pricetype></sup>",
            "StockCode": "MQR",
            "LastPrice": 0.0,
            "DisplayPrice": 0.075,
            "DisplayPriceType": "Close",
            "PriceChange": 0.0,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "LEGEND MINING LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.036,
            "BestSellPrice": 0.037,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.036,
            "Hash": "-3288996497171705942",
            "HasValidPricing": true,
            "HighSalePrice": 0.036,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.036,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.036,
            "OpenInterest": 0,
            "VWapPrice": 0.036,
            "TotalVolumeTraded": 55536,
            "TotalValueTraded": 1999.0,
            "TotalNumberOfTrades": 1,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "LEG",
            "LastPrice": 0.036,
            "DisplayPrice": 0.036,
            "DisplayPriceType": "Last",
            "PriceChange": 0.000,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "FLUENCE CORPORATION LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.52,
            "BestSellPrice": 0.525,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.525,
            "Hash": "-9038973476884942287",
            "HasValidPricing": true,
            "HighSalePrice": 0.54,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Down",
            "LastYield": 0.0,
            "LowSalePrice": 0.52,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 8200,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.535,
            "OpenInterest": 0,
            "VWapPrice": 0.530296584433113377324535093,
            "TotalVolumeTraded": 266720,
            "TotalValueTraded": 141440.0,
            "TotalNumberOfTrades": 37,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "FLC",
            "LastPrice": 0.52,
            "DisplayPrice": 0.52,
            "DisplayPriceType": "Last",
            "PriceChange": -0.005,
            "PriceChangePercent": -0.0095238095238095238095238095,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "MUSGRAVE MINERALS LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.075,
            "BestSellPrice": 0.078,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.074,
            "Hash": "984697759739871517",
            "HasValidPricing": true,
            "HighSalePrice": 0.078,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.074,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.074,
            "OpenInterest": 0,
            "VWapPrice": 0.0749464926315263177630838844,
            "TotalVolumeTraded": 320012,
            "TotalValueTraded": 23983.0,
            "TotalNumberOfTrades": 8,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "MGV",
            "LastPrice": 0.078,
            "DisplayPrice": 0.078,
            "DisplayPriceType": "Last",
            "PriceChange": 0.004,
            "PriceChangePercent": 0.0540540540540540540540540541,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "LIONTOWN RESOURCES LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.09,
            "BestSellPrice": 0.093,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.095,
            "Hash": "-5532714060453792352",
            "HasValidPricing": true,
            "HighSalePrice": 0.095,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.09,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 13529,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.095,
            "OpenInterest": 0,
            "VWapPrice": 0.0913782296148221859992987909,
            "TotalVolumeTraded": 5008492,
            "TotalValueTraded": 457667.0,
            "TotalNumberOfTrades": 95,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "LTR",
            "LastPrice": 0.091,
            "DisplayPrice": 0.091,
            "DisplayPriceType": "Last",
            "PriceChange": -0.004,
            "PriceChangePercent": -0.0421052631578947368421052632,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "AMPLIA THERAPEUTICS LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.082,
            "BestSellPrice": 0.091,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.09,
            "Hash": "9042231449465276644",
            "HasValidPricing": true,
            "HighSalePrice": 0.09,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.09,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.09,
            "OpenInterest": 0,
            "VWapPrice": 0.09,
            "TotalVolumeTraded": 5000,
            "TotalValueTraded": 450.0,
            "TotalNumberOfTrades": 1,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "ATX",
            "LastPrice": 0.09,
            "DisplayPrice": 0.09,
            "DisplayPriceType": "Last",
            "PriceChange": 0.00,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "RENASCOR RESOURCES LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.014,
            "BestSellPrice": 0.015,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.014,
            "Hash": "-8818058360182289872",
            "HasValidPricing": true,
            "HighSalePrice": 0.0,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.0,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.0,
            "OpenInterest": 0,
            "VWapPrice": 0.0,
            "TotalVolumeTraded": 0,
            "TotalValueTraded": 0.0,
            "TotalNumberOfTrades": 0,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Close\" class=pricetype></sup>",
            "StockCode": "RNU",
            "LastPrice": 0.0,
            "DisplayPrice": 0.014,
            "DisplayPriceType": "Close",
            "PriceChange": 0.0,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "DATA#3 LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 3.06,
            "BestSellPrice": 3.08,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 3.0,
            "Hash": "-7422079304075702132",
            "HasValidPricing": true,
            "HighSalePrice": 3.13,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 3.06,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 4056,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 3.1,
            "OpenInterest": 0,
            "VWapPrice": 3.0733203250380434908106785019,
            "TotalVolumeTraded": 433057,
            "TotalValueTraded": 1330922.0,
            "TotalNumberOfTrades": 121,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "DTL",
            "LastPrice": 3.08,
            "DisplayPrice": 3.08,
            "DisplayPriceType": "Last",
            "PriceChange": 0.08,
            "PriceChangePercent": 0.0266666666666666666666666667,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "INTIGER GROUP LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.001,
            "BestSellPrice": 0.002,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.001,
            "Hash": "8170760195309094048",
            "HasValidPricing": true,
            "HighSalePrice": 0.001,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.001,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.001,
            "OpenInterest": 0,
            "VWapPrice": 0.001,
            "TotalVolumeTraded": 1000000,
            "TotalValueTraded": 1000.0,
            "TotalNumberOfTrades": 2,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "IAM",
            "LastPrice": 0.001,
            "DisplayPrice": 0.001,
            "DisplayPriceType": "Last",
            "PriceChange": 0.000,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "CROPLOGIC LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.06,
            "BestSellPrice": 0.061,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.062,
            "Hash": "9053738612142577396",
            "HasValidPricing": true,
            "HighSalePrice": 0.067,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.06,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NR",
                "Name": "",
                "Description": "Notice Received"
              }
            ],
            "MatchVolume": 1083250,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.062,
            "OpenInterest": 0,
            "VWapPrice": 0.0636536119036596379146167554,
            "TotalVolumeTraded": 11396428,
            "TotalValueTraded": 725423.0,
            "TotalNumberOfTrades": 256,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "CLI",
            "LastPrice": 0.061,
            "DisplayPrice": 0.061,
            "DisplayPriceType": "Last",
            "PriceChange": -0.001,
            "PriceChangePercent": -0.0161290322580645161290322581,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "SPHERIA EMERGING COMPANIES LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 1.69,
            "BestSellPrice": 1.7,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 1.7,
            "Hash": "8723916141000721033",
            "HasValidPricing": true,
            "HighSalePrice": 1.7,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 1.69,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NL",
                "Name": "",
                "Description": "Notice Received after 4pm previous day"
              },
              {
                "Code": "NR",
                "Name": "",
                "Description": "Notice Received"
              }
            ],
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 1.7,
            "OpenInterest": 0,
            "VWapPrice": 1.6973382374292213134588394715,
            "TotalVolumeTraded": 20663,
            "TotalValueTraded": 35072.0,
            "TotalNumberOfTrades": 5,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received after 4pm previous day, Notice Received",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "SEC",
            "LastPrice": 1.69,
            "DisplayPrice": 1.69,
            "DisplayPriceType": "Last",
            "PriceChange": -0.01,
            "PriceChangePercent": -0.0058823529411764705882352941,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "FORAGER AUSTRALIAN SHARES FUND",
            "CompanyDescription": "ORDINARY UNITS FULLY PAID",
            "BestBuyPrice": 1.2,
            "BestSellPrice": 1.215,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 1.215,
            "Hash": "2122900060220693077",
            "HasValidPricing": true,
            "HighSalePrice": 1.215,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 1.215,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NR",
                "Name": "",
                "Description": "Notice Received"
              }
            ],
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 1.215,
            "OpenInterest": 0,
            "VWapPrice": 1.215,
            "TotalVolumeTraded": 13499,
            "TotalValueTraded": 16401.0,
            "TotalNumberOfTrades": 2,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "FOR",
            "LastPrice": 1.215,
            "DisplayPrice": 1.215,
            "DisplayPriceType": "Last",
            "PriceChange": 0.000,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "COBALT BLUE HOLDINGS LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.14,
            "BestSellPrice": 0.145,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.14,
            "Hash": "1262276769271748439",
            "HasValidPricing": true,
            "HighSalePrice": 0.145,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "NoChange",
            "LastYield": 0.0,
            "LowSalePrice": 0.145,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 50000,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.145,
            "OpenInterest": 0,
            "VWapPrice": 0.145,
            "TotalVolumeTraded": 53290,
            "TotalValueTraded": 7727.0,
            "TotalNumberOfTrades": 4,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "COB",
            "LastPrice": 0.145,
            "DisplayPrice": 0.145,
            "DisplayPriceType": "Last",
            "PriceChange": 0.005,
            "PriceChangePercent": 0.0357142857142857142857142857,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "ZETA RESOURCES LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.0,
            "BestSellPrice": 0.0,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.335,
            "Hash": "-5148785756966614913",
            "HasValidPricing": true,
            "HighSalePrice": 0.0,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.0,
            "StockStatus": {
              "Code": "Suspend",
              "Name": "",
              "Description": "Suspend"
            },
            "CorporateActions": [
              {
                "Code": "SU",
                "Name": "",
                "Description": "Suspended"
              },
              {
                "Code": "NR",
                "Name": "",
                "Description": "Notice Received"
              }
            ],
            "MatchVolume": 0,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.0,
            "OpenInterest": 0,
            "VWapPrice": 0.0,
            "TotalVolumeTraded": 0,
            "TotalValueTraded": 0.0,
            "TotalNumberOfTrades": 0,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Suspend, Suspended, Notice Received",
            "DisplayPriceTypeUi": "<sup title=\"Close\" class=pricetype></sup>",
            "StockCode": "ZER",
            "LastPrice": 0.0,
            "DisplayPrice": 0.335,
            "DisplayPriceType": "Close",
            "PriceChange": 0.0,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "IMMUTEP LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.025,
            "BestSellPrice": 0.026,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.026,
            "Hash": "-7138091680202097828",
            "HasValidPricing": true,
            "HighSalePrice": 0.026,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 0.025,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": [
              {
                "Code": "NL",
                "Name": "",
                "Description": "Notice Received after 4pm previous day"
              }
            ],
            "MatchVolume": 138807,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.025,
            "OpenInterest": 0,
            "VWapPrice": 0.0258960371978905947452001674,
            "TotalVolumeTraded": 769506,
            "TotalValueTraded": 19927.0,
            "TotalNumberOfTrades": 13,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open, Notice Received after 4pm previous day",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "IMM",
            "LastPrice": 0.026,
            "DisplayPrice": 0.026,
            "DisplayPriceType": "Last",
            "PriceChange": 0.000,
            "PriceChangePercent": 0.0,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:06",
            "QuoteTimeUi": "07 Oct 13:55:06",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "POLYNOVO LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 2.21,
            "BestSellPrice": 2.22,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 2.17,
            "Hash": "4267686313832568751",
            "HasValidPricing": true,
            "HighSalePrice": 2.22,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 2.15,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 17719,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 2.15,
            "OpenInterest": 0,
            "VWapPrice": 2.1891331227275967776431168461,
            "TotalVolumeTraded": 448864,
            "TotalValueTraded": 982623.0,
            "TotalNumberOfTrades": 793,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "PNV",
            "LastPrice": 2.21,
            "DisplayPrice": 2.21,
            "DisplayPriceType": "Last",
            "PriceChange": 0.04,
            "PriceChangePercent": 0.0184331797235023041474654378,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:05",
            "QuoteTimeUi": "07 Oct 13:55:05",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "AVITA MEDICAL LTD",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 0.55,
            "BestSellPrice": 0.555,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 0.535,
            "Hash": "-131555072267911394",
            "HasValidPricing": true,
            "HighSalePrice": 0.56,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "NoChange",
            "LastYield": 0.0,
            "LowSalePrice": 0.53,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 271561,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 0.53,
            "OpenInterest": 0,
            "VWapPrice": 0.5458832104885800188785026305,
            "TotalVolumeTraded": 2379426,
            "TotalValueTraded": 1298888.0,
            "TotalNumberOfTrades": 1265,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "AVH",
            "LastPrice": 0.552,
            "DisplayPrice": 0.552,
            "DisplayPriceType": "Last",
            "PriceChange": 0.017,
            "PriceChangePercent": 0.0317757009345794392523364486,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:05",
            "QuoteTimeUi": "07 Oct 13:55:05",
            "SecurityCategory": "Equity"
          },
          {
            "ExchangeId": "XASX",
            "CurrencyCode": "AUD",
            "CountryIsoCode": "AUS",
            "ContractSize": 1.0,
            "UnderlyingSecurityCategory": "Equity",
            "CompanyName": "MEGAPORT LIMITED",
            "CompanyDescription": "ORDINARY FULLY PAID",
            "BestBuyPrice": 9.09,
            "BestSellPrice": 9.11,
            "Bids": 0,
            "BidsTotalVolume": 0,
            "ClosingPrice": 9.1,
            "Hash": "749151949757363260",
            "HasValidPricing": true,
            "HighSalePrice": 9.55,
            "IndicativePrice": 0.0,
            "LastPriceMovement": "Up",
            "LastYield": 0.0,
            "LowSalePrice": 9.04,
            "StockStatus": {
              "Code": "Open",
              "Name": "",
              "Description": "Open"
            },
            "CorporateActions": null,
            "MatchVolume": 1244,
            "MidPrice": 0.0,
            "Offers": 0,
            "OffersTotalVolume": 0,
            "OpeningPrice": 9.2,
            "OpenInterest": 0,
            "VWapPrice": 9.234417042398097737815257078,
            "TotalVolumeTraded": 76961,
            "TotalValueTraded": 710689.0,
            "TotalNumberOfTrades": 769,
            "SurplusVolume": 0,
            "IsTradeable": true,
            "BrokerageScript": null,
            "StatusUi": "Open",
            "DisplayPriceTypeUi": "<sup title=\"Last\" class=pricetype></sup>",
            "StockCode": "MP1",
            "LastPrice": 9.09,
            "DisplayPrice": 9.09,
            "DisplayPriceType": "Last",
            "PriceChange": -0.01,
            "PriceChangePercent": -0.0010989010989010989010989011,
            "DecimalPrecisionForDisplay": 3,
            "Delayed": false,
            "QuoteTime": "2019-10-07T13:55:05",
            "QuoteTimeUi": "07 Oct 13:55:05",
            "SecurityCategory": "Equity"
          }
        ],
        "CodesNoData": [
          "QBL",
          "AGO",
          "KDR"
        ],
        "FxRates": {
          
        },
        "SecurityExcludeRuleResults": {
          
        },
        "_Et": 19.0
      }
    }
  ],
  "Date": "2019-10-07T13:55:06",
  "PollFreqMin": 1500,
  "Et": 24
}
'

		insert into StockData.RawData
		(
			DataTypeID,
			RawData,
			CreateDate,
			SourceSystemDate
		)
		select
			60 as DataTypeID,
			@pvchPriceSummaryJson as RawData,
			getdate() as CreateDate,
			getdate() as SourceSystemDate

		select 
			--EvId, PackageStatus, Responses, Response.TId, Quotes, Quote.ExchangeId, 
			Quote.StockCode, 
			Quote.LastPrice, 
			Quote.BestBuyPrice,
			Quote.BestSellPrice, 
			Quote.HighSalePrice, 
			Quote.LowSalePrice,
			Quote.TotalVolumeTraded,
			Quote.TotalValueTraded,
			Quote.TotalNumberOfTrades,
			Quote.VWapPrice,
			Quote.PriceChange,
			Quote.PriceChangePercent,
			Quote.Bids,
			Quote.BidsTotalVolume,
			Quote.Offers,
			Quote.OffersTotalVolume,
			Quote.QuoteTime,
			Quote.SurplusVolume,
			Quote.ClosingPrice,
			Quote.OpeningPrice,
			Quote.IndicativePrice
		into #TempPriceSummaryRaw
		from openjson (@pvchPriceSummaryJson)
		with
		(
			EvId varchar(100),
			Success varchar(100),
			PackageStatus varchar(100),
			Responses nvarchar(max) AS JSON,
			Date varchar(100),
			PollFreqMin int,
			Et varchar(100)
		) as FullJson
		cross apply openjson (FullJson.Responses)
		with
		(
			TId varchar(100),
			Model nvarchar(max) as Json
		) as Response
		cross apply openjson (Response.Model) 
		with
		(
			Quotes nvarchar(max) as Json
		) as Quotes
		cross apply openjson(Quotes.Quotes)
		with
		(
			ExchangeId varchar(100),
			StockCode varchar(100),
			LastPrice varchar(100),
			BestBuyPrice varchar(100),
			BestSellPrice varchar(100),
			HighSalePrice varchar(100),
			LowSalePrice varchar(100),
			TotalVolumeTraded varchar(100),
			TotalValueTraded varchar(100),
			TotalNumberOfTrades varchar(100),
			VWapPrice varchar(100),
			PriceChange varchar(100),
			PriceChangePercent varchar(100),
			Bids varchar(100),
			BidsTotalVolume varchar(100),
			Offers varchar(100),
			OffersTotalVolume varchar(100),
			QuoteTime varchar(100),
			SurplusVolume varchar(100),
			ClosingPrice varchar(100),
			OpeningPrice varchar(100),
			IndicativePrice varchar(100)
		) as Quote

		insert into Working.PriceSummaryRaw
		(
		   [StockCode]
		  ,[LastPrice]
		  ,[BestBuyPrice]
		  ,[BestSellPrice]
		  ,[HighSalePrice]
		  ,[LowSalePrice]
		  ,[TotalVolumeTraded]
		  ,[TotalValueTraded]
		  ,[TotalNumberOfTrades]
		  ,[VWapPrice]
		  ,[PriceChange]
		  ,[PriceChangePercent]
		  ,[Bids]
		  ,[BidsTotalVolume]
		  ,[Offers]
		  ,[OffersTotalVolume]
		  ,[QuoteTime]
		  ,[SurplusVolume]
		  ,[ClosingPrice]
		  ,[OpeningPrice]
		  ,[IndicativePrice]
		)
		select
		   [StockCode]
		  ,[LastPrice]
		  ,[BestBuyPrice]
		  ,[BestSellPrice]
		  ,[HighSalePrice]
		  ,[LowSalePrice]
		  ,[TotalVolumeTraded]
		  ,[TotalValueTraded]
		  ,[TotalNumberOfTrades]
		  ,[VWapPrice]
		  ,[PriceChange]
		  ,[PriceChangePercent]
		  ,[Bids]
		  ,[BidsTotalVolume]
		  ,[Offers]
		  ,[OffersTotalVolume]
		  ,[QuoteTime]
		  ,[SurplusVolume]
		  ,[ClosingPrice]
		  ,[OpeningPrice]
		  ,[IndicativePrice]
		from #TempPriceSummaryRaw

		set dateformat ymd
		
		if object_id(N'Tempdb.dbo.#TempPriceSummary') is not null
			drop table #TempPriceSummary

		select
			StockCode + '.AX' as ASXCode,
			cast(BestBuyPrice as decimal(20, 4)) as Bid,
			cast(BestSellPrice as decimal(20, 4)) as Offer,
			cast(OpeningPrice as decimal(20, 4)) as [Open],
			cast(HighSalePrice as decimal(20, 4)) as High,
			cast(LowSalePrice as decimal(20, 4)) as Low,
			case when try_cast(LastPrice as decimal(20, 4)) = 0 then try_cast(ClosingPrice as decimal(20, 4)) else try_cast(LastPrice as decimal(20, 4)) end as [Close],
			cast(TotalVolumeTraded as bigint) as Volume,
			cast(TotalValueTraded as decimal(20, 4)) as Value,
			cast(TotalNumberOfTrades as int) as Trades,
			cast(VWapPrice as decimal(20, 4)) as VWAP,
			convert(datetime, substring(QuoteTime, 1, 10) + ' ' + right(QuoteTime, 8), 121) as QuoteTime,
			cast(Bids as decimal(20, 4)) as bids,
			cast(BidsTotalVolume as bigint) as bidsTotalVolume,
			cast(Offers as decimal(20, 4)) as offers,
			cast(OffersTotalVolume as bigint) as offersTotalVolume,
			cast(IndicativePrice as decimal(20, 4)) as IndicativePrice,
			cast(SurplusVolume as int) as SurplusVolume,
			cast(ClosingPrice as decimal(20, 4)) as PrevClose
		into #TempPriceSummary
		from #TempPriceSummaryRaw

		if 
		(
			1 = 0
		)
		begin
			print 'Aggregation Auction Time'
		end
		else
		begin

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = c.[Close]
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Close] > 0
			and c.[Close] <= a.AlertPrice
			where a.TradingAlertTypeID = 1
			and AlertTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)
			
			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = c.[Close]
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Close] > 0
			and c.[Close] >= a.AlertPrice
			where a.TradingAlertTypeID = 2
			and AlertTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = c.Bid
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Bid] > 0
			and c.[Bid] >= a.AlertPrice
			where a.TradingAlertTypeID = 3
			and AlertTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)

			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualPrice = c.[Offer]
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Offer] > 0
			and c.[Offer] <= a.AlertPrice
			where a.TradingAlertTypeID = 4
			and AlertTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)
			
			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualVolume = c.Volume
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Volume] > 0
			and c.[Volume] >= a.AlertVolume
			where a.TradingAlertTypeID = 5
			and AlertTriggerDate is null
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)
			
			update a
			set a.AlertTriggerDate = getdate(),
				a.ActualVolume = c.Volume
			from [Alert].[v_TradingAlert] as a
			inner join LookupRef.TradingAlertType as b
			on a.TradingAlertTypeID = b.TradingAlertTypeID
			inner join #TempPriceSummary as c
			on a.ASXCode = c.ASXCode
			and c.[Volume] > 0
			and c.[Volume] < a.AlertVolume
			where a.TradingAlertTypeID = 6
			and AlertTriggerDate is null
			and cast(getdate() as time) > cast('15:40:00' as time)
			and cast(getdate() as time) < cast('15:55:00' as time)
			and not
			(
				left(c.ASXCode, 1) in ('A', 'B') and cast(QuoteTime as time) <= cast('10:00:15' as time)
				or
				left(c.ASXCode, 1) in ('C', 'D', 'E', 'F') and cast(QuoteTime as time) <= cast('10:02:30' as time)
				or
				left(c.ASXCode, 1) in ('G', 'H', 'I', 'J', 'K', 'L', 'M') and cast(QuoteTime as time) <= cast('10:04:45' as time)
				or
				left(c.ASXCode, 1) in ('N', 'O', 'P', 'Q', 'R') and cast(QuoteTime as time) <= cast('10:07:00' as time)
				or
				left(c.ASXCode, 1) in ('S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z') and cast(QuoteTime as time) <= cast('10:09:15' as time)
				or 
				cast(QuoteTime as time) >= cast('16:00:00' as time)
				or
				Offer <= Bid
			)
			
		end

		update a
		set a.DateTo = b.QuoteTime
		from StockData.PriceSummaryToday as a
		inner join #TempPriceSummary as b
		on a.ASXCode = b.ASXCode
		and cast(a.DateFrom as date) = cast(b.QuoteTime as date)
		left join #TempPriceSummary as c
		on a.ASXCode = c.ASXCode
		and cast(a.DateFrom as date) = cast(c.QuoteTime as date)
		and isnull(a.Bid, -1) = isnull(c.Bid, -1)
		and isnull(a.Offer, -1) = isnull(c.Offer, -1)
		and isnull(a.[Open], -1) = isnull(c.[Open], -1)
		and isnull(a.[High], -1) = isnull(c.[High], -1)
		and isnull(a.Low, -1) = isnull(c.Low, -1)
		and isnull(a.[Close], -1) = isnull(c.[Close], -1)
		and isnull(a.Volume, -1) = isnull(c.Volume, -1)
		and isnull(a.Value, -1) = isnull(c.Value, -1)
		and isnull(a.Trades, -1) = isnull(c.Trades, -1)
		--and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
		--and isnull(a.bids, -1) = isnull(c.bids, -1)
		--and isnull(a.bidsTotalVolume, -1) = isnull(c.bidsTotalVolume, -1)
		--and isnull(a.offers, -1) = isnull(c.offers, -1)
		--and isnull(a.offersTotalVolume, -1) = isnull(c.offersTotalVolume, -1)
		and isnull(a.IndicativePrice, -1) = isnull(c.IndicativePrice, -1)
		and isnull(a.SurplusVolume, -1) = isnull(c.SurplusVolume, -1)
		where a.DateTo is null
		and c.ASXCode is null
		
		update a
		set a.LastVerifiedDate = c.QuoteTime,
			a.VWAP = c.VWAP
		from StockData.PriceSummaryToday as a
		inner join #TempPriceSummary as c
		on a.ASXCode = c.ASXCode
		and cast(a.DateFrom as date) = cast(c.QuoteTime as date)
		and isnull(a.Bid, -1) = isnull(c.Bid, -1)
		and isnull(a.Offer, -1) = isnull(c.Offer, -1)
		and isnull(a.[Open], -1) = isnull(c.[Open], -1)
		and isnull(a.[High], -1) = isnull(c.[High], -1)
		and isnull(a.Low, -1) = isnull(c.Low, -1)
		and isnull(a.[Close], -1) = isnull(c.[Close], -1)
		and isnull(a.Volume, -1) = isnull(c.Volume, -1)
		and isnull(a.Value, -1) = isnull(c.Value, -1)
		and isnull(a.Trades, -1) = isnull(c.Trades, -1)
		--and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
		--and isnull(a.bids, -1) = isnull(c.bids, -1)
		--and isnull(a.bidsTotalVolume, -1) = isnull(c.bidsTotalVolume, -1)
		--and isnull(a.offers, -1) = isnull(c.offers, -1)
		--and isnull(a.offersTotalVolume, -1) = isnull(c.offersTotalVolume, -1)
		and isnull(a.IndicativePrice, -1) = isnull(c.IndicativePrice, -1)
		and isnull(a.SurplusVolume, -1) = isnull(c.SurplusVolume, -1)
		where a.DateTo is null
		and isnull(a.LastVerifiedDate, '2050-01-12') != c.QuoteTime
		
		update c
		set c.LatestForTheDay = 0
		from StockData.PriceSummaryToday as c
		inner join #TempPriceSummary as b
		on c.ASXCode = b.ASXCode
		and cast(c.DateFrom as date) = cast(b.QuoteTime as date)
		where c.ObservationDate = cast(getdate() as date)
		and c.LatestForTheDay = 1
		and not exists
		(
			select 1
			from #TempPriceSummary as a
			where ASXCode = a.ASXCode
			and cast(a.QuoteTime as date) = cast(c.DateFrom as date)
			and isnull(a.Bid, -1) = isnull(c.Bid, -1)
			and isnull(a.Offer, -1) = isnull(c.Offer, -1)
			and isnull(a.[Open], -1) = isnull(c.[Open], -1)
			and isnull(a.[High], -1) = isnull(c.[High], -1)
			and isnull(a.Low, -1) = isnull(c.Low, -1)
			and isnull(a.[Close], -1) = isnull(c.[Close], -1)
			and isnull(a.Volume, -1) = isnull(c.Volume, -1)
			and isnull(a.Value, -1) = isnull(c.Value, -1)
			and isnull(a.Trades, -1) = isnull(c.Trades, -1)
			--and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
			--and isnull(a.bids, -1) = isnull(c.bids, -1)
			--and isnull(a.bidsTotalVolume, -1) = isnull(c.bidsTotalVolume, -1)
			--and isnull(a.offers, -1) = isnull(c.offers, -1)
			--and isnull(a.offersTotalVolume, -1) = isnull(c.offersTotalVolume, -1)
			and isnull(a.IndicativePrice, -1) = isnull(c.IndicativePrice, -1)
			and isnull(a.SurplusVolume, -1) = isnull(c.SurplusVolume, -1)
		)
		and c.DateTo is null

		insert into StockData.PriceSummaryToday
		(
			 [ASXCode]
			,[Bid]
			,[Offer]
			,[Open]
			,[High]
			,[Low]
			,[Close]
			,[Volume]
			,[Value]
			,[Trades]
			,[VWAP]
			,[DateFrom]
			,[DateTo]
			,LastVerifiedDate
			,bids
			,bidsTotalVolume
			,offers
			,offersTotalVolume
			,IndicativePrice
			,SurplusVolume
			,PrevClose
			,SysCreateDate
			,ObservationDate
			,LatestForTheDay
		)
		select
			[ASXCode]
			,[Bid]
			,[Offer]
			,[Open]
			,[High]
			,[Low]
			,[Close]
			,[Volume]
			,[Value]
			,[Trades]
			,[VWAP]
			,QuoteTime as [DateFrom]
			,null as [DateTo]
			,QuoteTime as LastVerifiedDate
			,bids
			,bidsTotalVolume
			,offers
			,offersTotalVolume
			,IndicativePrice
			,SurplusVolume
			,PrevClose
			,getdate() as SysCreateDate
			,cast(QuoteTime as date) as ObservationDate
			,1 as LatestForTheDay
		from #TempPriceSummary as a
		where not exists
		(
			select 1
			from StockData.PriceSummaryToday as c
			where a.ASXCode = c.ASXCode
			and cast(a.QuoteTime as date) = c.ObservationDate
			and isnull(a.Bid, -1) = isnull(c.Bid, -1)
			and isnull(a.Offer, -1) = isnull(c.Offer, -1)
			and isnull(a.[Open], -1) = isnull(c.[Open], -1)
			and isnull(a.[High], -1) = isnull(c.[High], -1)
			and isnull(a.Low, -1) = isnull(c.Low, -1)
			and isnull(a.[Close], -1) = isnull(c.[Close], -1)
			and isnull(a.Volume, -1) = isnull(c.Volume, -1)
			and isnull(a.Value, -1) = isnull(c.Value, -1)
			and isnull(a.Trades, -1) = isnull(c.Trades, -1)
			--and isnull(a.VWAP, -1) = isnull(c.VWAP, -1)
			--and isnull(a.bids, -1) = isnull(c.bids, -1)
			--and isnull(a.bidsTotalVolume, -1) = isnull(c.bidsTotalVolume, -1)
			--and isnull(a.offers, -1) = isnull(c.offers, -1)
			--and isnull(a.offersTotalVolume, -1) = isnull(c.offersTotalVolume, -1)
			and isnull(a.IndicativePrice, -1) = isnull(c.IndicativePrice, -1)
			and isnull(a.SurplusVolume, -1) = isnull(c.SurplusVolume, -1)
			and c.DateTo is null
		) 
		--and not exists
		--(
		--	select 1
		--	from StockData.PriceSummaryToday as c
		--	where cast(a.QuoteTime as date) = c.ObservationDate
		--	and c.ASXCode = a.ASXCode
		--	and c.[Volume] > a.[Volume]
		--)

		update x
		set x.SysLastSaleDate = y.SysLastSaleDate
		from StockData.PriceSummaryToday as x
		inner join
		(
			select
				a.ASXCode,
				a.Volume,
				min(a.SysCreateDate) as SysLastSaleDate
			from StockData.PriceSummaryToday as a
			where cast(a.DateFrom as date) = cast(getdate() as date)
			and exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
			)
			group by
				a.ASXCode,
				a.Volume
		) as y
		on x.ASXCode = y.ASXCode
		and x.Volume = y.Volume

		update x
		set x.Prev1PriceSummaryID = y.Prev1PriceSummaryID
		from StockData.PriceSummaryToday as x
		inner join
		(
			select
				a.ASXCode,
				a.DateFrom,
				max(b.PriceSummaryID) as Prev1PriceSummaryID
			from StockData.PriceSummaryToday as a
			inner join StockData.PriceSummaryToday as b
			on cast(a.DateFrom as date) = cast(getdate() as date)
			and a.ASXCode = b.ASXCode
			and a.DateFrom > b.DateFrom
			and exists
			(
				select 1
				from #TempPriceSummary
				where ASXCode = a.ASXCode
			)
			and a.DateTo is null
			group by a.ASXCode, a.DateFrom
		) as y
		on x.ASXCode = y.ASXCode
		and x.DateFrom = y.DateFrom

		update x
		set x.Prev1Bid = y.Bid,
			x.Prev1Offer = y.Offer,
			x.Prev1Volume = y.Volume,
			x.Prev1Value = y.[Value],
			x.VolumeDelta = x.Volume - y.Volume,
			x.ValueDelta = x.[Value] - y.[Value],
			x.TimeIntervalInSec = datediff(second, y.LastVerifiedDate, x.DateFrom),
			x.Prev1Close = y.[close]
		from StockData.PriceSummaryToday as x
		inner join StockData.PriceSummaryToday as y
		on x.Prev1PriceSummaryID = y.PriceSummaryID 
		and x.DateTo is null
		and exists
		(
			select 1
			from #TempPriceSummary
			where ASXCode = x.ASXCode
		)
			
		update x
		set x.BuySellInd = case when x.VolumeDelta > 0 and x.[close] = x.Prev1Offer and x.[close] > x.Prev1Bid then 'B'
								when x.VolumeDelta > 0 and x.[close] = x.Prev1Bid and x.[close] < x.Prev1Offer then 'S'
								when x.VolumeDelta > 0 and x.[close] > x.[Prev1Close] then 'B'
								when x.VolumeDelta > 0 and x.[close] < x.[Prev1Close] then 'S'
								else null
							end
		from StockData.PriceSummaryToday as x
		where x.DateTo is null
		and exists
		(
			select 1
			from #TempPriceSummary
			where ASXCode = x.ASXCode
		)

	END TRY

	BEGIN CATCH
		-- Store the details of the error
		SELECT	@intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
				@intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
				@intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
	END CATCH

	IF @intErrorNumber = 0 OR @vchErrorProcedure = ''
	BEGIN
		-- No Error occured in this procedure

		--COMMIT TRANSACTION 

		IF @pbitDebug = 1
		BEGIN
			PRINT 'Procedure ' + @vchSchema + '.' + @vchProcedureName + ' finished executing (successfully) at ' + CAST(getdate() as varchar(20))
		END
	END

	ELSE
	BEGIN

		--IF @@TRANCOUNT > 0
		--BEGIN
		--	ROLLBACK TRANSACTION
		--END
			
		--EXECUTE da_utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		--@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
