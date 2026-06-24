-- File: db/dbvresidualkernel.sql
-- Destination: Eco-Fort/db/dbvresidualkernel.sql

DROP VIEW IF EXISTS vresidualkernel;

CREATE VIEW vresidualkernel AS
SELECT
    si.nodeid,
    si.region,
    si.windowstartms,
    si.windowendms,
    SUM(pw.weight * si.rplane * si.rplane) AS vtvalue,
    MAX(si.rplane) AS rmetric,
    (1.0 - MAX(si.rplane)) AS emetric,
    SUM(CASE
            WHEN pw.nonoffsettable = 1 AND si.rplane >= pw.goldband
            THEN 1
            ELSE 0
        END) AS nonoffset_violation_count
FROM shardinstance AS si
JOIN planeweights AS pw
  ON pw.planeid = si.planeid
 AND pw.contractid = si.contractid
GROUP BY
    si.nodeid,
    si.region,
    si.windowstartms,
    si.windowendms;
