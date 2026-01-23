-- Stored procedure: [Transform].[usp_RefreshMarketLevelAnalysis]



CREATE PROCEDURE [Transform].[usp_RefreshMarketLevelAnalysis]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT,
@pintBatchSize as int = 200
AS
/******************************************************************************
File: usp_RefreshMarketLevelAnalysis.sql
Stored Procedure Name: usp_RefreshMarketLevelAnalysis
Overview
-----------------
usp_RefreshMarketLevelAnalysis

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
Date:		2020-10-24
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshMarketLevelAnalysis'
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
		truncate table Transform.BrokerDataInflowTrend

		insert into Transform.BrokerDataInflowTrend
		(
			MarketCap,
			ObservationDate,
			BrokerCode,
			NetValueInK,
			NetValueInKMA10,
			NetValueInKMA20,
			CreateDate,
			Sector
		)
		select 
		case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 then 'f. 1B+'
		end as MarketCap, 
		ObservationDate,
		BrokerCode,
		sum(NetValue)/1000 as NetValueInK,
		null as NetValueInKMA10,
		null as NetValueInKMA20,
		getdate() as CreateDate,
		'XAO' as Sector
		from StockData.v_BrokerReport as a
		inner join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		where 1 = 1
		and case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 then 'f. 1B+'
		end is not null
		--and ObservationDate between '2029-10-10' and '2020-10-20'
		--and BrokerCode = 'UBSAus'
		group by 
		case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 then 'f. 1B+'
		end,
		ObservationDate,
		BrokerCode
		order by 
		case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 then 'f. 1B+'
		end,
		ObservationDate

		insert into Transform.BrokerDataInflowTrend
		(
			MarketCap,
			ObservationDate,
			BrokerCode,
			NetValueInK,
			NetValueInKMA10,
			NetValueInKMA20,
			CreateDate,
			Sector
		)
		select 
		case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 then 'f. 1B+'
		end as MarketCap, 
		ObservationDate,
		BrokerCode,
		sum(NetValue)/1000 as NetValueInK,
		null as NetValueInKMA10,
		null as NetValueInKMA20,
		getdate() as CreateDate,
		c.Token as Sector
		from StockData.v_BrokerReport as a
		inner join StockData.CompanyInfo as b
		on a.ASXCode = b.ASXCode
		inner join LookupRef.StockKeyToken as c
		on a.ASXCode = c.ASXCode
		inner join LookupRef.KeyToken as d
		on c.Token = d.Token
		and d.TokenType = 'Sector'
		where 1 = 1
		and
		case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 then 'f. 1B+'
		end	is not null	
		--and ObservationDate between '2029-10-10' and '2020-10-20'
		--and BrokerCode = 'UBSAus'
		group by 
		case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 then 'f. 1B+'
		end,
		c.Token,
		ObservationDate,
		BrokerCode
		order by 
		case when CleansedMarketCap < 20 then 'a. 0 - 20M'
			when CleansedMarketCap >= 20 and CleansedMarketCap < 50 then 'b. 20 - 50M'
			when CleansedMarketCap >= 50 and CleansedMarketCap < 100 then 'c. 50 - 100M'
			when CleansedMarketCap >= 10 and CleansedMarketCap < 300 then 'd. 100 - 300M'
			when CleansedMarketCap >= 300 and CleansedMarketCap < 1000 then 'e. 300 - 1000M'
			when CleansedMarketCap >= 1000 then 'f. 1B+'
		end,
		ObservationDate

		update a
		set a.NetValueInKMA10 = b.NetValueInKMA10,
			a.NetValueInKMA20 = b.NetValueInKMA20,
			a.NetValueInKMA50 = b.NetValueInKMA50,
			a.NetValueInKMA90 = b.NetValueInKMA90,
			a.NetValueInKMA255 = b.NetValueInKMA255
		from Transform.BrokerDataInflowTrend as a
		inner join
		(
		select
				ObservationDate,
				BrokerCode,
				MarketCap,
				Sector,
				NetValueInKMA10 = avg([NetValueInK]) over (partition by BrokerCode, MarketCap, Sector order by ObservationDate asc rows 9 preceding),
				NetValueInKMA20 = avg([NetValueInK]) over (partition by BrokerCode, MarketCap, Sector order by ObservationDate asc rows 19 preceding),
				NetValueInKMA50 = avg([NetValueInK]) over (partition by BrokerCode, MarketCap, Sector order by ObservationDate asc rows 49 preceding),
				NetValueInKMA90 = avg([NetValueInK]) over (partition by BrokerCode, MarketCap, Sector order by ObservationDate asc rows 89 preceding),
				NetValueInKMA255 = avg([NetValueInK]) over (partition by BrokerCode, MarketCap, Sector order by ObservationDate asc rows 254 preceding)
			from Transform.BrokerDataInflowTrend
		) as b
		on a.ObservationDate = b.ObservationDate
		and a.BrokerCode = b.BrokerCode
		and a.MarketCap = b.MarketCap
		and a.Sector = b.Sector

		update a
		set a.XAO =  b.[Close]
		from Transform.BrokerDataInflowTrend as a
		inner join
		(
			select *
			from StockData.PriceHistory
			where ASXCode = 'XAO.AX'
		) as b
		on a.ObservationDate = b.ObservationDate

		--update a
		--set a.NNetValueInKMA10 = case when NetValueInKMA255 > 0 then (NetValueInKMA10-NetValueInKMA255)*100.0/NetValueInKMA255 else null end,
		--	a.NNetValueInKMA20 = case when NetValueInKMA255 > 0 then (NetValueInKMA20-NetValueInKMA255)*100.0/NetValueInKMA255 else null end,
		--	a.NNetValueInKMA50 = case when NetValueInKMA255 > 0 then (NetValueInKMA50-NetValueInKMA255)*100.0/NetValueInKMA255 else null end
		--from Transform.BrokerDataInflowTrend as a
		
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
