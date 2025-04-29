-- init database
-- T1

/*
   Database Schema and Procedures for a Transportation System

   This SQL script defines a comprehensive database schema for managing a transportation system.
   It establishes the core infrastructure with tables for transport types, zones, stations, lines,
   and their relationships, as well as user-related structures such as person records, offers,
   subscriptions, contracts, journey tracking, and billing. In addition, it includes logging tables to
   track historical changes and stored procedures to add new entries with validation logic.
   The script also provides various views and functions that simplify common queries, perform data
   retrieval and calculations, and support business rules for cost estimation and subscription management.
*/

CREATE TABLE transport_type (
    	code VARCHAR(3) PRIMARY KEY,
    	name VARCHAR(32) UNIQUE,
    	capacity INT CHECK (capacity > 0),
    	avg_interval INT CHECK (avg_interval > 0)
);

CREATE TABLE zone (
    	zone_id SERIAL PRIMARY KEY,
    	name VARCHAR(32) UNIQUE,
    	price FLOAT CHECK (price > 0)
);

CREATE TABLE station (
    	id INT PRIMARY KEY,
    	name VARCHAR(64),
	town VARCHAR(32),
    	zone INT REFERENCES zone(zone_id),
    	type VARCHAR(3) REFERENCES transport_type(code)	
);

CREATE TABLE line (
    	code VARCHAR(3) PRIMARY KEY,
    	type VARCHAR(3) REFERENCES transport_type(code)
);


CREATE TABLE station_line (
    	station_id INT REFERENCES station(id) ON DELETE CASCADE,
    	line_code VARCHAR(3) REFERENCES line(code) ON DELETE CASCADE,
    	position INT CHECK (position > 0),
    	PRIMARY KEY (station_id, line_code)
);

-- T2

CREATE TABLE person (
    	email VARCHAR(128) PRIMARY KEY,
    	firstname VARCHAR(32),
    	lastname VARCHAR(32),
    	phone VARCHAR(10),
    	address TEXT,
    	town VARCHAR(32),
    	zipcode VARCHAR(5)
);

CREATE TABLE offer (
    	code VARCHAR(5) PRIMARY KEY,
    	name VARCHAR(32),
    	price FLOAT,
    	nb_month INT CHECK (nb_month > 0),
    	zone_from INT REFERENCES zone(zone_id),
    	zone_to INT REFERENCES zone(zone_id)
);

CREATE TABLE subscription (
    	num INT PRIMARY KEY,
    	email VARCHAR(128) REFERENCES person(email),
    	code VARCHAR(5) REFERENCES offer(code),
    	dateofsub DATE,
    	status VARCHAR(32) CHECK (status IN ('Registered', 'Pending', 'Incomplete'))
);


-- T3

CREATE TABLE service (
	name VARCHAR(32) PRIMARY KEY,
	discount INT CHECK (discount >= 0 AND discount <= 100)
);

CREATE TABLE contract (
    	email VARCHAR(128) REFERENCES person(email),
    	date_beginning DATE,
   	service VARCHAR(32) REFERENCES service(name),
    	login VARCHAR(32) UNIQUE,
    	PRIMARY KEY (email, date_beginning),
	date_end DATE
);


-- T4

CREATE TABLE journey (
    	id SERIAL PRIMARY KEY,
    	email VARCHAR(128) REFERENCES person(email),
    	time_start TIMESTAMP,
    	time_end TIMESTAMP,
    	station_start INT REFERENCES station(id),
    	station_end INT REFERENCES station(id)
);

CREATE TABLE bill (
    	id SERIAL PRIMARY KEY,
    	email VARCHAR(128) REFERENCES person(email),
   	year INT,
   	month INT,
   	amount FLOAT,
	paid BOOLEAN DEFAULT FALSE
);


-- T5

CREATE TABLE offer_updates (
    	id SERIAL PRIMARY KEY,
    	offer_code VARCHAR(5),
    	modification_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    	old_price FLOAT,
    	new_price FLOAT
);

CREATE TABLE subscription_status_updates (
    	id SERIAL PRIMARY KEY,
    	email VARCHAR(128),
    	subscription_code VARCHAR(5),
    	modification_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    	old_status VARCHAR(32),
    	new_status VARCHAR(32)
);

-- end init database





-- 5.1.1
-- add_transport_type(code VARCHAR (3), name VARCHAR (32), capacity INT, avg_interval INT ) RETURNS BOOLEAN

CREATE OR REPLACE FUNCTION add_transport_type(p_code VARCHAR, p_name VARCHAR, p_capacity INT, p_avg_interval INT
) RETURNS BOOLEAN AS $$
BEGIN
    	INSERT INTO transport_type (code, name, capacity, avg_interval) VALUES (p_code, p_name, p_capacity, p_avg_interval);
    	RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 5.1.2
