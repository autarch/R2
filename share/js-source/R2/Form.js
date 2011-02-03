JSAN.use('R2.FormWidget.ContactSearch');
JSAN.use('R2.FormWidget.DateRange');
JSAN.use('R2.FormWidget.LabeledRadioButton');
JSAN.use('R2.FormWidget.MemberSearch');
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
    new R2.FormWidget.MemberSearch;
    new R2.FormWidget.ContactSearch;
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
                $(this).closest("div.JS-repeat-group").first(),
                $(this)
            );
        }
    );
};

R2.Form.prototype._instrumentDateFields = function () {
    var self = this;

    var options = {
        "changeMonth": true,
        "changeYear":  true
    };

    $('input[name^="datepicker_"]').each(
        function () {
            var matches = $(this).attr("name").match( /datepicker_(\w+)/ );
            var key = matches[1];

            options[key] = $(this).val();
        }
    );

    new R2.FormWidget.DateRange (options);

    $("input.date").each(
        function () {
            $(this).datepicker(options);
        }
    );

    if ( $("input.date").length > 0 ) {
        var form = $("input.date").closest("form");

        form.submit(
            function () {
                $(this).find('input[name^="datepicker_"]').detach();
            }
        );
    }
};
