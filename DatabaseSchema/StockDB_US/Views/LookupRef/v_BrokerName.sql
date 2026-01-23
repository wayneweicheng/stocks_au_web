-- View: [LookupRef].[v_BrokerName]


CREATE view LookupRef.v_BrokerName
as
SELECT [BrokerCode]
      ,[BrokerName]
	  ,case when [BrokerScore] >= 1.25 then '*'+[BrokerCode] else [BrokerCode] end as [DisplayBrokerCode]
      ,[BrokerDescr]
      ,[CreateDate]
      ,[BrokerLevel]
      ,[APIBrokerName]
      ,[BrokerScore]
  FROM [LookupRef].[BrokerName]