-- add_zone(name VARCHAR (32), price FLOAT ) RETURNS BOOLEAN

CREATE OR REPLACE FUNCTION add_zone(p_name VARCHAR(32), p_price FLOAT
) RETURNS BOOLEAN AS $$
BEGIN
	IF p_price <= 0 OR ROUND(p_price::NUMERIC, 2) = 0 THEN
       	RAISE EXCEPTION 'Il faut un prix > 0 et qui ne soit pas proche de 0';
    	END IF;
	INSERT INTO zone (name, price) VALUES (p_name, p_price);
	RETURN TRUE; 
	EXCEPTION WHEN OTHERS THEN 
	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
	RETURN FALSE; 
END; 
$$ LANGUAGE plpgsql;


-- 5.1.3
-- add_station(id INT , name VARCHAR (64), town VARCHAR (32), zone INT , type VARCHAR (3)) RETURNS BOOLEAN

CREATE OR REPLACE FUNCTION add_station(
	p_id INT,
	p_name VARCHAR,
	p_town VARCHAR,
	p_zone INT,
	p_type VARCHAR
) RETURNS BOOLEAN AS $$
BEGIN
	IF NOT EXISTS (SELECT 1 FROM zone WHERE zone_id = p_zone) THEN
    		RAISE EXCEPTION '% n''existe pas', p_zone;
   	END IF;
    	IF NOT EXISTS (SELECT 1 FROM transport_type WHERE code = p_type) THEN
        	RAISE EXCEPTION '% n''existe pas', p_type;
    	END IF;
    	INSERT INTO station (id, name, town, zone, type) VALUES (p_id, p_name, p_town, p_zone, p_type);
    	RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 5.1.4
-- add_line(code VARCHAR (3), type VARCHAR (3)) RETURNS BOOLEAN

CREATE OR REPLACE FUNCTION add_line(p_code VARCHAR,
p_type VARCHAR
) RETURNS BOOLEAN AS $$
BEGIN
    	IF NOT EXISTS (SELECT 1 FROM transport_type WHERE code = p_type) THEN
        	RAISE EXCEPTION '% n''existe pas.', p_type;
    	END IF;
    	INSERT INTO line (code, type) VALUES (p_code, p_type);
    	RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 5.1.5
-- add_station_to_line( station INT , line VARCHAR (3), pos INT ) RETURNS BOOLEAN

CREATE OR REPLACE FUNCTION add_station_to_line(p_station INT, p_line VARCHAR(3),
p_pos INT
) RETURNS BOOLEAN AS $$
BEGIN
    	IF NOT EXISTS (SELECT 1 FROM line WHERE code = p_line) THEN
        	RAISE EXCEPTION '% n''existe pas', p_line;
    	END IF;
    	IF NOT EXISTS (SELECT 1 FROM station WHERE id = p_station) THEN
        	RAISE EXCEPTION '% n''existe pas', p_station;
    	END IF;
    	IF NOT EXISTS (SELECT 1 FROM station JOIN line ON station.type = line.type WHERE station.id = p_station AND line.code = p_line
    	) THEN
        	RAISE EXCEPTION 'type de station % ne matche pas avec le type de ligne %', p_station, p_line;
    	END IF;
	IF EXISTS ( SELECT 1 FROM station_line WHERE line_code = p_line AND position = p_pos
	) THEN
		RAISE EXCEPTION 'La position % est deja occupee sur la ligne %', p_pos, p_line;
	END IF;
    	INSERT INTO station_line (station_id, line_code, position) VALUES (p_station, p_line, p_pos);
    	RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN
	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;



-- 5.2.1

CREATE OR REPLACE VIEW view_transport_50_300_users AS
SELECT name AS transport FROM transport_type WHERE capacity BETWEEN 50 AND 300 ORDER BY name;

-- 5.2.2

CREATE OR REPLACE VIEW view_stations_from_villejuif AS
SELECT name AS station FROM station WHERE LOWER(town) = 'villejuif' ORDER BY name;

-- 5.2.3

CREATE OR REPLACE VIEW view_stations_zones AS
SELECT station.name AS station, zone.name AS zone FROM station
JOIN zone ON station.zone = zone.zone_id
ORDER BY zone.zone_id, station.name; -- pas obligé de mettre 'ASC' car par défaut

-- 5.2.4

CREATE OR REPLACE VIEW view_nb_station_type AS
SELECT t.name AS type, COUNT(s.id) AS stations FROM station s
JOIN transport_type t ON s.type = t.code
GROUP BY t.name
ORDER BY stations DESC, type;

