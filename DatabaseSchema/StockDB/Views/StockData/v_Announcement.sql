-- View: [StockData].[v_Announcement]


CREATE view StockData.v_Announcement
as
SELECT [AnnouncementID]
      ,[ASXCode]
      ,[AnnRetriveDateTime]
      ,[AnnDateTime]
      ,[MarketSensitiveIndicator]
      ,[AnnDescr]
      ,[AnnURL]
      ,replace(
		replace(ltrim(rtrim(DA_Utility.dbo.RegexReplace(AnnContent,'[^a-zA-Z0-9\.\,\+\''\s\%\|]',' '))), 
			'  ', 
			' '
			), 
			char(160), ''
		) as AnnContent
      ,[AnnNumPage]
      ,[CreateDate]
      ,[ObservationDate]
  FROM [StockData].[Announcement]

