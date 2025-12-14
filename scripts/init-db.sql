-- Create databases for each service
CREATE DATABASE IF NOT EXISTS orderdb;
CREATE DATABASE IF NOT EXISTS userdb;

-- Connect to orderdb
\c orderdb;

-- Orders table is created by Java service automatically via JPA

-- Connect to userdb
\c userdb;

-- Users table is created by Node.js service automatically

-- Grant permissions
GRANT ALL PRIVILEGES ON DATABASE orderdb TO postgres;
GRANT ALL PRIVILEGES ON DATABASE userdb TO postgres;