-- 5.2.5

CREATE OR REPLACE VIEW view_line_duration AS
SELECT t.name AS type, line.code AS line, (COUNT(sl.station_id)-1) * t.avg_interval AS minutes FROM line
JOIN station_line as sl ON line.code = sl.line_code
JOIN transport_type as t ON line.type = t.code
GROUP BY t.name, line.code, t.avg_interval
ORDER BY t.name, line.code;

-- 5.2.6

CREATE OR REPLACE VIEW view_a_station_capacity AS
SELECT station.name AS station, t.capacity AS capacity FROM station
JOIN transport_type as t ON station.type = t.code
WHERE LOWER(station.name) LIKE 'a%'
ORDER BY station.name, t.capacity;

-- 5.3.1
-- list_station_in_line( line_code VARCHAR (3)) RETURNS setof VARCHAR (64); 

CREATE OR REPLACE FUNCTION list_station_in_line(p_line_code VARCHAR(3)
) RETURNS SETOF VARCHAR AS $$
BEGIN
    	RETURN QUERY
    	SELECT station.name FROM station_line as sl
    	JOIN station ON sl.station_id = station.id WHERE sl.line_code = p_line_code
    	ORDER BY sl.position ASC;
END;
$$ LANGUAGE plpgsql;


-- 5.3.2
-- list_types_in_zone(zone INT ) RETURNS setof VARCHAR (32); 

CREATE OR REPLACE FUNCTION list_types_in_zone(p_zone INT
) RETURNS SETOF VARCHAR(32) AS $$
BEGIN
    	RETURN QUERY
	SELECT DISTINCT t.name FROM station
    	JOIN transport_type AS t ON station.type = t.code WHERE station.zone = p_zone
    	ORDER BY t.name;
END;
$$ LANGUAGE plpgsql;


-- 5.3.3
-- get_cost_travel( station_start INT , station_end INT ) RETURNS FLOAT ; 

CREATE OR REPLACE FUNCTION get_cost_travel(p_station_start INT, p_station_end INT
) RETURNS FLOAT AS $$
DECLARE
    	zone_start INT;
    	zone_end INT;
    	total_cost FLOAT := 0;
    	q_zone_id INT;
    	q_price FLOAT;
BEGIN
    	SELECT zone INTO zone_start FROM station WHERE id = p_station_start;
    	SELECT zone INTO zone_end FROM station WHERE id = p_station_end;
    	IF zone_start IS NULL OR zone_end IS NULL THEN
        	RETURN 0; 
    	END IF;
    	FOR q_zone_id, q_price IN
        	SELECT zone_id, price FROM zone
        	WHERE zone_id BETWEEN LEAST(zone_start, zone_end) AND GREATEST(zone_start, zone_end)
    	LOOP
        	total_cost := total_cost + q_price;
    	END LOOP;

    RETURN total_cost;
END;
$$ LANGUAGE plpgsql;


-- 6.1.1

CREATE OR REPLACE FUNCTION add_person(
    	p_firstname VARCHAR(32),
    	p_lastname VARCHAR(32),
    	p_email VARCHAR(128),
    	p_phone VARCHAR(10),
    	p_address TEXT,
    	p_town VARCHAR(32),
    	p_zipcode VARCHAR(5)
) RETURNS BOOLEAN AS $$
BEGIN
    	IF EXISTS (SELECT 1 FROM person WHERE email = p_email) THEN
        	RAISE EXCEPTION '% existe deja', p_email;
    	END IF;
    	INSERT INTO person (firstname, lastname, email, phone, address, town, zipcode) VALUES (p_firstname, p_lastname, p_email, p_phone, p_address, p_town, p_zipcode);
    	RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 6.1.2

CREATE OR REPLACE FUNCTION add_offer(
    	p_code VARCHAR,
    	p_name VARCHAR,
    	p_price FLOAT,
    	p_nb_month INT,
    	p_zone_from INT,
    	p_zone_to INT
) RETURNS BOOLEAN AS $$
BEGIN
    	IF NOT EXISTS (SELECT 1 FROM zone WHERE zone_id = p_zone_from) THEN
        	RAISE EXCEPTION '% n''existe pas', p_zone_from;
    	END IF;
    	IF NOT EXISTS (SELECT 1 FROM zone WHERE zone_id = p_zone_to) THEN
        	RAISE EXCEPTION '% n''existe pas.', p_zone_to;
    	END IF;
    	IF p_nb_month <= 0 THEN
        	RAISE EXCEPTION 'Mettre un nombre de mois plus grand que 0';
    	END IF;
    	IF p_price <= 0 THEN
        	RAISE EXCEPTION 'Mettre un prix plus grand que 0';
    	END IF;
    	INSERT INTO offer (code, name, price, nb_month, zone_from, zone_to)
    	VALUES (p_code, p_name, p_price, p_nb_month, p_zone_from, p_zone_to);
    	RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 6.1.3

