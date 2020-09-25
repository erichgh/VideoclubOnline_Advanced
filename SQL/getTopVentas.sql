CREATE OR REPLACE FUNCTION getTopVentas (desde double precision)
    RETURNS TABLE (
        ANIO bigint, PELICULA varchar, VENTAS bigint
)
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        date_part::bigint,
        movietitle::varchar,
        sales::bigint
    FROM
        imdb_movies
    NATURAL JOIN (
        SELECT
            *
        FROM (
            SELECT
                *,
                row_number() OVER (PARTITION BY date_part ORDER BY sales DESC) AS years
            FROM (
                SELECT
                    movieid,
                    EXTRACT(YEAR FROM orderdate),
                    sum(quantity) AS sales
                FROM (
                    SELECT
                        *
                    FROM
                        orderdetail
                        NATURAL JOIN orders
                    WHERE
                        status IS NOT NULL) AS allOrders
                    INNER JOIN products ON products.prod_id = allOrders.prod_id
                GROUP BY
                    movieid,
                    EXTRACT(YEAR FROM orderdate)) AS total) AS res
        WHERE
            years = 1) AS resultado_ids
WHERE
    date_part >= desde;
END;
$$
LANGUAGE plpgsql;