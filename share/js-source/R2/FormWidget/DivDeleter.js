if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.DivDeleter = function ( div, deleter ) {
    this.div = div;

    var self = this;

    deleter.click(
        function (e) {
            e.preventDefault();
            e.stopPropagation();

            self.div.fadeOut(
                500,
                function () {
                    self.div.detach();
                }
            );
        }
    );
};
