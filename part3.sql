INSERT INTO peers(nickname, birthday) VALUES('Leeloo','1997-05-07');
INSERT INTO peers(nickname, birthday) VALUES('RubyRhod','1997-05-07');
INSERT INTO peers(nickname, birthday) VALUES('CorbinDallas','1997-05-07');
INSERT INTO peers(nickname, birthday) VALUES('Akhnot','1997-05-07');
INSERT INTO peers(nickname, birthday) VALUES('VitoCornelius','1997-05-07'); 
INSERT INTO peers(nickname, birthday) VALUES('Plavalaguna','1997-05-07'); 
INSERT INTO peers(nickname, birthday) VALUES('David','1997-05-07'); 
INSERT INTO TransferredPoints(checkingpeer, checkedpeer, pointsamount) VALUES('Leeloo', 'CorbinDallas',10);
INSERT INTO TransferredPoints(checkingpeer, checkedpeer, pointsamount) VALUES('RubyRhod', 'CorbinDallas',1);
INSERT INTO TransferredPoints(checkingpeer, checkedpeer, pointsamount) VALUES('CorbinDallas', 'RubyRhod',13);
INSERT INTO TransferredPoints(checkingpeer, checkedpeer, pointsamount) VALUES('VitoCornelius', 'CorbinDallas',2);
INSERT INTO TransferredPoints(checkingpeer, checkedpeer, pointsamount) VALUES('Akhnot', 'CorbinDallas',1);
INSERT INTO TransferredPoints(checkingpeer, checkedpeer, pointsamount) VALUES('CorbinDallas', 'Akhnot',1);

SELECT * FROM TransferredPoints
WHERE checkingpeer='CorbinDallas' OR checkedpeer='CorbinDallas'
ORDER BY 1 DESC;

-- Написать функцию, возвращающую таблицу TransferredPoints в читаемом виде
-- Ник пира 1, ник пира 2, количество переданных пир поинтов
-- Количество отрицательное, если пир 2 получил от пира 1 больше поинтов

-- drop function fnc_TransferredPoints;

CREATE OR REPLACE FUNCTION fnc_TransferredPoints()
   RETURNS TABLE("Peer1" VARCHAR(50), "Peer2" VARCHAR(50), "PointsAmount" INTEGER)
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	SELECT coalesce(tp1.checkingpeer, tp2.checkedpeer) peer1, 
		   coalesce(tp1.checkedpeer, tp2.checkingpeer) peer2, 
		   coalesce(tp1.pointsamount,0) - coalesce(tp2.pointsamount,0)
	FROM TransferredPoints AS tp1
	FULL JOIN TransferredPoints AS tp2 ON tp1.checkingpeer = tp2.checkedpeer 
								AND tp2.checkingpeer = tp1.checkedpeer
	WHERE coalesce(tp1.checkingpeer, tp2.checkedpeer) < coalesce(tp1.checkedpeer, tp2.checkingpeer);
END;
$$;

SELECT *
FROM fnc_TransferredPoints()
WHERE "Peer1" = 'CorbinDallas' OR "Peer2" = 'CorbinDallas';


-- Написать функцию, которая возвращает таблицу вида: ник пользователя, название проверенного задания, кол-во полученного XP
-- В таблицу включить только задания, успешно прошедшие проверку (определять по таблице Checks)
-- Одна задача может быть успешно выполнена несколько раз (включить все успешные проверки)

-- SELECT * FROM verter WHERE "Check" = 174 
-- delete * FROM verter WHERE "Check" = 174 
CREATE OR REPLACE FUNCTION fnc_SuccesTasksXP()
   RETURNS TABLE("Peer" VARCHAR(50), "Task" VARCHAR(100), "XP" INTEGER)
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	SELECT c.peer, c.task, xp.xpamount 
	FROM checks c
	LEFT JOIN xp ON c.id = xp."Check"
	LEFT JOIN p2p p ON c.id = p."Check" AND p."State" = 'Success'
	LEFT JOIN verter v ON c.id = v."Check"
	WHERE v."State" is null OR v."State" = 'Success';	
