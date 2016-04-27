SET SESSION TRANSACTION ISOLATION LEVEL REPEATABLE READ;

START TRANSACTION;

CREATE TABLE IF NOT EXISTS t (
    id              BIGINT UNSIGNED NOT NULL AUTO_INCREMENT PRIMARY KEY,
    name            VARCHAR(200) NOT NULL,
    logicalClock    JSON,
    deleted         BOOLEAN DEFAULT FALSE,

    INDEX           (deleted)
);

CREATE TABLE IF NOT EXISTS t__sibling (
    id              BIGINT UNSIGNED NOT NULL,
    name            VARCHAR(200) NOT NULL,
    logicalClock    JSON,
    deleted         BOOLEAN DEFAULT FALSE,

    INDEX           (deleted)
);

DROP TRIGGER IF EXISTS t__initLogicalClock;
DROP TRIGGER IF EXISTS t__reconcile;
DROP FUNCTION IF EXISTS current_gtid_source_id;
DROP FUNCTION IF EXISTS vv_descend;
DROP FUNCTION IF EXISTS vv_merge;
DROP FUNCTION IF EXISTS vv_increment;

DELIMITER $$

CREATE FUNCTION current_gtid_source_id ()
RETURNS CHAR(36) DETERMINISTIC
RETURN IF(@@SESSION.gtid_next = 'AUTOMATIC',
          @@server_uuid,
          SUBSTRING_INDEX(@@SESSION.gtid_next, ':', 1)) $$

CREATE FUNCTION vv_descend (v1 JSON, v2 JSON)
RETURNS BOOLEAN DETERMINISTIC
BEGIN
    DECLARE servers JSON;
    DECLARE i, n, counter1, counter2 INTEGER;
    DECLARE path VARCHAR(100);

    SET servers = JSON_KEYS(v2);
    IF servers IS NULL THEN
        RETURN TRUE;
    END IF;

    SET n = JSON_LENGTH(servers),
        i = 0;

    WHILE i < n DO
        SET path = CONCAT('$.', JSON_EXTRACT(servers, CONCAT('$[', i, ']')));
        SET counter1 = JSON_EXTRACT(v1, path),
            counter2 = JSON_EXTRACT(v2, path);

        IF counter1 IS NULL OR counter1 < counter2 THEN
            RETURN FALSE;
        END IF;

        SET i = i + 1;
    END WHILE;

    RETURN TRUE;
END $$

CREATE FUNCTION vv_merge (v1 JSON, v2 JSON)
RETURNS JSON DETERMINISTIC
BEGIN
    DECLARE v, servers, val JSON;
    DECLARE i, n, e1, e2 INTEGER;
    DECLARE path VARCHAR(100);

    SET v = JSON_MERGE(v1, v2);
    SET servers = JSON_KEYS(v);
    SET n = JSON_LENGTH(servers),
        i = 0;

    WHILE i < n DO
        SET path = CONCAT('$.', JSON_EXTRACT(servers, CONCAT('$[', i, ']')));
        SET val = JSON_EXTRACT(v, path);

        IF JSON_TYPE(val) = 'ARRAY' THEN
            SET e1 = JSON_EXTRACT(val, '$[0]'),
                e2 = JSON_EXTRACT(val, '$[1]');

            SET v = JSON_SET(v, path, IF(e1 > e2, e1, e2));
        END IF;

        SET i = i + 1;
    END WHILE;

    RETURN v;
END $$

CREATE FUNCTION vv_increment (v JSON, server CHAR(36))
RETURNS JSON DETERMINISTIC
BEGIN
    DECLARE i INTEGER;
    DECLARE path VARCHAR(100);

    SET path = CONCAT('$."', server, '"');
    SET i = JSON_EXTRACT(v, path);

    IF i IS NULL THEN
        return JSON_SET(v, path, 1);
    ELSE
        return JSON_SET(v, path, i + 1);
    END IF;
END $$

CREATE TRIGGER t__initLogicalClock BEFORE INSERT ON t FOR EACH ROW
BEGIN
    IF NEW.logicalClock IS NULL THEN
        SET NEW.logicalClock = CONCAT('{"format": 1, "hasSibling": false, "versionVector": {"',
                                      current_gtid_source_id(),
                                      '": 1}}');
    END IF;
