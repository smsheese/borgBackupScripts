#!/bin/bash

# ============================================================================
# DATABASE ENGINE TYPE CHECKER
# ============================================================================
# This script checks which storage engine your databases use
# InnoDB = No locking during backup (recommended)
# MyISAM = Will lock during backup (consider migrating)

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=========================================="
echo "  Database Engine Type Checker"
echo "=========================================="
echo ""

# Check MySQL credentials from .env if exists
if [ -f "../.env" ]; then
    source "../.env"
    DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="${DB_PORT:-3306}"
    DB_USER="${DB_USER:-root}"
    DB_PASS="${DB_PASS:-root}"
else
    # Try to get from environment
    DB_HOST="${DB_HOST:-localhost}"
    DB_PORT="${DB_PORT:-3306}"
    DB_USER="${DB_USER:-root}"
    DB_PASS="${DB_PASS:-root}"
fi

# Test MySQL connection
echo "Testing MySQL connection..."
if ! mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" &>/dev/null; then
    echo -e "${RED}ERROR: Could not connect to MySQL${NC}"
    echo "Please check your credentials in .env file"
    exit 1
fi

echo -e "${GREEN}✓ Connected successfully${NC}"
echo ""

# Get database engines summary
echo "=========================================="
echo "Storage Engine Summary"
echo "=========================================="
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "
    SELECT 
        engine as 'Storage Engine',
        COUNT(*) as 'Number of Tables',
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as 'Size (MB)'
    FROM information_schema.tables
    WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    GROUP BY engine
    ORDER BY SUM(data_length + index_length) DESC;"

echo ""
echo "=========================================="
echo "Database Details by Engine"
echo "=========================================="
mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -e "
    SELECT 
        engine as 'Storage Engine',
        table_schema as 'Database',
        COUNT(*) as 'Tables',
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as 'Size (MB)'
    FROM information_schema.tables
    WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    GROUP BY engine, table_schema
    ORDER BY engine, SUM(data_length + index_length) DESC;"

echo ""
echo "=========================================="
echo "Performance Impact Assessment"
echo "=========================================="

# Check for MyISAM tables
MYISAM_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -sN -e "
    SELECT COUNT(*) 
    FROM information_schema.tables 
    WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND engine = 'MyISAM';" 2>/dev/null || echo "0")

MYISAM_SIZE=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -sN -e "
    SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2)
    FROM information_schema.tables
    WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND engine = 'MyISAM';" 2>/dev/null || echo "0")

INNODB_COUNT=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -sN -e "
    SELECT COUNT(*) 
    FROM information_schema.tables 
    WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND engine = 'InnoDB';" 2>/dev/null || echo "0")

INNODB_SIZE=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -sN -e "
    SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2)
    FROM information_schema.tables
    WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys')
    AND engine = 'InnoDB';" 2>/dev/null || echo "0")

# Total size
TOTAL_SIZE=$(mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" -sN -e "
    SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2)
    FROM information_schema.tables
    WHERE table_schema NOT IN ('information_schema', 'performance_schema', 'mysql', 'sys');" 2>/dev/null || echo "0")

echo ""
echo "InnoDB Tables:"
echo -e "  Count: ${GREEN}$INNODB_COUNT${NC}"
echo -e "  Size:  ${GREEN}${INNODB_SIZE} MB${NC}"
echo -e "  Impact: ${GREEN}NO LOCKING - Safe for hourly backups${NC}"

echo ""
if [ "$MYISAM_COUNT" -gt 0 ]; then
    echo -e "MyISAM Tables:"
    echo -e "  Count: ${RED}$MYISAM_COUNT${NC}"
    echo -e "  Size:  ${RED}${MYISAM_SIZE} MB${NC}"
    echo -e "  Impact: ${RED}WILL LOCK during backup${NC}"
    echo ""
    echo -e "${YELLOW}⚠️  RECOMMENDATION:${NC}"
    echo "  1. Consider migrating MyISAM tables to InnoDB"
    echo "  2. Or reduce backup frequency to every 6-12 hours"
    echo "  3. Schedule backups during low-traffic hours"
