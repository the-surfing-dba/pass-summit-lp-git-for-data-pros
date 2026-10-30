/*
    Fix orphaned users in the current database.

    An orphaned user is a database user whose SID doesn't match any login on
    the instance — common after restoring a DB to a new server. This script:
      1. Lists orphaned users (sp_change_users_login 'Report' is deprecated;
         use sys.database_principals + sys.server_principals instead).
      2. For each SQL user, re-links to a login with the same name if one
         exists (ALTER USER ... WITH LOGIN =).
      3. Emits DROP/CREATE LOGIN scaffolding for any that still have no match.
    Run inside the target user database (USE <db>) as a sysadmin or db_owner
    with ALTER ANY USER + control on the server for the login DDL.
*/

SET NOCOUNT ON;

/*######################################
 ######################################
    Step 1: report orphaned users
 ######################################
 ######################################*/
PRINT '--- Orphaned users in ' + DB_NAME() + ' ---';

SELECT
    dp.name              AS db_user,
    dp.type_desc         AS user_type,
    dp.sid               AS db_user_sid,
    dp.create_date,
    dp.modify_date
FROM sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp
       ON dp.sid = sp.sid
WHERE dp.type IN ('S', 'U', 'G')            -- SQL user, Windows user, Windows group
  AND dp.principal_id > 4                    -- skip dbo/guest/sys/INFORMATION_SCHEMA
  AND dp.authentication_type_desc <> 'NONE'  -- skip users w/o login (contained DB users)
  AND sp.sid IS NULL
ORDER BY dp.name;

/*######################################
 ######################################
    Step 2: auto-relink SQL users to
    same-named logins where possible
 ######################################
 ######################################*/
DECLARE @user  sysname;
DECLARE @sql   nvarchar(max);

DECLARE fix_cur CURSOR LOCAL FAST_FORWARD FOR
SELECT dp.name
FROM sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp
       ON dp.sid = sp.sid
WHERE dp.type = 'S'
  AND dp.principal_id > 4
  AND dp.authentication_type_desc <> 'NONE'
  AND sp.sid IS NULL
  AND EXISTS (SELECT 1 FROM sys.server_principals sp2 WHERE sp2.name = dp.name);

OPEN fix_cur;
FETCH NEXT FROM fix_cur INTO @user;
WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'ALTER USER ' + QUOTENAME(@user)
             + N' WITH LOGIN = ' + QUOTENAME(@user) + N';';
    PRINT @sql;
    EXEC sp_executesql @sql;

    FETCH NEXT FROM fix_cur INTO @user;
END
CLOSE fix_cur;
DEALLOCATE fix_cur;

/*######################################
 ######################################
    Step 3: emit CREATE LOGIN scripts
    for orphans with no matching login
 ######################################
 ######################################*/
PRINT '--- Users still orphaned (no matching login) — review before running ---';

SELECT
    'CREATE LOGIN ' + QUOTENAME(dp.name)
    + CASE dp.type
          WHEN 'S' THEN
              ' WITH PASSWORD = ''ChangeMe!'' + CONVERT(varchar(36), NEWID()),'
              + ' SID = 0x' + CONVERT(varchar(200), dp.sid, 2) + ','
              + ' CHECK_POLICY = ON;'
          ELSE ' FROM WINDOWS;'
      END AS create_login_script,
    'ALTER USER ' + QUOTENAME(dp.name)
    + ' WITH LOGIN = ' + QUOTENAME(dp.name) + ';' AS relink_script
FROM sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp
       ON dp.sid = sp.sid
WHERE dp.type IN ('S', 'U', 'G')
  AND dp.principal_id > 4
  AND dp.authentication_type_desc <> 'NONE'
  AND sp.sid IS NULL
ORDER BY dp.name;

/*######################################
 ######################################
    Step 4: final verification
 ######################################
 ######################################*/
PRINT '--- Remaining orphans after fix ---';

SELECT dp.name, dp.type_desc
FROM sys.database_principals AS dp
LEFT JOIN sys.server_principals AS sp
       ON dp.sid = sp.sid
WHERE dp.type IN ('S', 'U', 'G')
  AND dp.principal_id > 4
  AND dp.authentication_type_desc <> 'NONE'
  AND sp.sid IS NULL
ORDER BY dp.name;
