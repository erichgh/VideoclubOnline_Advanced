UPDATE
    orderdetail
SET
    price = p.price * (0.98 ^ (date_part('year', CURRENT_DATE) - date_part('year', o.orderdate)))
FROM
    orders AS o,
    products AS p
WHERE
    p.prod_id = orderdetail.prod_id
    AND o.orderid = orderdetail.orderid;

