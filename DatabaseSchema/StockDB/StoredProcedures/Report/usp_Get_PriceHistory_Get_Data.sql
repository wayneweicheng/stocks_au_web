-- Stored procedure: [Report].[usp_Get_PriceHistory_Get_Data]


  CREATE PROCEDURE [Report].[usp_Get_PriceHistory_Get_Data]
      @pStartDate DATETIME = NULL,
      @pEndDate DATETIME = NULL,
      @pASXCodes NVARCHAR(MAX) = NULL,
      @pbitDebug BIT = 0
  AS
  BEGIN
      SET NOCOUNT ON;

      BEGIN TRY
          IF @pbitDebug = 1
          BEGIN
              PRINT 'Procedure: usp_Get_PriceHistory_Get_Data'
              PRINT 'Parameters:'
              PRINT '  @pStartDate: ' + ISNULL(CONVERT(VARCHAR, @pStartDate, 120), 'NULL')
              PRINT '  @pEndDate: ' + ISNULL(CONVERT(VARCHAR, @pEndDate, 120), 'NULL')
              PRINT '  @pASXCodes: ' + ISNULL(@pASXCodes, 'NULL')
          END

          -- Default date range if not provided (last 2 years)
          IF @pStartDate IS NULL
              SET @pStartDate = DATEADD(YEAR, -2, GETDATE())
          IF @pEndDate IS NULL
              SET @pEndDate = GETDATE()

          -- Create temp table for ASX codes if provided
          CREATE TABLE #ASXCodeFilter (ASXCode VARCHAR(20))

          IF @pASXCodes IS NOT NULL AND @pASXCodes != ''
          BEGIN
              INSERT INTO #ASXCodeFilter (ASXCode)
              SELECT LTRIM(RTRIM(value)) AS ASXCode
              FROM STRING_SPLIT(@pASXCodes, ',')
              WHERE LTRIM(RTRIM(value)) != ''
          END

          SELECT
              ASXCode,
              ObservationDate,
              [Close],
              [Open],
              Low,
              High,
              Volume,
              Value,
              Trades,
              CreateDate,
              ModifyDate
          FROM stockdata.pricehistory ph
          WHERE ObservationDate >= @pStartDate
              AND ObservationDate <= @pEndDate
              AND (@pASXCodes IS NULL OR @pASXCodes = '' OR EXISTS (
                  SELECT 1 FROM #ASXCodeFilter WHERE ASXCode = ph.ASXCode
              ))
          ORDER BY ObservationDate, ASXCode

          DROP TABLE #ASXCodeFilter

          IF @pbitDebug = 1
              PRINT 'Procedure completed successfully'

      END TRY
      BEGIN CATCH
          DECLARE @ErrorMessage NVARCHAR(4000)
          DECLARE @ErrorSeverity INT
          DECLARE @ErrorState INT

          SELECT
              @ErrorMessage = ERROR_MESSAGE(),
              @ErrorSeverity = ERROR_SEVERITY(),
              @ErrorState = ERROR_STATE()

          IF @pbitDebug = 1
          BEGIN
              PRINT 'Error occurred:'
              PRINT 'Error Number: ' + CAST(ERROR_NUMBER() AS VARCHAR)
              PRINT 'Error Message: ' + @ErrorMessage
          END

          IF OBJECT_ID('tempdb..#ASXCodeFilter') IS NOT NULL
              DROP TABLE #ASXCodeFilter

          RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState)
      END CATCH
  END
