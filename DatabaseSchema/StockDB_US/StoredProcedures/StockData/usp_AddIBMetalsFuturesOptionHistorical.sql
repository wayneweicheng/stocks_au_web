-- Stored procedure: [StockData].[usp_AddIBMetalsFuturesOptionHistorical]


CREATE PROCEDURE [StockData].[usp_AddIBMetalsFuturesOptionHistorical]
    @pvchMetal VARCHAR(20),
    @pvchSymbol VARCHAR(50),
    @pvchUnderlyingSymbol VARCHAR(10),
    @pvchUnderlyingExpiry VARCHAR(10) = NULL,
    @pdecStrikePrice DECIMAL(18, 4),
    @pchOptionType CHAR(1),
    @pvchOptionExpiry VARCHAR(20) = NULL,
    @pbigOpenInterest BIGINT = NULL,
    @pbigVolume BIGINT = NULL,
    @pdecLastPrice DECIMAL(18, 6) = NULL,
    @pdecBidPrice DECIMAL(18, 6) = NULL,
    @pdecAskPrice DECIMAL(18, 6) = NULL,
    @pdecClosePrice DECIMAL(18, 6) = NULL,
    @pvchExchange VARCHAR(20) = NULL,
    @pvchTradingClass VARCHAR(10) = NULL,
    @pbigContractID BIGINT = NULL,
    @pdecUnderlyingPrice DECIMAL(18, 6) = NULL,
    @pdtRefreshDateTime DATETIME
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        -- 1. ALWAYS insert into history table (never update, full audit trail)
        INSERT INTO [StockData].[IBMetalsFuturesOptionsHistory] (
            [RefreshDateTime],
            [RefreshDate],
            [Metal],
            [Symbol],
            [UnderlyingSymbol],
            [UnderlyingExpiry],
            [StrikePrice],
            [OptionType],
            [OptionExpiry],
            [OpenInterest],
            [Volume],
            [LastPrice],
            [BidPrice],
            [AskPrice],
            [ClosePrice],
            [Exchange],
            [TradingClass],
            [ContractID],
            [UnderlyingPrice],
            [CreateDate]
        )
        VALUES (
            @pdtRefreshDateTime,
            CAST(@pdtRefreshDateTime AS DATE),
            @pvchMetal,
            @pvchSymbol,
            @pvchUnderlyingSymbol,
            @pvchUnderlyingExpiry,
            @pdecStrikePrice,
            @pchOptionType,
            @pvchOptionExpiry,
            @pbigOpenInterest,
            @pbigVolume,
            @pdecLastPrice,
            @pdecBidPrice,
            @pdecAskPrice,
            @pdecClosePrice,
            @pvchExchange,
            @pvchTradingClass,
            @pbigContractID,
            @pdecUnderlyingPrice,
            GETDATE()
        )

        -- 2. Upsert into current table (maintain latest snapshot)
        IF EXISTS (
            SELECT 1
            FROM [StockData].[IBMetalsFuturesOptionsCurrent]
            WHERE [Metal] = @pvchMetal
                AND [Symbol] = @pvchSymbol
                AND [StrikePrice] = @pdecStrikePrice
                AND [OptionType] = @pchOptionType
                AND ISNULL([OptionExpiry], '') = ISNULL(@pvchOptionExpiry, '')
        )
        BEGIN
            -- Update existing record with latest data
            UPDATE [StockData].[IBMetalsFuturesOptionsCurrent]
            SET
                [RefreshDateTime] = @pdtRefreshDateTime,
                [UnderlyingSymbol] = @pvchUnderlyingSymbol,
                [UnderlyingExpiry] = @pvchUnderlyingExpiry,
                [OpenInterest] = @pbigOpenInterest,
                [Volume] = @pbigVolume,
                [LastPrice] = @pdecLastPrice,
                [BidPrice] = @pdecBidPrice,
                [AskPrice] = @pdecAskPrice,
                [ClosePrice] = @pdecClosePrice,
                [Exchange] = @pvchExchange,
                [TradingClass] = @pvchTradingClass,
                [ContractID] = @pbigContractID,
                [UnderlyingPrice] = @pdecUnderlyingPrice,
                [UpdateDate] = GETDATE()
            WHERE [Metal] = @pvchMetal
                AND [Symbol] = @pvchSymbol
                AND [StrikePrice] = @pdecStrikePrice
                AND [OptionType] = @pchOptionType
                AND ISNULL([OptionExpiry], '') = ISNULL(@pvchOptionExpiry, '')
        END
        ELSE
        BEGIN
            -- Insert new record
            INSERT INTO [StockData].[IBMetalsFuturesOptionsCurrent] (
                [RefreshDateTime],
                [Metal],
                [Symbol],
                [UnderlyingSymbol],
                [UnderlyingExpiry],
                [StrikePrice],
                [OptionType],
                [OptionExpiry],
                [OpenInterest],
                [Volume],
                [LastPrice],
                [BidPrice],
                [AskPrice],
                [ClosePrice],
                [Exchange],
                [TradingClass],
                [ContractID],
                [UnderlyingPrice],
                [CreateDate],
                [UpdateDate]
            )
            VALUES (
                @pdtRefreshDateTime,
                @pvchMetal,
                @pvchSymbol,
                @pvchUnderlyingSymbol,
                @pvchUnderlyingExpiry,
                @pdecStrikePrice,
                @pchOptionType,
                @pvchOptionExpiry,
                @pbigOpenInterest,
                @pbigVolume,
                @pdecLastPrice,
                @pdecBidPrice,
                @pdecAskPrice,
                @pdecClosePrice,
                @pvchExchange,
                @pvchTradingClass,
                @pbigContractID,
                @pdecUnderlyingPrice,
                GETDATE(),
                GETDATE()
            )
        END

    END TRY
    BEGIN CATCH
        -- Error handling
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE()
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY()
        DECLARE @ErrorState INT = ERROR_STATE()

        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
    END CATCH
END
