-- Table: [Transform].[QuarterlyCashflow]

CREATE TABLE [Transform].[QuarterlyCashflow] (
    [AnnouncementID] [int] NOT NULL,
    [ASXCode] [varchar](10) NOT NULL,
    [AnnDateTime] [smalldatetime] NOT NULL,
    [AnnDescr] [varchar](200) NOT NULL,
    [CleansedAnnContent] [nvarchar](MAX) NULL,
    [Cash] [int] NULL,
    [ReceiptFromCustomer] [int] NULL,
    [RandDCost] [int] NULL,
    [ManufacturingOperatingCost] [int] NULL,
    [AdandMarketingCost] [int] NULL,
    [ExplorationandEvaluationCost] [int] NULL,
    [DevelopmentCost] [int] NULL,
    [ProductionCost] [int] NULL,
    [LeasedAssetCost] [int] NULL,
    [StaffCost] [int] NULL,
    [AdminandCorporateCost] [int] NULL,
    [CashflowFromIssueOfShare] [int] NULL,
    [NQRandDCost] [int] NULL,
    [NQManufacturingOperatingCost] [int] NULL,
    [NQAdandMarketingCost] [int] NULL,
    [NQExplorationandEvaluationCost] [int] NULL,
    [NQDevelopmentCost] [int] NULL,
    [NQProductionCost] [int] NULL,
    [NQLeasedAssetCost] [int] NULL,
    [NQStaffCost] [int] NULL,
    [NQAdminandCorporateCost] [int] NULL,
    [UniqueKey] [int] IDENTITY(1,1) NOT NULL
,
    CONSTRAINT [pk_transform_quarterlycashflow_uniquekey] PRIMARY KEY (UniqueKey)
);
