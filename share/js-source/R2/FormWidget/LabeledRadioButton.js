JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.LabeledRadioButton = function ( radio, label ) {
    this.radio = radio;
    this.label = label;
    this.seen  = {};

    DOM.Events.addListener( this.radio, "click",
                            this._makeRadioClickListener() );

    if ( this.radio.checked ) {
        DOM.Element.addClassName( this.label, "selected" );
    }
};

R2.FormWidget.LabeledRadioButton.prototype._makeRadioClickListener = function () {
    var self = this;

    var func = function (event) {
        self._onClick();
    };

    return func;
};

R2.FormWidget.LabeledRadioButton.prototype._onClick = function () {
    DOM.Element.addClassName( this.label, "selected" );

    var radios =
        DOM.Find.getElementsByAttributes( { tagName: "INPUT",
                                            name:    this.radio.name } );


    for ( var i = 0; i < radios.length; i++ ) {
        var label = $( "for-" + radios[i].id );

        if ( ! label ) {
            continue;
        }

        if ( label.id == this.label.id ) {
            continue;
        }

        DOM.Element.removeClassName( label, "selected" );
    }
};
