-- Supporting indexes for quote-based option trade-side inference.
-- These are intentionally separate from the base table definitions because
-- they support the Analysis feature workload.

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'ix_optionbidask_asxcode_symbol_observationtime'
      AND object_id = OBJECT_ID('StockData.OptionBidAsk')
)
BEGIN
    CREATE INDEX [ix_optionbidask_asxcode_symbol_observationtime]
        ON [StockData].[OptionBidAsk] ([ASXCode], [OptionSymbol], [ObservationTime])
        INCLUDE ([PriceBid], [PriceAsk]);
END;

IF NOT EXISTS
(
    SELECT 1
    FROM sys.indexes
    WHERE name = 'ix_optiontrade_asxcode_observationdate_expiry'
      AND object_id = OBJECT_ID('StockData.OptionTrade')
)
BEGIN
    CREATE INDEX [ix_optiontrade_asxcode_observationdate_expiry]
        ON [StockData].[OptionTrade] ([ASXCode], [ObservationDateLocal], [ExpiryDate])
        INCLUDE ([OptionTradeID], [OptionSymbol], [SaleTime], [Strike], [PorC], [Price], [Size], [BuySellIndicator]);
END;
