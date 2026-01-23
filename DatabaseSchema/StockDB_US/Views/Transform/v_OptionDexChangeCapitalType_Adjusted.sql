-- View: [Transform].[v_OptionDexChangeCapitalType_Adjusted]












CREATE view [Transform].[v_OptionDexChangeCapitalType_Adjusted]
as
SELECT [ObservationDate]
      ,[ASXCode]
      ,[GEXDelta] as [DEXDelta]
      ,[CapitalType]
      ,[Close]
      ,[VWAP]
FROM Transform.OptionGEXChangeCapitalType_Pre
