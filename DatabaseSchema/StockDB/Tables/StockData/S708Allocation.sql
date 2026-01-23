-- Table: [StockData].[S708Allocation]

CREATE TABLE [StockData].[S708Allocation] (
    [S708AllocationID] [int] IDENTITY(1,1) NOT NULL,
    [S708DealID] [int] NOT NULL,
    [AllocationPercBand] [varchar](200) NOT NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [CreatedBy] [varchar](200) NOT NULL,
    [CreatedByUserID] [varchar](50) NULL
);
