#!/usr/bin/env python3
"""
fb_migration_tests_firebird_driver.py

Test automatici post-migrazione Firebird usando 'firebird-driver':
- verifica esistenza tabelle
- conteggi record
- checksum/hash per confronto dati (campionamento opzionale)
- esistenza sequence (RDB$GENERATORS) e trigger (RDB$TRIGGERS)
- violazioni FK (sample)
- output JSON con PASS/FAIL e dettagli

Usage:
  pip install firebird-driver
  python fb_migration_tests_firebird_driver.py --database /path/to/db.fdb --user SYSDBA --password masterkey --out results.json
"""

import argparse
import json
import hashlib
import sys
from typing import Dict, Any, List, Tuple

try:
    from firebird.driver import connect
except Exception as e:
    print("Missing dependency 'firebird-driver'. Install with: pip install firebird-driver")
    raise

# ---------- Utility helpers ----------

def md5_of_row_values(row: Tuple) -> str:
    parts = []
    for v in row:
        if v is None:
            parts.append('<NULL>')
        else:
            parts.append(str(v))
    s = '|'.join(parts)
    return hashlib.md5(s.encode('utf-8')).hexdigest()

def run_query(conn, sql: str, params: Tuple = ()) -> List[Tuple]:
    cur = conn.cursor()
    cur.execute(sql, params)
    rows = cur.fetchall()
    cur.close()
    return rows

# ---------- Tests implementations ----------

def list_user_tables(conn) -> List[str]:
    sql = """
    SELECT TRIM(RDB$RELATION_NAME)
    FROM RDB$RELATIONS
    WHERE RDB$SYSTEM_FLAG = 0
      AND RDB$VIEW_BLR IS NULL
    ORDER BY RDB$RELATION_NAME
    """
    rows = run_query(conn, sql)
    return [r[0] for r in rows]

def table_row_count(conn, table: str) -> int:
    sql = f"SELECT COUNT(*) FROM {table}"
    rows = run_query(conn, sql)
    return rows[0][0] if rows else 0

def table_checksum(conn, table: str, sample_limit: int = None) -> str:
    cur = conn.cursor()
    cur.execute("SELECT TRIM(RDB$FIELD_NAME) FROM RDB$RELATION_FIELDS WHERE RDB$RELATION_NAME = ? ORDER BY RDB$FIELD_POSITION", (table,))
    cols = [r[0] for r in cur.fetchall()]
    if not cols:
        cur.close()
        return ''
    # col_list = ','.join(cols)
    # dopo aver ottenuto cols
    col_list = ','.join([f'"{c}"' for c in cols])   # QUOTE ogni nome di colonna

    sql = f"SELECT {col_list} FROM {table}"
    if sample_limit and isinstance(sample_limit, int):
        sql = f"SELECT FIRST {sample_limit} {col_list} FROM {table}"
    cur.execute(sql)
    md5_acc = hashlib.md5()
    for row in cur:
        row_md5 = md5_of_row_values(row)
        md5_acc.update(row_md5.encode('utf-8'))
    cur.close()
    return md5_acc.hexdigest()

def sequences_exist(conn, expected_seq_names: List[str]) -> Dict[str, bool]:
    res = {}
    cur = conn.cursor()
    for seq in expected_seq_names:
        cur.execute("SELECT COUNT(*) FROM RDB$GENERATORS WHERE RDB$GENERATOR_NAME = ?", (seq.upper(),))
        cnt = cur.fetchone()[0]
        res[seq] = (cnt > 0)
    cur.close()
    return res

def triggers_exist(conn, expected_trg_names: List[str]) -> Dict[str, bool]:
    res = {}
    cur = conn.cursor()
    for trg in expected_trg_names:
        cur.execute("SELECT COUNT(*) FROM RDB$TRIGGERS WHERE RDB$TRIGGER_NAME = ?", (trg.upper(),))
        cnt = cur.fetchone()[0]
        res[trg] = (cnt > 0)
    cur.close()
    return res

