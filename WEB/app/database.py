# -*- coding: utf-8 -*-

import os
import sys, traceback
from sqlalchemy import create_engine
from sqlalchemy import Table, Column, Integer, String, MetaData, ForeignKey, text
from sqlalchemy.sql import select
from datetime import date

# configurar el motor de sqlalchemy
db_engine = create_engine("postgresql://alumnodb:alumnodb@localhost/si1", echo=False)
db_meta = MetaData(bind=db_engine)

def err_conexion(db_conn):
    if db_conn is not None:
        db_conn.close()
    print("Exception in DB access:")
    print("-" * 60)
    traceback.print_exc(file=sys.stderr)
    print("-" * 60)

    return 'Something is broken'

def get_user(usuario):
    try:
        # conexion a la base de datos
        db_conn = None
        db_conn = db_engine.connect()

        # Buscar si hay un usuario con el nombre pasado como argumento
        request = "Select * from public.customers where username =" + "'" + usuario + "'"+";"
        db_result = db_conn.execute(request)

        db_conn.close()

        return list(db_result)
    except:
        return err_conexion(db_conn)


def create_user(user_data):
    try:
        # conexion a la base de datos
        db_conn = None
        db_conn = db_engine.connect()

        # Insertamos en la base de datos el registro

        #fecha de experacion la tomamos como la concatenacion de mes + anio
        fechaexp = str(user_data['Monthcc']) + "-" +str(int(user_data['Yearcc'])+2019)

        # Calculamos la edad de la persona que se esta registrando
        today = date.today()
        year_birth = int(user_data['Nacimiento'][0:4])
        month_birth = int(user_data['Nacimiento'][5:7])
        date_birth = int(user_data['Nacimiento'][8:10])
        edad = today.year - year_birth -((today.month, today.day) < (month_birth, date_birth))

        # Decidimos que de momento en income metemos el saldo
        dinero = int(user_data['saldo'])

        #Metemos la primera letra de la seleccion, que puede ser M (masculino), F (femenino), o S (sin especificar)
        genero = str(user_data['Genero'])[0]

        #Insertamos el usuario en la base de datos
        insert = "INSERT INTO public.customers (firstname, email, phone, creditcard, creditcardexpiration, username, password, age, income, gender)"+ \
                  "values('"+str(user_data['Nombre'])+"','"+str(user_data['Email'])+"','"+str(user_data['Phone'])+\
                 "','"+str(user_data['Creditcard'])+"','"+fechaexp+"','"+str(user_data['Username'])+"','"+str(user_data['Password'])+"',"+\
                 str(edad)+","+str(dinero)+",'"+genero+"');"

        db_conn.execute(insert)
        db_conn.close()
        return None
    except:
        return err_conexion(db_conn)

def get_film_details_db(prod_id):
    try:
        # conexion a la base de datos
        db_conn = None
        db_conn = db_engine.connect()

        # Buscar la pelicula de la que se ha mandado el product_id
        request = "select * from products natural join imdb_movies where prod_id="+str(prod_id[0])

        # En caso de que nos manden una lista de ids, le devuelvo todas las filas que cumplen la condicion
        if len(prod_id) > 1:
            for i in range (1, len(prod_id)):
                request += " or prod_id = "+str(prod_id[i])

        request += ";"

        db_result = db_conn.execute(request)

        db_conn.close()

        return list(db_result)
    except:
        return err_conexion(db_conn)


def add_film_to_orderdetail(prod_id, username):
    try:
        # conexion a la base de datos
        db_conn = None
        db_conn = db_engine.connect()

        # Sacamos el customerid del usuario (lo vamos a necesitar en dos
        # consultas, es ma eficiente sacarlo directamente)
        customerid_request = "SELECT customerid FROM customers WHERE username='"+str(username)+"';"
        customerid_aux = db_conn.execute(customerid_request)
        customerid_aux = list(customerid_aux)
        customerid = customerid_aux[0].customerid

        # Hacemos una solicitud para ver si existe algun pedido con estado null, y que el usuario que lo haya hecho es el que ha iniciado sesion
        request_order = "SELECT orderid FROM orders WHERE customerid="+str(customerid)+" AND status IS NULL"
        orderid_aux = db_conn.execute(request_order)
        orderid_aux = list(orderid_aux)

        # Sacamos el precio del producto que se quiere añadir al carrito
        get_price = "SELECT * FROM products WHERE prod_id="+str(prod_id)
        price_aux = db_conn.execute(get_price)
        price_aux = list(price_aux)
        price = price_aux[0].price

        # Si no hay resultados, significa que el usuario todavia no ha añadido nada al carrito
        if len(orderid_aux) == 0:
            # Creamos una nueva entrada en la tabla orders, que esta en status NULL para el customerid
            # que quiere añadir un producto al carrito
            today = date.today()
            insert_orders = "INSERT INTO orders (orderdate, customerid, status) VALUES ('"+str(today)+"', "+str(customerid)+", NULL);"
            db_conn.execute(insert_orders)

            # Sacamos el id del order que acabamos de crear
            request_order = "SELECT orderid FROM orders WHERE orderdate='"+str(today)+"' AND customerid="+str(customerid)+" AND status is NULL;"
            orderid_aux = db_conn.execute(request_order)
            orderid_aux = list(orderid_aux)

        # En esta altura ya tenemos un pedido con estado NULL para el usuario que lo ha solicitado
        # Insertamos el producto en la tabla de detalles del pedido. En caso de que el pedido
        # ya estuviese en la tabla, solo incrementamos 1 (es decir, hacemos un "upsert")
        order_id = orderid_aux[0].orderid
        insert_orderdetail = "INSERT INTO orderdetail (orderid, prod_id, price, quantity) VALUES ("+str(order_id)+","+str(prod_id)+","+str(price)+", 1) ON CONFLICT ON CONSTRAINT orderdetail_pkey DO UPDATE SET quantity=orderdetail.quantity+1;"
        db_conn.execute(insert_orderdetail)

        db_conn.close()
    except:
        return err_conexion(db_conn)

