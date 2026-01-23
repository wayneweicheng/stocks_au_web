-- Table: [dbo].[DAU_UserAccessWrites]

CREATE TABLE [dbo].[DAU_UserAccessWrites] (
    [databasename] [varchar](200) NOT NULL,
    [username] [varchar](200) NOT NULL,
    [rolename] [varchar](200) NOT NULL,
    [defaultschema] [varchar](200) NULL,
    [loginname] [varchar](200) NULL
);
