JSAN.use('R2.FormWidget.LabeledRadioButton');
JSAN.use('R2.FormWidget.RepeatableGroup');
JSAN.use('R2.Utils');

if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.Form = function (form) {
    this.form = form;

    this.instrumentRadioButtons();
    this._instrumentRepeatableGroups();
    this._instrumentDivDeleters();
    this._instrumentDateFields();
};

R2.Form.instrumentAllForms = function () {
    $("form.JS-standard-form").each(
        function () {
            new R2.Form( $(this) );
        }
    );
};

R2.Form.prototype.instrumentRadioButtons = function () {
    var radios = $( 'input[type="radio"]', this.form );

    radios.each(
        function() {
            var label = $(this).next();

            if ( ! label.length ) {
                return;
            }

            new R2.FormWidget.LabeledRadioButton( $(this), label );
        }
    );
};

R2.Form.prototype._instrumentRepeatableGroups = function () {
    var self = this;

    $( "div", this.form ).filter(
        function() {
            return /JS-repeatable-group/.test( $(this).attr("class") );
        }
    ).each(
        function () {
            new R2.FormWidget.RepeatableGroup( $(this), self );
        }
    );
};

R2.Form.prototype._instrumentDivDeleters = function () {
    var anchors = $( "a.JS-delete-div", this.form );

    anchors.each(
        function () {
            new R2.FormWidget.DivDeleter(
                $(this).closest("div.repeat-group").first(),
                $(this)
            );
        }
    );
};

R2.Form.prototype._instrumentDateFields = function () {
    var self = this;

    var date_format = $('input[name="date_format"]').val();

    $("input.date").each(
        function () {
            $(this).datepicker( { "dateFormat": date_format } );
        }
    );
};