END;
$$;

SELECT *
FROM fnc_SuccesTasksXP();

-- Написать функцию, определяющую пиров, которые не выходили из кампуса в течение всего дня
-- Параметры функции: день, например 12.05.2022
-- Функция возвращает только список пиров
INSERT INTO timetracking(peer, "Date", "Time", "State") VALUES('apqafznlpp', '2022-05-12', '10:03:23', 2);
SELECT * FROM timetracking
WHERE "Date" = '2022-05-12';

CREATE OR REPLACE FUNCTION fnc_PeersNotLeaveCampusInDay(pday DATE DEFAULT '2022-05-12')
   RETURNS TABLE("Peer" VARCHAR(50))
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	SELECT peer
	FROM timetracking
	WHERE "Date" = pday
	EXCEPT
	SELECT peer
	FROM timetracking
	WHERE "Date" = pday AND "State" = 2 ;	
END;
$$;

SELECT *
FROM fnc_PeersNotLeaveCampusInDay();


-- Посчитать изменение в количестве пир поинтов каждого пира по таблице TransferredPoints
-- Результат отсортировать по изменению числа поинтов
-- Формат вывода: ник пира, изменение в количество пир поинтов
SELECT * FROM TransferredPoints
WHERE checkingpeer='CorbinDallas' OR checkedpeer='CorbinDallas';

CREATE OR REPLACE FUNCTION fnc_TransferredPointsChangeUsingTransferredPoints()
   RETURNS TABLE("Peer" VARCHAR(50), "PointsChange" INTEGER)
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	SELECT "Peer1" AS "Peer",
		   CAST(sum("PointsAmount") AS INTEGER) AS "PointsChange"
	FROM (
		SELECT coalesce(tp1.checkingpeer, tp2.checkedpeer) "Peer1", 
			   coalesce(tp1.checkedpeer, tp2.checkingpeer) "Peer2", 
			   coalesce(tp1.pointsamount,0) - coalesce(tp2.pointsamount,0) "PointsAmount"
		FROM TransferredPoints AS tp1
		FULL JOIN TransferredPoints AS tp2 ON tp1.checkingpeer = tp2.checkedpeer 
									AND tp2.checkingpeer = tp1.checkedpeer) pa
	GROUP BY "Peer1"
	ORDER BY "PointsChange" DESC;
END;
$$;

SELECT *
FROM fnc_TransferredPointsChangeUsingTransferredPoints()
WHERE "Peer" = 'CorbinDallas' 
	OR "Peer" = 'Leeloo' 
	OR "Peer" = 'Akhnot'
	OR "Peer" = 'RubyRhod'
	OR "Peer" = 'VitoCornelius';


-- Посчитать изменение в количестве пир поинтов каждого пира по таблице, возвращаемой первой функцией из Part 3
-- Результат отсортировать по изменению числа поинтов
-- Формат вывода: ник пира, изменение в количество пир поинтов
CREATE OR REPLACE FUNCTION fnc_TransferredPointsChangeUsingFunction()
   RETURNS TABLE("Peer" VARCHAR(50), "PointsChange" INTEGER)
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	SELECT peer AS "Peer",
		   CAST(sum("PointsAmount") AS INTEGER) AS "PointsChange"
	FROM 
		(SELECT "Peer1" peer, "PointsAmount" from fnc_TransferredPoints() 
		UNION ALL
		SELECT "Peer2", -"PointsAmount" from fnc_TransferredPoints()) u
	GROUP BY peer
	ORDER BY "PointsChange" DESC;
END;
$$;

SELECT *
FROM fnc_TransferredPointsChangeUsingFunction()
WHERE "Peer" = 'CorbinDallas' 
	or "Peer" = 'Leeloo' 
	or "Peer" = 'Akhnot'
	or "Peer" = 'RubyRhod'
	OR "Peer" = 'VitoCornelius';

