--MODIFICACIONES ACTORMOVIES
--Vamos a cambiar la tabla actormovies, para poner que el actorid y
--movieid sean foreign keys, y que estas dos juntas actuen como pk

ALTER TABLE public.imdb_actormovies
    ADD CONSTRAINT imdb_actormovies_pkey PRIMARY KEY (actorid, movieid);

ALTER TABLE public.imdb_actormovies
    ADD CONSTRAINT imdb_actormovies_actorid_fkey FOREIGN KEY (actorid) REFERENCES public.imdb_actors (actorid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

ALTER TABLE public.imdb_actormovies
    ADD CONSTRAINT imdb_actormovies_movieid_fkey FOREIGN KEY (movieid) REFERENCES public.imdb_movies (movieid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

--MODIFICACIONES DIRECTORMOVIES
--En la tabla directormovies, hemos decidido que son innecesarias la
--asignacion de ids en una secuencia, ya que estos se calculan en las
--tablas directors y movies
--Ademas, hemos decidido que la primary key de esta tabla deberia ser simplemente
--juntar los campos directorid y movieid, ya que dados estos dos identificamos de
--forma única el la tabla directormovies

ALTER TABLE public.imdb_directormovies
    ALTER COLUMN directorid DROP DEFAULT;

ALTER TABLE public.imdb_directormovies
    ALTER COLUMN movieid DROP DEFAULT;

ALTER TABLE public.imdb_directormovies
    DROP CONSTRAINT imdb_directormovies_pkey;

ALTER TABLE public.imdb_directormovies
    ADD CONSTRAINT imdb_directormovies_pkey PRIMARY KEY (directorid, movieid);

--MODIFICACIONES ORDERS
--Vamos a cambiar la tabla orders, para que el customerid sea un
--foreign key de customers

ALTER TABLE public.orders
    ADD CONSTRAINT orders_customerid_fkey FOREIGN KEY (customerid) REFERENCES public.customers (customerid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

--Actualizamos la tabla orders para que los valores por defecto de netamount, tax, y totalamount
--sean 0

ALTER TABLE orders
    ALTER COLUMN netamount SET DEFAULT 0;

ALTER TABLE orders
    ALTER COLUMN tax SET DEFAULT 21;

ALTER TABLE orders
    ALTER COLUMN totalamount SET DEFAULT 0;

--MODIFICACIONES ORDERDETAIL
--Modificaciones en al tabla order detail. Lo primero que queremos hacer es que los campos
--orderid y prod_id formen la primary key de esta tabla. Esta tabla tiene información inconsistente
--ya que dado un orderid y un prod_id en algunos casos obtenemos varios resultados con un valor de cantidad
--cuando el resultado deberia ser único y la cantidad ser la suma de cantidades. Por ello, vamos
--a crear una tabla auxiliar llamada tempo, en la que corregimos ese error, y luego volcamos la informacion
--correcta a la tabla orderdetail
--Ademas, queremos que los campos orderid y prod_id sean claves foraneas de sus respectivas tablas

CREATE TABLE tempo AS (
    SELECT
        orderid,
        prod_id,
        sum(quantity
) AS quantity
    FROM
        orderdetail
    GROUP BY
        orderid,
        prod_id
);

DELETE FROM public.orderdetail;

INSERT INTO public.orderdetail (orderid, prod_id, quantity)
SELECT
    orderid,
    prod_id,
    quantity
FROM
    tempo;

DROP TABLE tempo;

ALTER TABLE public.orderdetail
    ADD CONSTRAINT orderdetail_orderid_fkey FOREIGN KEY (orderid) REFERENCES public.orders (orderid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

ALTER TABLE public.orderdetail
    ADD CONSTRAINT orderdetail_prod_id_fkey FOREIGN KEY (prod_id) REFERENCES public.products (prod_id) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

ALTER TABLE public.orderdetail
    ADD CONSTRAINT orderdetail_pkey PRIMARY KEY (orderid, prod_id);

--MODIFICACIONES TABLA CUSTOMERS
--Hemos decidido quitar algunos campos que estaban marcados como NOT NULL de la tabla customers,
--ya que nuestra aplicacion no los necesita para registrar nuevos usuarios. Tambien vamos a poner
--algunos como que se pueden quedar a NULL, ya que son obligatorios en el proceso de registro de
--nuestra aplicacion

ALTER TABLE public.customers
    ALTER COLUMN
    address1 DROP NOT NULL;

ALTER TABLE public.customers
    ALTER COLUMN country DROP NOT NULL;

ALTER TABLE public.customers
    ALTER COLUMN region DROP NOT NULL;

ALTER TABLE public.customers
    ALTER COLUMN lastname DROP NOT NULL;

ALTER TABLE public.customers
    ALTER COLUMN creditcardtype DROP NOT NULL;

ALTER TABLE public.customers
    ALTER COLUMN city DROP NOT NULL;

ALTER TABLE public.customers
    ALTER COLUMN email SET NOT NULL;

ALTER TABLE public.customers
    ALTER COLUMN phone SET NOT NULL;

ALTER TABLE public.customers
    ALTER COLUMN gender SET NOT NULL;

ALTER TABLE public.customers
    ALTER COLUMN age SET NOT NULL;

--Actualizamos la tabla customers ya que hay usuarios repetidos con el mismo username. Lo que
--vamos a hacer en vez de eleminar esos usuarios, es hacer una concatenacion de su nombre de
--usuario con su id, para hacer eliminar los usuarios repetidos.

UPDATE
    customers
SET
    username = reals.realusername
FROM (
    SELECT
        concat(users.username, customerid) AS realusername,
        customerid,
        users.username
    FROM
        customers AS c,
        (
            SELECT
                aux.username
            FROM (
                SELECT
                    count(username) AS repetitions,
                    username
                FROM
                    customers
                GROUP BY
                    username) AS aux
            WHERE
                aux.repetitions > 1) AS users
        WHERE
            users.username = c.username) AS reals
WHERE
    reals.customerid = customers.customerid;

--Una vez modificados los nombres de usuario para que sean unicos, ya podemos poner como unica la
--columna de username de la tabla customers

ALTER TABLE customers
    ADD CONSTRAINT UC_username UNIQUE (username);

--CONFIGURACIÓN DE SUCUENCIAS DE CREACIÓN DE IDS
--Tenemos que modificar las secuencias de creacion de ids, para que obtengan el valor mas alto de
--de la tabla

SELECT
    setval('customers_customerid_seq', (
            SELECT
                max(customerid)
            FROM customers), TRUE);

SELECT
    setval('orders_orderid_seq', (
            SELECT
                max(orderid)
            FROM orders), TRUE);

SELECT
    setval('products_prod_id_seq', (
            SELECT
                max(prod_id)
            FROM products), TRUE);

SELECT
    setval('imdb_movies_movieid_seq', (
            SELECT
                max(movieid)
            FROM imdb_movies), TRUE);

SELECT
    setval('imdb_actors_actorid_seq', (
            SELECT
                max(actorid)
            FROM imdb_actors), TRUE);

SELECT
    setval('imdb_directors_directorid_seq', (
            SELECT
                max(directorid)
            FROM imdb_directors), TRUE);

--MODIFICACIONES TABLA MOVIES
--Actualizamos la tabla movies para que el campo de movie title sea unico

ALTER TABLE imdb_movies
    ADD CONSTRAINT UC_movietitle UNIQUE (movietitle);

--CREAR TABLA COUNTRY
--Creamos la nueva tabla country, que contendrá los distintos paises que encontremos
--en la tabla imdb_moviecountries. Creamos tambien una secuencia de valores, para que
--se asignen de forma automática los ids de los paises al insertarlos en la tabla. La
--clave primaria de esta tabla sera este numero entero asignado de forma automatica

CREATE SEQUENCE imdb_countries_countryid_seq
    START WITH 1
    INCREMENT BY 1;

CREATE TABLE public.imdb_countries (
    countryid integer DEFAULT nextval('imdb_countries_countryid_seq'),
    country VARCHAR(32) NOT NULL
);

ALTER TABLE public.imdb_countries
    ADD CONSTRAINT imdb_countries_pkey PRIMARY KEY (countryid);

GRANT ALL PRIVILEGES ON TABLE public.imdb_countries TO alumnodb;

INSERT INTO imdb_countries (country)
SELECT
    country
FROM
    imdb_moviecountries
GROUP BY
    country;

--CREAR TABLA GENRES
--Rellenamos la infomación de forma análoga a la tabla contry

CREATE SEQUENCE imdb_genres_genreid_seq
    START WITH 1
    INCREMENT BY 1;

CREATE TABLE public.imdb_genres (
    genreid integer DEFAULT nextval('imdb_genres_genreid_seq'),
    genre VARCHAR(32) NOT NULL
);

ALTER TABLE public.imdb_genres
    ADD CONSTRAINT imdb_genres_pkey PRIMARY KEY (genreid);

GRANT ALL PRIVILEGES ON TABLE imdb_genres TO alumnodb;

INSERT INTO imdb_genres (genre)
SELECT
    genre
FROM
    imdb_moviegenres
GROUP BY
    genre;

--CREAR TABLA LANGUAGES
--Rellenamos la infomación de forma análoga a la tabla contry
--Si algun languge tiene un campo en null en

CREATE SEQUENCE imdb_languages_languageid_seq
    START WITH 1
    INCREMENT BY 1;

CREATE TABLE public.imdb_languages (
    languageid integer DEFAULT nextval('imdb_languages_languageid_seq'),
    language VARCHAR
(32) NOT NULL,
    extrainformation VARCHAR(128) NOT NULL
);

ALTER TABLE public.imdb_languages
    ADD CONSTRAINT imdb_languages_pkey PRIMARY KEY (languageid);

GRANT ALL PRIVILEGES ON TABLE imdb_languages TO alumnodb;

INSERT INTO imdb_languages (
    LANGUAGE, extrainformation)
SELECT
    LANGUAGE,
    extrainformation
FROM
    imdb_movielanguages
GROUP BY
    LANGUAGE,
    extrainformation;

--MODIFICAMOS LA TABLA IMDB_MOVIECOUNTRIES
--La tabla ahora simplemente se va a usar para relacionar una movie con un country
--por lo que tendrá como claves foraneas el movieid y el countryid, y estas dos juntas
--formarán la clave primaria de esta tabla modificada
--Eliminamos la secuencia de cálculo de ids de movie de las tablas moviecountries y
--moviegenres. Esta sevuencia solo se deberia calcular en movie,
--que será la encargada de generar los ids de las peliculas

ALTER TABLE public.imdb_moviecountries
    ALTER COLUMN movieid DROP DEFAULT;

ALTER TABLE imdb_moviecountries
    DROP CONSTRAINT imdb_moviecountries_pkey;

ALTER TABLE imdb_moviecountries
    DROP CONSTRAINT imdb_moviecountries_movieid_fkey;

ALTER TABLE imdb_moviecountries
    ADD countryid integer;

UPDATE
    imdb_moviecountries
SET
    countryid = imdb_countries.countryid
FROM
    imdb_countries
WHERE
    imdb_moviecountries.country = imdb_countries.country;

ALTER TABLE public.imdb_moviecountries
    ALTER COLUMN countryid SET NOT NULL;

ALTER TABLE public.imdb_moviecountries
    ADD CONSTRAINT imdb_countrymovies_pkey PRIMARY KEY (movieid, countryid);

ALTER TABLE public.imdb_moviecountries
    ADD CONSTRAINT imdb_countrymovies_movieid_fkey FOREIGN KEY (movieid) REFERENCES public.imdb_movies (movieid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

ALTER TABLE public.imdb_moviecountries
    ADD CONSTRAINT imdb_countrymovies_countryid_fkey FOREIGN KEY (countryid) REFERENCES public.imdb_countries (countryid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

ALTER TABLE imdb_moviecountries
    DROP COLUMN country;

ALTER TABLE imdb_moviecountries RENAME TO imdb_countrymovies;

--MODIFICAMOS LA TABLA IMDB_MOVIEGENRES
--Modificamos la tabla moviegenres de forma análoga a imdb_moviecountries

ALTER TABLE public.imdb_moviegenres
    ALTER COLUMN movieid DROP DEFAULT;

ALTER TABLE imdb_moviegenres
    DROP CONSTRAINT imdb_moviegenres_pkey;

ALTER TABLE imdb_moviegenres
    DROP CONSTRAINT imdb_moviegenres_movieid_fkey;

ALTER TABLE imdb_moviegenres
    ADD genreid integer;

UPDATE
    imdb_moviegenres
SET
    genreid = imdb_genres.genreid
FROM
    imdb_genres
WHERE
    imdb_moviegenres.genre = imdb_genres.genre;

ALTER TABLE public.imdb_moviegenres
    ALTER COLUMN movieid SET NOT NULL;

ALTER TABLE public.imdb_moviegenres
    ADD CONSTRAINT imdb_genremovies_pkey PRIMARY KEY (movieid, genreid);

ALTER TABLE public.imdb_moviegenres
    ADD CONSTRAINT imdb_genremovies_movieid_fkey FOREIGN KEY (movieid) REFERENCES public.imdb_movies (movieid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

ALTER TABLE public.imdb_moviegenres
    ADD CONSTRAINT imdb_genremovies_genreid_fkey FOREIGN KEY (genreid) REFERENCES public.imdb_genres (genreid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

ALTER TABLE imdb_moviegenres
    DROP COLUMN genre;

ALTER TABLE imdb_moviegenres RENAME TO imdb_genremovies;

--MODIFICAMOS LA TABLA IMDB_LANGUAGES
--Modificamos la tabla moviegenres de forma análoga a imdb_moviecountries

ALTER TABLE imdb_movielanguages
    DROP CONSTRAINT imdb_movielanguages_pkey;

ALTER TABLE imdb_movielanguages
    DROP CONSTRAINT imdb_movielanguages_movieid_fkey;

ALTER TABLE imdb_movielanguages
    ADD languageid integer;

UPDATE
    imdb_movielanguages
SET
    languageid = imdb_languages.languageid
FROM
    imdb_languages
WHERE
    imdb_movielanguages.language = imdb_languages.language
    AND imdb_movielanguages.extrainformation = imdb_languages.extrainformation;

ALTER TABLE public.imdb_movielanguages
    ALTER COLUMN languageid SET NOT NULL;

ALTER TABLE public.imdb_movielanguages
    ADD CONSTRAINT imdb_languagemovies_pkey PRIMARY KEY (movieid, languageid);

ALTER TABLE public.imdb_movielanguages
    ADD CONSTRAINT imdb_languagemovies_movieid_fkey FOREIGN KEY (movieid) REFERENCES public.imdb_movies (movieid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

ALTER TABLE public.imdb_movielanguages
    ADD CONSTRAINT imdb_languagemovies_languageid_fkey FOREIGN KEY (languageid) REFERENCES public.imdb_languages (languageid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

ALTER TABLE imdb_movielanguages
    DROP COLUMN LANGUAGE;

ALTER TABLE imdb_movielanguages
    DROP COLUMN extrainformation;

ALTER TABLE imdb_movielanguages RENAME TO imdb_languagemovies;

--Creamos la tabla de las alertas
CREATE TABLE public.alertas (
    prod_id INTEGER,
    FOREIGN KEY (prod_id) REFERENCES products (prod_id)
);

GRANT ALL PRIVILEGES ON TABLE public.alertas TO alumnodb;

--Vamos a modificar la forma en la que asociamos un pais a un customer.
--Añadimos una nueva columna que es el countryid, cuyo valor vamos a
--obtener a partir del country original de la tabla customers, junto
--con la informacion de la tabla countries.

ALTER TABLE public.customers
    ADD countryid integer;

--Rellenamos la nueva columna con el id del pais correspondiente
UPDATE
    customers
SET
    countryid = imdb_countries.countryid
FROM
    imdb_countries
WHERE
    imdb_countries.country = customers.country
    AND customers.country IS NOT NULL;

--Decimos que el id del pais que le hemos asignado es una clave foranea de la tabla imdb_countries
ALTER TABLE public.customers
    ADD CONSTRAINT customerss_countryid_fkey FOREIGN KEY (countryid) REFERENCES public.imdb_countries (countryid) MATCH SIMPLE ON
    UPDATE
        NO ACTION ON DELETE NO ACTION;

--Borramos la columna del pais ya que ahora tenemos información suficiente con el countryid
ALTER TABLE public.customers
    DROP "country";