CREATE OR REPLACE FUNCTION add_subscription(
    	p_num INT,
    	p_email VARCHAR,
    	p_code VARCHAR,
    	p_dateofsub DATE
) RETURNS BOOLEAN AS $$
BEGIN
	IF NOT EXISTS (SELECT 1 FROM person WHERE email = p_email) THEN
        	RAISE EXCEPTION '% n''existe pas', p_email;
    	END IF;
    	IF NOT EXISTS (SELECT 1 FROM offer WHERE code = p_code) THEN
        	RAISE EXCEPTION '% non existante', p_code;
    	END IF;
    	IF EXISTS (
        	SELECT 1 FROM subscription WHERE email = p_email AND status IN ('Pending', 'Incomplete')
    	) THEN
        	RAISE EXCEPTION 'Souscription deja en attente ou incomplete';
    	END IF;
    	INSERT INTO subscription (num, email, code, dateofsub, status)
    	VALUES (p_num, p_email, p_code, p_dateofsub, 'Incomplete');
    	RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree: %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;



-- 6.2.1

CREATE OR REPLACE FUNCTION update_status(
p_num INT, p_new_status VARCHAR
) RETURNS BOOLEAN AS $$
BEGIN
    	IF NOT EXISTS (SELECT 1 FROM subscription WHERE num = p_num) THEN
        	RAISE EXCEPTION '% n''existe pas.', p_num;
    	END IF;
    	IF p_new_status NOT IN ('Registered', 'Pending', 'Incomplete') THEN
        	RAISE EXCEPTION '% invalide', p_new_status;
    	END IF;
    	UPDATE subscription
    	SET status = p_new_status
    	WHERE num = p_num;
    	RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 6.2.2

CREATE OR REPLACE FUNCTION update_offer_price(p_code VARCHAR(5), p_price FLOAT
) RETURNS BOOLEAN AS $$
BEGIN
    	IF NOT EXISTS (SELECT 1 FROM offer WHERE code = p_code) THEN
        	RAISE EXCEPTION '% n''existe pas.', p_code;
    	END IF;
    	IF p_price <= 0 THEN
        	RAISE EXCEPTION 'Le prix % doit etre strictement positif', p_price;
    	END IF;
    	UPDATE offer
    	SET price = p_price
    	WHERE code = p_code;
    	RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 6.3.1

CREATE OR REPLACE VIEW view_user_small_name AS
SELECT lastname, firstname FROM person WHERE LENGTH(lastname) <= 4
ORDER BY lastname, firstname;

-- 6.3.2

CREATE OR REPLACE VIEW view_user_subscription AS
SELECT CONCAT(person.lastname, ' ', person.firstname) AS user, offer.name AS offer FROM subscription AS s
JOIN person ON s.email = person.email
JOIN offer ON s.code = offer.code ORDER BY lastname ASC, offer ASC;

-- 6.3.3

CREATE OR REPLACE VIEW view_unloved_offers AS
SELECT name FROM offer
WHERE NOT EXISTS (SELECT 1 FROM subscription as s WHERE s.code = offer.code)
ORDER BY name;

-- 6.3.4

CREATE OR REPLACE VIEW view_pending_subscriptions AS
SELECT person.lastname, person.firstname FROM subscription as s
JOIN person ON s.email = person.email
WHERE s.status = 'Pending'
ORDER BY s.dateofsub;

-- 6.3.5

CREATE OR REPLACE VIEW view_old_subscription AS
SELECT person.lastname, person.firstname, offer.name AS subscription, s.status
FROM subscription AS s
JOIN person ON s.email = person.email
JOIN offer ON s.code = offer.code WHERE s.status IN ('Pending', 'Incomplete') AND s.dateofsub <= CURRENT_DATE - INTERVAL '21 day'
ORDER BY lastname, firstname, subscription;



-- 6.4.1

CREATE OR REPLACE FUNCTION list_station_near_user(p_email VARCHAR(128))
RETURNS SETOF TEXT AS $$
BEGIN
    	RETURN QUERY
    	SELECT DISTINCT LOWER(station.name) AS station_name
    	FROM station
    	JOIN person ON LOWER(station.town) = LOWER(person.town)
    	WHERE person.email = p_email
    	ORDER BY station_name;
