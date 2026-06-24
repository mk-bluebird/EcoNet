-- filename: dbartifactregistry_nodel.sql
-- destination: Eco-Fort/db/dbartifactregistry_nodel.sql

PRAGMA foreign_keys = ON;

CREATE TRIGGER IF NOT EXISTS trg_artifactregistry_no_delete
BEFORE DELETE ON artifactregistry
FOR EACH ROW
BEGIN
    SELECT RAISE(ABORT, 'DELETE forbidden on artifactregistry; use active = 0');
END;
