-- Создать хранимую процедуру, которая, не уничтожая БД,
-- уничтожает все те таблицы текущей БД, имена к-ых начинаются с фразы 'TableName'

CREATE TABLE IF NOT EXISTS TableNameTest(
  Firstname VARCHAR(50),
  Lasttname VARCHAR(50),
  Regdate DATE
);

CREATE OR REPLACE PROCEDURE drop_tables()
AS $$
  DECLARE
  	table_name VARCHAR;
    TableCursor CURSOR FOR (SELECT tablename
							FROM pg_tables
							WHERE schemaname='public' AND tablename LIKE 'tablename%');
  BEGIN
    OPEN TableCursor;
    FETCH TableCursor INTO table_name;
    WHILE FOUND LOOP
      EXECUTE 'DROP TABLE IF EXISTS '|| quote_ident(table_name) || ' CASCADE';
      FETCH TableCursor INTO table_name;
    END LOOP;
    CLOSE TableCursor;
  END  
$$ LANGUAGE PLPGSQL;

CALL drop_tables();


-- Создать хранимую процедуру с выходным параметром, к-ая выводит список имен и параметров
-- всех скалярных SQL ф-ий пользователя в текущей БД. Имена ф-ий без параметров не выводить
-- Имена и список параметров должны выводиться в одну строку
-- Выходной параметр возвращает количество найденных функций

CREATE OR REPLACE PROCEDURE get_functions()
AS $$
DECLARE
    amount INT;
    rec RECORD;
BEGIN
    amount := 0;
    FOR rec IN SELECT routine_name || ' (' || ARRAY_TO_STRING(ARRAY_AGG(DISTINCT parameter_name), ', ') || ')'
      FROM information_schema.routines
      JOIN information_schema.parameters ON parameters.specific_name = routines.specific_name
      WHERE information_schema.routines.specific_schema = 'public'
		 GROUP BY routine_name
    LOOP
      amount := amount + 1;
      RAISE NOTICE '%', rec;
    END LOOP;
    RAISE NOTICE 'amount: %', amount;
END;
$$ LANGUAGE PLPGSQL;

CALL get_functions();


-- Создать хранимую процедуру с выходным параметром, которая уничтожает все SQL DML триггеры в
-- текущей БД. Выходной параметр возвращает количество уничтоженных триггеров

CREATE OR REPLACE PROCEDURE delete_triggers()
AS $$
DECLARE
  amount_triggers INT;
  rec RECORD;
BEGIN 
  amount_triggers:= 0;
    FOR rec IN SELECT * FROM information_schema.triggers
  LOOP
    EXECUTE 'DROP TRIGGER IF EXISTS ' || rec.trigger_name || ' ON ' || rec.event_object_table;
    amount_triggers = amount_triggers + 1;
  END LOOP;
    RAISE NOTICE 'amount_triggers: %', amount_triggers;  
END;
$$ LANGUAGE PLPGSQL;

CALL delete_triggers();


-- Создать хранимую процедуру с входным параметром, которая выводит имена и описания типа объектов
-- (только хранимых процедур и скалярных ф-ий), в тексте к-ых на языке SQL встречается строка,
-- задаваемая параметром процедуры

CREATE OR REPLACE PROCEDURE get_objects(description TEXT)
AS $$
DECLARE
  rec RECORD;
BEGIN
  FOR rec IN SELECT * FROM information_schema.routines
  WHERE routine_type IN ('PROCEDURE', 'FUNCTION')
  AND information_schema.routines.routine_name LIKE '%' || description || '%'
  AND information_schema.routines.specific_schema = 'public'
LOOP
  RAISE NOTICE '%', rec.routine_name;
END LOOP;
END;
$$ LANGUAGE PLPGSQL;

CALL get_objects('peer');