-- Определить самое часто проверяемое задание за каждый день
-- При одинаковом количестве проверок каких-то заданий в определенный день, вывести их все
-- Формат вывода: день, название задания
CREATE OR REPLACE FUNCTION fnc_MostPopularTasksPerDay()
   RETURNS TABLE("Day" DATE, "Task" VARCHAR(100))
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	WITH dateTasksCount AS (SELECT "Date", task, COUNT(task) AS ct
							FROM checks
							GROUP BY "Date", task)
	SELECT "Date", task
	FROM dateTasksCount dtc
	WHERE ct = (SELECT max(ct) FROM dateTasksCount WHERE "Date" = dtc."Date");
END;
$$;

SELECT * 
FROM fnc_MostPopularTasksPerDay();

-- Найти всех пиров, выполнивших весь заданный блок задач и дату завершения последнего задания
-- Параметры процедуры: название блока, например «CPP»
-- Результат отсортировать по дате завершения
-- Формат вывода: ник пира, дата завершения блока (т.е. последнего выполненного задания из этого блока)

CREATE OR REPLACE FUNCTION fnc_PeersFinishedBlock(pblock VARCHAR(100))
   RETURNS TABLE("Peer" VARCHAR(50), "Day" DATE)
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	WITH peersFinishedBlock AS (
			SELECT peer
			FROM checks c
			JOIN xp ON c.id = xp."Check"
			WHERE task ~ ('^' || pblock|| '\d+$')
			GROUP BY peer
			HAVING COUNT(distinct task) in (SELECT COUNT(distinct title) FROM tasks
											WHERE title ~ ('^' || pblock|| '\d+$')))
	SELECT peer, max("Date")
	FROM (
		SELECT peer, min("Date") over(partition by peer, task) "Date"
		FROM checks c
		JOIN xp ON c.id = xp."Check"
		WHERE peer in (SELECT * FROM peersFinishedBlock) AND task ~ ('^' || pblock|| '\d+$')) z
	GROUP BY peer;
END;
$$;

SELECT * 
FROM fnc_PeersFinishedBlock('CPP');
SELECT * 
FROM fnc_PeersFinishedBlock('A');

-- Определить, к какому пиру стоит идти на проверку каждому обучающемуся
-- Определять нужно исходя из рекомендаций друзей пира, т.е. нужно найти пира, проверяться у которого рекомендует наибольшее число друзей
-- Формат вывода: ник пира, ник найденного проверяющего
insert into friends(peer1,peer2) values('Leeloo','CorbinDallas');
insert into friends(peer1,peer2) values('CorbinDallas','RubyRhod');
insert into friends(peer1,peer2) values('Leeloo','RubyRhod'); 
insert into friends(peer1,peer2) values('Leeloo','VitoCornelius');
insert into friends(peer1,peer2) values('Leeloo','Plavalaguna');
insert into friends(peer1,peer2) values('Leeloo','David');

insert into recommendations(peer,recommendedpeer) values('RubyRhod','CorbinDallas');
insert into recommendations(peer,recommendedpeer) values('RubyRhod','ymalorpccg');
insert into recommendations(peer,recommendedpeer) values('VitoCornelius','CorbinDallas');
insert into recommendations(peer,recommendedpeer) values('VitoCornelius','ymalorpccg');
insert into recommendations(peer,recommendedpeer) values('CorbinDallas','ymalorpccg');
insert into recommendations(peer,recommendedpeer) values('Plavalaguna','CorbinDallas');
insert into recommendations(peer,recommendedpeer) values('David','CorbinDallas');

