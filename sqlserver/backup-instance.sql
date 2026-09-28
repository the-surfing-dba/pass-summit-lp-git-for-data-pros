/*
    Striped FULL backup of [YoMomma] to 8 files on D:\Backup.
    COMPRESSION + CHECKSUM + STATS = 5 for a fast, verifiable backup.
    Filename pattern: YoMomma_FULL_yyyyMMdd_HHmmss_<n>of8.bak
*/

DECLARE @db          sysname       = N'YoMomma';
DECLARE @dir         nvarchar(260) = N'D:\Backup\';
DECLARE @stamp       nvarchar(20)  = REPLACE(CONVERT(varchar(20), SYSDATETIME(), 120), ':', '');
DECLARE @basename    nvarchar(260) = @db + N'_FULL_' + REPLACE(REPLACE(@stamp, '-', ''), ' ', '_');
DECLARE @sql         nvarchar(max);

SET @sql = N'BACKUP DATABASE ' + QUOTENAME(@db) + N' TO '
    + N'DISK = N''' + @dir + @basename + N'_1of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_2of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_3of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_4of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_5of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_6of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_7of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_8of8.bak'' '
    + N'WITH COMPRESSION, CHECKSUM, INIT, FORMAT, STATS = 5, '
    + N'NAME = N''' + @db + N' FULL backup ' + @stamp + N''';';

PRINT @sql;
EXEC sp_executesql @sql;

/*
    Verify the striped set is readable end-to-end.
*/
DECLARE @verify nvarchar(max) = N'RESTORE VERIFYONLY FROM '
    + N'DISK = N''' + @dir + @basename + N'_1of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_2of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_3of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_4of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_5of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_6of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_7of8.bak'', '
    + N'DISK = N''' + @dir + @basename + N'_8of8.bak'' '
    + N'WITH CHECKSUM;';

PRINT @verify;
EXEC sp_executesql @verify;