END;
$$ LANGUAGE plpgsql;


-- 6.4.2

CREATE OR REPLACE FUNCTION list_subscribers(p_code_offer VARCHAR(5)
) RETURNS SETOF TEXT AS $$
BEGIN
    	RETURN QUERY
    	SELECT DISTINCT CONCAT(person.lastname, ' ', person.firstname) FROM subscription AS s
    	JOIN person ON s.email = person.email WHERE s.code = p_code_offer
	ORDER BY CONCAT(person.lastname, ' ', person.firstname);
END;
$$ LANGUAGE plpgsql;

-- 6.4.3

CREATE OR REPLACE FUNCTION list_subscription( p_email VARCHAR(128), p_date DATE
) RETURNS SETOF VARCHAR(5) AS $$
BEGIN
    	RETURN QUERY
    	SELECT DISTINCT s.code FROM subscription AS s
    	WHERE s.email = p_email AND s.status = 'Registered' AND s.dateofsub <= p_date
   	ORDER BY s.code;
END;
$$ LANGUAGE plpgsql;


-- 7.1.1

-- add_service(name VARCHAR (32), discount INT ) RETURNS BOOLEAN; 

CREATE OR REPLACE FUNCTION add_service(p_name VARCHAR,
p_discount INT
) RETURNS BOOLEAN AS $$
BEGIN
    	IF p_discount < 0 OR p_discount > 100 THEN
        	RAISE EXCEPTION ' % doit etre un nombre entre 0 et 100', p_discount;
    	END IF;
    	INSERT INTO service (name, discount)
    	VALUES (p_name, p_discount);
    	RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 7.1.2

-- add_contract(email VARCHAR (128), date_beginning DATE , service VARCHAR (32)) RETURNS BOOLEAN; 
-- Trouver moyen de rajouter lettre après le login pour éviter les doublons !! (trouvé)

CREATE OR REPLACE FUNCTION add_contract( p_email VARCHAR, p_date_beginning DATE, 
p_service VARCHAR
) RETURNS BOOLEAN AS $$
DECLARE
    	base_login VARCHAR(32);
    	unique_login VARCHAR(32);
    	lettre CHAR := 'a';
BEGIN
    	IF NOT EXISTS (SELECT 1 FROM person WHERE email = p_email) THEN
        	RAISE EXCEPTION '% n''existe pas', p_email;
    	END IF;
    	IF NOT EXISTS (SELECT 1 FROM service WHERE name = p_service) THEN
        	RAISE EXCEPTION '% n''existe pas', p_service;
    	END IF;
    	SELECT CONCAT(LOWER(SUBSTRING(lastname, 1, 6)), '_', LOWER(SUBSTRING(firstname, 1, 1)))
    	INTO base_login
    	FROM person WHERE email = p_email;
    	unique_login := base_login;
    	WHILE EXISTS (SELECT 1 FROM contract WHERE login = unique_login) LOOP
        	unique_login := CONCAT(base_login, lettre);
        	lettre := CHR(ASCII(lettre) + 1);
    	END LOOP;
    	INSERT INTO contract (email, date_beginning, service, login)
    	VALUES (p_email, p_date_beginning, p_service, unique_login);
    	RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;



-- 7.1.3

-- end_contract(email VARCHAR (128), date_end DATE ) RETURNS BOOLEAN;

CREATE OR REPLACE FUNCTION end_contract(p_email VARCHAR(128), p_date_end DATE
) RETURNS BOOLEAN AS $$
BEGIN
    	IF NOT EXISTS (SELECT 1 FROM contract WHERE email = p_email AND date_beginning <= p_date_end AND (date_end IS NULL OR date_end >= p_date_end)) THEN
        	RAISE EXCEPTION 'Pas de contrat actif pour %', p_email;
    	END IF;
    	UPDATE contract
    	SET date_end = p_date_end
    	WHERE email = p_email AND date_end IS NULL;
    	RETURN TRUE;
EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;



-- 7.2.1

-- update_service(name VARCHAR (32), discount INT ) RETURNS BOOLEAN;

CREATE OR REPLACE FUNCTION update_service(p_name VARCHAR(32), p_discount INT
) RETURNS BOOLEAN AS $$
BEGIN
    	IF NOT EXISTS (SELECT 1 FROM service WHERE name = p_name) THEN
        	RAISE EXCEPTION '% n''existe pas.', p_name;
    	END IF;
    	IF p_discount < 0 OR p_discount > 100 THEN
        	RAISE EXCEPTION ' % doit etre entre 0 et 100', p_discount;
    	END IF;
    	UPDATE service
    	SET discount = p_discount
    	WHERE name = p_name;
    	RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 7.2.2

