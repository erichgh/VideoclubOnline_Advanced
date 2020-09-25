var equals = 0;

// Medidor de fuerza
function checkPassword() {
    var pass1 = document.getElementById("pwd1");
    var pass2 = document.getElementById("pwd2");

    // Contraseñas coinciden
    if (pass1.value !== pass2.value || pass1.value === '') {
        document.getElementById("equals").style.color = '#9C1A1C';
        equals = 0;
    } else {
        document.getElementById("equals").style.color = '#3a7d34';
        equals = 1;
    }

    // Longitud
    if (pass1.value.length < 8) {
        document.getElementById("long").style.color = '#9C1A1C';
    } else {
        document.getElementById("long").style.color = '#3a7d34';
    }

    // Letra
    if ( pass1.value.match(/[A-z]/) ) {
        document.getElementById("letra").style.color = '#3a7d34';
    } else {
        document.getElementById("letra").style.color = '#9C1A1C';
    }

    // Mayuscula
    if ( pass1.value.match(/[A-Z]/) ) {
        document.getElementById("mayus").style.color = '#3a7d34';
    } else {
        document.getElementById("mayus").style.color = '#9C1A1C';
    }

    // Numero
    if ( pass1.value.match(/\d/) ) {
        document.getElementById("numero").style.color = '#3a7d34';
    } else {
        document.getElementById("numero").style.color = '#9C1A1C';
    }
}

function checkRegister() {
    var i;
    var checks = 0;

    for(i = 0; i < document.getElementsByName("Genero").length; i++) {
        if(document.getElementsByName("Genero")[i].checked) {
            checks++;
        }
    }

    if (checks === 0) {
        document.getElementById("checkGender").style.visibility = 'visible';
    } else {
        document.getElementById("checkGender").style.visibility = 'hidden';
    }

    if (equals === 0) {
        document.getElementById("checkEquals").style.visibility = 'visible';
        return false
    } else {
        document.getElementById("checkEquals").style.visibility = 'hidden';
    }

    if (checks === 0) {
        return false;
    } else {
        return true;
    }
}