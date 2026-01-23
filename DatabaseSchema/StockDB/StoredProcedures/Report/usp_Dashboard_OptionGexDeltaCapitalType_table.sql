-- Stored procedure: [Report].[usp_Dashboard_OptionGexDeltaCapitalType_table]


CREATE PROCEDURE [Report].[usp_Dashboard_OptionGexDeltaCapitalType_table]
@pbitDebug AS BIT = 0,
@pvchASXCode as varchar(20)
AS
SET NOCOUNT ON

BEGIN --Proc
    DECLARE @pintErrorNumber as int = 0
    IF @pintErrorNumber <> 0 RETURN @pintErrorNumber

    BEGIN TRY
        DECLARE @vchProcedureName AS VARCHAR(100); SET @vchProcedureName = 'usp_Dashboard_OptionGexDeltaCapitalType'
        DECLARE @vchSchema AS NVARCHAR(50);        SET @vchSchema = 'Report'
        DECLARE @intErrorNumber AS INT;            SET @intErrorNumber = 0
        DECLARE @intErrorSeverity AS INT;          SET @intErrorSeverity = 0
        DECLARE @intErrorState AS INT;             SET @intErrorState = 0   
        DECLARE @vchErrorProcedure AS NVARCHAR(126); SET @vchErrorProcedure = ''
        DECLARE @intErrorLine AS INT;              SET @intErrorLine = 0
        DECLARE @vchErrorMessage AS NVARCHAR(4000); SET @vchErrorMessage = ''

        SET NOCOUNT ON;
        DECLARE @nvchGenericQuery as nvarchar(max)

        select @nvchGenericQuery =
N'
        select *
        into #Temp_v_OptionGexChangeCapitalType
        from StockDB_US.Transform.v_OptionGexChangeCapitalType
        where ASXCode = ''' + @pvchASXCode + '''
        and ObservationDate > dateadd(day, -180, getdate())

        select *
        into #Temp_v_OptionGexChangeCapitalType_Pre
        from StockDB_US.Transform.v_OptionGexChangeCapitalType_Pre
        where ASXCode = ''' + @pvchASXCode + '''
        and ObservationDate > dateadd(day, -180, getdate());

        CREATE CLUSTERED INDEX [IX_Temp_Gex] ON #Temp_v_OptionGexChangeCapitalType(ASXCode, ObservationDate);
        CREATE CLUSTERED INDEX [IX_Temp_Gex_Pre] ON #Temp_v_OptionGexChangeCapitalType_Pre(ASXCode, ObservationDate);

        WITH BaseData AS (
            select 
                x.ObservationDate,
                a.GEXDeltaPerc as BC_GEXDeltaPerc,
                c.GEXDeltaPerc as BC_GEXDeltaPerc_Pre,
                b.GEXDeltaPerc as BP_GEXDeltaPerc,
                d.GEXDeltaPerc as BP_GEXDeltaPerc_Pre,
                a.[Close],
                a.VWAP,
                a.AvgGEXDelta,
                a.NumObs,
                a.ASXCode
            from 
            (
                select ObservationDate, ASXCode
                from #Temp_v_OptionGexChangeCapitalType
                where CapitalType = ''BC''
                union
                select ObservationDate, ASXCode 
                from #Temp_v_OptionGexChangeCapitalType_Pre
                where CapitalType = ''BC''
            ) as x
            left join #Temp_v_OptionGexChangeCapitalType as a
                on x.ASXCode = a.ASXCode
                and x.ObservationDate = a.ObservationDate
                and a.CapitalType = ''BC''
            left join #Temp_v_OptionGexChangeCapitalType as b
                on x.ASXCode = b.ASXCode
                and x.ObservationDate = b.ObservationDate
                and b.CapitalType = ''BP''
            left join #Temp_v_OptionGexChangeCapitalType_Pre as c
                on x.ASXCode = c.ASXCode
                and x.ObservationDate = c.ObservationDate
                and c.CapitalType = ''BC''
            left join #Temp_v_OptionGexChangeCapitalType_Pre as d
                on x.ASXCode = d.ASXCode
                and x.ObservationDate = d.ObservationDate
                and d.CapitalType = ''BP''
        ),
        LaggedData AS (
            SELECT 
                *,
                LAG([Close]) OVER (ORDER BY ObservationDate ASC) as PreviousClose,
                LAG(BC_GEXDeltaPerc) OVER (ORDER BY ObservationDate ASC) as Prev_BC_GEXDeltaPerc
            FROM BaseData
        )
        SELECT 
            ObservationDate,
            CASE 
                WHEN BC_GEXDeltaPerc < 48 
                     AND (BC_GEXDeltaPerc * 1.1) < Prev_BC_GEXDeltaPerc 
                     AND ([Close] * 1.003) > PreviousClose 
                THEN ''Down''

                WHEN BC_GEXDeltaPerc > 52 
                     AND (BC_GEXDeltaPerc * 0.9) > Prev_BC_GEXDeltaPerc 
                     AND ([Close] * 0.997) < PreviousClose 
                THEN ''Up''
                
                ELSE NULL 
            END AS GEXInsight,
            BC_GEXDeltaPerc,
            BC_GEXDeltaPerc_Pre,
            BP_GEXDeltaPerc,
            BP_GEXDeltaPerc_Pre,
            [Close],
            PreviousClose,
            VWAP,
            AvgGEXDelta,
            NumObs,
            ASXCode
        FROM LaggedData
        ORDER BY 
            case when ASXCode = ''SPXW.US'' then 1 else 0 end desc, 
            ASXCode, 
            ObservationDate desc;
'

        --print(@nvchGenericQuery)
        exec sp_executesql @nvchGenericQuery

    END TRY
    BEGIN CATCH
        SELECT  @intErrorNumber = ERROR_NUMBER(), @intErrorSeverity = ERROR_SEVERITY(),
                @intErrorState = ERROR_STATE(), @vchErrorProcedure = ERROR_PROCEDURE(),
                @intErrorLine = ERROR_LINE(), @vchErrorMessage = ERROR_MESSAGE()
    END CATCH

    IF @intErrorNumber <> 0
    BEGIN
        RAISERROR (@vchErrorMessage, @intErrorSeverity, @intErrorState)
    END

    SET @pintErrorNumber = @intErrorNumber
END