-- update_employee_mail(login  VARCHAR (8),  email  VARCHAR (128))  RETURNS  BOOLEAN;
-- Ne fonctionne pas car je ne trouve pas le moyen d'outrepasser les clés primaires qui sont liées en cascade

CREATE OR REPLACE FUNCTION update_employee_mail(p_login VARCHAR(32),
p_new_email VARCHAR(128)
) RETURNS BOOLEAN AS $$
DECLARE
    	current_email VARCHAR(128);
BEGIN
    	SELECT email INTO current_email FROM contract WHERE login = p_login;
    	IF current_email IS NULL THEN
        	RAISE EXCEPTION '% n''existe ps', p_login;
    	END IF;
    	IF current_email = p_new_email THEN
        	RETURN TRUE;
    	END IF;
        UPDATE person SET email = p_new_email WHERE email = current_email;
        UPDATE subscription SET email = p_new_email WHERE email = current_email;
        UPDATE contract SET email = p_new_email WHERE login = p_login;
        RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 7.3.1

CREATE OR REPLACE VIEW view_employees AS
SELECT person.lastname, person.firstname, c.login, c.service FROM contract as c
JOIN person ON c.email = person.email
WHERE c.date_end IS NULL OR c.date_end > CURRENT_DATE
ORDER BY lastname, firstname, c.login;


-- 7.3.2

CREATE OR REPLACE VIEW view_nb_employees_per_service AS
SELECT service.name AS service, COUNT(c.login) AS nb
FROM service
LEFT JOIN contract AS c ON service.name = c.service AND (c.date_end IS NULL OR c.date_end > CURRENT_DATE)
GROUP BY service.name
ORDER BY service.name;


-- 7.4.1
-- list_login_employee( date_service DATE ) RETURNS setof VARCHAR (8); 

CREATE OR REPLACE FUNCTION list_login_employee(date_service DATE) 
RETURNS SETOF VARCHAR AS $$
BEGIN
    RETURN QUERY
    SELECT login FROM contract
    WHERE date_beginning <= date_service AND (date_end IS NULL OR date_end >= date_service)
    ORDER BY login;
END;
$$ LANGUAGE plpgsql;


-- 7.4.2
-- list_not_employee( date_service DATE ) RETURNS TABLE ( lastname VARCHAR(32), firstname VARCHAR (32), has_worked TEXT); 

CREATE OR REPLACE FUNCTION list_not_employee(date_service DATE) 
RETURNS TABLE (lastname VARCHAR(32), firstname VARCHAR(32), has_worked TEXT
) AS $$
BEGIN
    	RETURN QUERY
    	SELECT person.lastname, person.firstname, 
        	CASE 
            		WHEN EXISTS ( SELECT 1 FROM contract as c 
                	WHERE c.email = person.email
            		) THEN 'YES'
            		ELSE 'NO'
        	END AS has_worked
    	FROM person
    	WHERE NOT EXISTS (
        	SELECT 1 FROM contract AS c
        	WHERE c.email = person.email 
        	AND c.date_beginning <= date_service AND (c.date_end IS NULL OR c.date_end >= date_service)
    	)
    	ORDER BY has_worked DESC, person.lastname, person.firstname;
END;
$$ LANGUAGE plpgsql;



-- 7.4.3

CREATE OR REPLACE FUNCTION list_subscription_history(p_email VARCHAR(128))
RETURNS TABLE (type TEXT, name VARCHAR, start_date DATE, duration TEXT
) AS $$
BEGIN
    	RETURN QUERY
    	SELECT 'sub' AS type, offer.name AS name, s.dateofsub AS start_date,
        	CONCAT(offer.nb_month * 30, ' days') AS duration
    	FROM subscription AS s
    	JOIN offer ON s.code = offer.code WHERE s.email = p_email
    	UNION ALL
    	SELECT 
        	'ctr' AS type, c.service AS name, c.date_beginning AS start_date,
        	CASE
            	WHEN c.date_end IS NOT NULL THEN CONCAT(c.date_end - c.date_beginning, ' days')
            	ELSE ''
        	END AS duration
    	FROM contract AS c
    	WHERE c.email = p_email;
END;
$$ LANGUAGE plpgsql;


-- 8.1.1
-- add_journey(email VARCHAR (128), time_start TIMESTAMP , time_end TIMESTAMP , station_start INT , station_end INT ) RETURNS BOOLEAN; 

CREATE OR REPLACE FUNCTION add_journey(
    	p_email VARCHAR(128),
    	p_time_start TIMESTAMP,
    	p_time_end TIMESTAMP,
    	p_station_start INT,
    	p_station_end INT)
