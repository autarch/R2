if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.LabeledRadioButton = function ( radio, label ) {
    this.radio = radio;
    this.label = label;

    if ( this.radio.attr("checked") ) {
        this.label.addClass("selected");
    }

    /* This works around a bug (?) in the browser which
       when a repeatable group is deleted, then the page
       is reloaded. The label is still marked as selected
       but the radio button is no longed checked. */
    if ( /selected/.test( this.label.attr("class") ) ) {
        this.radio.attr( "checked", "checked" );
    }

    var self = this;

    this.radio.click(
        function (event) {
            self._onClick();
        }
    );

};

R2.FormWidget.LabeledRadioButton.prototype._onClick = function () {
    this.label.addClass("selected");

    var radios = $( ':radio[name="' + this.radio.attr("name") + '"]' );

    var my_radio = this.radio;

    radios.each(
        function () {
            if ( $(this).attr("id") == my_radio.attr("id") ) {
                return;
            }

            $( "label#for-" + $(this).attr("id") ).removeClass("selected");
        }
    );
};
