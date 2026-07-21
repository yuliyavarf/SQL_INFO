
-- Удаление таблиц и процедур, если они существуют
DROP TABLE IF EXISTS Peers CASCADE;
DROP TABLE IF EXISTS Tasks CASCADE;
DROP TABLE IF EXISTS Checks CASCADE;
DROP TABLE IF EXISTS P2P CASCADE;
DROP TABLE IF EXISTS Verter CASCADE;
DROP TABLE IF EXISTS TransferredPoints CASCADE;
DROP TABLE IF EXISTS Friends CASCADE;
DROP TABLE IF EXISTS Recommendations CASCADE;
DROP TABLE IF EXISTS XP CASCADE;
DROP TABLE IF EXISTS TimeTracking CASCADE;
DROP TYPE IF EXISTS CheckStatus;

DROP PROCEDURE IF EXISTS import();
DROP PROCEDURE IF EXISTS importAllTables();
DROP PROCEDURE IF EXISTS export();
DROP PROCEDURE IF EXISTS exportAllTables();

-- Создание таблиц

CREATE TABLE IF NOT EXISTS Peers (
    Nickname VARCHAR(50) NOT NULL PRIMARY KEY,
    Birthday DATE NOT NULL);

CREATE TABLE IF NOT EXISTS Tasks (
    Title VARCHAR(100) DEFAULT NULL PRIMARY KEY,
    ParentTask VARCHAR(100) REFERENCES Tasks(Title),
    MaxXP INTEGER NOT NULL,
	CONSTRAINT fk_parent_task FOREIGN KEY (ParentTask) REFERENCES Tasks(Title),
	CONSTRAINT unique_pair CHECK (ParentTask != Title));

CREATE TYPE CheckStatus AS ENUM ('Start','Success','Failure');

CREATE TABLE IF NOT EXISTS Checks(
    ID SERIAL NOT NULL PRIMARY KEY,
    Peer VARCHAR(50) NOT NULL REFERENCES Peers(Nickname),
    Task VARCHAR(100) NOT NULL REFERENCES Tasks(Title),
    "Date" DATE NOT NULL);

CREATE TABLE IF NOT EXISTS P2P(
    ID SERIAL NOT NULL PRIMARY KEY,
    "Check" INTEGER NOT NULL REFERENCES Checks(ID),
    CheckingPeer VARCHAR(50) NOT NULL REFERENCES Peers(Nickname),
    "State" CheckStatus NOT NULL,
    "Time" TIME NOT NULL);

CREATE TABLE IF NOT EXISTS Verter(
    ID SERIAL NOT NULL PRIMARY KEY,
    "Check" INTEGER NOT NULL REFERENCES Checks(ID),
    "State" CheckStatus NOT NULL,
    "Time" TIME NOT NULL);

CREATE TABLE IF NOT EXISTS TransferredPoints(
    ID SERIAL NOT NULL PRIMARY KEY,
    CheckingPeer VARCHAR(50) NOT NULL,
    CheckedPeer VARCHAR(50) NOT NULL,
    PointsAmount INTEGER NOT NULL,
	CONSTRAINT unique_pair CHECK (CheckingPeer != CheckedPeer),
	CONSTRAINT fk_checking_peer FOREIGN KEY (CheckingPeer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_checked_peer FOREIGN KEY (CheckedPeer) REFERENCES Peers(Nickname));

CREATE TABLE IF NOT EXISTS Friends(
    ID SERIAL NOT NULL PRIMARY KEY,
    Peer1 VARCHAR(50) NOT NULL,
    Peer2 VARCHAR(50) NOT NULL,
	CONSTRAINT fk_friends_peer1 FOREIGN KEY (Peer1) REFERENCES Peers(Nickname),
	CONSTRAINT fk_friends_peer2 FOREIGN KEY (Peer2) REFERENCES Peers(Nickname),
	CONSTRAINT unique_pair CHECK (Peer1 != Peer2));

CREATE TABLE IF NOT EXISTS Recommendations(
    ID SERIAL NOT NULL PRIMARY KEY,
    Peer VARCHAR(50) NOT NULL,
    RecommendedPeer VARCHAR(50) NOT NULL,
	CONSTRAINT fk_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname),
	CONSTRAINT fk_recommendedpeer FOREIGN KEY (RecommendedPeer) REFERENCES Peers(Nickname),
	CONSTRAINT unique_pair CHECK (Peer != RecommendedPeer));