RETURNS BOOLEAN AS $$
BEGIN
    	IF NOT EXISTS (SELECT 1 FROM person WHERE email = p_email) THEN
        	RAISE EXCEPTION '% n''existe pas', p_email;
    	END IF;
    	IF NOT EXISTS (SELECT 1 FROM station WHERE id = p_station_start) THEN
        	RAISE EXCEPTION '% n''existe pas', p_station_start;
    	END IF;
    	IF NOT EXISTS (SELECT 1 FROM station WHERE id = p_station_end) THEN
        	RAISE EXCEPTION 'La station d''arrivee % n''existe pas.', p_station_end;
    	END IF;
    	IF p_time_end - p_time_start > INTERVAL '24 hours' THEN
        	RAISE EXCEPTION 'trajet > 24 heures';
    	END IF;
    	IF EXISTS (
        	SELECT 1 FROM journey WHERE email = p_email
          	AND ((p_time_start, p_time_end) OVERLAPS (time_start, time_end))
    	) THEN
        	RAISE EXCEPTION ' Overlap pour %', p_email;
    	END IF;
    	INSERT INTO journey (email, time_start, time_end, station_start, station_end)
    	VALUES (p_email, p_time_start, p_time_end, p_station_start, p_station_end);
    	RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;

-- 8.1.2
-- add_bill(email VARCHAR (128), year INT , month INT ) RETURNS BOOLEAN; 


