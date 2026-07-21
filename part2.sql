-- 1 
CREATE OR REPLACE PROCEDURE addigP2Pcheck(checked_peer VARCHAR, inspector VARCHAR, taskname VARCHAR, status CheckStatus, "time" TIME) AS $$
BEGIN
	IF status = 'Start' THEN
		IF ((SELECT COUNT(*) FROM P2P INNER JOIN Checks ON P2P."Check" = Checks.Id
			 WHERE P2P.CheckingPeer = inspector AND Checks.Peer = checked_peer AND Checks.Task = taskname) % 2 = 1) THEN
			 RAISE EXCEPTION 'There is already an unfinished p2p check';
		ELSE
			INSERT INTO Checks VALUES ((SELECT MAX(Id) FROM Checks) + 1, checked_peer, taskname, NOW());
			INSERT INTO P2P VALUES ((SELECT MAX(Id) FROM P2P) + 1, (SELECT MAX(Id) FROM Checks), inspector, status, "time");
		END IF;
	ELSE 
		INSERT INTO P2P
		VALUES ((SELECT MAX(Id) FROM P2P) + 1,
				(SELECT "Check" FROM P2P INNER JOIN Checks ON P2P."Check" = Checks.Id
				 WHERE P2P.CheckingPeer = inspector AND Checks.Peer = checked_peer AND Checks.Task = taskname ORDER BY P2P.id DESC LIMIT 1),
				inspector,
				status,
				"time");
	END IF;        
END;
$$ LANGUAGE plpgsql;


-- Тестовые запросы

CALL addigP2Pcheck('jlbpsacywv', 'owznrhbniu', 'DO2', 'Start', '12:01:00'); -- старт проверки задания D06
CALL addigP2Pcheck('jlbpsacywv', 'owznrhbniu', 'DO2', 'Start', '12:02:00'); -- повторный старт проверки D06, не добаится
CALL addigP2Pcheck('jlbpsacywv', 'owznrhbniu', 'DO2', 'Failure', '12:20:00'); -- финиш проверки задания D06 не успешно
CALL addigP2Pcheck('jlbpsacywv', 'owznrhbniu', 'DO2', 'Start', '13:00:00'); -- старт проверки задания D06
CALL addigP2Pcheck('jlbpsacywv', 'owznrhbniu', 'DO2', 'Success', '13:20:00'); -- финиш проверки задания D06 успешно



-- 2

CREATE OR REPLACE PROCEDURE proc_add_VerterCheck(checked_peer VARCHAR, taskname VARCHAR, status CheckStatus, "time" TIME) AS $$
BEGIN
	IF (status = 'Start') THEN
		IF ((SELECT MAX(P2P."Time") FROM P2P INNER JOIN Checks ON P2P."Check" = Checks.ID
			 WHERE P2P."Time" < "time" AND Checks.Peer = checked_peer AND Checks.Task = taskname AND P2P."State" = 'Success') IS NOT NULL AND
			(SELECT COUNT(*) FROM verter INNER JOIN Checks ON verter."Check" = Checks.Id
			 WHERE Checks.Peer = checked_peer AND Checks.Task = taskname) % 2 = 0) THEN
	
			 INSERT INTO Verter
			 VALUES ((SELECT MAX(ID) FROM Verter) + 1,
					(SELECT Checks.ID FROM P2P JOIN Checks ON P2P."Check" = Checks.ID
					 WHERE Checks.Peer = checked_peer AND Checks.Task = taskname AND P2P."State" = 'Success' ORDER BY 1 DESC LIMIT 1),
					 status,
					 "time");
		ELSE
			RAISE EXCEPTION 'Review not completed or there is already an unfinished verter check';
		END IF;
	ELSE
	   INSERT INTO Verter
	   VALUES ((SELECT MAX(ID) FROM Verter) + 1,
		      (SELECT "Check" FROM verter GROUP BY "Check" HAVING COUNT(*) % 2 = 1),
			   status,
			   "time");
	END IF;
END;
$$ LANGUAGE plpgsql;


-- Тестовые запросы