CREATE OR REPLACE FUNCTION fnc_PeersByRecommendation()
   RETURNS TABLE("Peer" VARCHAR(50), "RecommendedPeer" VARCHAR(50))
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	SELECT p.nickname, tmp.recommendedpeer
	FROM peers p
	LEFT JOIN (
		SELECT peer, recommendedpeer FROM (
			SELECT fr.peer, 
				   r.recommendedpeer, 
				   row_number() over(partition by fr.peer ORDER BY COUNT(*) DESC) AS num
			FROM (
				SELECT peer1 AS peer, peer2 AS friend FROM friends
				UNION 
				SELECT peer2, peer1 FROM friends) fr
			JOIN recommendations r ON fr.friend = r.peer
			WHERE fr.peer != r.recommendedpeer
			GROUP BY fr.peer, r.recommendedpeer
			) t
		WHERE num = 1 ) tmp ON p.nickname = tmp.peer;
END;
$$;

SELECT * 
FROM fnc_PeersByRecommendation()
WHERE "RecommendedPeer" is not Null;

-- Определить процент пиров, которые:
-- Приступили только к блоку 1
-- Приступили только к блоку 2
-- Приступили к обоим
-- Не приступили ни к одному
-- Пир считается приступившим к блоку, если он проходил хоть одну проверку любого задания из этого блока (по таблице Checks)
-- Параметры процедуры: название блока 1, например SQL, название блока 2, например A
-- Формат вывода: процент приступивших только к первому блоку, процент приступивших только ко второму блоку, процент приступивших к обоим, процент не приступивших ни к одному

-- drop function fnc_percentsByBlocks;
CREATE OR REPLACE FUNCTION fnc_percentsByBlocks(pblock1 VARCHAR(100), pblock2 VARCHAR(100))
   RETURNS TABLE("StartedBlock1" NUMERIC , "StartedBlock2" NUMERIC ,
			     "StartedBothBlocks" NUMERIC , "DidntStartAnyBlock" NUMERIC)
   LANGUAGE plpgsql
AS
$$
DECLARE
    peersCount NUMERIC  := (SELECT COUNT(*) FROM peers)/100.0;
BEGIN
	RETURN QUERY
	SELECT (sum("block1")/peersCount)::NUMERIC(5,2) "StartedBlock1", 
	   (sum("block2")/peersCount)::NUMERIC(5,2) "StartedBlock2", 
	   (sum("bothBlocks")/peersCount)::NUMERIC(5,2) "StartedBothBlocks", 
	   (sum("neitherBlocks")/peersCount)::NUMERIC(5,2) "DidntStartAnyBlock"
FROM (	
	SELECT p.nickname, 
		   CASE WHEN COUNT(distinct "block1") > 0 AND COUNT(distinct "block2") = 0 THEN 1 ELSE 0 END "block1",
		   CASE WHEN COUNT(distinct "block1") = 0 AND COUNT(distinct "block2") > 0 THEN 1 ELSE 0 END "block2",
		   CASE WHEN COUNT(distinct "block1") > 0 AND COUNT(distinct "block2") > 0 THEN 1 ELSE 0 END "bothBlocks",
		   CASE WHEN COUNT(distinct "block1") = 0 AND COUNT(distinct "block2") = 0 THEN 1 ELSE 0 END "neitherBlocks"
	FROM peers p
	LEFT JOIN 
	(
		SELECT  peer, 
				CASE WHEN task ~ ('^' || pblock1|| '\d+$') THEN 'block1' END "block1",
				CASE WHEN task ~ ('^' || pblock2|| '\d+$') THEN 'block2' END "block2"
		FROM checks 
		) c ON p.nickname = c.peer
	GROUP BY p.nickname
)z;
END;
$$;

SELECT * 
FROM fnc_percentsByBlocks('SQL', 'A');

-- Определить процент пиров, которые когда-либо успешно проходили проверку в свой день рождения
-- Также определи процент пиров, которые хоть раз проваливали проверку в свой день рождения
-- Формат вывода: процент пиров, успешно прошедших проверку в день рождения, процент пиров, проваливших проверку в день рождения
CREATE OR REPLACE FUNCTION fnc_percentsBirthbayChecks()
   RETURNS TABLE("SuccessfulChecks" NUMERIC , "UnsuccessfulChecks" NUMERIC )
   LANGUAGE plpgsql
