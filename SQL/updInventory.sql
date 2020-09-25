CREATE OR REPLACE FUNCTION udpInventory_func ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF OLD.status IS NULL AND NEW.status = 'Paid' THEN
        -- Comprobamos si tenemos stock para realizar el pedido
        IF EXISTS (
            SELECT
                *
            FROM (
                SELECT
                    sum(stock - aux.quantity) AS minInventory,
                    aux.prod_id
                FROM
                    inventory,
                    (
                        SELECT
                            orderid,
                            prod_id,
                            quantity
                        FROM
                            orderdetail
                        WHERE
                            orderid = OLD.orderid) AS aux
                    WHERE
                        inventory.prod_id = aux.prod_id
                    GROUP BY
                        aux.prod_id) AS res
                WHERE
                    mininventory < 0) THEN
            -- Si no tenemos suficiente no permitimos el update
            RETURN NULL;
    END IF;
    -- Actualizamos el inventario con el stock y las venta nuevos
    UPDATE
        inventory
    SET
        stock = stock - aux.quantity,
        sales = sales + aux.quantity
    FROM (
        SELECT
            orderid,
            prod_id,
            quantity
        FROM
            orderdetail
        WHERE
            orderid = OLD.orderid) AS aux
WHERE
    inventory.prod_id = aux.prod_id;
    -- Creamos la alerta de los productos que se hayan quedado a 0
    INSERT INTO alertas (prod_id)
SELECT
    inventory.prod_id
FROM
    inventory,
    (
        SELECT
            orderid,
            prod_id
        FROM
            orderdetail
        WHERE
            orderid = OLD.orderid) AS aux
WHERE
    aux.prod_id = inventory.prod_id
    AND stock = 0;
END IF;
    RETURN NEW;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER udpInventory
    BEFORE UPDATE ON orders
    FOR EACH ROW
    EXECUTE PROCEDURE udpInventory_func ();

