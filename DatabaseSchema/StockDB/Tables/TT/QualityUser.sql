-- Table: [TT].[QualityUser]

CREATE TABLE [TT].[QualityUser] (
    [QualityUserID] [int] IDENTITY(1,1) NOT NULL,
    [UserName] [varchar](200) NOT NULL,
    [FriendlyName] [varchar](200) NOT NULL,
    [Rating] [tinyint] NULL,
    [UserType] [varchar](50) NULL,
    [TTUserID] [varchar](50) NULL,
    [CreateDate] [smalldatetime] NOT NULL
,
    CONSTRAINT [pk_ttqualityuser_qualityuserid] PRIMARY KEY (QualityUserID)
);
