-- Table: [dbo].[DAU_UserTableAccess]

CREATE TABLE [dbo].[DAU_UserTableAccess] (
    [AccessID] [int] IDENTITY(1,1) NOT NULL,
    [DatabaseName] [varchar](200) NULL,
    [UserName] [varchar](200) NULL,
    [ObjectName] [varchar](200) NULL,
    [AccessType] [varchar](20) NULL
);
