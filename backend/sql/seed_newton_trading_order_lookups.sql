/*
Seed lookup rows for the NEWTON trading-orders workflow.

NEWTON defaults on the website:
- OrderSourceType: SIGNAL
- SignalType: SMA_CROSS
- TimeFrame: 5M
- EntryType: LIMIT_MID
- EntryPrice mode: MID, stored in Trading.Orders.MetaJson
- StopLossMode: BAR_CLOSE

The SMA_CROSS signal is documented here as a simple moving average cross.
The website defaults NEWTON to 5M and annotates SMA_CROSS orders as SMA10
on the selected order timeframe.
*/

IF NOT EXISTS (
    SELECT 1
    FROM Trading.Strategy
    WHERE StrategyCode = 'NEWTON'
)
BEGIN
    INSERT INTO Trading.Strategy
        (StrategyCode, Name, Description, IsActive, CreatedAt, UpdatedAt)
    VALUES
        (
            'NEWTON',
            'NEWTON',
            'SMA cross strategy for website and signal-driven live orders.',
            1,
            GETDATE(),
            GETDATE()
        );
END;

IF NOT EXISTS (
    SELECT 1
    FROM Trading.SignalType
    WHERE SignalType = 'SMA_CROSS'
)
BEGIN
    INSERT INTO Trading.SignalType
        (SignalType, Description, IsActive)
    VALUES
        (
            'SMA_CROSS',
            'Simple moving average cross',
            1
        );
END;
