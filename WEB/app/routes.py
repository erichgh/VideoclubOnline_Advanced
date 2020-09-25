#!/usr/bin/env python3
# -*- coding: utf-8 -*-

from app import app, database
from flask import render_template, request, url_for, redirect, session
from flask import make_response
import json
import os
import sys
import re
import random
import hashlib
from datetime import date

catalogue = None


# Función para leer el catalogo y no repetir código
def leer_catalogo():
    global catalogue
    catalogue_data = open(os.path.join(app.root_path, 'catalogue/catalogue.json'), encoding="utf-8").read()
    catalogue = json.loads(catalogue_data)

# Reads the data file from the given path into a dictionary and returns it
def data_to_dict(path):
    dict = {}
    f = open(path, 'r')
    for line in f.readlines():
        words = line.split(' ')
        dict[words[0]] = words[2][:-1]
    f.close()
    return dict

@app.route('/', methods=["GET", "POST"])
@app.route('/index/', methods=["GET", "POST"])
def index():
    sys.stderr.write(url_for('static', filename='master.css'))

    global catalogue
    if catalogue is None:
        leer_catalogo()

    # Guardar una lista con las categorias por las que se puede filtrar una peli
    categories = []

    # Guardo los ids de las peliculas
    lista_ids = []
    for element in catalogue['peliculas']:
        lista_ids.append(element['id'])

    # Guardo las distintas categorias de peliculas
    for element in catalogue['peliculas']:
        if element['categoria'] not in categories:
            categories.append(element['categoria'])
    categories.sort()

    # En peliculas_db tengo todas las pelis que coincidian con los prod_id del catalogo.json
    peliculas_bd = database.get_film_details_db(lista_ids)

    # En top_ventas tengo las peliculas mas vendidas de los ultimos 3 años
    top_ventas = database.getTopVentas()

    # Devuelvo las peliculas encontradas en la consulta SQL a la base de datos
    return render_template('index.html', catalogo=peliculas_bd, categories=categories, top_ventas=top_ventas)


@app.route('/login', methods=['GET', 'POST'])
def login():
    # doc sobre request object en http://flask.pocoo.org/docs/1.0/api/#incoming-request-data

    # Si nos llaman con metodo get, significa que se acaba de registrar
    if request.args.get("username"):
        # Vaciamos la url de la sesion, para volver al index cuando iniciamos sesion
        session.pop('url_origen', None)
        session.modified = True

        # Le dejamos en la página de inicio de sesión para que acceda
        login_text = "Ahora puedes iniciar sesion con tu usuario " + request.args.get("username")
        context_dict = {'text': login_text}
        return render_template('login.html', title="Sign In", message=context_dict)

    # Si acaban de pulsar el boton de iniciar sesion
    if request.method == 'POST':

        #Realizamos una solicitud a la base de datos
        lista = database.get_user(request.form['Username'])

        # Comprobamos si el usuario existe
        if len(lista) == 0:
            err_text = "No existe el usuario " + request.form['Username']
            context_dict = {'text': err_text}

            return render_template('login.html', title="Sign In", message=context_dict)

        else:
            #Sacamos la contraseña del usuario y su saldo, y comparamos con la introducida en el formulario
            password = lista[0].password
            saldo = lista[0].income

            if password == request.form['Password']:
                session['usuario'] = request.form['Username']
                session['saldo'] = saldo
                session.modified = True

                if 'url_origen' in session.keys():
                    # Si estas en login por voluntad propia, al iniciar sesion te devuelve al index
                    if session['url_origen'] is not "http://0.0.0.0:5001/login":
                        resp = make_response(redirect(session['url_origen']))
                        resp.set_cookie('username', request.form['Username'])
                        return resp

                resp = make_response(redirect(url_for('index')))
                resp.set_cookie('username', request.form['Username'])
                return resp

            else:
                err_text = "Contraseña incorrecta para el usuario " + request.form['Username']
                context_dict = {'text': err_text}
                return render_template('login.html', title="Sign In", message=context_dict)
    else:
        session['url_origen'] = request.referrer
        session.modified = True

    return render_template('login.html', title="Sign In")

