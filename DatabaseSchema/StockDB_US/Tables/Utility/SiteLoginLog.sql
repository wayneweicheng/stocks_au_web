-- Table: [Utility].[SiteLoginLog]

CREATE TABLE [Utility].[SiteLoginLog] (
    [SiteLoginLogID] [int] IDENTITY(1,1) NOT NULL,
    [Site] [varchar](200) NULL,
    [LoginName] [varchar](200) NULL,
    [LoginDate] [date] NULL,
    [LoginDateTime] [smalldatetime] NULL
,
    CONSTRAINT [pk_utilitysiteloginlog_siteloginid] PRIMARY KEY (SiteLoginLogID)
);
