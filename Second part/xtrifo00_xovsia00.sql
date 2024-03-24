CREATE SEQUENCE uzivatel_seq
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE TABLE Uzivatel (
  ID NUMBER PRIMARY KEY,
  Jmeno VARCHAR2(100),
  Datum_narozeni DATE,
  Email VARCHAR2(100),
  Heslo VARCHAR2(100),
  Oddeleni VARCHAR2(10) CHECK (Oddeleni IN ('Sales', 'Marketing', 'Finance', 'CEO'))
);

CREATE SEQUENCE udalost_seq
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE TABLE Udalost (
    ID NUMBER PRIMARY KEY,
    DATUM_CAS TIMESTAMP,
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

CREATE SEQUENCE zprava_seq
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE TABLE Zprava (
    ID NUMBER PRIMARY KEY,
    Udalost_ID NUMBER,
    Resviver_ID NUMBER,
    CONSTRAINT fk_zprava_udalost FOREIGN KEY (Udalost_ID) REFERENCES Udalost(ID)
);

CREATE TABLE Manazer (
  ID NUMBER PRIMARY KEY,
  CONSTRAINT fk_manazer_uzivatel FOREIGN KEY (ID) REFERENCES Uzivatel(ID)
);

CREATE TABLE Reditel (
    ID NUMBER PRIMARY KEY,
    CONSTRAINT fk_reditel_uzivatel FOREIGN KEY (ID) REFERENCES Uzivatel(ID)
);

CREATE TABLE Sekretarka_manazera (
  ID NUMBER PRIMARY KEY,
  Manazer_ID NUMBER,
  CONSTRAINT fk_sekretarka_manazera_manazer FOREIGN KEY (Manazer_ID) REFERENCES Manazer(ID)
);

CREATE TABLE Sekretarka_reditel (
  ID NUMBER PRIMARY KEY,
  Reditel_ID NUMBER,
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

CREATE SEQUENCE udalosti_v_kalendari_seq
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

CREATE TABLE Události_v_kalendářích (
  Udalost_ID NUMBER,
  Kalendar_ID NUMBER NOT NULL,
  CONSTRAINT pk_udalosti_v_kalendari PRIMARY KEY (Udalost_ID, Kalendar_ID),
  CONSTRAINT fk_udalosti_v_kalendari_udalost FOREIGN KEY (Udalost_ID) REFERENCES Udalost(ID),
  CONSTRAINT fk_udalosti_v_kalendari_kalendar FOREIGN KEY (Kalendar_ID)
      REFERENCES Kalendar(ID) ON DELETE CASCADE
);

--Trigger to add id and check if the id is not null and if it already exists
CREATE OR REPLACE TRIGGER trg_check_uzivatel_id_not_null
BEFORE INSERT ON Uzivatel
FOR EACH ROW
DECLARE
    v_id_exists NUMBER;
BEGIN
    IF :NEW.ID IS NULL THEN
        LOOP
            SELECT uzivatel_seq.NEXTVAL INTO :NEW.ID FROM DUAL;

            SELECT COUNT(*) INTO v_id_exists FROM Uzivatel WHERE ID = :NEW.ID;

            EXIT WHEN v_id_exists = 0;
        END LOOP;
    ELSE
        -- If an ID is manually specified, check if it already exists.
        SELECT COUNT(*) INTO v_id_exists FROM Uzivatel WHERE ID = :NEW.ID;
        IF v_id_exists > 0 THEN
            RAISE_APPLICATION_ERROR(-20001, 'Specified ID already exists.');
        END IF;
    END IF;
END;
/

--Trigger to add id and check if the id is not null and if it already exists
CREATE OR REPLACE TRIGGER trg_check_udalost_id_not_null
BEFORE INSERT ON Udalost
FOR EACH ROW
DECLARE
    v_id_exists NUMBER;
BEGIN
    IF :NEW.ID IS NULL THEN
        LOOP
            SELECT udalost_seq.NEXTVAL INTO :NEW.ID FROM DUAL;

            SELECT COUNT(*) INTO v_id_exists FROM Udalost WHERE ID = :NEW.ID;

            EXIT WHEN v_id_exists = 0;
        END LOOP;
    ELSE
        -- If an ID is manually specified, check if it already exists.
        SELECT COUNT(*) INTO v_id_exists FROM Udalost WHERE ID = :NEW.ID;
        IF v_id_exists > 0 THEN
            RAISE_APPLICATION_ERROR(-20002, 'Specified ID already exists in Udalost.');
        END IF;
    END IF;
END;
/

--Trigger to create a calendar for a manager
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

--Trigger to create a calendar for the director
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

--Trigger to ensure only one director with the department CEO
CREATE OR REPLACE TRIGGER trg_ensure_single_ceo_director
BEFORE INSERT ON Reditel
FOR EACH ROW
DECLARE
  v_count_ceo NUMBER;
  v_count_director NUMBER;
BEGIN
  SELECT COUNT(*)
  INTO v_count_ceo
  FROM Uzivatel u
  JOIN Reditel r ON u.ID = r.ID
  WHERE u.Oddeleni = 'CEO';

  SELECT COUNT(*)
  INTO v_count_director
  FROM Reditel;

  IF v_count_ceo > 0 THEN
    RAISE_APPLICATION_ERROR(-20003, 'There can only be one director with the department CEO.');
  END IF;

  IF v_count_director > 0 THEN
    RAISE_APPLICATION_ERROR(-20004, 'There can only be one director in the system.');
  END IF;
END;
/


--Trigger to check if calendar already exists for a user
CREATE OR REPLACE TRIGGER trg_check_kalendar_count
BEFORE INSERT OR UPDATE ON Kalendar
FOR EACH ROW
DECLARE
  v_count NUMBER;
BEGIN

  SELECT COUNT(*) INTO v_count
  FROM Kalendar
  WHERE ID_Vlastnika = :NEW.ID_Vlastnika;

  -- If attempting to insert a new calendar for a 'Vlastnik' who already has one, raise an error
  IF v_count > 0 AND INSERTING THEN
    RAISE_APPLICATION_ERROR(-20003, 'The user already has a calendar.');
  END IF;
END;
/


--Triggers for event and calendar management
CREATE OR REPLACE TRIGGER trg_create_zprava_and_event_calendar
AFTER INSERT ON Události_v_kalendářích
FOR EACH ROW
DECLARE
    v_id_tvurce NUMBER;
    v_id_vlastnika NUMBER;
    v_oddeleni_tvurce VARCHAR2(100);
    v_oddeleni_vlastnika VARCHAR2(100);
BEGIN
    -- Find the creator of the event
    SELECT ID_Tvurce INTO v_id_tvurce FROM Udalost WHERE ID = :NEW.Udalost_ID;

    -- Find the department of the event creator
    SELECT Oddeleni INTO v_oddeleni_tvurce FROM Uzivatel WHERE ID = v_id_tvurce;

    -- Find the owner of the calendar associated with the event
    SELECT ID_Vlastnika INTO v_id_vlastnika FROM Kalendar WHERE ID = :NEW.Kalendar_ID;

    -- Find the department of the calendar owner
    SELECT Oddeleni INTO v_oddeleni_vlastnika FROM Uzivatel WHERE ID = v_id_vlastnika;


    --Check if the creator of the event is not the owner of the calendar or the CEO
    IF v_oddeleni_tvurce != v_oddeleni_vlastnika AND v_oddeleni_tvurce != 'CEO' THEN
        RAISE_APPLICATION_ERROR(-20001, 'The event creator cannot be the owner of the calendar.');
    END IF;

    -- Check if the creator of the event is not the owner of the calendar
    IF v_id_tvurce != v_id_vlastnika  THEN
        -- Insert a new Zprava since the IDs do not match and the department condition is met
        INSERT INTO Zprava (ID, Udalost_ID, Resviver_ID)
        VALUES (zprava_seq.NEXTVAL, :NEW.Udalost_ID, v_id_vlastnika);
    END IF;
END;
/

-- Trigger to prevent managers or manager secretaries from inserting events into the director's calendar
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

-- Trigger to check if the department of the secretary matches the manager's department
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

-- Trigger to check if the department of the secretary matches the director's department
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

-- Trigger to check for event overlap in the same calendar
CREATE OR REPLACE TRIGGER trg_check_event_overlap
BEFORE INSERT OR UPDATE ON Události_v_kalendářích
FOR EACH ROW
DECLARE
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration NUMBER;
    v_conflict_count NUMBER;
BEGIN
    -- Retrieve the start time and duration of the event being inserted or updated.
    SELECT DATUM_CAS, Doba_trvani INTO v_start_time, v_duration
    FROM Udalost
    WHERE ID = :NEW.Udalost_ID;

    -- Calculate the end time of the event.
    v_end_time := v_start_time + NUMTODSINTERVAL(v_duration, 'HOUR');

    -- Check for any events that overlap with the time frame of the new event in the same calendar.
    SELECT COUNT(*)
    INTO v_conflict_count
    FROM Udalost e
    JOIN Události_v_kalendářích uk ON e.ID = uk.Udalost_ID
    WHERE uk.Kalendar_ID = :NEW.Kalendar_ID
    AND (
        (e.DATUM_CAS BETWEEN v_start_time AND v_end_time)
        OR (e.DATUM_CAS + NUMTODSINTERVAL(e.Doba_trvani, 'HOUR') BETWEEN v_start_time AND v_end_time)
        OR (v_start_time BETWEEN e.DATUM_CAS AND e.DATUM_CAS + NUMTODSINTERVAL(e.Doba_trvani, 'HOUR'))
    )
    AND e.ID != :NEW.Udalost_ID; -- Exclude the event itself in case of an update

    -- If there's at least one conflict, raise an error.
    IF v_conflict_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20020, 'This event overlaps with another event in the same calendar.');
    END IF;
END;
/


-- View to display events of director for managers
CREATE OR REPLACE VIEW DirectorEventsForManagers AS
SELECT
    e.ID AS EventID,
    e.DATUM_CAS AS EventDateTime,
    e.Dostupnost
FROM
    Udalost e
    INNER JOIN Události_v_kalendářích uk ON e.ID = uk.Udalost_ID
    INNER JOIN Kalendar k ON uk.Kalendar_ID = k.ID
    INNER JOIN Uzivatel uz ON k.ID_Vlastnika = uz.ID
WHERE
    uz.Oddeleni = 'CEO';

-- Insert Director User
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Director Name', TO_DATE('1970-01-01', 'YYYY-MM-DD'), 'director@example.com', 'dir123', 'CEO');

-- Assuming the director's user ID is manually set to 1
-- Insert Director Role
INSERT INTO Reditel (ID)
VALUES (1);

-- Director creates an event
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-01-01 10:00:00', 'Director Meeting', 'Board Room', 'Strategy Meeting', 2, 'Nedostupny', 1);

--add event to the director's calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (1, 1);

-- Manager 1 and their event
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Manager One', TO_DATE('1980-02-01', 'YYYY-MM-DD'), 'manager.one@example.com', 'mgr123', 'Sales');
INSERT INTO Manazer (ID)
VALUES (2);
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-02-01 11:00:00', 'Sales Review', 'Conference Room A', 'Quarterly Sales', 2, 'Nedostupny', 2);

--add event to the manager's calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (2, 2);

-- Manager 2 and their event
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Manager Two', TO_DATE('1981-03-02', 'YYYY-MM-DD'), 'manager.two@example.com', 'mgr456', 'Marketing');
INSERT INTO Manazer (ID)
VALUES (3);
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-03-02 12:00:00', 'Marketing Brainstorm', 'Conference Room B', 'Campaign Ideas', 1, 'Nedostupny', 3);

--add event to the manager's calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (3, 3);

-- Manager 3 and their event
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Manager Three', TO_DATE('1982-04-03', 'YYYY-MM-DD'), 'manager.three@example.com', 'mgr789', 'Finance');
INSERT INTO Manazer (ID)
VALUES (4);
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-04-03 13:00:00', 'Budget Planning', 'Conference Room C', 'Fiscal Year Budget', 3, 'Nedostupny', 4);

--add event to the manager's calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (4, 4);

-- Secretary 1 for Manager 1
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Secretary One', TO_DATE('1990-05-05', 'YYYY-MM-DD'), 'sec.one@example.com', 'sec123', 'Sales');
-- Assuming the next ID is 5
INSERT INTO Sekretarka_manazera (ID, Manazer_ID)
VALUES (5, 2);

-- Secretary 2 for Manager 1
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Secretary Two', TO_DATE('1991-06-06', 'YYYY-MM-DD'), 'sec.two@example.com', 'sec456', 'Sales');
-- Assuming the next ID is 6
INSERT INTO Sekretarka_manazera (ID, Manazer_ID)
VALUES (6, 2);

-- Secretary 3 for Manager 1
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Secretary Three', TO_DATE('1992-07-07', 'YYYY-MM-DD'), 'sec.three@example.com', 'sec789', 'Sales');
-- Assuming the next ID is 7
INSERT INTO Sekretarka_manazera (ID, Manazer_ID)
VALUES (7, 2);


-- Secretary 1 for Manager 2
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Secretary One M2', TO_DATE('1990-08-08', 'YYYY-MM-DD'), 'secm2.one@example.com', 'secm2123', 'Marketing');
-- Assuming the next ID is 8
INSERT INTO Sekretarka_manazera (ID, Manazer_ID)
VALUES (8, 3);

-- Secretary 2 for Manager 2
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Secretary Two M2', TO_DATE('1991-09-09', 'YYYY-MM-DD'), 'secm2.two@example.com', 'secm2456', 'Marketing');
-- Assuming the next ID is 9
INSERT INTO Sekretarka_manazera (ID, Manazer_ID)
VALUES (9, 3);

-- Secretary 3 for Manager 2
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Secretary Three M2', TO_DATE('1992-10-10', 'YYYY-MM-DD'), 'secm2.three@example.com', 'secm2789', 'Marketing');
-- Assuming the next ID is 10
INSERT INTO Sekretarka_manazera (ID, Manazer_ID)
VALUES (10, 3);

-- Secretary 1 for Manager 3
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Secretary One M3', TO_DATE('1990-11-11', 'YYYY-MM-DD'), 'secm3.one@example.com', 'secm3123', 'Finance');
-- Assuming the next ID is 11
INSERT INTO Sekretarka_manazera (ID, Manazer_ID)
VALUES (11, 4);

-- Secretary 2 for Manager 3
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Secretary Two M3', TO_DATE('1991-12-12', 'YYYY-MM-DD'), 'secm3.two@example.com', 'secm3456', 'Finance');
-- Assuming the next ID is 12
INSERT INTO Sekretarka_manazera (ID, Manazer_ID)
VALUES (12, 4);

-- Secretary 3 for Manager 3
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Secretary Three M3', TO_DATE('1992-01-13', 'YYYY-MM-DD'), 'secm3.three@example.com', 'secm3789', 'Finance');
-- Assuming the next ID is 13
INSERT INTO Sekretarka_manazera (ID, Manazer_ID)
VALUES (13, 4);

-- Events for first Secretaries of Manager 1
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-05-05 14:00:00', 'Documentation Review', 'Office 1', 'Doc Review S1', 1, 'Nedostupny', 5);

--add event to the secretary's manager calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (5, 2);

-- Events for second Secretaries of Manager 1
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-06-06 15:00:00', 'Client Meeting', 'Office 2', 'Client Meeting S2', 2, 'Nedostupny', 6);

--add event to the secretary's manager calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (6, 2);

-- Events for third Secretaries of Manager 1
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-07-07 16:00:00', 'Team Building', 'Office 3', 'Team Building S3', 3, 'Nedostupny', 7);

--add event to the secretary's manager calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (7, 2);

-- Events for first Secretaries of Manager 2
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-08-08 17:00:00', 'Marketing Meeting', 'Office 4', 'Marketing Meeting S1', 1, 'Nedostupny', 8);

--add event to the secretary's manager calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (8, 3);

-- Events for second Secretaries of Manager 2
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-09-09 18:00:00', 'Campaign Planning', 'Office 5', 'Campaign Planning S2', 2, 'Nedostupny', 9);

--add event to the secretary's manager calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (9, 3);

-- Events for third Secretaries of Manager 2
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-10-10 19:00:00', 'Product Launch', 'Office 6', 'Product Launch S3', 3, 'Nedostupny', 10);

--add event to the secretary's manager calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (10, 3);

-- Events for first Secretaries of Manager 3
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-11-11 20:00:00', 'Budget Review', 'Office 7', 'Budget Review S1', 1, 'Nedostupny', 11);

--add event to the secretary's manager calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (11, 4);

-- Events for second Secretaries of Manager 3
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-12-12 21:00:00', 'Financial Report', 'Office 8', 'Financial Report S2', 2, 'Nedostupny', 12);

--add event to the secretary's manager calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (12, 4);

-- Events for third Secretaries of Manager 3
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2024-01-01 22:00:00', 'Quarterly Review', 'Office 9', 'Quarterly Review S3', 3, 'Nedostupny', 13);
--add event to the secretary's manager calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (13, 4);

-- Secretary 1 for the Director
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Director Secretary 1', TO_DATE('1991-08-08', 'YYYY-MM-DD'), 'dsec1@example.com', 'dsec123', 'CEO');
-- Assuming the next ID is 8
INSERT INTO Sekretarka_reditel (ID, Reditel_ID)
VALUES (14, 1);

-- Event for Director's Secretary 1
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-08-01 17:00:00', 'Director Task 1', 'Director Office', 'Task D1', 1, 'Nedostupny', 14);

-- add event to the director's secretary calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (14, 1);

-- Secretary 2 for the Director
INSERT INTO Uzivatel (ID ,Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES (NULL, 'Director Secretary 2', TO_DATE('1992-09-09', 'YYYY-MM-DD'), 'dsec2@example.com', 'dsec456', 'CEO');
-- Assuming the next ID is 9
INSERT INTO Sekretarka_reditel (ID, Reditel_ID)
VALUES (uzivatel_seq.currval, 1);

-- Event for Director's Secretary 2
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-09-02 18:00:00', 'Director Task 2', 'Director Office', 'Task D2', 2, 'Nedostupny', 15);

--add event to the director's secretary calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (udalost_seq.currval, 1);

-- Secretary 3 for the Director
INSERT INTO Uzivatel (Jmeno, Datum_narozeni, Email, Heslo, Oddeleni)
VALUES ('Director Secretary 3', TO_DATE('1993-10-10', 'YYYY-MM-DD'), 'dsec3@example.com', 'dsec789', 'CEO');
-- Assuming the next ID is 10
INSERT INTO Sekretarka_reditel (ID, Reditel_ID)
VALUES (uzivatel_seq.currval, 1);

-- Event for Director's Secretary 3
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-10-03 19:00:00', 'Director Task 3', 'Director Office', 'Task D3', 3, 'Nedostupny', 16);

--add event to the director's secretary calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (udalost_seq.currval, 1);

-- Event from Director to all Managers and himself
-- Director creates a Teambuilding event for himself
INSERT INTO Udalost (DATUM_CAS, Popis, Misto, Nazev, Doba_trvani, Dostupnost, ID_Tvurce)
VALUES (TIMESTAMP '2023-12-01 09:00:00', 'Annual Teambuilding', 'Outdoor Retreat', 'Teambuilding', 8, 'Dostupny', 1);
--add event to the director's calendar
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (udalost_seq.currval, 1);

-- Director creates a Teambuilding event for Manager 1
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (udalost_seq.currval, 2);

-- Director creates a Teambuilding event for Manager 2
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (udalost_seq.currval, 3);

-- Director creates a Teambuilding event for Manager 3
INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
VALUES (udalost_seq.currval, 4);

