-- View: [Transform].[v_OptionPutCallExposure]


CREATE view Transform.v_OptionPutCallExposure
as
SELECT a.[ASXCode]
    ,a.[ObservationDate]
    ,a.[PorC]
    ,b.[Delta] as DeltaExposure
	,a.Delta as GammaExposure
FROM [StockDB_US].[Transform].[OptionGEXByPutCall] as a
inner join [StockDB_US].[Transform].[OptionDEXByPutCall] as b
on a.ASXCode = b.ASXCode
and a.ObservationDate = b.ObservationDate
and a.PorC = b.PorC
where a.ASXCode is not null