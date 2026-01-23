-- Table: [Utility].[EmailHistory]

CREATE TABLE [Utility].[EmailHistory] (
    [EmailHistoryID] [int] IDENTITY(1,1) NOT NULL,
    [EmailRecipient] [varchar](200) NOT NULL,
    [EmailSubject] [varchar](2000) NOT NULL,
    [EmailBody] [varchar](MAX) NOT NULL,
    [StatusID] [char](1) NOT NULL,
    [ErrorMessage] [varchar](MAX) NULL,
    [EventTypeID] [tinyint] NOT NULL,
    [CreateDate] [datetime] NOT NULL,
    [EmailSentDate] [datetime] NULL
,
    CONSTRAINT [pk_utilityemailhistory_emailhistoryid] PRIMARY KEY (EmailHistoryID)
);
