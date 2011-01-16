if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.DivDeleter = function ( div, deleter ) {
    this.div = div;

    var matches = div.attr("class").match( /(JS-repeat-type-\S+)/ );
    this.type = matches[1];

    var self = this;

    deleter.click(
        function (e) {
            e.preventDefault();
            e.stopPropagation();

            self.div.fadeOut(
                500,
                function () {
                    self._maybeMovePreferred();
                    self.div.detach();
                }
            );
        }
    );
};

R2.FormWidget.DivDeleter.prototype._maybeMovePreferred = function () {
    if ( ! this.div.find(':radio[name$="is_preferred"]').attr("checked") ) {
        return;
    }

    $( "div." + this.type ).first().find(':radio[name$="is_preferred"]').click();
};