@app.route('/register', methods=['GET', 'POST'])
def register():
    if request.method == 'POST':
        # Realizamos una solicitud a la base de datos para ver si existe un usuario con ese nombre
        lista = database.get_user(request.form['Username'])

        # Comprobamos si el usuario existe
        if len(lista) == 1:
            err_text = "El usuario " + request.form['Username'] + " ya existe. Elija otro nombre de usuario"
            context_dict = {'text': err_text}
            return render_template('register.html', err=context_dict)

        else:
            # Creamos un diccionario con los datos del usuario, y se lo mandamos a la funcion create_user para que lo meta en la base de datos
            dict = request.form.copy()
            # El saldo ahora es el income de los usuarios (el dinero que tienen)
            # por ello, su income inicial lo calculamos como un numero mas grande
            dict['saldo'] = random.randint(1, 60000)
            database.create_user(dict)
            return redirect(url_for('login', username=request.form['Username']))

    else:
        return render_template('register.html')

@app.route('/carrito', methods=['GET', 'POST'])
def carrito():
    # Necesito el id del usuario que está en la sesion
    if 'usuario' in session.keys():
        lista_peliculas = database.get_carrito(session['usuario'])
        return render_template('carrito.html', title='Carrito', lista_peliculas=lista_peliculas)

    # Inicia sesion antes de usar el carrito
    else:
        error = {'mensaje': "No puede usar el carrito si no ha iniciado sesion"}
        return render_template('carrito.html', title='Carrito', aux=error)


@app.route('/aniadir_carrito/<prod_id>', methods=['GET', 'POST'])
def aniadir_carrito(prod_id):
    # Si el usuario ha iniciado sesion, gestiono desde la base de datos
    # Solo los usuarios registrados pueden usar el carrito
    if 'usuario' in session.keys():
        database.add_film_to_orderdetail(prod_id, session['usuario'])

    return redirect(request.referrer)

@app.route('/pedidos', methods=['GET', 'POST'])
def pedidos():
    err_text = "Historial de pedidos no disponible todavia"
    context_dict = {'text': err_text}
    return render_template('pedidos.html', title="Pedidos", message=context_dict)


@app.route('/about', methods=['GET', 'POST'])
def about():
    return render_template('about.html', title="About")


@app.route('/terms', methods=['GET', 'POST'])
def terms():
    return render_template('terms.html',  title="Routes")


@app.route('/detalles_pelicula/<prod_id>', methods=['GET', 'POST'])
def detalles_pelicula(prod_id):
    # Con el prod_id de la pelicula, ya puedo sacar sus detalles
    list = database.get_film_details_db(prod_id)
    list = list[0]
    return render_template('detalles_pelicula.html', title=list.movietitle, pelicula=list)


@app.route('/logout', methods=['GET', 'POST'])
def logout():
    session.pop('usuario', None)
    return redirect(url_for('index'))

@app.route('/actualizar_carrito/<prod_id>/<orderid>/<modificacion>', methods=['GET', 'POST'])
def actualizar_carrito(prod_id, orderid, modificacion):
    # Actualizamos al información del carrito. Si llegamos a 0, lo borramos del
    # carrito
    database.update_orderdetail_quantity(prod_id, orderid, modificacion)
    return redirect(url_for('carrito'))


@app.route('/eliminar_carrito/<prod_id>/<orderid>', methods=['GET', 'POST'])
def eliminar_carrito(prod_id, orderid):
    # Funcion que borra de la base de datos dado un product_id y un orderid
    if 'usuario' in session.keys():
        database.remove_from_orderdetail(prod_id, orderid)

    return redirect(url_for('carrito'))


@app.route('/realizar_pago/<orderid>', methods=['GET', 'POST'])
def realizar_pago(orderid):
    # Hay que haber iniciado sesion para realizar la compra
    if 'usuario' not in session.keys():
        return redirect(url_for('login'))

    else:
        # En caso de exito la funcion retorna 0
        if database.finish_purchase(orderid) == 0:
            compra = {'mensaje': 'Compra efectuada correctamente'}
            return render_template('carrito.html', Title="Carrito", aux=compra)

        else:
            lista_peliculas = database.get_carrito(session['usuario'])
            error = {'mensaje': 'Alguna de las peliculas del carrito se ha quedado sin stock. Lo sentimos, no se ha realizado la compra'}
            return render_template('carrito.html', title='Carrito', lista_peliculas=lista_peliculas, aux=error)

@app.route('/aniadir_saldo', methods=['GET', 'POST'])
def aniadir_saldo():
    # Hay que haber iniciado sesion para añadir saldo
    if 'usuario' not in session.keys():
        return redirect(url_for('login'))

    else:
        return render_template('aniadir_saldo.html', title="Añadir Saldo")

@app.route('/people', methods=['GET', 'POST'])
def people():
    if request.method == "GET":
        try:
            return str(random.randint(900, 1000))
        except Exception as e:
            return "error: " + str(e)
