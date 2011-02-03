if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.DateRange = function (options) {
    var start_end = $( 'input[name="start_date"], input[name="end_date"]' );

    if ( start_end.length != 2 ) {
        return;
    }

    this._start = start_end.first();
    this._end   = start_end.last();

    var self = this;

    options.onClose =
        function () {
            self._maybeAdjustEndDate();
        };

    this._start.datepicker(options);

    options.onClose =
        function () {
            self._maybeAdjustStartDate();
        };

    this._end.datepicker(options);
};

R2.FormWidget.DateRange.prototype._maybeAdjustStartDate = function () {
    var start = this._start.datepicker("getDate");
    var end   = this._end.datepicker("getDate");

    if ( start && end && start >= end ) {
        end.setDate( end.getDate() - 1 );
        this._start.datepicker( "setDate", end );
    }
};

R2.FormWidget.DateRange.prototype._maybeAdjustEndDate = function () {
    var start = this._start.datepicker("getDate");
    var end   = this._end.datepicker("getDate");

    if ( start && end && start >= end ) {
        start.setDate( start.getDate() + 1 );
        this._end.datepicker( "setDate", start );
    }
};
