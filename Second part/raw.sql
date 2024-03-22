-- DROP TABLE Události_v_kalendářích;
-- DROP TABLE Kalendar;
-- DROP TABLE Zprava;
-- DROP TABLE Sekretarka_reditel;
-- DROP TABLE Sekretarka_manazera;
-- DROP TABLE Reditel;
-- DROP TABLE Manazer;
-- DROP TABLE Udalost;
-- DROP TABLE Uzivatel;
--
-- DROP SEQUENCE seq_kalendar;
-- DROP SEQUENCE zprava_seq;
--
-- DROP TRIGGER trg_create_manager_calendar;
-- DROP TRIGGER trg_create_director_calendar;
-- DROP TRIGGER trg_ensure_single_ceo_director;
-- -- DROP TRIGGER trg_check_vlastnik;
-- DROP TRIGGER trg_check_oddeleni;
-- DROP TRIGGER trg_create_zprava_and_event_calendar;
-- DROP TRIGGER trg_prevent_manager_in_director;
--
-- DROP VIEW DirectorEventsForManagers;

CREATE TABLE Uzivatel (
  ID NUMBER PRIMARY KEY,
  Jmeno VARCHAR2(100),
  Datum_narozeni DATE,
  Email VARCHAR2(100),
  Heslo VARCHAR2(100),
  Oddeleni VARCHAR2(100) CHECK (Oddeleni IN ('Sales', 'Marketing', 'Finance', 'CEO'))
);

CREATE TABLE Udalost (
    ID NUMBER PRIMARY KEY,
    Datum DATE,
    Cas VARCHAR2(50),
    Popis VARCHAR2(255),
    Misto VARCHAR2(100),
    Nazev VARCHAR2(100),
    Doba_trvani NUMBER,
    Dostupnost VARCHAR2(10) CHECK (Dostupnost IN ('Dostupny', 'Nedostupny')),
    ID_Tvurce NUMBER NOT NULL,
    CONSTRAINT fk_udalost_tvurce FOREIGN KEY (ID_Tvurce)
        REFERENCES Uzivatel (ID),
    Dalsi_informace VARCHAR2(255)
);

CREATE TABLE Zprava (
    ID NUMBER PRIMARY KEY,
    Udalost_ID NUMBER,
    Resviver_ID NUMBER,
    CONSTRAINT fk_zprava_udalost FOREIGN KEY (Udalost_ID) REFERENCES Udalost(ID)
);

CREATE TABLE Manazer (
  ID NUMBER PRIMARY KEY,
  -- Additional manager-specific columns here, if necessary
  CONSTRAINT fk_manazer_uzivatel FOREIGN KEY (ID) REFERENCES Uzivatel(ID)
);

CREATE TABLE Reditel (
    ID NUMBER PRIMARY KEY,
    -- Additional director-specific columns here, if necessary
    CONSTRAINT fk_reditel_uzivatel FOREIGN KEY (ID) REFERENCES Uzivatel(ID)
);

CREATE TABLE Sekretarka_manazera (
  ID NUMBER PRIMARY KEY,
  Manazer_ID NUMBER UNIQUE,
  -- Additional columns for the secretary as needed
  CONSTRAINT fk_sekretarka_manazera_manazer FOREIGN KEY (Manazer_ID) REFERENCES Manazer(ID)
);

CREATE TABLE Sekretarka_reditel (
  ID NUMBER PRIMARY KEY,
  Reditel_ID NUMBER UNIQUE,
  -- Additional columns for the secretary as needed
  CONSTRAINT fk_sekretarka_reditel_reditel FOREIGN KEY (Reditel_ID) REFERENCES Reditel(ID)
);

CREATE SEQUENCE seq_kalendar
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE TABLE Kalendar (
    ID NUMBER PRIMARY KEY,
    ID_Vlastnika NUMBER,
    ID_Spravce NUMBER,
    CONSTRAINT fk_kalendar_spravce FOREIGN KEY (ID_Spravce) REFERENCES Uzivatel(ID),
    CONSTRAINT fk_kalendar_vlastnik FOREIGN KEY (ID_Vlastnika) REFERENCES Uzivatel(ID)
);

CREATE TABLE Události_v_kalendářích (
  Udalost_ID NUMBER,
  Kalendar_ID NUMBER NOT NULL,
  CONSTRAINT pk_udalosti_v_kalendari PRIMARY KEY (Udalost_ID, Kalendar_ID),
  CONSTRAINT fk_udalosti_v_kalendari_udalost FOREIGN KEY (Udalost_ID) REFERENCES Udalost(ID),
  CONSTRAINT fk_udalosti_v_kalendari_kalendar FOREIGN KEY (Kalendar_ID)
      REFERENCES Kalendar(ID) ON DELETE CASCADE
);


