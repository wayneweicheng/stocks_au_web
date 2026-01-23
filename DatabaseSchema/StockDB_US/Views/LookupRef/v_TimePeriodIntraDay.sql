-- View: [LookupRef].[v_TimePeriodIntraDay]



CREATE view [LookupRef].[v_TimePeriodIntraDay]
as
select '1H' as TimeFrame, * from LookupRef.TimePeriod1Hour
union all
select '30M' as TimeFrame, * from LookupRef.TimePeriod30Min
union all
select '15M' as TimeFrame, * from LookupRef.TimePeriod15Min
union all
select '5M' as TimeFrame, * from LookupRef.TimePeriod5Min
union all
select '1M' as TimeFrame, * from LookupRef.TimePeriod1Min
