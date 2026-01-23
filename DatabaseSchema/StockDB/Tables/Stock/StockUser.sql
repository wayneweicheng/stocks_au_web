-- Table: [Stock].[StockUser]

CREATE TABLE [Stock].[StockUser] (
    [UserID] [int] IDENTITY(1,1) NOT NULL,
    [UserName] [varchar](200) NOT NULL,
    [Email] [varchar](200) NULL,
    [CreateDate] [smalldatetime] NOT NULL,
    [IsDisabled] [bit] NOT NULL,
    [KeyEventEmail] [varchar](200) NULL,
    [Mobile] [varchar](200) NULL,
    [UserRole] [varchar](50) NULL
,
    CONSTRAINT [pk_stockstockuser_userid] PRIMARY KEY (UserID)
);