def get_carrito(username):
    try:
        # conexion a la base de datos
        db_conn = None
        db_conn = db_engine.connect()

        # Consulta que dado el nombre de usuario, nos va a devolver toda la informacion
        # que necesitamos sobre su carrito (el id del producto, el titulo que incluye
        # la descripcion de pelicula, el precio y la cantidad

        request = "SELECT prod_id, concat(movietitle, ' (', description,')') AS titulo, aux.price, aux.quantity, aux.totalamount, aux.orderid FROM " \
                  "products NATURAL JOIN (SELECT orderid, prod_id, price, quantity, totalamount FROM orderdetail NATURAL JOIN " \
                  "(SELECT orderid, totalamount FROM orders WHERE customerid IN (SELECT customerid FROM customers WHERE username='"\
                  +str(username)+"') AND status IS NULL) AS tempo) AS aux NATURAL JOIN imdb_movies;"
        db_result = db_conn.execute(request)
        db_conn.close()
        return list(db_result)
    except:
        return err_conexion(db_conn)

def remove_from_orderdetail(prod_id, orderid):
    """Funcion que borra una pelicula dado su product id del pedido del usuario que le dan como parametro"""
    try:
        # conexion a la base de datos
        db_conn = None
        db_conn = db_engine.connect()

        # Eliminar la pelicula dado el product id y el orderid
        delete_request = "DELETE FROM orderdetail WHERE prod_id="+str(prod_id)+" AND orderid="+str(orderid)+";"

        db_conn.execute(delete_request)
        db_conn.close()
    except:
        return err_conexion(db_conn)


def get_film_info(prod_id):
    """Funcion que borra una pelicula dado su product id del pedido del usuario
     que le dan como parametro"""
    try:
        # conexion a la base de datos
        db_conn = None
        db_conn = db_engine.connect()

        # Buscar la pelicula de la que se el prod_id
        request_details = "SELECT prod_id, price, concat(movietitle, ' (', description,')') AS titulo FROM imdb_movies NATURAL JOIN (SELECT * FROM products WHERE prod_id="+str(prod_id)+") AS aux;"

        db_result = db_conn.execute(request_details)
        db_conn.close()
        return list(db_result)
    except:
        return err_conexion(db_conn)

def update_orderdetail_quantity(prod_id, orderid, quantity):
    """Funcion que actualiza la informacion de una tabla"""
    try:
        # conexion a la base de datos
        db_conn = None
        db_conn = db_engine.connect()

        # Actualizamos la cantidad de peliculas del pedido. En funcion de si
        # la cantidad es negativa o positiva, ponemos un +
        request = "UPDATE orderdetail SET quantity=orderdetail.quantity"
        if int(quantity) > 0:
            request+="+"
        request+=str(quantity)+" WHERE orderid="+str(orderid)+" AND prod_id="+str(prod_id)+";"
        db_conn.execute(request)
        db_conn.close()
    except:
        return err_conexion(db_conn)

def getTopVentas():
    """Funcion que devuelve las peliculas mas vendidas de los ultimos 3 años"""
    try:
        # conexion a la base de datos
        db_conn = None
        db_conn = db_engine.connect()

        # Actualizamos la cantidad de peliculas del pedido. En funcion de si
        # la cantidad es negativa o positiva, ponemos un +
        request = "SELECT * from getTopVentas(date_part('year', CURRENT_DATE) - 2);"
        db_result = db_conn.execute(request)
        db_conn.close()
        return list(db_result)
    except:
        return err_conexion(db_conn)

def finish_purchase(orderid):
    """Funcion que finaliza la compra de un carrito.
    Retorno: 0 si se ha comprado bien
             1 en caso contraio
             """
    try:
        # conexion a la base de datos
        db_conn = None
        db_conn = db_engine.connect()

        # Ponemos el estado del pedido en pagado
        request = "UPDATE orders SET status='Paid' WHERE orderid="+str(orderid)+";"
        db_conn.execute(request)

        # Si el pedido sigue en estado NULL, es porque no tenemos stock suficiente de alguna de las peliculas
        request = "SELECT * FROM orders WHERE orderid="+str(orderid)+" AND status is NULL;"
        db_result = db_conn.execute(request)
        db_conn.close()

        # Retornará 0 si se ha comprado bien ya que no encontraremos ningun pedido con esas condiciones
        return len(list(db_result))
    except:
        return err_conexion(db_conn)