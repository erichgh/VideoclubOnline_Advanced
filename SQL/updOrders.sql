CREATE OR REPLACE FUNCTION udpOrders_func ()
    RETURNS TRIGGER
    AS $$
BEGIN
    IF TG_OP = 'UPDATE' THEN
        IF NEW.quantity <= 0 THEN
            DELETE FROM orderdetail
            WHERE NEW.prod_id = prod_id
                AND NEW.orderid = orderid;
            RETURN NEW;
        END IF;
    END IF;
    IF TG_OP = 'DELETE' OR TG_OP = 'UPDATE' THEN
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
            WHERE
                orderid = OLD.orderid
            GROUP BY
                orderid) AS aux
    WHERE
        orders.orderid = aux.orderid;
        RETURN OLD;
    ELSE
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
            WHERE
                orderid = NEW.orderid
            GROUP BY
                orderid) AS aux
    WHERE
        orders.orderid = aux.orderid;
        RETURN NEW;
    END IF;
END;
$$
LANGUAGE plpgsql;

CREATE TRIGGER udpOrders
    AFTER UPDATE
    OR DELETE
    OR INSERT ON orderdetail
    FOR EACH ROW
    EXECUTE PROCEDURE udpOrders_func ();

