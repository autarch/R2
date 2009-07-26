JSAN.use('Animation.Fade');
JSAN.use('DOM.Events');

if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.DivDeleter = function ( div, deleter, post_delete ) {
    /* This needs to be explicitly set for the fade to work. */
    div.style.opacity = 1;

    DOM.Events.addListener( deleter,
                            "click",
                            this._makeGroupDeleter( div, post_delete )
                          );
};

R2.FormWidget.DivDeleter.prototype._makeGroupDeleter = function ( div, post_delete ) {
    var func = function (e) {
        e.preventDefault();
        if ( e.stopPropogation ) {
            e.stopPropagation();
        }

        Animation.Fade.fade( { "elementId":     div.id,
                               "targetOpacity": 0 ,
                               onFinish:        function () {
                                   div.parentNode.removeChild(div);
                               }
                             }
                           );

        if ( typeof post_delete != "undefined" ) {
            post_delete();
        }
    };

    return func;
};
