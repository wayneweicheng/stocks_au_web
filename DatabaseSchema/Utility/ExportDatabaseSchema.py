#!/usr/bin/env python3
"""
SQL Server Database Schema Export Tool

Exports database objects (tables, views, stored procedures, functions, triggers)
to individual .sql files organized by object type.

Usage:
    python ExportDatabaseSchema.py --database StockDB --output ./schema
    python ExportDatabaseSchema.py --database StockDB --output ./schema --server 192.168.20.122
"""

import pyodbc
import os
import argparse
import logging
from pathlib import Path
from typing import List, Dict, Tuple

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class SQLServerSchemaExporter:
    """Exports SQL Server database schema to individual files per object."""

    def __init__(self, server: str, database: str, username: str, password: str):
        """
        Initialize the schema exporter.

        Args:
            server: SQL Server hostname or IP
            database: Database name to export
            username: SQL Server username
            password: SQL Server password
        """
        self.server = server
        self.database = database
        self.username = username
        self.password = password
        self.connection = None
        self.cursor = None
        # Statistics tracking
        self.stats = {
            'created': 0,
            'updated': 0,
            'unchanged': 0
        }

    def connect(self) -> None:
        """Establish connection to SQL Server."""
        try:
            connection_string = (
                f"Driver={{ODBC Driver 17 for SQL Server}};"
                f"Server={self.server};"
                f"Database={self.database};"
                f"uid={self.username};"
                f"pwd={self.password};"
            )
            self.connection = pyodbc.connect(connection_string, attrs_before={103: 300})
            self.cursor = self.connection.cursor()
            logger.info(f"Connected to database: {self.database} on server: {self.server}")
        except Exception as e:
            logger.error(f"Failed to connect to database: {e}")
            raise

    def disconnect(self) -> None:
        """Close database connection."""
        if self.cursor:
            self.cursor.close()
        if self.connection:
            self.connection.close()
        logger.info("Disconnected from database")

    def get_tables(self) -> List[Dict[str, str]]:
        """
        Get all user tables in the database.

        Returns:
            List of dictionaries with schema and table names
        """
        query = """
        SELECT
            s.name AS schema_name,
            t.name AS table_name,
            t.object_id
        FROM sys.tables t
        INNER JOIN sys.schemas s ON t.schema_id = s.schema_id
        WHERE t.is_ms_shipped = 0
        ORDER BY s.name, t.name
        """

        self.cursor.execute(query)
        tables = []
        for row in self.cursor.fetchall():
            tables.append({
                'schema_name': row.schema_name,
                'table_name': row.table_name,
                'object_id': row.object_id
            })

        logger.info(f"Found {len(tables)} tables")
        return tables

    def get_views(self) -> List[Dict[str, str]]:
        """
        Get all user views in the database.

        Returns:
            List of dictionaries with schema and view names
        """
        query = """
        SELECT
            s.name AS schema_name,
            v.name AS view_name,
            v.object_id
        FROM sys.views v
        INNER JOIN sys.schemas s ON v.schema_id = s.schema_id
        WHERE v.is_ms_shipped = 0
        ORDER BY s.name, v.name
        """

        self.cursor.execute(query)
        views = []
        for row in self.cursor.fetchall():
            views.append({
                'schema_name': row.schema_name,
                'view_name': row.view_name,
                'object_id': row.object_id
            })

        logger.info(f"Found {len(views)} views")
        return views

    def get_stored_procedures(self) -> List[Dict[str, str]]:
        """
        Get all user stored procedures in the database.

        Returns:
            List of dictionaries with schema and procedure names
        """
        query = """
        SELECT
            s.name AS schema_name,
            p.name AS procedure_name,
            p.object_id
        FROM sys.procedures p
        INNER JOIN sys.schemas s ON p.schema_id = s.schema_id
        WHERE p.is_ms_shipped = 0
        ORDER BY s.name, p.name
        """

        self.cursor.execute(query)
        procedures = []
        for row in self.cursor.fetchall():
            procedures.append({
                'schema_name': row.schema_name,
                'procedure_name': row.procedure_name,
                'object_id': row.object_id
            })

        logger.info(f"Found {len(procedures)} stored procedures")
        return procedures

    def get_functions(self) -> List[Dict[str, str]]:
        """
        Get all user functions in the database.

        Returns:
            List of dictionaries with schema and function names
        """
        query = """
        SELECT
            s.name AS schema_name,
            o.name AS function_name,
            o.object_id,
            o.type_desc
        FROM sys.objects o
        INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
        WHERE o.type IN ('FN', 'IF', 'TF', 'FS', 'FT')  -- Scalar, Inline TVF, Table TVF, Assembly Scalar, Assembly Table
        AND o.is_ms_shipped = 0
        ORDER BY s.name, o.name
        """

        self.cursor.execute(query)
        functions = []
        for row in self.cursor.fetchall():
            functions.append({
                'schema_name': row.schema_name,
                'function_name': row.function_name,
                'object_id': row.object_id,
                'type_desc': row.type_desc
            })

        logger.info(f"Found {len(functions)} functions")
        return functions

    def get_triggers(self) -> List[Dict[str, str]]:
        """
        Get all user triggers in the database.

        Returns:
            List of dictionaries with schema, parent object, and trigger names
        """
        query = """
        SELECT
            s.name AS schema_name,
            OBJECT_NAME(tr.parent_id) AS parent_object,
            tr.name AS trigger_name,
            tr.object_id
        FROM sys.triggers tr
        INNER JOIN sys.objects o ON tr.parent_id = o.object_id
        INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
        WHERE tr.is_ms_shipped = 0
        AND tr.parent_class = 1  -- Object or column trigger
        ORDER BY s.name, OBJECT_NAME(tr.parent_id), tr.name
        """

        self.cursor.execute(query)
        triggers = []
        for row in self.cursor.fetchall():
            triggers.append({
                'schema_name': row.schema_name,
                'parent_object': row.parent_object,
                'trigger_name': row.trigger_name,
                'object_id': row.object_id
            })

        logger.info(f"Found {len(triggers)} triggers")
        return triggers

    def get_table_ddl(self, table: Dict[str, str]) -> str:
        """
        Generate CREATE TABLE DDL for a table including columns, constraints, and indexes.

        Args:
            table: Dictionary with schema_name, table_name, and object_id

        Returns:
            DDL script as string
        """
        schema_name = table['schema_name']
        table_name = table['table_name']
        object_id = table['object_id']

        ddl = []
        ddl.append(f"-- Table: [{schema_name}].[{table_name}]")
        ddl.append("")
        ddl.append(f"CREATE TABLE [{schema_name}].[{table_name}] (")

        # Get columns
        column_query = """
        SELECT
            c.name AS column_name,
            t.name AS data_type,
            c.max_length,
            c.precision,
            c.scale,
            c.is_nullable,
            c.is_identity,
            ISNULL(dc.definition, '') AS default_value,
            c.column_id
        FROM sys.columns c
        INNER JOIN sys.types t ON c.user_type_id = t.user_type_id
        LEFT JOIN sys.default_constraints dc ON c.default_object_id = dc.object_id
        WHERE c.object_id = ?
        ORDER BY c.column_id
        """

        self.cursor.execute(column_query, (object_id,))
        columns = []

        for row in self.cursor.fetchall():
            col_def = f"    [{row.column_name}] [{row.data_type}]"

            # Add length/precision
            if row.data_type in ('varchar', 'char', 'nvarchar', 'nchar', 'binary', 'varbinary'):
                if row.max_length == -1:
                    col_def += "(MAX)"
                elif row.data_type.startswith('n'):
                    col_def += f"({row.max_length // 2})"
                else:
                    col_def += f"({row.max_length})"
            elif row.data_type in ('decimal', 'numeric'):
                col_def += f"({row.precision},{row.scale})"

            # Identity
            if row.is_identity:
                col_def += " IDENTITY(1,1)"

            # Nullable
            col_def += " NOT NULL" if not row.is_nullable else " NULL"

            # Default
            if row.default_value:
                col_def += f" DEFAULT {row.default_value}"

            columns.append(col_def)

        ddl.append(",\n".join(columns))

        # Get primary key
        pk_query = """
        SELECT
            kc.name AS constraint_name,
            STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS columns
        FROM sys.key_constraints kc
        INNER JOIN sys.index_columns ic ON kc.parent_object_id = ic.object_id AND kc.unique_index_id = ic.index_id
        INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE kc.parent_object_id = ? AND kc.type = 'PK'
        GROUP BY kc.name
        """

        self.cursor.execute(pk_query, (object_id,))
        pk_row = self.cursor.fetchone()
        if pk_row:
            ddl.append(f",\n    CONSTRAINT [{pk_row.constraint_name}] PRIMARY KEY ({pk_row.columns})")

        ddl.append(");")
        ddl.append("")

        # Get foreign keys
        fk_query = """
        SELECT
            fk.name AS constraint_name,
            STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY fkc.constraint_column_id) AS columns,
            OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS ref_schema,
            OBJECT_NAME(fk.referenced_object_id) AS ref_table,
            STRING_AGG(rc.name, ', ') WITHIN GROUP (ORDER BY fkc.constraint_column_id) AS ref_columns
        FROM sys.foreign_keys fk
        INNER JOIN sys.foreign_key_columns fkc ON fk.object_id = fkc.constraint_object_id
        INNER JOIN sys.columns c ON fkc.parent_object_id = c.object_id AND fkc.parent_column_id = c.column_id
        INNER JOIN sys.columns rc ON fkc.referenced_object_id = rc.object_id AND fkc.referenced_column_id = rc.column_id
        WHERE fk.parent_object_id = ?
        GROUP BY fk.name, fk.referenced_object_id
        """

        self.cursor.execute(fk_query, (object_id,))
        for fk_row in self.cursor.fetchall():
            ddl.append(
                f"ALTER TABLE [{schema_name}].[{table_name}] "
                f"ADD CONSTRAINT [{fk_row.constraint_name}] "
                f"FOREIGN KEY ({fk_row.columns}) "
                f"REFERENCES [{fk_row.ref_schema}].[{fk_row.ref_table}] ({fk_row.ref_columns});"
            )

        # Get indexes (non-primary key)
        idx_query = """
        SELECT
            i.name AS index_name,
            i.is_unique,
            STRING_AGG(c.name, ', ') WITHIN GROUP (ORDER BY ic.key_ordinal) AS columns
        FROM sys.indexes i
        INNER JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
        INNER JOIN sys.columns c ON ic.object_id = c.object_id AND ic.column_id = c.column_id
        WHERE i.object_id = ?
        AND i.is_primary_key = 0
        AND i.type > 0  -- Exclude heaps
        GROUP BY i.name, i.is_unique
        """

        self.cursor.execute(idx_query, (object_id,))
        for idx_row in self.cursor.fetchall():
            unique_str = "UNIQUE " if idx_row.is_unique else ""
            ddl.append(
                f"CREATE {unique_str}INDEX [{idx_row.index_name}] "
                f"ON [{schema_name}].[{table_name}] ({idx_row.columns});"
            )

        return "\n".join(ddl)

    def get_object_definition(self, object_id: int, object_type: str,
                            schema_name: str, object_name: str) -> str:
        """
        Get the DDL definition for a database object using OBJECT_DEFINITION().

        Args:
            object_id: The object ID
            object_type: Type of object (view, procedure, function, trigger)
            schema_name: Schema name
            object_name: Object name

        Returns:
            DDL script as string
        """
        query = "SELECT OBJECT_DEFINITION(?)"
        self.cursor.execute(query, (object_id,))
        result = self.cursor.fetchone()

        if result and result[0]:
            ddl = []
            ddl.append(f"-- {object_type.capitalize()}: [{schema_name}].[{object_name}]")
            ddl.append("")
            # Normalize line endings to LF (Unix style)
            definition = result[0].replace('\r\n', '\n').replace('\r', '\n')
            ddl.append(definition)
            return "\n".join(ddl)
        else:
            logger.warning(f"Could not retrieve definition for {object_type} [{schema_name}].[{object_name}]")
            return f"-- Definition not available for [{schema_name}].[{object_name}]"

    def export_to_file(self, output_dir: Path, object_type: str,
                      schema_name: str, object_name: str, ddl: str) -> None:
        """
        Export DDL to a file, but only if content has changed.

        Args:
            output_dir: Base output directory
            object_type: Type of object (Tables, Views, etc.)
            schema_name: Schema name
            object_name: Object name
            ddl: DDL script content
        """
        # Create directory structure: output_dir/object_type/schema_name/
        type_dir = output_dir / object_type / schema_name
        type_dir.mkdir(parents=True, exist_ok=True)

        # Sanitize filename
        safe_name = object_name.replace('/', '_').replace('\\', '_')
        file_path = type_dir / f"{safe_name}.sql"

        # Check if file exists and compare content
        should_write = True
        if file_path.exists():
            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    existing_content = f.read()

                # Compare content - if identical, skip write
                if existing_content == ddl:
                    should_write = False
                    self.stats['unchanged'] += 1
                    logger.debug(f"Unchanged (skipped): {file_path}")
                else:
                    self.stats['updated'] += 1
                    logger.debug(f"Updated: {file_path}")
            except Exception as e:
                logger.warning(f"Error reading existing file {file_path}: {e}, will overwrite")
                self.stats['updated'] += 1
        else:
            self.stats['created'] += 1
            logger.debug(f"Created (new): {file_path}")

        # Write file only if changed
        if should_write:
            with open(file_path, 'w', encoding='utf-8') as f:
                f.write(ddl)

    def export_all(self, output_dir: str) -> None:
        """
        Export all database objects to files.

        Args:
            output_dir: Base output directory path
        """
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        logger.info(f"Exporting schema to: {output_path.absolute()}")

        # Export tables
        logger.info("Exporting tables...")
        tables = self.get_tables()
        for table in tables:
            try:
                ddl = self.get_table_ddl(table)
                self.export_to_file(output_path, "Tables", table['schema_name'], table['table_name'], ddl)
            except Exception as e:
                logger.error(f"Error exporting table [{table['schema_name']}].[{table['table_name']}]: {e}")

        # Export views
        logger.info("Exporting views...")
        views = self.get_views()
        for view in views:
            try:
                ddl = self.get_object_definition(
                    view['object_id'], 'view',
                    view['schema_name'], view['view_name']
                )
                self.export_to_file(output_path, "Views", view['schema_name'], view['view_name'], ddl)
            except Exception as e:
                logger.error(f"Error exporting view [{view['schema_name']}].[{view['view_name']}]: {e}")

        # Export stored procedures
        logger.info("Exporting stored procedures...")
        procedures = self.get_stored_procedures()
        for proc in procedures:
            try:
                ddl = self.get_object_definition(
                    proc['object_id'], 'stored procedure',
                    proc['schema_name'], proc['procedure_name']
                )
                self.export_to_file(output_path, "StoredProcedures", proc['schema_name'], proc['procedure_name'], ddl)
            except Exception as e:
                logger.error(f"Error exporting procedure [{proc['schema_name']}].[{proc['procedure_name']}]: {e}")

        # Export functions
        logger.info("Exporting functions...")
        functions = self.get_functions()
        for func in functions:
            try:
                ddl = self.get_object_definition(
                    func['object_id'], 'function',
                    func['schema_name'], func['function_name']
                )
                self.export_to_file(output_path, "Functions", func['schema_name'], func['function_name'], ddl)
            except Exception as e:
                logger.error(f"Error exporting function [{func['schema_name']}].[{func['function_name']}]: {e}")

        # Export triggers
        logger.info("Exporting triggers...")
        triggers = self.get_triggers()
        for trigger in triggers:
            try:
                ddl = self.get_object_definition(
                    trigger['object_id'], 'trigger',
                    trigger['schema_name'], trigger['trigger_name']
                )
                # Organize triggers under their parent object
                parent_folder = f"{trigger['parent_object']}_triggers"
                self.export_to_file(output_path, f"Triggers/{parent_folder}", trigger['schema_name'], trigger['trigger_name'], ddl)
            except Exception as e:
                logger.error(f"Error exporting trigger [{trigger['schema_name']}].[{trigger['trigger_name']}]: {e}")

        logger.info(f"Schema export complete! Total objects exported:")
        logger.info(f"  - Tables: {len(tables)}")
        logger.info(f"  - Views: {len(views)}")
        logger.info(f"  - Stored Procedures: {len(procedures)}")
        logger.info(f"  - Functions: {len(functions)}")
        logger.info(f"  - Triggers: {len(triggers)}")
        logger.info(f"")
        logger.info(f"File statistics:")
        logger.info(f"  - Created (new): {self.stats['created']}")
        logger.info(f"  - Updated: {self.stats['updated']}")
        logger.info(f"  - Unchanged (skipped): {self.stats['unchanged']}")


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description="Export SQL Server database schema to individual .sql files"
    )
    parser.add_argument(
        '--server',
        default='192.168.20.122',
        help='SQL Server hostname or IP address (default: 192.168.20.122)'
    )
    parser.add_argument(
        '--database',
        required=True,
        help='Database name to export'
    )
    parser.add_argument(
        '--username',
        default='BSV_Supp_User',
        help='SQL Server username (default: BSV_Supp_User)'
    )
    parser.add_argument(
        '--password',
        default='!ntegr!ty',
        help='SQL Server password'
    )
    parser.add_argument(
        '--output',
        default='./schema_export',
        help='Output directory for exported schema files (default: ./schema_export)'
    )
    parser.add_argument(
        '--verbose',
        action='store_true',
        help='Enable verbose logging'
    )

    args = parser.parse_args()

    # Set logging level
    if args.verbose:
        logger.setLevel(logging.DEBUG)

    # Create exporter
    exporter = SQLServerSchemaExporter(
        server=args.server,
        database=args.database,
        username=args.username,
        password=args.password
    )

    try:
        # Connect to database
        exporter.connect()

        # Export all objects
        exporter.export_all(args.output)

    except Exception as e:
        logger.error(f"Export failed: {e}")
        raise
    finally:
        # Disconnect
        exporter.disconnect()


if __name__ == '__main__':
    main()
