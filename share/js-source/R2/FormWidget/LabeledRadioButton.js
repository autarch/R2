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

    this.other_labels = [];

    var other_radios =
        DOM.Find.getElementsByAttributes( { tagName: "INPUT",
                                            name:    this.radio.name } );


    for ( var i = 0; i < other_radios.length; i++ ) {
        var other_label = $( "for-" + other_radios[i].id );

        if ( ! other_label ) {
            continue;
        }

        if ( other_label.id == this.label.id ) {
            continue;
        }

        this.other_labels.push(other_label);
    }

    DOM.Events.addListener( this.radio, "click",
                            this._makeRadioClickListener() );

    if ( this.radio.checked ) {
        DOM.Element.addClassName( this.label, "selected" );
    }
};

R2.FormWidget.LabeledRadioButton.prototype._makeRadioClickListener = function () {
    var self = this;

    var func = function (event) {
        DOM.Element.addClassName( self.label, "selected" );

        for ( var i = 0; i < self.other_labels.length; i++ ) {
            DOM.Element.removeClassName( self.other_labels[i], "selected" );
        }
    };

    return func;
};