AS
$$
DECLARE
    peersCount NUMERIC  := (SELECT COUNT(*) FROM peers);
BEGIN
	RETURN QUERY
	SELECT (100.0*sum(success)/COUNT(*))::NUMERIC(5,2) "SuccessfulChecks",
		   (100.0*sum(failure)/COUNT(*))::NUMERIC(5,2) "UnsuccessfulChecks"
	-- SELECT (100.0*sum(success)/peersCount)::NUMERIC(5,2) "SuccessfulChecks", процент от всех пиров
	--  	   (100.0*sum(failure)/peersCount)::NUMERIC(5,2) "UnsuccessfulChecks"
	FROM (
		SELECT CASE WHEN sum(success) > 0 THEN 1 ELSE 0 END success,
			   CASE WHEN sum(failure) > 0 THEN 1 ELSE 0 END failure
		FROM (
			SELECT p.nickname,  
				   CASE WHEN xp.id is not null THEN 1 ELSE 0 END success,
				   CASE WHEN xp.id is null THEN 1 ELSE 0 END failure
			FROM peers p
			JOIN checks c ON p.nickname = c.peer 
									and date_part('day', p.birthday) = date_part('day', c."Date")
									and date_part('month', p.birthday) = date_part('month', c."Date")
			LEFT JOIN xp ON c.id = xp."Check"
		) bdChecks
		GROUP BY nickname
	)z;
END;
$$;

SELECT * 
FROM fnc_percentsBirthbayChecks();

-- Определить всех пиров, которые сдали заданные задания 1 и 2, но не сдали задание 3
-- Параметры процедуры: названия заданий 1, 2 и 3
-- Формат вывода: список пиров
CREATE OR REPLACE FUNCTION fnc_solved12failed3(ptask1 VARCHAR(100), 
												ptask2 VARCHAR(100), 
												ptask3 VARCHAR(100))
   RETURNS TABLE("Peer" VARCHAR(50))
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	WITH succesChecks AS (
		SELECT peer, task 
		FROM checks c 
		JOIN xp ON c.id = xp."Check") 
	(SELECT peer FROM succesChecks WHERE task = ptask1
	INTERSECT
	SELECT peer FROM succesChecks WHERE task = ptask2)
	EXCEPT
	SELECT peer FROM succesChecks WHERE task = ptask3;
END;
$$;

SELECT * 
FROM fnc_solved12failed3('C1', 'C2', 'C3');

-- Используя рекурсивное обобщенное табличное выражение, для каждой задачи вывести кол-во предшествующих ей задач
-- То есть сколько задач нужно выполнить, исходя из условий входа, чтобы получить доступ к текущей
-- Формат вывода: название задачи, количество предшествующих
CREATE OR REPLACE FUNCTION fnc_previousTasksCOUNT()
   RETURNS TABLE("Task" VARCHAR(100), "PrevCount" INTEGER)
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	WITH RECURSIVE taskTree(task, previosCount) AS (
		SELECT title, 0 FROM tasks WHERE parenttask is null
		UNION
		SELECT t.title, tt.previosCount + 1 
		FROM taskTree tt
		JOIN tasks t ON t.parenttask = tt.task
	) 
	SELECT * FROM taskTree;
END;
$$;

SELECT * 
FROM fnc_previousTasksCOUNT()
ORDER BY 2, 1;


