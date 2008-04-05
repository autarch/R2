JSAN.use('DOM.Find');
JSAN.use('DOM.Utils');
JSAN.use('R2.FormWidget.LabeledRadioButton');
JSAN.use('R2.FormWidget.RepeatableGroup');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.Form = function (form) {
    this.form = form;
    this.seen = {};

    this.instrumentRadioButtons();
    this._instrumentRepeatableGroups();
};

R2.Form.instrumentAllForms = function () {
    var forms = DOM.Find.getElementsByAttributes( { tagName:   "FORM",
                                                    className: /JS-standard-form/ } );

    for ( var i = 0; i < forms.length; i++ ) {
        new R2.Form( forms[i] );
    }
};

R2.Form.prototype.instrumentRadioButtons = function () {
    var radios = DOM.Find.getElementsByAttributes( { tagName: "INPUT",
                                                     type:    "radio" }, this.form );

    for ( var i = 0; i < radios.length; i++ ) {
        if ( this.seen[ radios[i].id ] ) {
            continue;
        }

        var label = $( "for-" + radios[i].id );

        if ( ! label ) {
            continue;
        }

        new R2.FormWidget.LabeledRadioButton( radios[i], label );

        this.seen[ radios[i].id ] = 1;
    }
};

R2.Form.prototype._instrumentRepeatableGroups = function () {
    var divs = DOM.Find.getElementsByAttributes( { tagName:   "DIV",
                                                   className: /JS-repeatable-group/ }, this.form );

    for ( var i = 0; i < divs.length; i++ ) {
        new R2.FormWidget.RepeatableGroup( divs[i], this );
    }
};
