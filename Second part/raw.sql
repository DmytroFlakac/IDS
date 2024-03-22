CREATE TABLE Uzivatel (
  ID NUMBER PRIMARY KEY,
  Jmeno VARCHAR2(100),
  Datum_narozeni DATE,
  Email VARCHAR2(100),
  Heslo VARCHAR2(100),
  Oddeleni VARCHAR2(100)
);

CREATE TABLE Udalost (
    ID NUMBER PRIMARY KEY,
    Datum DATE,
    Cas VARCHAR2(50),
    Popis VARCHAR2(255),
    Misto VARCHAR2(100),
    Nazev VARCHAR2(100),
    Vyrobny VARCHAR2(100),
    Doba_trvani NUMBER,
    Dostupnost VARCHAR2(50),
    Kalendar_ID NUMBER,
    ID_Tvurce NUMBER NOT NULL,
    CONSTRAINT fk_udalost_tvurce FOREIGN KEY (ID_Tvurce)
        REFERENCES Uzivatel (ID)
);

CREATE TABLE Zprava (
  ID NUMBER PRIMARY KEY,
  Dalsi_informace VARCHAR2(255),
  Udalost_ID NUMBER,
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
BEGIN
    INSERT INTO Kalendar (ID, ID_Vlastnika, ID_Spravce)
    VALUES (seq_kalendar.NEXTVAL, :NEW.ID, :NEW.ID);
END;
/

CREATE OR REPLACE TRIGGER trg_create_director_calendar
AFTER INSERT ON Reditel
FOR EACH ROW
BEGIN
    INSERT INTO Kalendar (ID, ID_Vlastnika, ID_Spravce)
    VALUES (seq_kalendar.NEXTVAL, :NEW.ID, :NEW.ID);
END;
/

-- CREATE OR REPLACE TRIGGER trg_check_vlastnik
-- BEFORE INSERT OR UPDATE ON Kalendar
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
  IF v_oddeleni_vlastnika != v_oddeleni_spravce THEN
    RAISE_APPLICATION_ERROR(-20002, 'The department of the owner must be the same as that of the administrator.');
  END IF;
END;
/

CREATE SEQUENCE zprava_seq
START WITH 1
INCREMENT BY 1
NOCACHE
NOCYCLE;

ALTER TABLE Udalost ADD CONSTRAINT fk_udalost_kalendar FOREIGN KEY (Kalendar_ID) REFERENCES Kalendar(ID);

CREATE OR REPLACE TRIGGER trg_create_zprava
AFTER INSERT OR UPDATE ON Udalost
FOR EACH ROW
DECLARE
    v_id_vlastnika NUMBER;
BEGIN
    -- Find the owner of the calendar associated with the event
    SELECT ID_Vlastnika INTO v_id_vlastnika FROM Kalendar WHERE ID = :NEW.Kalendar_ID;

    -- Check if the creator of the event is not the owner of the calendar
    IF :NEW.ID_Tvurce != v_id_vlastnika THEN
        -- Insert a new Zprava since the IDs do not match
        INSERT INTO Zprava (ID, Udalost_ID, Dalsi_informace)
        VALUES (zprava_seq.NEXTVAL, :NEW.ID, 'Message related information');
    END IF;
END;
/

CREATE OR REPLACE TRIGGER trg_create_zprava_and_event_calendar
AFTER INSERT ON Udalost
FOR EACH ROW
DECLARE
    v_id_vlastnika NUMBER;
BEGIN
    -- Find the owner of the calendar associated with the event
    SELECT ID_Vlastnika INTO v_id_vlastnika FROM Kalendar WHERE ID = :NEW.Kalendar_ID; -- Assuming you have a Kalendar_ID in the Udalost table

    -- Check if the creator of the event is not the owner of the calendar
    IF :NEW.ID_Tvurce != v_id_vlastnika THEN
        -- Insert a new Zprava since the IDs do not match
        INSERT INTO Zprava (ID, Udalost_ID, Dalsi_informace)
        VALUES (zprava_seq.NEXTVAL, :NEW.ID, 'Message related information');
    END IF;

    -- Insert into Události_v_kalendářích to associate the event with the calendar
    INSERT INTO Události_v_kalendářích (Udalost_ID, Kalendar_ID)
    VALUES (:NEW.ID, :NEW.Kalendar_ID);
END;
/


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

-- Insert a new Udalost
INSERT INTO Udalost (ID, Datum, Cas, Popis, Misto, Nazev, Vyrobny, Doba_trvani, Dostupnost, Kalendar_ID, ID_Tvurce)
VALUES (1, TO_DATE('2022-05-15', 'YYYY-MM-DD'), '10:00', 'Meeting with clients', 'Conference Room', 'Client Meeting', 'Sales', 2, 'Public', 1, 9);

-- Insert a new Udalost
INSERT INTO Udalost (ID, Datum, Cas, Popis, Misto, Nazev, Vyrobny, Doba_trvani, Dostupnost, Kalendar_ID, ID_Tvurce)
VALUES (2, TO_DATE('2022-06-20', 'YYYY-MM-DD'), '14:00', 'Budget review meeting', 'Board Room', 'Budget Meeting', 'Finance', 1, 'Private', 2, 10);

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
INSERT INTO Udalost (ID, Datum, Cas, Popis, Misto, Nazev, Vyrobny, Doba_trvani, Dostupnost, Kalendar_ID, ID_Tvurce)
VALUES (3, TO_DATE('2022-07-25', 'YYYY-MM-DD'), '09:00', 'Team building event', 'Outdoor Park', 'Team Building', 'HR', 3, 'Public', 2, 11);

INSERT INTO Udalost (ID, Datum, Cas, Popis, Misto, Nazev, Vyrobny, Doba_trvani, Dostupnost, Kalendar_ID, ID_Tvurce)
VALUES (4, TO_DATE('2022-07-26', 'YYYY-MM-DD'), '01:00', 'Team building ', 'Outdoor', 'Team ', 'Sale', 10, 'Public', 2, 11);