-- Найти «удачные» для проверок дни. День считается «удачным», если в нем есть хотя бы N идущих подряд успешных проверки
-- Параметры процедуры: количество идущих подряд успешных проверок N
-- Временем проверки считать время начала P2P этапа
-- Под идущими подряд успешными проверками подразумеваются успешные проверки, между которыми нет неуспешных
-- При этом кол-во опыта за каждую из этих проверок должно быть не меньше 80% от максимального
-- Формат вывода: список дней
CREATE OR REPLACE FUNCTION fnc_luckyStrikes()
   RETURNS TABLE("Date" DATE, "Time" TIME, checkResult INTEGER, rn BIGINT)
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
		SELECT c."Date", ps."Time",
			   CASE WHEN pr."State" = 'Success' AND (vr."State" = 'Success' OR vs."State" is null) THEN 1 ELSE 0 END checkResult,
			   row_number() over(ORDER BY c."Date", ps."Time") rn
		FROM checks c
		JOIN tasks t ON c.task = t.title
		JOIN p2p ps ON c.id = ps."Check" AND ps."State" = 'Start'
		JOIN p2p pr ON c.id = pr."Check" AND pr."State" != 'Start'
		LEFT JOIN verter vs ON c.id = vs."Check" AND vs."State" = 'Start'
		LEFT JOIN verter vr ON c.id = vr."Check" AND vr."State" != 'Start'
		LEFT JOIN xp ON c.id = xp."Check"
		WHERE (vs."State" is null) = (vr."State" is null) -- отсечение неоконченных проверок вертером
			AND (xp.xpamount is null OR xp.xpamount >= 0.8*t.maxxp); -- % опыта	
END;
$$;

		
SELECT * FROM fnc_luckyStrikes();


CREATE OR REPLACE FUNCTION fnc_luckyN(pn INTEGER DEFAULT 3)
   RETURNS TABLE("Date" DATE)
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
		WITH RECURSIVE lucky("Date", "Time", checkResult, rn, lucky_len)  AS (
			SELECT f."Date", f."Time", f.checkResult, f.rn, f.checkResult AS lucky_len
			FROM fnc_luckyStrikes() f
			WHERE rn = 1
			UNION
			SELECT tmp."Date", 
					tmp."Time", 
					tmp.checkResult, 
					tmp.rn, 
					CASE WHEN tmp.checkResult = 0 THEN 0
						 WHEN tmp.checkResult != 0 AND tmp."Date" = l."Date" THEN l.lucky_len + 1
						 ELSE 1 END
			FROM lucky AS l
			JOIN fnc_luckyStrikes() tmp ON tmp.rn = l.rn + 1
		)
	SELECT t."Date"
	FROM (
		SELECT  l."Date", max(l.lucky_len) maxLuckySrike
		FROM lucky l
		GROUP BY l."Date"
	) t
	WHERE maxLuckySrike >= pn;
END;
$$;

SELECT * FROM fnc_luckyN();

-- Определить пира с наибольшим количеством XP
-- Формат вывода: ник пира, количество XP
CREATE OR REPLACE FUNCTION fnc_MostExperiencedPeer()
   RETURNS TABLE("Peer" VARCHAR(50), "XP" BIGINT)
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	SELECT c.peer, sum(xp.xpamount) XP
	FROM checks c
	JOIN xp ON c.id = xp."Check"
	GROUP BY c.peer
	ORDER BY XP DESC LIMIT(1); 
END;
$$;

SELECT * FROM fnc_MostExperiencedPeer();


-- Определить пиров, приходивших раньше заданного времени не менее N раз за всё время
-- Параметры процедуры: время, количество раз N
-- Формат вывода: список пиров
-- (1 - пришел, 2 - вышел)
CREATE OR REPLACE FUNCTION fnc_EarlyEntriesCount(ptime TIME DEFAULT '09:00:00', pn INTEGER DEFAULT 3)
   RETURNS TABLE("Peer" VARCHAR(50))
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	SELECT peer
	FROM timetracking
	WHERE "Time" < ptime AND "State" = 1
	GROUP BY peer
	HAVING COUNT(*) >= pn;
END;
$$;

SELECT * FROM fnc_EarlyEntriesCount();

