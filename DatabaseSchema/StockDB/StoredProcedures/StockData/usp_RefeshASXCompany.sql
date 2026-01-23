-- Stored procedure: [StockData].[usp_RefeshASXCompany]







CREATE PROCEDURE [StockData].[usp_RefeshASXCompany]
@pbitDebug AS BIT = 0,
@pintErrorNumber AS INT = 0 OUTPUT
AS
/******************************************************************************
File: usp_RefeshASXCompany.sql
Stored Procedure Name: usp_RefeshASXCompany
Overview
-----------------
usp_RefeshASXCompany

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
Date:		2016-06-04
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
		DECLARE @vchProcedureName AS VARCHAR(100);		SET @vchProcedureName = 'usp_RefeshASXCompany'
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

		--Download the ASXListedCompanies.csv from https://www.asx.com.au/asx/research/listedCompanies.do

		--Open the first and remove the header line and header info added by ASX and run the followings in order

		--begin transaction
		if object_id(N'Working.ASXCompany') is not null
			drop table Working.ASXCompany

		create table Working.ASXCompany
		(
			CompanyName varchar(200),
			ASXCode varchar(10),
			IndustryGroup varchar(2000)
		)

		insert into Working.ASXCompany
		--SELECT substring(CompanyName, 2, len(CompanyName) - 1) as CompanyName, ASXCode, IndustryGroup
		select CompanyName, ASXCode, IndustryGroup
		from
		(
			select replace(CompanyName, '"', '') as CompanyName, replace(ASXCode, '"', '') as ASXCode, replace(IndustryGroup, '"', '') as IndustryGroup
			FROM 
			OPENROWSET
			(
				BULK 'C:\\Data\\ASX Company\\ASXListedCompanies.csv',
				FORMATFILE = 'C:\\Data\\ASX Company\\ASXListedCompany.fmt'
			) AS e
		) as x
		where len(ASXCode) <= 3
			
		update a
		set [ASXcode] = rtrim(ltrim([ASXcode])) + '.AX'
		from Working.ASXCompany as a

		declare @intExpired as int

		select @intExpired = count(*)
		from Stock.ASXCompany as a
		where not exists
		(
			select 1
			from Working.ASXCompany
			where [ASXcode] = a.ASXCode
		)
		and IsDisabled = 0

		if @intExpired > 300
		begin
			raiserror('Number of expired records over threshold', 16, 0)
		end
		else
		begin

			update a
			set IsDisabled = 1
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from Working.ASXCompany
				where [ASXcode] = a.ASXCode
			)
			and IsDisabled = 0

			update a
			set IsDisabled = 0
			from Stock.ASXCompany as a
			where exists
			(
				select 1
				from Working.ASXCompany
				where [ASXcode] = a.ASXCode
			)
			and IsDisabled = 1

			insert into Stock.ASXCompany
			(
				   [ASXCode]
				  ,[ASXCompanyName]
				  ,[CreateDate]
				  ,[IndustryGroup]
				  ,[IsDisabled]
			)
			select
				   a.[ASXcode] as [ASXCode]
				  ,a.[Companyname] as [ASXCompanyName]
				  ,getdate() as [CreateDate]
				  ,[IndustryGroup] as [IndustryGroup]
				  ,0 as [IsDisabled]
			from Working.ASXCompany as a
			where not exists
			(
				select 1
				from Stock.ASXCompany
				where ASXCode = a.[ASXCode]
			)

			update a
			set a.ASXCompanyName = b.CompanyName,
				a.IndustryGroup = b.IndustryGroup
			from Stock.ASXCompany as a
			inner join Working.ASXCompany as b
			on a.ASXCode = b.ASXCode
			where a.ASXCompanyName != b.CompanyName
			or a.IndustryGroup != b.IndustryGroup

			update a
			set a.IndustryGroup = null
			from Stock.ASXCompany as a
			where IndustryGroup in
			(
				'N/A',
				'Not Applic',
				'Unknown'
			)

			delete a
			from [Stock].[ASXAlertSetting] as a
			inner join LookupRef.AlertType as b
			on a.AlertTypeID = b.AlertTypeID
		
			insert into [Stock].[ASXAlertSetting]
			(
				   [ASXCode]
				  ,[AlertTypeID]
				  ,[CreateDate]
				  ,[StockUserID]
			)
			select
				   [ASXCode]
				  ,[AlertTypeID]
				  ,getdate() as [CreateDate]
				  ,1 as [StockUserID]
			from [Stock].[ASXCompany] as a
			cross join 
			(
				select AlertTypeID
				from LookupRef.AlertType
			) as b
			where a.IsDisabled = 0

			delete a
			from [Stock].[StockStats] as a

			dbcc checkident('[Stock].[StockStats]', reseed, 1);

			insert into [Stock].[StockStats]
			(
				   [ASXCode]
				  ,[IsTrendFlatOrUp]
				  ,[LatestPrice]
				  ,[LastUpdateDate]
			)
			select
				   [ASXCode]
				  ,null as [IsTrendFlatOrUp]
				  ,null as [LatestPrice]
				  ,null as [LastUpdateDate]
			from [Stock].[ASXCompany] as a
			where IsDisabled = 0

			insert into [BackTest].[ExecutionSettingStock]
			(
				   [ExecutionSettingID]
				  ,[ASXCode]
				  ,[IsDisabled]
				  ,[CreateDate]
			)
			select
				   1 as [ExecutionSettingID]
				  ,[ASXCode]
				  ,[IsDisabled]
				  ,[CreateDate]
			from [Stock].[ASXCompany] as a
			where not exists
			(
				select 1
				from [BackTest].[ExecutionSettingStock]
				where ASXCode = a.ASXCode
				and ExecutionSettingID = 1
			)

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('C')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('M')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('A')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			insert into StockData.MonitorStock
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			)
			select
			   [ASXCode]
			  ,getdate() as[CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,'A' as [MonitorTypeID]
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from StockData.MonitorStock
				where ASXCode = a.ASXCode
				and MonitorTypeID = 'A'
				
			)
			and a.IsDisabled = 0

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('O')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			insert into StockData.MonitorStock
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			)
			select
			   [ASXCode]
			  ,getdate() as[CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,'O' as [MonitorTypeID]
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from StockData.MonitorStock
				where ASXCode = a.ASXCode
				and MonitorTypeID = 'O'
			)
			and a.IsDisabled = 0

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('P')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			insert into StockData.MonitorStock
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			)
			select
			   [ASXCode]
			  ,getdate() as[CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,'P' as [MonitorTypeID]
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from StockData.MonitorStock
				where ASXCode = a.ASXCode
				and MonitorTypeID = 'P'
			)
			and a.IsDisabled = 0

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('H')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			insert into StockData.MonitorStock
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			)
			select
			   [ASXCode]
			  ,getdate() as[CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,'H' as [MonitorTypeID]
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from StockData.MonitorStock
				where ASXCode = a.ASXCode
				and MonitorTypeID = 'H'
			)
			and a.IsDisabled = 0

			delete a
			from StockData.MonitorStock as a
			where MonitorTypeID in ('E')
			and not exists
			(
				select 1
				from Stock.ASXCompany 
				where ASXCode = a.ASXCode
				and IsDisabled = 0
			)

			insert into StockData.MonitorStock
			(
			   [ASXCode]
			  ,[CreateDate]
			  ,[LastUpdateDate]
			  ,[UpdateStatus]
			  ,[MonitorTypeID]
			)
			select
			   [ASXCode]
			  ,getdate() as[CreateDate]
			  ,null as [LastUpdateDate]
			  ,null as [UpdateStatus]
			  ,'E' as [MonitorTypeID]
			from Stock.ASXCompany as a
			where not exists
			(
				select 1
				from StockData.MonitorStock
				where ASXCode = a.ASXCode
				and MonitorTypeID = 'E'
			)
			and a.IsDisabled = 0

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
