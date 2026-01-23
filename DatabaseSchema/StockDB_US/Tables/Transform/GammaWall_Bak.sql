-- Table: [Transform].[GammaWall_Bak]

CREATE TABLE [Transform].[GammaWall_Bak] (
    [Strike] [decimal](20,4) NULL,
    [ExpiryDate] [date] NULL,
    [CallGamma] [decimal](38,6) NULL,
    [PutGamma] [decimal](38,6) NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [ObservationDate] [date] NULL
);