-- Определить пиров, выходивших за последние N дней из кампуса больше M раз
-- Параметры процедуры: количество дней N, количество раз M
-- Формат вывода: список пиров
-- (1 - пришел, 2 - вышел)
CREATE OR REPLACE FUNCTION fnc_ExitedLastNDaysMoremTimes(pn INTEGER DEFAULT 365+90, pm INTEGER DEFAULT 5)
   RETURNS TABLE("Peer" VARCHAR(50))
   LANGUAGE plpgsql
AS
$$
BEGIN
	RETURN QUERY
	WITH RECURSIVE dates("day") AS (
		SELECT NOW()::DATE "day"
		UNION
		SELECT "day" - 1 FROM dates WHERE "day" >= NOW()::DATE - (pn-2)
	)
	SELECT peer
	FROM dates d
	JOIN timetracking t ON d."day" = t."Date"
	WHERE "State" = 2
	GROUP BY peer
	HAVING COUNT(*) > pm;
END;
$$;

SELECT * FROM fnc_ExitedLastNDaysMoremTimes();

--Определить для каждого месяца процент ранних входов
--Для каждого месяца: сколько раз люди, родившиеся в этот месяц, приходили в кампус за всё время ("общее число входов"). 
--Для каждого месяца: сколько раз люди, родившиеся в этот месяц, приходили в кампус раньше 12:00 за всё время ("число ранних входов"). 
--Для каждого месяца: процент ранних входов в кампус относительно общего числа входов
--Формат вывода: месяц, процент ранних входов.
CREATE OR REPLACE FUNCTION func_percent_of_entrances()
    RETURNS TABLE (Month text, EarlyEntries real) AS $$
    BEGIN
        RETURN QUERY 
		(WITH p_birtmonth AS (SELECT Nickname, EXTRACT(month FROM Birthday) AS birthday FROM Peers),
			  entry_month AS (SELECT Peer, "Date", birthday
							  FROM TimeTracking INNER JOIN p_birtmonth ON TimeTracking.Peer = p_birtmonth.Nickname
							  WHERE "State" = 1 AND EXTRACT(month FROM "Date") = birthday
							  GROUP BY Peer, "Date", birthday),
			  all_count   AS (SELECT COUNT(*) AS count, birthday
							  FROM entry_month
							  GROUP BY birthday),
			  early_entry AS (SELECT Peer, "Date", birthday
							  FROM TimeTracking INNER JOIN p_birtmonth ON TimeTracking.Peer = p_birtmonth.Nickname
							  WHERE "State" = 1 AND EXTRACT(month FROM "Date") = birthday AND "Time" < '12:00:00'
							  GROUP BY Peer, "Date", birthday),
			  early_count AS (SELECT COUNT(*) AS count1, birthday
							  FROM early_entry
							  GROUP BY birthday)
		 SELECT (CASE WHEN all_count.birthday = 1 THEN 'January'
					  WHEN all_count.birthday = 2 THEN 'February'
					  WHEN all_count.birthday = 3 THEN 'March'
					  WHEN all_count.birthday = 4 THEN 'April'
					  WHEN all_count.birthday = 5 THEN 'May'
					  WHEN all_count.birthday = 6 THEN 'June'
					  WHEN all_count.birthday = 7 THEN 'July'
					  WHEN all_count.birthday = 8 THEN 'August'
					  WHEN all_count.birthday = 9 THEN 'September'
					  WHEN all_count.birthday = 10 THEN 'October'
					  WHEN all_count.birthday = 11 THEN 'November'
					  ELSE 'December'
				 END), ((early_count.count1 * 100) / all_count.count)::real
		  FROM all_count
		  JOIN early_count ON all_count.birthday = early_count.birthday
		  GROUP BY all_count.birthday, early_count.count1, all_count.count
        );
    END
$$ LANGUAGE plpgsql;


-- Тестовые запросы

SELECT * FROM func_percent_of_entrances(); 