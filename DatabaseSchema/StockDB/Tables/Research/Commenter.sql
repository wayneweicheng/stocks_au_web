-- Table: [Research].[Commenter]

CREATE TABLE [Research].[Commenter] (
    [CommenterID] [int] IDENTITY(1,1) NOT NULL,
    [Name] [nvarchar](100) NOT NULL,
    [Description] [nvarchar](500) NULL,
    [CreatedAt] [datetime] NOT NULL DEFAULT (getdate()),
    [IsActive] [bit] NOT NULL DEFAULT ((1))
,
    CONSTRAINT [PK__Commente__D903DF6D379AB6DA] PRIMARY KEY (CommenterID)
);

CREATE UNIQUE INDEX [UQ__Commente__737584F69120FD2B] ON [Research].[Commenter] (Name);