-- Step 3: Triggers for automatic calendar creation
CREATE OR REPLACE TRIGGER trg_create_manager_calendar
AFTER INSERT ON Manazer
FOR EACH ROW
DECLARE
    V_ODDELENI VARCHAR2(100);
    V_COUNT NUMBER;
BEGIN
    -- Retrieve the department of the newly inserted manager
    SELECT Oddeleni INTO V_ODDELENI FROM Uzivatel WHERE ID = :NEW.ID;

    -- Check if the department is CEO and raise an error if it is
    IF V_ODDELENI = 'CEO' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Managers with the department CEO cannot have a calendar.');
    END IF;

    -- Check if there's already an existing user with the same department
    SELECT COUNT(*) INTO V_COUNT FROM Uzivatel WHERE Oddeleni = V_ODDELENI AND ID != :NEW.ID;
    IF V_COUNT > 0 THEN
        RAISE_APPLICATION_ERROR(-20002, 'A user with the same department already exists.');
    END IF;

    -- If checks pass, insert the new calendar entry
    INSERT INTO Kalendar (ID, ID_Vlastnika, ID_Spravce)
    VALUES (seq_kalendar.NEXTVAL, :NEW.ID, :NEW.ID);
END;
/

CREATE OR REPLACE TRIGGER trg_create_director_calendar
AFTER INSERT ON Reditel
FOR EACH ROW
DECLARE V_ODDELENI VARCHAR2(100);
BEGIN
    SELECT Oddeleni INTO V_ODDELENI FROM Uzivatel WHERE ID = :NEW.ID;
    IF V_ODDELENI != 'CEO' THEN
        RAISE_APPLICATION_ERROR(-20001, 'Only directors with the department CEO can have a calendar.');
    END IF;

    INSERT INTO Kalendar (ID, ID_Vlastnika, ID_Spravce)
    VALUES (seq_kalendar.NEXTVAL, :NEW.ID, :NEW.ID);
END;
/

CREATE OR REPLACE TRIGGER trg_ensure_single_ceo_director
BEFORE INSERT ON Reditel
FOR EACH ROW
DECLARE
  v_count_ceo NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO v_count_ceo
  FROM Uzivatel u
  JOIN Reditel r ON u.ID = r.ID
  WHERE u.Oddeleni = 'CEO';

  IF v_count_ceo > 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'There can only be one director with the department CEO.');
  END IF;
END;
/


-- CREATE OR REPLACE TRIGGER trg_check_vlastnik
-- AFTER INSERT OR UPDATE ON Kalendar
-- FOR EACH ROW
-- DECLARE
--   v_count NUMBER;
--   PRAGMA AUTONOMOUS_TRANSACTION;
-- BEGIN
--   -- Check if the ID exists in Manager or Reditel table
--   SELECT COUNT(*)
--   INTO v_count
--   FROM (
--     SELECT ID FROM Manazer
--     UNION
--     SELECT ID FROM Reditel
--   )
--   WHERE ID = :NEW.ID_Vlastnika;
--
--   IF v_count = 0 THEN
--     -- If the ID does not exist, raise an application error
--     RAISE_APPLICATION_ERROR(-20001, 'ID_Vlastnika must be an ID of a Manager or a Director.');
--   END IF;
--
--   COMMIT; -- Commit the autonomous transaction
-- END;
-- /

CREATE OR REPLACE TRIGGER trg_check_oddeleni
BEFORE INSERT OR UPDATE ON Kalendar
FOR EACH ROW
DECLARE
  v_oddeleni_vlastnika VARCHAR2(100);
  v_oddeleni_spravce VARCHAR2(100);
BEGIN
  -- Retrieve the 'Oddeleni' of the 'Vlastnik'
  SELECT Oddeleni INTO v_oddeleni_vlastnika
  FROM Uzivatel
  WHERE ID = :NEW.ID_Vlastnika;

  -- Retrieve the 'Oddeleni' of the 'Spravce'
  SELECT Oddeleni INTO v_oddeleni_spravce
  FROM Uzivatel
  WHERE ID = :NEW.ID_Spravce;

  -- Check if the 'Oddeleni' of 'Vlastnik' is the same as that of 'Spravce'
  IF v_oddeleni_vlastnika != v_oddeleni_spravce AND v_oddeleni_vlastnika != 'CEO' THEN
    RAISE_APPLICATION_ERROR(-20002, 'The department of the owner must be the same as that of the administrator.');
  END IF;
END;
/

CREATE SEQUENCE zprava_seq
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

