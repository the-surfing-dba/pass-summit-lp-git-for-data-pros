-- Grant all privileges to michael.dspain on all databases.
-- Run as root or a user with GRANT OPTION:
--   mysql -u root -p < grant-all-michael-dspain.sql

CREATE USER IF NOT EXISTS 'michael.dspain'@'%' IDENTIFIED BY 'ChangeMe!123';

GRANT ALL PRIVILEGES ON *.* TO 'michael.dspain'@'%' WITH GRANT OPTION;

FLUSH PRIVILEGES;

SHOW GRANTS FOR 'michael.dspain'@'%';
