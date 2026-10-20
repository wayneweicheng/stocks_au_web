# StockDB_US inventory and research map

Inventory contains 419 tables/views. Approximate table row counts come from SQL Server partition metadata; view counts are not evaluated.

## Candidate research families
### Primary causal strategy sources

- `Analysis.GEX_Features` — table; approximate rows: 245103
- `Transform.OptionGEXChangeCapitalType` — table; approximate rows: 2377534
- `StockData.PriceHistoryTimeFrame` — table; approximate rows: 6677224
- `StockData.OptionDelayedQuote_V2` — table; approximate rows: 97727314
- `Transform.OptionFlowContractDaily` — table; approximate rows: 2368
- `Transform.OptionFlowTradeDaily` — table; approximate rows: 12359
- `Transform.OptionDEXByPutCall` — table; approximate rows: 733910
- `Transform.OptionGEXByPutCall` — table; approximate rows: 1286370
- `Transform.OISummary` — table; approximate rows: 327159

### Price and volatility

- `StockData.PriceHistory` — table; approximate rows: 5702416
- `StockData.PriceHistory5M` — table; approximate rows: 0
- `StockData.PriceHistoryTimeFrame` — table; approximate rows: 6677224
- `StockData.PriceSummary` — table; approximate rows: 0
- `StockData.UnderlyingVolatilityHistory` — table; approximate rows: 289190
- `StockData.RelativePriceStrength` — table; approximate rows: 1913994
- `Transform.PriceHistory` — table; approximate rows: 96419
- `Transform.PriceHistory24Month` — table; approximate rows: 3797887
- `Transform.PriceHistoryNetVolume` — table; approximate rows: 0

### Option flow and exposure

- `StockData.OptionTrade` — table; approximate rows: 254523322
- `StockData.SignificantOptionTrade` — table; approximate rows: 905277
- `StockData.OptionPriceHistory` — table; approximate rows: 922961
- `StockData.OptionIntradayQuote` — table; approximate rows: 0
- `StockData.OptionIntradayUnderlyingQuote` — table; approximate rows: 0
- `Transform.OptionFlowContractDaily` — table; approximate rows: 2368
- `Transform.OptionFlowTradeDaily` — table; approximate rows: 12359
- `Transform.OptionDEXByPutCall` — table; approximate rows: 733910
- `Transform.OptionGEXByPutCall` — table; approximate rows: 1286370
- `Transform.OptionNetExposureAggregate` — table; approximate rows: 9619021
- `Transform.CapitalTypeRatioFromOI` — table; approximate rows: 2190905
- `Transform.OptionGEXChangeCapitalType` — table; approximate rows: 2377534

### Market and cross-sectional

- `Transform.BreathLine` — table; approximate rows: 2419
- `Transform.LeadingBreath` — table; approximate rows: 2210
- `Transform.MarketCLVTrend` — table; approximate rows: 10106
- `Transform.MarketCLVTrendDetails` — table; approximate rows: 1146
- `Report.SectorPerformance` — table; approximate rows: 0
- `Report.SectorPerformanceDetails` — table; approximate rows: 0
- `StockData.ETFComFundFlow` — table; approximate rows: 8424
- `StockData.MoneyFlowInfo` — table; approximate rows: 293738
- `StockData.MoneyFlowInOutHistory` — table; approximate rows: 7065
- `Analysis.MostTradedStock` — table; approximate rows: 141

### Event and fundamental

- `StockData.Announcement` — table; approximate rows: 0
- `StockData.AnnouncementToken` — table; approximate rows: 0
- `StockData.DirectorBuyOnMarket` — table; approximate rows: 0
- `StockData.DirectorCurrent` — table; approximate rows: 0
- `StockData.SignificantHolder` — table; approximate rows: 0
- `StockData.CompanyInfo` — table; approximate rows: 5124
- `Transform.QuarterlyCashflow` — table; approximate rows: 0

### Existing signal features

- `Analysis.OptionFlowFeatures` — table; approximate rows: 6902
- `Analysis.OptionTradeSideInference` — table; approximate rows: 162292
- `Analysis.SignalStrength` — table; approximate rows: 3626
- `Analysis.CSPRecommendations` — table; approximate rows: 2717

### Existing backtest/strategy artifacts

- `BackTest.Strategy` — table; approximate rows: 11
- `BackTest.Execution` — table; approximate rows: 19
- `BackTest.TradeMF` — table; approximate rows: 4293
- `TradingSignal.SignalOutcome` — table; approximate rows: 798
- `TradingSignal.StrategyComparison` — table; approximate rows: 0