def fk_violations(conn, table: str) -> List[Dict[str, Any]]:
    violations = []
    cur = conn.cursor()
    sql_fk = """
    SELECT rc.RDB$CONSTRAINT_NAME, rf.RDB$CONST_NAME_UQ
    FROM RDB$RELATION_CONSTRAINTS rc
    LEFT JOIN RDB$REF_CONSTRAINTS rf ON rc.RDB$CONSTRAINT_NAME = rf.RDB$CONSTRAINT_NAME
    WHERE rc.RDB$RELATION_NAME = ?
      AND rc.RDB$CONSTRAINT_TYPE = 'FOREIGN KEY'
    """
    cur.execute(sql_fk, (table,))
    fks = cur.fetchall()
    for fk in fks:
        fk_name = fk[0].strip()
        parent_constraint = fk[1]
        # get child index name
        cur2 = conn.cursor()
        cur2.execute("SELECT RDB$INDEX_NAME FROM RDB$RELATION_CONSTRAINTS WHERE RDB$CONSTRAINT_NAME = ?", (fk_name,))
        row = cur2.fetchone()
        if not row or not row[0]:
            cur2.close()
            continue
        child_index = row[0].strip()
        # parent constraint -> parent index -> parent table
        cur2.execute("SELECT RDB$CONST_NAME_UQ FROM RDB$REF_CONSTRAINTS WHERE RDB$CONSTRAINT_NAME = ?", (fk_name,))
        pr = cur2.fetchone()
        if not pr or not pr[0]:
            cur2.close()
            continue
        parent_constraint = pr[0].strip()
        cur2.execute("SELECT RDB$INDEX_NAME FROM RDB$RELATION_CONSTRAINTS WHERE RDB$CONSTRAINT_NAME = ?", (parent_constraint,))
        pr2 = cur2.fetchone()
        if not pr2 or not pr2[0]:
            cur2.close()
            continue
        parent_index = pr2[0].strip()
        # index segments -> columns
        cur2.execute("SELECT RDB$FIELD_NAME FROM RDB$INDEX_SEGMENTS WHERE RDB$INDEX_NAME = ? ORDER BY RDB$FIELD_POSITION", (child_index,))
        child_cols = [r[0].strip() for r in cur2.fetchall()]
        cur2.execute("SELECT RDB$FIELD_NAME FROM RDB$INDEX_SEGMENTS WHERE RDB$INDEX_NAME = ? ORDER BY RDB$FIELD_POSITION", (parent_index,))
        parent_cols = [r[0].strip() for r in cur2.fetchall()]
        cur2.close()
        if not child_cols or not parent_cols or len(child_cols) != len(parent_cols):
            continue
        # parent table name
        cur3 = conn.cursor()
        cur3.execute("SELECT RDB$RELATION_NAME FROM RDB$RELATION_CONSTRAINTS WHERE RDB$CONSTRAINT_NAME = ?", (parent_constraint,))
        pr_table_row = cur3.fetchone()
        if not pr_table_row or not pr_table_row[0]:
            cur3.close()
            continue
        parent_table = pr_table_row[0].strip()
        cur3.close()
        # build join condition
        conds = []
        for ccol, pcol in zip(child_cols, parent_cols):
            conds.append(f"c.{ccol} = p.{pcol}")
        join_cond = " AND ".join(conds)
        where_nulls = " OR ".join([f"p.{pc} IS NULL" for pc in parent_cols])
        sql_check = f"SELECT c.* FROM {table} c LEFT JOIN {parent_table} p ON {join_cond} WHERE {where_nulls}"
        cur4 = conn.cursor()
        try:
            cur4.execute(sql_check)
            bad = cur4.fetchmany(10)
            if bad:
                violations.append({
                    "fk_constraint": fk_name,
                    "parent_table": parent_table,
                    "child_table": table,
                    "child_columns": child_cols,
                    "parent_columns": parent_cols,
                    "sample_violations": [list(r) for r in bad]
                })
        except Exception as ex:
            violations.append({
                "fk_constraint": fk_name,
                "error": str(ex)
            })
        finally:
            cur4.close()
    cur.close()
    return violations

# ---------- Main orchestration ----------

