-- Table: [Transform].[GammaWallByExpiryDate]

CREATE TABLE [Transform].[GammaWallByExpiryDate] (
    [ExpiryDate] [date] NULL,
    [CallGamma] [decimal](38,6) NULL,
    [PutGamma] [decimal](38,6) NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [ObservationDate] [date] NULL
);