CALL proc_add_VerterCheck('jlbpsacywv', 'DO2', 'Start', '14:01:00'); -- старт проверки задания D02
CALL proc_add_VerterCheck('jlbpsacywv', 'DO2', 'Start', '14:02:00'); -- повторный старт проверки D02, не добавится
CALL proc_add_VerterCheck('jlbpsacywv', 'DO2', 'Success', '14:20:00'); -- финиш проверки задания D02 успешно


--3
--Функция обновляющая transferredpoints
CREATE OR REPLACE FUNCTION fnc_trg_transfer_points() RETURNS TRIGGER AS $$
BEGIN
	IF(NEW."State" = 'Start') THEN
		WITH peer AS (
			SELECT Checks.Peer FROM P2P INNER JOIN Checks ON P2P."Check" = Checks.Id
			WHERE "State" = 'Start' AND NEW."Check" = Checks.Id)
		UPDATE transferredpoints
		SET pointsamount = pointsamount + 1
		FROM peer
		WHERE transferredpoints.checkingpeer = NEW.checkingpeer AND transferredpoints.checkedpeer = peer.Peer;
	END IF;
	RETURN NULL;
END;
$$ LANGUAGE plpgsql;

--Триггер обрабатывающий добавление значений в таблицу P2P
CREATE OR REPLACE TRIGGER trg_p2p_newline
AFTER INSERT ON p2p
FOR EACH ROW
EXECUTE PROCEDURE fnc_trg_transfer_points();


-- Тестовые запросы

CALL addigP2Pcheck('vrbyeonaxg', 'cpwfiewvim', 'DO3', 'Start', '12:03:00'); -- тестовый запрос
CALL addigP2Pcheck('vrbyeonaxg', 'cpwfiewvim', 'DO3', 'Failure', '12:10:00'); -- завершение проверки для корретного наполнения базы


-- 4
--Функция проверяющая условия обновления значений в таблице XP
CREATE OR REPLACE FUNCTION fnc_trg_XP_insert() RETURNS TRIGGER AS $$
BEGIN
	IF((SELECT MaxXP FROM tasks t INNER JOIN checks c ON c.Task = t.Title
		WHERE c.ID = NEW."Check") < NEW.XPAmount) THEN
		RAISE EXCEPTION 'XP added above the max value';
	ELSEIF ((SELECT "State" FROM p2p WHERE p2p."Check" = NEW."Check" ORDER BY 1 DESC LIMIT 1) IN ('Start', 'Failure')) THEN
		RAISE EXCEPTION 'P2P check failed or unfinished';
	ELSEIF ((SELECT "State" FROM verter WHERE verter."Check" = NEW."Check" ORDER BY 1 DESC LIMIT 1) IN ('Start', 'Failure')) THEN
		RAISE EXCEPTION 'Verter check failed or unfinished';
	END IF;
	RETURN (NEW.ID, NEW."Check", NEW.XPAmount);	
END;
$$ LANGUAGE plpgsql;

--Триггер обрабатывающий добавление значений в таблицу XP
CREATE OR REPLACE TRIGGER trg_XP_insert
BEFORE INSERT ON xp
FOR EACH ROW
EXECUTE PROCEDURE fnc_trg_XP_insert();


-- Тестовые запросы

INSERT INTO xp VALUES ((SELECT MAX(ID) FROM xp) + 1, 13930, 950); -- превышение баллов
INSERT INTO xp VALUES ((SELECT MAX(ID) FROM xp) + 1, 13928, 600); -- P2P не сдан
INSERT INTO xp VALUES ((SELECT MAX(ID) FROM xp) + 1, 10309, 50); -- Verter не сдан
INSERT INTO xp VALUES ((SELECT MAX(ID) FROM xp) + 1, 10312, 50); -- успешно добавляется
CALL addigP2Pcheck('jlbpsacywv', 'owznrhbniu', 'DO2', 'Start', '12:01:00'); -- старт проверки задания без завершения
INSERT INTO xp VALUES ((SELECT MAX(ID) FROM xp) + 1, 13934, 50); -- попытка добавить xp у незавершенной проверки

DELETE FROM xp WHERE ID = 2451; -- удалить тестовые изменения