// filename: crates/non_actuating_core/src/sqlite_ro.rs
// destination: Eco-Fort/crates/non_actuating_core/src/sqlite_ro.rs

use rusqlite::{Connection, OpenFlags};
use std::path::Path;

/// Thin wrapper around rusqlite::Connection enforcing read-only, immutable access.
pub struct ReadOnlySqlite {
    conn: Connection,
}

impl ReadOnlySqlite {
    /// Open SQLite database in strict read-only mode.
    pub fn open<P: AsRef<Path>>(path: P) -> Result<Self, rusqlite::Error> {
        let flags = OpenFlags::SQLITE_OPEN_READ_ONLY
            | OpenFlags::SQLITE_OPEN_URI
            | OpenFlags::SQLITE_OPEN_NO_MUTEX;

        // URI with mode=ro&immutable=1 to harden against writes.
        let uri = format!(
            "file:{}?mode=ro&immutable=1",
            path.as_ref().to_string_lossy()
        );

        let conn = Connection::open_with_flags(uri, flags)?;
        Ok(Self { conn })
    }

    pub fn connection(&self) -> &Connection {
        &self.conn
    }
}

impl super::ReadOnlyStore for ReadOnlySqlite {
    fn select_json(&self, sql: &str, params: &[(&str, &str)]) -> Result<String, String> {
        let mut stmt = self
            .conn
            .prepare(sql)
            .map_err(|e| format!("prepare error: {e}"))?;
        let mut rows = stmt
            .query_named(
                &params
                    .iter()
                    .map(|(k, v)| (*k as &str, v as &dyn rusqlite::ToSql))
                    .collect::<Vec<_>>()[..],
            )
            .map_err(|e| format!("query error: {e}"))?;

        let mut out = Vec::<serde_json::Value>::new();
        while let Some(row) = rows.next().map_err(|e| format!("step error: {e}"))? {
            let mut obj = serde_json::Map::new();
            for (i, col) in row.as_ref().column_names().iter().enumerate() {
                let val: rusqlite::types::Value = row.get(i).map_err(|e| format!("{e}"))?;
                let jv = match val {
                    rusqlite::types::Value::Null => serde_json::Value::Null,
                    rusqlite::types::Value::Integer(i) => serde_json::Value::from(i),
                    rusqlite::types::Value::Real(r) => serde_json::Value::from(r),
                    rusqlite::types::Value::Text(t) => {
                        serde_json::Value::from(String::from_utf8_lossy(&t).to_string())
                    }
                    rusqlite::types::Value::Blob(_) => {
                        serde_json::Value::from("<blob>")
                    }
                };
                obj.insert((*col).to_string(), jv);
            }
            out.push(serde_json::Value::Object(obj));
        }

        serde_json::to_string(&out).map_err(|e| format!("json error: {e}"))
    }
}
