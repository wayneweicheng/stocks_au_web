-- Stored procedure: [Report].[usp_Get_Aggregate_BrokerTradeTransaction]


CREATE PROCEDURE [Report].[usp_Get_Aggregate_BrokerTradeTransaction]
      @pvchASXCode VARCHAR(20),
      @pdtStartDate DATETIME,
      @pdtEndDate DATETIME
  AS
  BEGIN
      SET NOCOUNT ON;

      SELECT
          x.Buyer,
          x.BuyVolume,
          y.SellVolume,
          x.BuyVolume - y.SellVolume AS NetVolume,
          x.BuyValue,
          y.SellValue,
          x.BuyValue - y.SellValue AS NetValue,
          x.BuyValue * 1.0 / x.BuyVolume AS BuyVWAP,
          y.SellValue * 1.0 / y.SellVolume AS SellVWAP,
          z.BuyVolume AS SelfTradeVolume,
          z.BuyVolume * 1.0 / y.SellVolume AS SelfTradePerc
      FROM
      (
          SELECT
              Buyer,
              SUM(Volume) AS BuyVolume,
              SUM([Value]) AS BuyValue
          FROM StockData.BrokerTradeTransaction
          WHERE ObservationDate >= @pdtStartDate
              AND ObservationDate <= @pdtEndDate
              AND ASXCode = @pvchASXCode
          GROUP BY Buyer
      ) AS x
      LEFT JOIN
      (
          SELECT
              Seller,
              SUM(Volume) AS SellVolume,
              SUM([Value]) AS SellValue
          FROM StockData.BrokerTradeTransaction
          WHERE ObservationDate >= @pdtStartDate
              AND ObservationDate <= @pdtEndDate
              AND ASXCode = @pvchASXCode
          GROUP BY Seller
      ) AS y
          ON x.Buyer = y.Seller
      LEFT JOIN
      (
          SELECT
              Buyer,
              SUM(Volume) AS BuyVolume,
              SUM([Value]) AS BuyValue
          FROM StockData.BrokerTradeTransaction
          WHERE ObservationDate >= @pdtStartDate
              AND ObservationDate <= @pdtEndDate
              AND ASXCode = @pvchASXCode
              AND Buyer = Seller
          GROUP BY Buyer
      ) AS z
          ON x.Buyer = z.Buyer
      ORDER BY x.BuyVolume - y.SellVolume DESC;
  END