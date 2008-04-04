if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.Element = {};

R2.Element.realPosition = function (elt) {
    var top  = 0;
    var left = 0;

    var element = elt;
    do {
        top  += element.offsetTop  || 0;
        left += element.offsetLeft || 0;

        element = element.offsetParent;
    } while (element);

    return { "top": top, "left": left };
};
