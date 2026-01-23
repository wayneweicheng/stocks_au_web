-- Table: [dbo].[DAU_UserAccessRights]

CREATE TABLE [dbo].[DAU_UserAccessRights] (
    [databasename] [varchar](200) NOT NULL,
    [username] [varchar](200) NOT NULL,
    [rolename] [varchar](200) NOT NULL,
    [defaultschema] [varchar](200) NULL,
    [loginname] [varchar](200) NULL,
    [isRole] [int] NULL,
    [isGroup] [int] NULL
,
    CONSTRAINT [PK_DAU_UserAccessRights] PRIMARY KEY (databasename, username, rolename)
);
