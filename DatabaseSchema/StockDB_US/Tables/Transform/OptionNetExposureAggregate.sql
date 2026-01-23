-- Table: [Transform].[OptionNetExposureAggregate]

CREATE TABLE [Transform].[OptionNetExposureAggregate] (
    [Strike] [decimal](20,4) NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [ObservationDate] [date] NULL,
    [CallGamma] [decimal](38,6) NULL,
    [PutGamma] [decimal](38,6) NULL,
    [NetGamma] [decimal](38,6) NULL,
    [Exposure] [varchar](8) NOT NULL,
    [TotalCallGamma] [decimal](38,6) NULL,
    [TotalPutGamma] [decimal](38,6) NULL,
    [TotalNetGamma] [decimal](38,6) NULL,
    [CloseChange] [decimal](21,4) NULL,
    [TotalNetGammaChange] [decimal](38,6) NULL
);
