JSAN.use('DOM.Find');
JSAN.use('DOM.Utils');
JSAN.use('R2.FormWidget.LabeledRadioButton');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.Form = function (form) {
    this.form = form;

    this._instrumentRadioButtons();
};

R2.Form.instrumentAllForms = function () {
    var forms = DOM.Find.getElementsByAttributes( { tagName:   "FORM",
                                                    className: /JS-standard-form/ } );

    for ( var i = 0; i < forms.length; i++ ) {
        new R2.Form( forms[i] );
    }
};

R2.Form.prototype._instrumentRadioButtons = function () {
    var radios = DOM.Find.getElementsByAttributes( { tagName: "INPUT",
                                                     type:    "radio" }, this.form );

    for ( var i = 0; i < radios.length; i++ ) {
        var label = $( "for-" + radios[i].id );

        if ( ! label ) {
            continue;
        }

        var lbr = new R2.FormWidget.LabeledRadioButton( radios[i], label );
        lbr.instrument();
    }
};
