-- Stored procedure: [DataMaintenance].[usp_RefreshTransformBreathLine]





create PROCEDURE [DataMaintenance].[usp_RefreshTransformBreathLine]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefreshTransformBreathLine.sql
Stored Procedure Name: usp_RefreshTransformBreathLine
Overview
-----------------
usp_RefreshTransformBreathLine

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
Date:		2020-08-09
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefreshTransformBreathLine'
		DECLARE @vchSchema AS NVARCHAR(50);				SET @vchSchema = 'DataMaintenance'
		DECLARE @intErrorNumber AS INT;					SET @intErrorNumber = 0
		DECLARE @intErrorSeverity AS INT;				SET @intErrorSeverity = 0
		DECLARE @intErrorState AS INT;					SET @intErrorState = 0	
		DECLARE @vchErrorProcedure AS NVARCHAR(126);	SET @vchErrorProcedure = ''
		DECLARE @intErrorLine AS INT;					SET @intErrorLine  = 0
		DECLARE @vchErrorMessage AS NVARCHAR(4000);		SET @vchErrorMessage = ''

		set nocount on;

		--Normal varible declarations

		--Code goes here 
		truncate table Transform.BreathLine 

		insert into Transform.BreathLine
		(
			ObservationDate,
			NumAdv,
			NumDec,
			Breath,
			SPX,
			TodayChange,
			CreateDate
		)
		select
			a.ObservationDate,
			sum(case when a.TodayChange > 0 then 1 else 0 end) as NumAdv,
			sum(case when a.TodayChange < 0 then 1 else 0 end) as NumDec,
			null as Breath,
			c.[Close] as SPX,
			c.TodayChange as TodayChange,
			getdate() as CreateDate
		from StockData.v_PriceHistory as a
		inner join dbo.[Component Stocks - SPX500] as b
		on a.ASXCode = b.ASXCode
		inner join StockDB.StockData.v_PriceHistory as c
		on a.ObservationDate = c.ObservationDate
		and c.ASXCode = 'SPX'
		where a.ObservationDate > '2017-03-05'
		group by a.ObservationDate, c.[Close], c.TodayChange
		order by a.ObservationDate

		update a
		set Breath = NumAdv - NumDec
		from Transform.BreathLine as a
		inner join
		(
			select min(ObservationDate) as ObservationDate
			from Transform.BreathLine
		) as b
		on a.ObservationDate = b.ObservationDate

		declare @intNum as int  = 1

		while @intNum > 0
		begin
			update a
			set Breath = NumAdv - NumDec + PrevBreath
			from (
				select lag(Breath) over (partition by 1 order by ObservationDate) as PrevBreath, *
				from Transform.BreathLine
			) as a
			where a.PrevBreath is not null
			and a.Breath is null

			select @intNum = @@ROWCOUNT
		end


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
