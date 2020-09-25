$(document).ready(function () {
    var shown = false;
    $(".desplegar").click(function () {
        var myClass = this.classList[1];
        var detalles = ".detalles.".concat(myClass, " td");
        var imagen = ".imagepedido.".concat(myClass);
        if (!shown) {
            $(detalles).slideDown(200);
            $(imagen).animate({
                height: '10rem'
            }, { duration: 200, queue: false });
        } else {
            $(detalles).slideUp(200);
            $(imagen).animate({
                height: '0'
            }, { duration: 200, queue: false });
        }
        shown = !shown;
    });
});