def run_tests(cfg: Dict[str, Any]) -> Dict[str, Any]:
    out = {
        "connection": {"database": cfg["database"], "user": cfg["user"]},
        "tables": {},
        "summary": {}
    }
    conn = None

    # With this block:
    try:
        # firebird-driver accepts 'database' (path) and optional host/port
        conn = connect(
            database=cfg["database"],
            user=cfg.get("user", "SYSDBA"),
            password=cfg.get("password", ""),
            charset=cfg.get("charset", "UTF8")
        )
    except TypeError:
        # fallback for older/newer API variants: try positional connect via URL-like string
        try:
            # Example: 'localhost:/path/to/db.fdb' or '/absolute/path/to/db.fdb'
            conn = connect(cfg["database"], cfg.get("user", "SYSDBA"), cfg.get("password", ""))
        except Exception as e:
            out["error"] = f"Connection failed (fallback): {str(e)}"
            return out
    except Exception as e:
        out["error"] = f"Connection failed: {str(e)}"
        return out

    try:
        tables = cfg.get("tables")
        if not tables:
            tables = list_user_tables(conn)
        for t in tables:
            tname = t if isinstance(t, str) else t.get("name")
            table_report = {"exists": False, "row_count": None, "checksum": None,
                            "sequences": {}, "triggers": {}, "fk_violations": [], "status": "FAIL", "details": []}
            user_tables = list_user_tables(conn)
            if tname not in user_tables:
                table_report["details"].append("Table not found in target DB")
                out["tables"][tname] = table_report
                continue
            table_report["exists"] = True
            try:
                cnt = table_row_count(conn, tname)
                table_report["row_count"] = cnt
            except Exception as e:
                table_report["details"].append(f"Count failed: {str(e)}")
            try:
                sample_limit = cfg.get("sample_limit")
                ch = table_checksum(conn, tname, sample_limit)
                table_report["checksum"] = ch
            except Exception as e:
                table_report["details"].append(f"Checksum failed: {str(e)}")
            # detect PK fields
            pk_fields = []
            try:
                cur = conn.cursor()
                cur.execute("SELECT RDB$INDEX_NAME FROM RDB$RELATION_CONSTRAINTS WHERE RDB$RELATION_NAME = ? AND RDB$CONSTRAINT_TYPE = 'PRIMARY KEY'", (tname,))
                pk_index_row = cur.fetchone()
                if pk_index_row and pk_index_row[0]:
                    pk_index = pk_index_row[0].strip()
                    cur.execute("SELECT RDB$FIELD_NAME FROM RDB$INDEX_SEGMENTS WHERE RDB$INDEX_NAME = ? ORDER BY RDB$FIELD_POSITION", (pk_index,))
                    pk_fields = [r[0].strip() for r in cur.fetchall()]
                cur.close()
            except Exception:
                pk_fields = []
            expected_seqs = []
            expected_trgs = []
            if pk_fields:
                for pf in pk_fields:
                    expected_seqs.append(f"GEN_{tname}_{pf}")
                    expected_trgs.append(f"BI_{tname}_{pf}")
            else:
                try:
                    cur2 = conn.cursor()
                    cur2.execute("SELECT TRIM(RDB$FIELD_NAME) FROM RDB$RELATION_FIELDS WHERE RDB$RELATION_NAME = ? ORDER BY RDB$FIELD_POSITION", (tname,))
                    cols = [r[0] for r in cur2.fetchall()]
                    cur2.close()
                    for c in cols:
                        if c.upper() == "ID" or c.upper().endswith("_ID"):
                            expected_seqs.append(f"GEN_{tname}_{c}")
                            expected_trgs.append(f"BI_{tname}_{c}")
                except Exception:
                    pass
            seqs = sequences_exist(conn, expected_seqs) if expected_seqs else {}
            trgs = triggers_exist(conn, expected_trgs) if expected_trgs else {}
            table_report["sequences"] = seqs
            table_report["triggers"] = trgs
            try:
                fk_viol = fk_violations(conn, tname)
                table_report["fk_violations"] = fk_viol
            except Exception as e:
                table_report["details"].append(f"FK check failed: {str(e)}")
            fail_reasons = []
            if table_report["row_count"] is None:
                fail_reasons.append("Row count unavailable")
            for sname, exists in seqs.items():
                if not exists:
                    fail_reasons.append(f"Missing sequence {sname}")
            for tname2, exists in trgs.items():
                if not exists:
                    fail_reasons.append(f"Missing trigger {tname2}")
            if table_report["fk_violations"]:
                fail_reasons.append(f"FK violations: {len(table_report['fk_violations'])}")
            table_report["status"] = "PASS" if not fail_reasons else "FAIL"
            table_report["fail_reasons"] = fail_reasons
            out["tables"][tname] = table_report

        total_tables = len(out["tables"])
        total_fail = sum(1 for v in out["tables"].values() if v.get("status") != "PASS")
        total_errors = sum(len(v.get("fail_reasons", [])) for v in out["tables"].values())
        out["summary"] = {
            "total_tables": total_tables,
            "tables_passed": total_tables - total_fail,
            "tables_failed": total_fail,
            "total_fail_reasons": total_errors
        }

    finally:
        if conn:
            conn.close()
    return out

# ---------- CLI ----------

def main():
    parser = argparse.ArgumentParser(description="Firebird migration tests (firebird-driver)")
    parser.add_argument("--database", required=True, help="Path or DSN to Firebird database (e.g. /path/to/db.fdb)")
    parser.add_argument("--user", default="SYSDBA", help="DB user")
    parser.add_argument("--password", default="", help="DB password")
    parser.add_argument("--charset", default="UTF8", help="Connection charset")
    parser.add_argument("--tables", nargs="*", help="Optional list of tables to test (default: all user tables)")
    parser.add_argument("--sample-limit", type=int, help="Limit rows used for checksum (optional)")
    parser.add_argument("--out", default="migration_test_results.json", help="Output JSON file")
    args = parser.parse_args()

    cfg = {
        "database": args.database,
        "user": args.user,
        "password": args.password,
        "charset": args.charset,
        "tables": args.tables if args.tables else None,
        "sample_limit": args.sample_limit
    }

    print("Connecting to database:", cfg["database"])
    results = run_tests(cfg)
    out_file = args.out
    with open(out_file, "w", encoding="utf-8") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print("Results written to", out_file)

if __name__ == "__main__":
    main()