END $$

CREATE TRIGGER t__reconcile BEFORE UPDATE ON t FOR EACH ROW
BEGIN
    DECLARE old_format, new_format INTEGER;
    DECLARE old_hasSibling, new_hasSibling BOOLEAN;
    DECLARE old_vv, new_vv JSON;
    DECLARE source_id CHAR(36);

    -- check transaction isolation level
    IF @@SESSION.tx_isolation <> 'REPEATABLE-READ' AND @@SESSION.tx_isolation <> 'SERIALIZABLE' THEN
        SIGNAL SQLSTATE '55000'
            SET MESSAGE_TEXT = 'Transaction isolation level isn\'t REPEATABLE-READ or SERIALIZABLE';
    END IF;

    -- check data schema of logical clock
    SET old_format = JSON_EXTRACT(OLD.logicalClock, '$.format'),
        new_format = JSON_EXTRACT(NEW.logicalClock, '$.format'),
        old_hasSibling = JSON_EXTRACT(OLD.logicalClock, '$.hasSibling'),
        new_hasSibling = JSON_EXTRACT(NEW.logicalClock, '$.hasSibling'),
        old_vv = JSON_EXTRACT(OLD.logicalClock, '$.versionVector'),
        new_vv = JSON_EXTRACT(NEW.logicalClock, '$.versionVector');

    IF old_format IS NULL OR new_format IS NULL OR old_format <> 1 OR new_format <> 1 THEN
        SIGNAL SQLSTATE '55000'
            SET MESSAGE_TEXT = 'Invalid "format" in logical clock';
    END IF;

    IF old_hasSibling IS NULL OR new_hasSibling IS NULL THEN
        SIGNAL SQLSTATE '55000'
            SET MESSAGE_TEXT = 'Invalid "hasSibling" in logical clock';
    END IF;

    IF old_vv IS NULL OR new_vv IS NULL OR
            JSON_TYPE(old_vv) <> 'OBJECT' OR JSON_TYPE(new_vv) <> 'OBJECT' OR
            JSON_DEPTH(old_vv) <> 2 OR JSON_DEPTH(new_vv) <> 2 THEN
        SIGNAL SQLSTATE '55000'
            SET MESSAGE_TEXT = 'Invalid "versionVector" in logical clock';
    END IF;

    -- check conflicts
    SET source_id = current_gtid_source_id();
    IF source_id = @@server_uuid THEN   -- on master
        IF new_hasSibling IS TRUE OR vv_descend(new_vv, old_vv) IS FALSE THEN
            SIGNAL SQLSTATE '55005'
                SET MESSAGE_TEXT = 'Must reconcile conflicted values';
        END IF;

        IF old_hasSibling IS TRUE THEN
            UPDATE t__sibling SET deleted = TRUE WHERE id = OLD.id AND deleted IS FALSE;
        END IF;
    ELSE                                -- on slave
        IF vv_descend(new_vv, old_vv) IS TRUE THEN
            IF old_hasSibling IS TRUE THEN
                UPDATE t__sibling SET deleted = TRUE WHERE id = OLD.id AND deleted IS FALSE;
            END IF;

            SET new_hasSibling = FALSE;
        ELSE
            IF old_hasSibling IS TRUE THEN
                UPDATE t__sibling SET deleted = TRUE WHERE id = OLD.id AND deleted IS FALSE AND
                    vv_descend(new_vv, JSON_EXTRACT(logicalClock, '$.versionVector')) IS TRUE;
            END IF;

            INSERT INTO t__sibling SELECT * FROM t WHERE id = OLD.id;

            SET new_hasSibling = TRUE;
        END IF;
    END IF;

    SET NEW.logicalClock = JSON_SET(NEW.logicalClock,
                                    '$.hasSibling',
                                    CAST(new_hasSibling IS TRUE AS JSON),
                                    '$.versionVector',
                                    vv_increment(vv_merge(old_vv, new_vv), source_id));
END $$

DELIMITER ;

COMMIT;

