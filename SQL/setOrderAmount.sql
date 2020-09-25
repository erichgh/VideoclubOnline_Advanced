--Esta funcion solo actualizará los campos de netamount y totalamount
--en caso de que o sean 0 (que es el valor que hemos decidido poner
--nosotros por defecto, o sean NULL)

CREATE OR REPLACE FUNCTION setOrderAmount ()
    RETURNS void
    AS $$
BEGIN
    UPDATE
        orders
    SET
        netamount = aux.net,
        totalamount = aux.net * (1 + (orders.tax / 100))
    FROM (
        SELECT
            orderid,
            sum(price * quantity) AS net
        FROM
            orderdetail
        GROUP BY
            orderid) AS aux
WHERE
    orders.orderid = aux.orderid
    AND (orders.netamount IS NULL
        OR orders.netamount = 0
        OR orders.totalamount IS NULL
        OR orders.totalamount = 0);
END
$$
LANGUAGE plpgsql;

SELECT
    *
FROM
    setOrderAmount ();

