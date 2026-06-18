-- Table: [Configuration].[PriceLevelStockGroupMember]

CREATE TABLE [Configuration].[PriceLevelStockGroupMember] (
    [GroupMemberID] [int] IDENTITY(1,1) NOT NULL,
    [GroupID] [int] NOT NULL,
    [ASXCode] [varchar](32) NOT NULL,
    [CreatedAt] [datetime2] NOT NULL DEFAULT (sysutcdatetime())
,
    CONSTRAINT [PK__PriceLev__344812B26334A3F8] PRIMARY KEY (GroupMemberID)
);

ALTER TABLE [Configuration].[PriceLevelStockGroupMember] ADD CONSTRAINT [FK_PriceLevelStockGroupMember_PriceLevelStockGroup] FOREIGN KEY (GroupID) REFERENCES [Configuration].[PriceLevelStockGroup] (GroupID);
CREATE UNIQUE INDEX [UQ_PriceLevelStockGroupMember_GroupCode] ON [Configuration].[PriceLevelStockGroupMember] (GroupID, ASXCode);