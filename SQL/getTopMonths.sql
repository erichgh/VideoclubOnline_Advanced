CREATE OR REPLACE FUNCTION getTopMonths (total FLOAT, prod bigint)
    RETURNS TABLE (
        ANIO bigint, MES bigint, IMPORTE FLOAT, PRODUCTOS bigint
)
    AS $$
BEGIN
    RETURN QUERY
    SELECT
        EXTRACT(YEAR FROM orderdate)::bigint AS anio,
        EXTRACT(MONTH FROM orderdate)::bigint AS mes,
        sum(totalamount)::FLOAT AS importe,
        count(prod_id)::bigint AS productos
    FROM
        orderdetail
    NATURAL JOIN orders
WHERE
    status IS NOT NULL
GROUP BY
    anio,
    mes
HAVING
    SUM(totalamount) > total
    OR COUNT(prod_id) > prod;
END;
$$
LANGUAGE plpgsql;

