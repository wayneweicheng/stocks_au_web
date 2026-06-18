-- Table: [Configuration].[PriceLevelStockGroup]

CREATE TABLE [Configuration].[PriceLevelStockGroup] (
    [GroupID] [int] IDENTITY(1,1) NOT NULL,
    [Name] [nvarchar](100) NOT NULL,
    [Description] [nvarchar](1000) NULL,
    [IsDefault] [bit] NOT NULL DEFAULT ((0)),
    [IsActive] [bit] NOT NULL DEFAULT ((1)),
    [CreatedAt] [datetime2] NOT NULL DEFAULT (sysutcdatetime()),
    [UpdatedAt] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK__PriceLev__149AF30AB8EFBD57] PRIMARY KEY (GroupID)
);

CREATE UNIQUE INDEX [UQ_PriceLevelStockGroup_Name] ON [Configuration].[PriceLevelStockGroup] (Name);