-- ALTER TABLE Udalost ADD CONSTRAINT fk_udalost_kalendar FOREIGN KEY (Kalendar_ID) REFERENCES Kalendar(ID);

CREATE OR REPLACE TRIGGER trg_create_zprava_and_event_calendar
AFTER INSERT ON Události_v_kalendářích
FOR EACH ROW
DECLARE
    v_id_tvurce NUMBER;
    v_id_vlastnika NUMBER;
BEGIN
    -- Find the creator of the event
    SELECT ID_Tvurce INTO v_id_tvurce FROM Udalost WHERE ID = :NEW.Udalost_ID;

    -- Find the owner of the calendar associated with the event
    SELECT ID_Vlastnika INTO v_id_vlastnika FROM Kalendar WHERE ID = :NEW.Kalendar_ID;

    -- Check if the creator of the event is not the owner of the calendar
    IF v_id_tvurce != v_id_vlastnika THEN
        -- Insert a new Zprava since the IDs do not match
        INSERT INTO Zprava (ID, Udalost_ID, Resviver_ID)
        VALUES (zprava_seq.NEXTVAL, :NEW.Udalost_ID, v_id_vlastnika);
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_prevent_manager_in_director
AFTER INSERT ON Události_v_kalendářích
FOR EACH ROW
DECLARE
    v_tvurce_dept VARCHAR2(100);
    v_vlastnik_dept VARCHAR2(100);
BEGIN
    -- Get the department of the event creator
    SELECT Oddeleni
    INTO v_tvurce_dept
    FROM Uzivatel
    WHERE ID = (
        SELECT ID_Tvurce
        FROM Udalost
        WHERE ID = :NEW.Udalost_ID
    );

    -- Get the department of the calendar owner
    SELECT Oddeleni
    INTO v_vlastnik_dept
    FROM Uzivatel
    WHERE ID = (
        SELECT ID_Vlastnika
        FROM Kalendar
        WHERE ID = :NEW.Kalendar_ID
    );

    -- Check if the event creator is not a manager or if the calendar owner is not the director
    IF v_tvurce_dept != 'CEO' AND v_vlastnik_dept = 'CEO' THEN
        RAISE_APPLICATION_ERROR(-20001, 'A manager or manager secretary cannot insert events into the director''s calendar.');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_check_manazer_sekretarka_dept
BEFORE INSERT ON Sekretarka_manazera
FOR EACH ROW
DECLARE
  v_manager_oddeleni VARCHAR2(100);
  v_secretary_oddeleni VARCHAR2(100);
BEGIN
  -- Retrieve the department of the manager
  SELECT Oddeleni INTO v_manager_oddeleni
  FROM Uzivatel
  WHERE ID = (
      SELECT ID FROM Manazer
      WHERE ID = :NEW.Manazer_ID
  );

  -- Retrieve the department of the secretary
  SELECT Oddeleni INTO v_secretary_oddeleni
  FROM Uzivatel
  WHERE ID = :NEW.ID;

  -- Check if the departments match
  IF v_manager_oddeleni != v_secretary_oddeleni THEN
    RAISE_APPLICATION_ERROR(-20010, 'The secretary''s department must match the manager''s department.');
  END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_check_reditel_sekretarka_dept
BEFORE INSERT ON Sekretarka_reditel
FOR EACH ROW
DECLARE
  v_director_oddeleni VARCHAR2(100);
  v_secretary_oddeleni VARCHAR2(100);
BEGIN
  -- Retrieve the department of the director
  SELECT Oddeleni INTO v_director_oddeleni
  FROM Uzivatel
  WHERE ID = (
      SELECT ID FROM Reditel
      WHERE ID = :NEW.Reditel_ID
  );

  -- Retrieve the department of the secretary
  SELECT Oddeleni INTO v_secretary_oddeleni
  FROM Uzivatel
  WHERE ID = :NEW.ID;

  -- Check if the departments match
  IF v_director_oddeleni != v_secretary_oddeleni THEN
    RAISE_APPLICATION_ERROR(-20011, 'The secretary''s department must match the director''s department.');
  END IF;
END;
/


CREATE OR REPLACE VIEW DirectorEventsForManagers AS
SELECT
    e.ID AS EventID,
    e.Datum,
    e.Cas,
    e.Dostupnost
FROM
    Udalost e
    INNER JOIN Události_v_kalendářích uk ON e.ID = uk.Udalost_ID
    INNER JOIN Kalendar k ON uk.Kalendar_ID = k.ID
    INNER JOIN Uzivatel uz ON k.ID_Vlastnika = uz.ID
WHERE
    uz.Oddeleni = 'CEO'; -- Assuming directors are identified by being in the 'CEO' department



