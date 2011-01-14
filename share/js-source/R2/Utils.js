if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.Utils == "undefined" ) {
    R2.Utils = {};
}

R2.Utils._id_base = 0;
R2.Utils.makeUniqueId = function () {
    var id = "js-R2-Utils-" + R2.Utils._id_base;

    R2.Utils._id_base++;

    return id;
};
