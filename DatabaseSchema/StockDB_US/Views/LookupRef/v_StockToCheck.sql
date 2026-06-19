-- View: [LookupRef].[v_StockToCheck]

CREATE VIEW [LookupRef].[v_StockToCheck] AS
SELECT DISTINCT
    ASXCode
FROM [LookupRef].[StocksToCheck]
WHERE ASXCode IS NOT NULL
  AND LEN(ASXCode) > 0;