-- Insert a new Uzivatel
INSERT INTO Uzivatel (ID, Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES (9, 'John Doe', TO_DATE('1990-05-15', 'YYYY-MM-DD'), 'safa@gmail.com', 'password123', 'Sales');

-- Insert a new Manazer based on the Uzivatel ID
INSERT INTO Manazer (ID)
VALUES (9);

-- Insert a new Uzivatel
INSERT INTO Uzivatel (ID, Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES (10, 'Jane Smith', TO_DATE('1985-11-22', 'YYYY-MM-DD'), 'director@gmail.com', 'secret', 'CEO');

-- Insert a new Reditel based on the Uzivatel ID
INSERT INTO Reditel (ID)
VALUES (10);

INSERT INTO Uzivatel (ID, Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES (13, 'Alice Johnson', TO_DATE('1990-05-15', 'YYYY-MM-DD'), 'alice@gmail.com', 'password123', 'Finance');

-- Insert a new Manazer based on the Uzivatel ID
INSERT INTO Manazer (ID)
VALUES (13);


-- Insert a new Udalost
INSERT INTO Udalost (ID, Datum, Cas, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce, Dalsi_informace)
VALUES (1, TO_DATE('2022-05-15', 'YYYY-MM-DD'), '10:00', 'Meeting with clients', 'Conference Room', 'Client Meeting', 1, 'Nedostupny', 9, NULL);

INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (1, 1);


-- Insert a new Udalost
INSERT INTO Udalost (ID, Datum, Cas, Popis, Misto, Nazev, Doba_trvani, Dostupnost,  ID_Tvurce, Dalsi_informace)
VALUES (2, TO_DATE('2022-06-20', 'YYYY-MM-DD'), '14:00', 'Budget review meeting', 'Board Room', 'Budget Meeting', 2, 'Nedostupny', 10, NULL);

INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (2, 2);

-- Insert a new uzivatel Secretary for the Manager
INSERT INTO Uzivatel (ID, Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES (11, 'Alice Johnson', TO_DATE('1990-05-15', 'YYYY-MM-DD'), 'safdgdsha@gmail.com', 'passwosdgsdgrd123', 'Sales');

-- Insert a new Secretary for the Manager based on the Uzivatel ID
INSERT INTO Sekretarka_manazera (ID, Manazer_ID)
VALUES (11, 9);

-- Insert a new uzivatel Secretary for the Director
INSERT INTO Uzivatel (ID, Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES (12, 'Bob Brown', TO_DATE('1990-05-15', 'YYYY-MM-DD'), 'directorsec@gmail.com', 'secretarypassword', 'CEO');

-- Insert a new Secretary for the Director based on the Uzivatel ID
INSERT INTO Sekretarka_reditel (ID, Reditel_ID)
VALUES (12, 10);


-- Insert a new Udalost secretary
INSERT INTO Udalost (ID, Datum, Cas, Popis, Misto, Nazev,  Doba_trvani, Dostupnost, ID_Tvurce, Dalsi_informace)
VALUES (3, TO_DATE('2022-07-25', 'YYYY-MM-DD'), '09:00', 'Team building event', 'Outdoor Park', 'Team Building', 3, 'Nedostupny',  11, 'Additional information1');

INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (3, 1);

INSERT INTO Udalost (ID, Datum, Cas, Popis, Misto, Nazev,  Doba_trvani, Dostupnost, ID_Tvurce, Dalsi_informace)
VALUES (4, TO_DATE('2022-07-26', 'YYYY-MM-DD'), '01:00', 'Team building ', 'Outdoor', 'Team ', 10, 'Nedostupny', 12, 'Additional information2');

INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (4, 2);

INSERT INTO Udalost (ID, Datum, Cas, Popis, Misto, Nazev,  Doba_trvani, Dostupnost, ID_Tvurce, Dalsi_informace)
VALUES (5, TO_DATE('2022-07-26', 'YYYY-MM-DD'), '01:00', 'Team building fgf ', 'Outdoor', 'Team ', 10, 'Nedostupny', 10, 'Additional information3');

INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (5, 1);

INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (5, 3);

INSERT INTO Udalost (ID, Datum, Cas, Popis, Misto, Nazev,  Doba_trvani, Dostupnost, ID_Tvurce, Dalsi_informace)
VALUES (6, TO_DATE('2022-07-26', 'YYYY-MM-DD'), '01:00', 'Team buildinnnxnxgxxgfg fgf ', 'Outdoor', 'Tevvndndfam ', 10, 'Nedostupny', 9, 'Additional information6');

INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (6, 1);

