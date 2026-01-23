-- Table: [Transform].[GammaWall]

CREATE TABLE [Transform].[GammaWall] (
    [Strike] [decimal](20,4) NULL,
    [ExpiryDate] [date] NULL,
    [CallGamma] [decimal](38,6) NULL,
    [PutGamma] [decimal](38,6) NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [Close] [decimal](20,4) NOT NULL,
    [ObservationDate] [date] NULL
);

CREATE INDEX [IX_GammaWall_ASXCode_ObsDate] ON [Transform].[GammaWall] (ASXCode, ObservationDate);
CREATE INDEX [IX_GammaWall_ASXCode_ObsDate_Covering] ON [Transform].[GammaWall] (CallGamma, PutGamma, Close, ASXCode, ObservationDate);
CREATE INDEX [IX_GammaWall_ASXCode_ObsDate_Strike] ON [Transform].[GammaWall] (ExpiryDate, CallGamma, PutGamma, Close, ASXCode, ObservationDate, Strike);