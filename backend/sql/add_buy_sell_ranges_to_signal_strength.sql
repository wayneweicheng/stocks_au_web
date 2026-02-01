-- Migration: Add BuyDipRange and SellRipRange columns to Analysis.SignalStrength
-- Safe to run multiple times; uses IF NOT EXISTS guards

IF NOT EXISTS (
	SELECT 1
	FROM sys.columns
	WHERE Name = N'BuyDipRange'
	  AND Object_ID = Object_ID(N'Analysis.SignalStrength')
)
BEGIN
	ALTER TABLE Analysis.SignalStrength
	ADD BuyDipRange NVARCHAR(64) NULL;
END
GO

IF NOT EXISTS (
	SELECT 1
	FROM sys.columns
	WHERE Name = N'SellRipRange'
	  AND Object_ID = Object_ID(N'Analysis.SignalStrength')
)
BEGIN
	ALTER TABLE Analysis.SignalStrength
	ADD SellRipRange NVARCHAR(64) NULL;
END
GO


