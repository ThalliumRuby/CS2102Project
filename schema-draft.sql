CREATE TABLE healthDeclaration(
    declearDate DATE,
    temp NUMERIC(3, 1) NOT NULL,
    fever BOOLEAN NOT NULL DEFAULT FALSE,
    eid INTEGER,
    FOREIGN KEY (eid) REFERENCES Employees(eid),
    PRIMARY KEY (eid, date),
);

CREATE TABLE Employees(
    eid INTEGER,
    ename VARCHAR(50) NOT NULL,
    email VARCHAR(50),
    contact VARCHAR(50) NOT NULL,
    resignedDate DATE,
    type VARCHAR(10),
    PRIMARY KEY (eid),
    CHECK (type IN {'Junior', 'Senior', 'Manager'})
);

