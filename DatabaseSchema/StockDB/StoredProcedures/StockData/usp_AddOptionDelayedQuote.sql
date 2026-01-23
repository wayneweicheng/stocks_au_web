-- Stored procedure: [StockData].[usp_AddOptionDelayedQuote]


CREATE PROCEDURE [StockData].[usp_AddOptionDelayedQuote]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pvchASXCode as varchar(10),
@pvchResponse as varchar(max)
AS
/******************************************************************************
File: usp_AddOptionDelayedQuote.sql
Stored Procedure Name: usp_AddOptionDelayedQuote
Overview
-----------------
usp_AddOptionDelayedQuote

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
Date:		2017-02-06
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = object_name(@@PROCID)
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = schema_name()
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		--declare @pvchASXCode as varchar(10) = 'STO.AX'
		--declare @pvchResponse as varchar(max) = '
		--{"datesAvailable": {"quarterly": [], "monthly": ["2023-04-20", "2023-05-18", "2023-06-15", "2023-07-20", "2023-08-17", "2023-09-21", "2023-12-21", "2024-03-21", "2024-06-20", "2024-09-19", "2024-12-19", "2025-03-20", "2025-06-19", "2025-12-18"], "weekly": ["2023-03-30", "2023-04-06", "2023-04-13", "2023-12-21"]}, "datesIncluded": {"quarterly": [], "monthly": ["2023-04-20"], "weekly": []}, "expiryGroups": {"items": [{"date": "2023-04-20", "exerciseGroups": [{"periodicity": "Monthly", "priceExercise": 5, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "5.00 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 5, "priceLast": 0, "priceTheoretical": 2, "periodicity": "Monthly", "style": "American", "symbol": "STOUO9", "volume": 0, "xid": "786570283", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "5.00 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 5, "priceLast": 0, "priceTheoretical": 0.001, "periodicity": "Monthly", "style": "American", "symbol": "STOUP9", "volume": 0, "xid": "786550178", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 5.25, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "5.25 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 5.25, "priceLast": 0, "priceTheoretical": 1.755, "periodicity": "Monthly", "style": "American", "symbol": "STOFI8", "volume": 0, "xid": "773979685", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "5.25 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 5.25, "priceLast": 0, "priceTheoretical": 0.001, "periodicity": "Monthly", "style": "American", "symbol": "STOFJ8", "volume": 0, "xid": "773986662", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 5.5, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "5.50 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 5.5, "priceLast": 0, "priceTheoretical": 1.51, "periodicity": "Monthly", "style": "American", "symbol": "STOUW7", "volume": 0, "xid": "769942085", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "5.50 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 5.5, "priceLast": 0, "priceTheoretical": 0.002, "periodicity": "Monthly", "style": "American", "symbol": "STOUX7", "volume": 0, "xid": "769953682", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 5.75, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "5.75 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 55, "priceAsk": 0, "priceBid": 0, "priceExercise": 5.75, "priceLast": 1.565, "priceTheoretical": 1.265, "periodicity": "Monthly", "style": "American", "symbol": "STOJ47", "volume": 0, "xid": "764886618", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "5.75 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 5.75, "priceLast": 0, "priceTheoretical": 0.004, "periodicity": "Monthly", "style": "American", "symbol": "STOJ57", "volume": 0, "xid": "764900572", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 6, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.00 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 6, "priceLast": 0, "priceTheoretical": 1.025, "periodicity": "Monthly", "style": "American", "symbol": "STOJ67", "volume": 0, "xid": "764902343", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.00 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 934, "priceAsk": 0, "priceBid": 0, "priceExercise": 6, "priceLast": 0.03, "priceTheoretical": 0.01, "periodicity": "Monthly", "style": "American", "symbol": "STOJ77", "volume": 0, "xid": "764908884", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 6.01, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.01 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.01, "priceLast": 0, "priceTheoretical": 1.015, "periodicity": "Monthly", "style": "European", "symbol": "STOUQ9", "volume": 0, "xid": "786561927", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.01 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.01, "priceLast": 0, "priceTheoretical": 0.01, "periodicity": "Monthly", "style": "European", "symbol": "STOUR9", "volume": 0, "xid": "786536231", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 6.25, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.25 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.25, "priceLast": 0, "priceTheoretical": 0.785, "periodicity": "Monthly", "style": "American", "symbol": "STOJ87", "volume": 0, "xid": "764899748", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.25 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 1090, "priceAsk": 0.035, "priceBid": 0, "priceExercise": 6.25, "priceLast": 0.04, "priceTheoretical": 0.025, "periodicity": "Monthly", "style": "American", "symbol": "STOJ97", "volume": 0, "xid": "764884617", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 6.26, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.26 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.26, "priceLast": 0, "priceTheoretical": 0.78, "periodicity": "Monthly", "style": "European", "symbol": "STOFK8", "volume": 0, "xid": "773966539", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.26 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 400, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.26, "priceLast": 0.23, "priceTheoretical": 0.025, "periodicity": "Monthly", "style": "European", "symbol": "STOFL8", "volume": 0, "xid": "773951381", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 6.5, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.50 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.5, "priceLast": 0, "priceTheoretical": 0.565, "periodicity": "Monthly", "style": "American", "symbol": "STOJA7", "volume": 0, "xid": "764866426", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.50 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 1895, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.5, "priceLast": 0.055, "priceTheoretical": 0.055, "periodicity": "Monthly", "style": "American", "symbol": "STOJB7", "volume": 410, "xid": "764923268", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 6.51, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.51 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 145, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.51, "priceLast": 0.84, "priceTheoretical": 0.56, "periodicity": "Monthly", "style": "European", "symbol": "STOUY7", "volume": 0, "xid": "769913403", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.51 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 1066, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.51, "priceLast": 0.13, "priceTheoretical": 0.055, "periodicity": "Monthly", "style": "European", "symbol": "STOUZ7", "volume": 0, "xid": "769917440", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 6.75, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.75 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 703, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.75, "priceLast": 0.4, "priceTheoretical": 0.37, "periodicity": "Monthly", "style": "American", "symbol": "STOJC7", "volume": 0, "xid": "764884032", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.75 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 16108, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.75, "priceLast": 0.115, "priceTheoretical": 0.11, "periodicity": "Monthly", "style": "American", "symbol": "STOJD7", "volume": 200, "xid": "764892752", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 6.76, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.76 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 436, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.76, "priceLast": 0.33, "priceTheoretical": 0.36, "periodicity": "Monthly", "style": "European", "symbol": "STOJY7", "volume": 0, "xid": "764899768", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "6.76 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 1199, "priceAsk": 0, "priceBid": 0, "priceExercise": 6.76, "priceLast": 0.12, "priceTheoretical": 0.11, "periodicity": "Monthly", "style": "European", "symbol": "STOJZ7", "volume": 50, "xid": "764881050", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 7, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.00 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 5871, "priceAsk": 0, "priceBid": 0, "priceExercise": 7, "priceLast": 0.195, "priceTheoretical": 0.21, "periodicity": "Monthly", "style": "American", "symbol": "STOJE7", "volume": 450, "xid": "764890384", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.00 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 4115, "priceAsk": 0, "priceBid": 0.19, "priceExercise": 7, "priceLast": 0.215, "priceTheoretical": 0.205, "periodicity": "Monthly", "style": "American", "symbol": "STOJF7", "volume": 0, "xid": "764914885", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 7.01, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.01 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 210, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.01, "priceLast": 0.18, "priceTheoretical": 0.205, "periodicity": "Monthly", "style": "European", "symbol": "STOK17", "volume": 0, "xid": "764878793", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.01 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 3068, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.01, "priceLast": 0.23, "priceTheoretical": 0.21, "periodicity": "Monthly", "style": "European", "symbol": "STOK27", "volume": 0, "xid": "764886379", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 7.25, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.25 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 14263, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.25, "priceLast": 0.08, "priceTheoretical": 0.105, "periodicity": "Monthly", "style": "American", "symbol": "STOJG7", "volume": 650, "xid": "764907354", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.25 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 4930, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.25, "priceLast": 0.4, "priceTheoretical": 0.355, "periodicity": "Monthly", "style": "American", "symbol": "STOJH7", "volume": 0, "xid": "764873240", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 7.26, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.26 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 3977, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.26, "priceLast": 0.125, "priceTheoretical": 0.1, "periodicity": "Monthly", "style": "European", "symbol": "STOK37", "volume": 0, "xid": "764924457", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.26 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 2889, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.26, "priceLast": 0.445, "priceTheoretical": 0.36, "periodicity": "Monthly", "style": "European", "symbol": "STOK47", "volume": 0, "xid": "764907099", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 7.5, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.50 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 9696, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.5, "priceLast": 0.045, "priceTheoretical": 0.045, "periodicity": "Monthly", "style": "American", "symbol": "STOJI7", "volume": 10, "xid": "764899751", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.50 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 520, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.5, "priceLast": 0.62, "priceTheoretical": 0.545, "periodicity": "Monthly", "style": "American", "symbol": "STOJJ7", "volume": 0, "xid": "764899208", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 7.51, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.51 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 2103, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.51, "priceLast": 0.06, "priceTheoretical": 0.04, "periodicity": "Monthly", "style": "European", "symbol": "STOK57", "volume": 0, "xid": "764902328", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.51 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 1477, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.51, "priceLast": 0.5750000000000001, "priceTheoretical": 0.55, "periodicity": "Monthly", "style": "European", "symbol": "STOK67", "volume": 0, "xid": "764905317", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 7.75, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.75 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 771, "priceAsk": 0.05, "priceBid": 0, "priceExercise": 7.75, "priceLast": 0.115, "priceTheoretical": 0.015, "periodicity": "Monthly", "style": "American", "symbol": "STOJK7", "volume": 0, "xid": "764860021", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.75 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 431, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.75, "priceLast": 0.62, "priceTheoretical": 0.77, "periodicity": "Monthly", "style": "American", "symbol": "STOJL7", "volume": 0, "xid": "764901932", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 7.76, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.76 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 307, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.76, "priceLast": 0.035, "priceTheoretical": 0.015, "periodicity": "Monthly", "style": "European", "symbol": "STOK77", "volume": 0, "xid": "764924056", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "7.76 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 4375, "priceAsk": 0, "priceBid": 0, "priceExercise": 7.76, "priceLast": 0.59, "priceTheoretical": 0.77, "periodicity": "Monthly", "style": "European", "symbol": "STOK87", "volume": 0, "xid": "764862044", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 8, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.00 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 1290, "priceAsk": 0, "priceBid": 0, "priceExercise": 8, "priceLast": 0.06, "priceTheoretical": 0.005, "periodicity": "Monthly", "style": "American", "symbol": "STOJM7", "volume": 0, "xid": "764921872", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.00 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 147, "priceAsk": 0, "priceBid": 0, "priceExercise": 8, "priceLast": 0.91, "priceTheoretical": 1.01, "periodicity": "Monthly", "style": "American", "symbol": "STOJN7", "volume": 0, "xid": "764920066", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 8.01, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.01 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 337, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.01, "priceLast": 0.05, "priceTheoretical": 0.005, "periodicity": "Monthly", "style": "European", "symbol": "STOK97", "volume": 0, "xid": "764882571", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.01 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 370, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.01, "priceLast": 0, "priceTheoretical": 1.01, "periodicity": "Monthly", "style": "European", "symbol": "STOKA7", "volume": 0, "xid": "764896169", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 8.25, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.25 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.25, "priceLast": 0, "priceTheoretical": 0.001, "periodicity": "Monthly", "style": "American", "symbol": "STOJO7", "volume": 0, "xid": "764922064", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.25 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.25, "priceLast": 1.135, "priceTheoretical": 1.26, "periodicity": "Monthly", "style": "American", "symbol": "STOJP7", "volume": 0, "xid": "764894364", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 8.26, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.26 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 810, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.26, "priceLast": 0.03, "priceTheoretical": 0.001, "periodicity": "Monthly", "style": "European", "symbol": "STOKB7", "volume": 0, "xid": "764888998", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.26 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 875, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.26, "priceLast": 0, "priceTheoretical": 1.255, "periodicity": "Monthly", "style": "European", "symbol": "STOKC7", "volume": 0, "xid": "764909903", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 8.5, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.50 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 60, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.5, "priceLast": 0.12, "priceTheoretical": 0, "periodicity": "Monthly", "style": "American", "symbol": "STOJQ7", "volume": 0, "xid": "764879231", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.50 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.5, "priceLast": 1.49, "priceTheoretical": 1.51, "periodicity": "Monthly", "style": "American", "symbol": "STOJR7", "volume": 0, "xid": "764866641", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 8.51, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.51 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.51, "priceLast": 0, "priceTheoretical": 0, "periodicity": "Monthly", "style": "European", "symbol": "STOML7", "volume": 0, "xid": "765834288", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.51 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 300, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.51, "priceLast": 0, "priceTheoretical": 1.5, "periodicity": "Monthly", "style": "European", "symbol": "STOMM7", "volume": 0, "xid": "765805212", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 8.75, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.75 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.75, "priceLast": 0, "priceTheoretical": 0, "periodicity": "Monthly", "style": "American", "symbol": "STOJS7", "volume": 0, "xid": "764902959", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.75 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.75, "priceLast": 0, "priceTheoretical": 1.76, "periodicity": "Monthly", "style": "American", "symbol": "STOJT7", "volume": 0, "xid": "764912302", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 8.76, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.76 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.76, "priceLast": 0, "priceTheoretical": 0, "periodicity": "Monthly", "style": "European", "symbol": "STOMX7", "volume": 0, "xid": "767147809", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "8.76 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 150, "priceAsk": 0, "priceBid": 0, "priceExercise": 8.76, "priceLast": 0, "priceTheoretical": 1.75, "periodicity": "Monthly", "style": "European", "symbol": "STOMY7", "volume": 0, "xid": "767166097", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 9, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "9.00 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 9, "priceLast": 0, "priceTheoretical": 0, "periodicity": "Monthly", "style": "American", "symbol": "STOJU7", "volume": 0, "xid": "764916470", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "9.00 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 9, "priceLast": 0, "priceTheoretical": 2.01, "periodicity": "Monthly", "style": "American", "symbol": "STOJV7", "volume": 0, "xid": "764893789", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 9.25, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "9.25 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 9.25, "priceLast": 0, "priceTheoretical": 0, "periodicity": "Monthly", "style": "American", "symbol": "STOJW7", "volume": 0, "xid": "764902741", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "9.25 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 9.25, "priceLast": 0, "priceTheoretical": 2.26, "periodicity": "Monthly", "style": "American", "symbol": "STOJX7", "volume": 0, "xid": "764917081", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 9.5, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "9.50 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 9.5, "priceLast": 0, "priceTheoretical": 0, "periodicity": "Monthly", "style": "American", "symbol": "STOMJ7", "volume": 0, "xid": "765830530", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "9.50 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 9.5, "priceLast": 0, "priceTheoretical": 2.51, "periodicity": "Monthly", "style": "American", "symbol": "STOMK7", "volume": 0, "xid": "765828513", "optionRoot": "STO"}}, {"periodicity": "Monthly", "priceExercise": 9.75, "call": {"chainType": "Call", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "9.75 CALL OPTION EXPIRING 20-APR-2023", "openInterest": 25, "priceAsk": 0, "priceBid": 0, "priceExercise": 9.75, "priceLast": 0.165, "priceTheoretical": 0, "periodicity": "Monthly", "style": "American", "symbol": "STOMV7", "volume": 0, "xid": "767127053", "optionRoot": "STO"}, "put": {"chainType": "Put", "contractSize": 100, "dateExpiry": "2023-04-20", "name": "9.75 PUT OPTION EXPIRING 20-APR-2023", "openInterest": 0, "priceAsk": 0, "priceBid": 0, "priceExercise": 9.75, "priceLast": 0, "priceTheoretical": 2.76, "periodicity": "Monthly", "style": "American", "symbol": "STOMW7", "volume": 0, "xid": "767131391", "optionRoot": "STO"}}]}]}, "underlyingAsset": {"displayName": "SANTOS LIMITED", "issueType": "CS", "priceAsk": 6.99, "priceBid": 6.98, "priceChange": -0.009999999999999787, "priceChangePercent": -0.14306151645207132, "priceChangeFiveDayPercent": 1.1594202898550734, "priceDayHigh": 7.01, "priceDayLow": 6.865, "priceLast": 6.98, "sparkChartBaseUrl": "https://api.markitondemand.com/apiman-gateway/MOD/chartworks-image/1.0/Chart/sparkLine", "statusCode": "", "symbol": "STO", "xid": "261429"}}'

		if object_id(N'Tempdb.dbo.#TempOptionDelayedQuote') is not null
			drop table #TempOptionDelayedQuote

		select
			@pvchASXCode as ASXCode,
			@pvchResponse as Quote
		into #TempOptionDelayedQuote
		--into MAWork.dbo.TempOptionDelayedQuoteNew

		--return

		declare @dtObservationDate as date 
		if datepart(hour, getdate()) < 10
		begin
			select @dtObservationDate = Common.DateAddBusinessDay_Plus(-1, getdate())
		end
		else
		begin
			select @dtObservationDate = Common.DateAddBusinessDay_Plus(0, getdate())
		end

		if object_id(N'Tempdb.dbo.#TempParsedOptionDelayedQuote') is not null
			drop table #TempParsedOptionDelayedQuote
		
		select 
			g.[key],
			g.value,
			a.ASXCode,
			@dtObservationDate as ObservationDate,
			cast(json_value(g.value, '$.symbol') as varchar(200)) as OptionSymbol,
			cast(json_value(g.value, '$.priceBid') as decimal(20, 4)) as Bid,
			1 as BidSize,
			cast(json_value(g.value, '$.priceAsk') as decimal(20, 4)) as Ask,
			1 as AskSize,
			cast(null as decimal(20, 4)) as IV,
			cast(json_value(g.value, '$."openInterest"') as decimal(20, 4)) as OpenInterest,
			cast(json_value(g.value, '$.volume') as decimal(20, 4)) as Volume,
			cast(null as decimal(20, 4)) as Delta,
			cast(null as decimal(20, 4)) as Gamma,
			cast(null as decimal(20, 4)) as Theta,
			cast(null as decimal(20, 4)) as RHO,
			cast(null as decimal(20, 4)) as Vega,
			cast(null as decimal(20, 4)) as Theo,
			cast(null as decimal(20, 4)) as Change,
			cast(null as decimal(20, 4)) as [Open],
			cast(null as decimal(20, 4)) as [High],
			cast(null as decimal(20, 4)) as [Low],
			cast(null as varchar(100)) as [Tick],
			cast(json_value(g.value, '$.priceLast') as decimal(20, 4)) as [LastTradePrice],
			cast(null as varchar(100)) as [LastTradeTime],
			cast(null as varchar(100)) as [PrevDayClose],
			cast(json_value(g.value, '$.priceExercise') as decimal(20, 4)) as Strike,
			case when g.[key] = 'call' then 'C' 
				 when g.[key] = 'put' then 'P'
			end as PorC,
			cast(json_value(g.value, '$.dateExpiry') as date) as ExpiryDate,
			cast(null as varchar(8)) as Expiry
		into #TempParsedOptionDelayedQuote
		from #TempOptionDelayedQuote as a
		cross apply openjson(Quote) as b
		cross apply openjson(b.value) as c
		cross apply openjson(c.value) as d
		cross apply openjson(d.value) as e
		cross apply openjson(e.value) as g
		where b.[key] = 'items'
		and d.[key] = 'exerciseGroups' 
		and g.[key] in ('call', 'put')

		update a
		set Expiry = convert(varchar(8), ExpiryDate, 112)
		from #TempParsedOptionDelayedQuote as a

		if object_id(N'Tempdb.dbo.#TempToDelete') is not null
			drop table #TempToDelete

		select *
		into #TempToDelete
		from
		(
			select a.*
			from StockData.OptionDelayedQuote as a
			where exists
			(
				select 1
				from #TempParsedOptionDelayedQuote as b
				where a.ASXCode = b.ASXCode
				and a.OptionSymbol = b.OptionSymbol
				and a.ObservationDate = b.ObservationDate
			)
			and ExpiryDate >= ObservationDate
		) as x

		insert into [StockData].[OptionDelayedQuoteHistory]
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[OptionSymbol]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[IV]
		  ,[OpenInterest]
		  ,[Volume]
		  ,[Delta]
		  ,[Gamma]
		  ,[Theta]
		  ,[RHO]
		  ,[Vega]
		  ,[Theo]
		  ,[Change]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Tick]
		  ,[LastTradePrice]
		  ,[LastTradeTime]
		  ,[PrevDayClose]
		  ,[CreateDate]
		  ,Strike
		  ,PorC
		  ,ExpiryDate
		  ,Expiry
		)
		select
		   [ASXCode]
		  ,[ObservationDate]
		  ,[OptionSymbol]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[IV]
		  ,[OpenInterest]
		  ,[Volume]
		  ,[Delta]
		  ,[Gamma]
		  ,[Theta]
		  ,[RHO]
		  ,[Vega]
		  ,[Theo]
		  ,[Change]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Tick]
		  ,[LastTradePrice]
		  ,[LastTradeTime]
		  ,[PrevDayClose]
		  ,[CreateDate]
		  ,Strike
		  ,PorC
		  ,ExpiryDate
		  ,Expiry
		from #TempToDelete

		delete a
		from StockData.OptionDelayedQuote as a
		inner join #TempToDelete as b
		on a.ASXCode = b.ASXCode
		and a.OptionSymbol = b.OptionSymbol
		and a.CreateDate = b.CreateDate

		insert into StockData.OptionDelayedQuote
		(
		   [ASXCode]
		  ,[ObservationDate]
		  ,[OptionSymbol]
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[IV]
		  ,[OpenInterest]
		  ,[Volume]
		  ,[Delta]
		  ,[Gamma]
		  ,[Theta]
		  ,[RHO]
		  ,[Vega]
		  ,[Theo]
		  ,[Change]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Tick]
		  ,[LastTradePrice]
		  ,[LastTradeTime]
		  ,[PrevDayClose]
		  ,[CreateDate]
		  ,Strike
		  ,PorC
		  ,ExpiryDate
		  ,Expiry
		)
		select
	       [ASXCode]
		  ,[ObservationDate]
		  ,replace([OptionSymbol], ' ', '')
		  ,[Bid]
		  ,[BidSize]
		  ,[Ask]
		  ,[AskSize]
		  ,[IV]
		  ,[OpenInterest]
		  ,[Volume]
		  ,[Delta]
		  ,[Gamma]
		  ,[Theta]
		  ,[RHO]
		  ,[Vega]
		  ,[Theo]
		  ,[Change]
		  ,[Open]
		  ,[High]
		  ,[Low]
		  ,[Tick]
		  ,[LastTradePrice]
		  ,[LastTradeTime]
		  ,[PrevDayClose]
		  ,getdate() as [CreateDate]
		  ,Strike
		  ,PorC
		  ,ExpiryDate
		  ,Expiry
		from #TempParsedOptionDelayedQuote

		delete a
		from StockData.OptionDelayedQuote as a
		where ASXCode = @pvchASXCode
		and ExpiryDate < ObservationDate

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
			
		EXECUTE DA_Utility.dbo.[usp_DAU_ErrorLog] 'StoredProcedure', @vchErrorProcedure, @vchSchema, @intErrorNumber,
		@intErrorSeverity, @intErrorState, @intErrorLine, @vchErrorMessage

		--Raise the error back to the calling stored proc if needed		
		RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
	END


	SET @pintErrorNumber = @intErrorNumber	-- Set the return parameter


END