CREATE TABLE IF NOT EXISTS XP(
    ID SERIAL NOT NULL PRIMARY KEY,
    "Check" INTEGER NOT NULL REFERENCES Checks(ID),
    XPAmount INTEGER NOT NULL,
	CONSTRAINT fk_check_id FOREIGN KEY ("Check") REFERENCES Checks(ID));

CREATE TABLE IF NOT EXISTS TimeTracking(
    ID SERIAL NOT NULL PRIMARY KEY,
    Peer VARCHAR(50) NOT NULL,
    "Date" DATE NOT NULL,
    "Time" TIME NOT NULL,
    "State" INTEGER NOT NULL CHECK ("State" IN(1, 2)),
	CONSTRAINT fk_peer FOREIGN KEY (Peer) REFERENCES Peers(Nickname));

-- Создание процедур
-- IMPORT

CREATE OR REPLACE PROCEDURE import(IN tablename VARCHAR, IN path TEXT, IN separator CHAR) AS $$
    BEGIN
        EXECUTE format('COPY %s FROM ''%s'' DELIMITER ''%s'' CSV HEADER;',
            tablename, path, separator);
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE importAllTables(IN pathToFolder TEXT) AS $$
DECLARE
    tables TEXT[] := ARRAY[
		'Peers',
		'Tasks',
		'Checks',
		'P2P',
		'Verter',
		'TransferredPoints',
		'Friends',
		'Recommendations',
		'XP',
		'TimeTracking'];
	tables_with_serial_id TEXT[] := ARRAY[
		'Checks',
		'P2P',
		'Verter',
		'TransferredPoints',
		'Friends',
		'Recommendations',
		'XP',
		'TimeTracking'];
    table_name TEXT;
BEGIN
    FOR table_name IN SELECT unnest(tables) LOOP
		EXECUTE 'CALL IMPORT(''' || table_name || ''', ''' || pathToFolder || table_name || '.csv'', '';'')';
		IF table_name = ANY(tables_with_serial_id) THEN
            EXECUTE 'SELECT setval(pg_get_serial_sequence(''' || table_name || ''', ''id''), (SELECT MAX(id) FROM ' || table_name || '))';
		END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- EXPORT

CREATE OR REPLACE PROCEDURE export(IN tablename VARCHAR, IN path TEXT, IN separator CHAR) AS $$
    BEGIN
        EXECUTE format('COPY %s TO ''%s'' DELIMITER ''%s'' CSV HEADER;',
            tablename, path, separator);
    END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE exportAllTables(IN pathToFolder TEXT) AS $$
DECLARE
    tables TEXT[] := ARRAY['Peers','Tasks','Checks','P2P','Verter','TransferredPoints','Friends','Recommendations','XP','TimeTracking'];
	tables_with_serial_id TEXT[] := ARRAY['Checks','P2P','Verter','TransferredPoints','Friends','Recommendations','XP','TimeTracking'];
    table_name TEXT;
BEGIN
    FOR table_name IN SELECT unnest(tables) LOOP
		EXECUTE 'CALL EXPORT(''' || table_name || ''', ''' || pathToFolder || table_name || '.csv'', '';'')';
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Вызов процедур импорта и экспорта (перед запуском необходимо указать путь к директориям)

CALL importAllTables('/Users/mar/Desktop/SQL_Info/src/dataset_sql/');
CALL exportAllTables('/Users/mar/Desktop/SQL_Info/src/dataset_sql/');