else
    echo -e "MyISAM Tables:"
    echo -e "  Count: ${GREEN}$MYISAM_COUNT${NC}"
    echo -e "  Size:  ${GREEN}${MYISAM_SIZE} MB${NC}"
    echo -e "  Impact: ${GREEN}No locking issues${NC}"
fi

echo ""
echo "Total Database Size: ${TOTAL_SIZE} MB"
echo ""

# Estimate backup duration
echo "=========================================="
echo "Estimated Backup Duration"
echo "=========================================="

if [ "$(echo "$TOTAL_SIZE > 100" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
    echo -e "Database Size: ${RED}> 100 MB${NC}"
    echo "Estimated Duration: 30-60 seconds"
    echo -e "Impact: ${GREEN}Negligible${NC}"
elif [ "$(echo "$TOTAL_SIZE > 500" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
    echo -e "Database Size: ${YELLOW}> 500 MB${NC}"
    echo "Estimated Duration: 1-5 minutes"
    echo -e "Impact: ${GREEN}Minimal${NC}"
elif [ "$(echo "$TOTAL_SIZE > 2000" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
    echo -e "Database Size: ${YELLOW}> 2 GB${NC}"
    echo "Estimated Duration: 5-15 minutes"
    echo -e "Impact: ${YELLOW}Low to Moderate${NC}"
elif [ "$(echo "$TOTAL_SIZE > 5000" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
    echo -e "Database Size: ${RED}> 5 GB${NC}"
    echo "Estimated Duration: 15-30 minutes"
    echo -e "Impact: ${YELLOW}Moderate${NC}"
    echo -e "${YELLOW}⚠️  Consider: Reduce frequency to every 6 hours${NC}"
else
    echo -e "Database Size: ${RED}> 10 GB${NC}"
    echo "Estimated Duration: 30-60+ minutes"
    echo -e "Impact: ${RED}Significant${NC}"
    echo -e "${RED}⚠️  Consider: Reduce frequency to every 12-24 hours${NC}"
fi

echo ""
echo "=========================================="
echo "Hourly Backup Recommendation"
echo "=========================================="

# Determine recommendation
if [ "$MYISAM_COUNT" -eq 0 ] && [ "$(echo "$TOTAL_SIZE < 2000" | bc -l 2>/dev/null || echo 1)" = "1" ]; then
    echo -e "${GREEN}✅ HOURLY BACKUPS RECOMMENDED${NC}"
    echo "Your databases are InnoDB and reasonably sized."
    echo "Hourly backups will have no locking and minimal impact."
elif [ "$MYISAM_COUNT" -gt 0 ]; then
    echo -e "${YELLOW}⚠️  CAUTION: MyISAM tables detected${NC}"
    echo "Consider migrating to InnoDB or reducing frequency."
    echo "If keeping MyISAM: backup every 6-12 hours instead."
elif [ "$(echo "$TOTAL_SIZE > 5000" | bc -l 2>/dev/null || echo 0)" = "1" ]; then
    echo -e "${YELLOW}⚠️  CAUTION: Large databases${NC}"
    echo "Consider reducing frequency to every 6-12 hours."
    echo "Or schedule backups during low-traffic hours."
else
    echo -e "${GREEN}✅ HOURLY BACKUPS SHOULD WORK${NC}"
    echo "Monitor performance and adjust if needed."
fi

echo ""
echo "=========================================="
echo "Next Steps"
echo "=========================================="
echo "1. Review the results above"
echo "2. Read: docs/DATABASE_BACKUP_PERFORMANCE.md"
echo "3. If concerned, reduce backup frequency in:"
echo "   /etc/systemd/system/borgmatic-databases.timer"
echo "4. Monitor after first few backups:"
echo "   journalctl -u borgmatic-databases -f"
echo ""