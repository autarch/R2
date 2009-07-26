JSAN.use('DOM.Find');
JSAN.use('DOM.Utils');
JSAN.use('R2.FormWidget.LabeledRadioButton');
JSAN.use('R2.FormWidget.RepeatableGroup');
JSAN.use('R2.FormWidget.PairedMultiSelect');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.Form = function (form) {
    this.form = form;
    this.seen = {};

    this.instrumentRadioButtons();
    this._instrumentRepeatableGroups();
    this._instrumentDivDeleters();
    this._instrumentPairedMultiSelects();
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
    var divs =
        DOM.Find.getElementsByAttributes
            ( { tagName:   "DIV",
                className: /JS-repeatable-group/ }, this.form );

    for ( var i = 0; i < divs.length; i++ ) {
        new R2.FormWidget.RepeatableGroup( divs[i], this );
    }
};

R2.Form.prototype._instrumentDivDeleters = function () {
    var anchors =
        DOM.Find.getElementsByAttributes
            ( { tagName:   "A",
                className: /JS-delete-div/ }, this.form );

    for ( var i = 0; i < anchors.length; i++ ) {
        var div = R2.Utils.firstParentWithTagName( anchors[i], "DIV" );

        new R2.FormWidget.DivDeleter( div.parentNode, anchors[i] );
    }
};

R2.Form.prototype._instrumentPairedMultiSelects = function () {
    var selects =
        DOM.Find.getElementsByAttributes
            ( { tagName: "SELECT",
                id:      /^wpms-/ }, this.form );

    var ids = {};
    for ( var i = 0; i < selects.length; i++ ) {
        var matches = selects[i].id.match( /^(wpms-\w+)-/ );

        if ( ! matches ) {
            continue;
        }

        if ( ids[ matches[1] ] ) {
            continue;
        }

        ids[ matches[1] ] = 1;

        R2.FormWidget.PairedMultiSelect.newFromPrefix( matches[1] );
    }
};