CREATE OR REPLACE FUNCTION add_bill(p_email VARCHAR(128), p_year INT, p_month INT) 
RETURNS BOOLEAN AS $$
DECLARE
    	total_trajet NUMERIC := 0;
    	total_abo NUMERIC := 0;
    	total_amount NUMERIC;
    	discount_percent INT := 0;
    	start_date DATE := MAKE_DATE(p_year, p_month, 1);
    	end_date DATE := (start_date + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
BEGIN
    	IF NOT EXISTS (SELECT 1 FROM person WHERE email = p_email) THEN
        	RAISE EXCEPTION '% n''existe pas.', p_email;
    	END IF;
    	IF CURRENT_DATE <= end_date THEN
        	RAISE EXCEPTION ' %-% non fini', p_month, p_year;
    	END IF;
    	IF EXISTS (SELECT 1 FROM bill WHERE email = p_email AND year = p_year AND month = p_month) THEN
        	RETURN TRUE;
    	END IF;
    	SELECT COALESCE(SUM(zone.price), 0) INTO total_trajet -- Ici j'utilise la fonction COALESCE à plusieurs reprises car au debut ça me retournait des factures à valeurs NULL
    	FROM journey AS j
    	JOIN station AS s_start ON j.station_start = s_start.id
    	JOIN station AS s_end ON j.station_end = s_end.id
    	JOIN zone ON zone.zone_id BETWEEN LEAST(s_start.zone, s_end.zone) AND GREATEST(s_start.zone, s_end.zone)
    	WHERE j.email = p_email AND j.time_start >= start_date AND j.time_start < start_date + INTERVAL '1 month' AND NOT EXISTS (
        	SELECT 1 FROM subscription AS s JOIN offer ON s.code = offer.code
          	WHERE s.email = p_email AND s.dateofsub <= end_date AND (s.dateofsub + INTERVAL '1 month' * offer.nb_month) >= start_date AND LEAST(s_start.zone, s_end.zone) >= offer.zone_from AND GREATEST(s_start.zone, s_end.zone) <= offer.zone_to
      );

    	SELECT COALESCE(SUM(offer.price), 0) INTO total_abo
    	FROM subscription AS s
    	JOIN offer ON s.code = offer.code WHERE s.email = p_email AND s.dateofsub <= end_date AND (s.dateofsub + INTERVAL '1 month' * offer.nb_month) >= start_date;
    
    	total_amount := total_trajet + total_abo;

    	SELECT COALESCE(MAX(service.discount),0) INTO discount_percent
    	FROM contract AS c JOIN service ON c.service = service.name
    	WHERE c.email = p_email AND c.date_beginning <= end_date AND (c.date_end IS NULL OR c.date_end >= start_date);
    
    	total_amount := total_amount * (1 - discount_percent / 100.0);

    	IF total_amount <= 0 THEN
        	RETURN TRUE;
    	END IF;
    	INSERT INTO bill (email, year, month, amount) VALUES (p_email, p_year, p_month, ROUND(total_amount, 2));
    	RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 8.1.3
-- pay_bill(email VARCHAR (128), year INT , month INT ) RETURNS BOOLEAN;

CREATE OR REPLACE FUNCTION pay_bill(p_email VARCHAR(128), p_year INT, p_month INT
) RETURNS BOOLEAN AS $$
BEGIN 
	IF NOT EXISTS (SELECT 1 FROM person WHERE email = p_email) THEN 
		RAISE EXCEPTION ' % n''existe pas.', p_email; 
	END IF;
    	IF NOT EXISTS (SELECT 1 FROM bill WHERE email = p_email AND year = p_year AND month = p_month) THEN
        	RETURN FALSE;
    	END IF;
    	IF (SELECT amount FROM bill WHERE email = p_email AND year = p_year AND month = p_month) <= 0 THEN
        	RETURN FALSE; -- Normalement on ne devrait rien trouver puisque la fonction precedente ne laisse pas les factures dont le prix est nul s'inserer dans la table
    	END IF;
    	UPDATE bill
    	SET paid = TRUE WHERE email = p_email and year = p_year AND month = p_month;
    	RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 8.1.4
-- generate_bill(year INT , month INT ) RETURNS BOOLEAN;

CREATE OR REPLACE FUNCTION generate_bill( p_year INT, p_month INT)
RETURNS BOOLEAN AS $$
DECLARE
    	user_email VARCHAR(128);
	result BOOLEAN;
	start_date DATE := MAKE_DATE(p_year, p_month, 1);
	end_date DATE := (start_date + INTERVAL '1 month' - INTERVAL '1 day')::DATE;
BEGIN
	IF CURRENT_DATE <= end_date THEN
        	RAISE EXCEPTION ' %-% non fini', p_month, p_year;
    	END IF;
    	FOR user_email IN 
        	SELECT DISTINCT email FROM person
    	LOOP
        	result := add_bill(user_email, p_year, p_month);
    	END LOOP;
    	RETURN TRUE;
	EXCEPTION WHEN OTHERS THEN
    	RAISE NOTICE 'Erreur rencontree : %', SQLERRM;
    	RETURN FALSE;
END;
$$ LANGUAGE plpgsql;


-- 8.2.1

CREATE OR REPLACE VIEW view_all_bills AS
SELECT person.lastname, person.firstname, bill.id AS bill_number, bill.amount AS bill_amount FROM bill
JOIN person ON bill.email = person.email
ORDER BY bill.id;

-- 8.2.2

CREATE OR REPLACE VIEW view_bill_per_month AS
SELECT bill.year, bill.month, COUNT(bill.id) AS bills, SUM(bill.amount) AS total_amount
FROM bill
GROUP BY bill.year, bill.month
ORDER BY bill.year, bill.month;


-- 8.2.3

CREATE OR REPLACE VIEW view_average_entries_station AS
SELECT t.name AS type, station.name AS station,
ROUND(SUM(1.0) / COUNT(DISTINCT DATE(j.time_start)), 2) AS entries 
FROM journey AS j
JOIN station ON j.station_start = station.id
JOIN transport_type AS t ON station.type = t.code
GROUP BY station.name, t.name
ORDER BY t.name, station.name;


-- 8.2.4

CREATE OR REPLACE VIEW view_current_non_paid_bills AS
SELECT p.lastname, p.firstname, bill.id AS bill_number, bill.amount AS bill_amount
FROM bill
JOIN person as p ON bill.email = p.email
WHERE bill.paid = FALSE
ORDER BY p.lastname, bill.id;


-- 9.2.1

CREATE OR REPLACE FUNCTION log_offer_update()
RETURNS TRIGGER AS $$
BEGIN
    	INSERT INTO offer_updates (offer_code, old_price, new_price) VALUES (OLD.code, OLD.price, NEW.price);
    	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER store_offer_updates
AFTER UPDATE OF price ON offer
FOR EACH ROW
EXECUTE FUNCTION log_offer_update();

-- 9.2.2

CREATE OR REPLACE FUNCTION log_status_update()
RETURNS TRIGGER AS $$
BEGIN
    	INSERT INTO subscription_status_updates ( email, subscription_code, old_status, new_status) VALUES (OLD.email, OLD.code, OLD.status, NEW.status);
    	RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER store_status_updates
AFTER UPDATE OF status ON subscription
FOR EACH ROW
EXECUTE FUNCTION log_status_update();


-- 9.3.1

CREATE OR REPLACE VIEW view_offer_updates AS
SELECT offer_code as subscription, modification_time as modification, old_price, new_price
FROM offer_updates
ORDER BY modification_time;


-- 9.3.2

CREATE OR REPLACE VIEW view_status_updates AS
SELECT email, subscription_code AS sub, modification_time AS modification, old_status, new_status 
FROM subscription_status_updates
ORDER BY modification_time;













