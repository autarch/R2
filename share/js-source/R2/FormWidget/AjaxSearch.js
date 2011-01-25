if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.AjaxSearch = function ( url, prefix, on_submit, on_empty, on_success, on_failure ) {
    this.text   = $( "#" + prefix + "-search-text" );
    this.submit = $( "#" + prefix + "-search-submit" );

    if ( ! ( this.text.length && this.submit.length ) ) {
        return;
    }

    this.url        = url;
    this.on_submit  = on_submit;
    this.on_empty   = on_empty;
    this.on_success = on_success;
    this.on_failure = on_failure;

    this._instrumentTextInput();
    this._instrumentSubmit();
};

R2.FormWidget.AjaxSearch.prototype._instrumentTextInput = function () {
    var self = this;

    this.text.keypress(
        function (e) {
            if ( e.which != 13 ) {
                return e.which;
            }

            self.submit.click();

            e.preventDefault();
            e.stopPropagation();
        }
    );
};

R2.FormWidget.AjaxSearch.prototype._instrumentSubmit = function () {
    var self = this;

    this.submit.click(
        function (e) {
            e.preventDefault();
            e.stopPropagation();

            self._submitSearch();
        }
    );
};

R2.FormWidget.AjaxSearch.prototype._submitSearch = function () {
    if ( this.req && this.req.transport ) {
        this.req.transport.abort();
    }

    if ( this.text.val().length == 0 ) {
        this.on_empty();

        return;
    }

    var self = this;

    this.on_submit();

    $.ajax(
        {
            "url":      this.url,
            "type":     "GET",
            "data":     this._parameters(),
            "dataType": "json",
            "success" : function (data) { self._handleSuccess(data) },
            "error":    function (xhr, status, error) { self._handleFailure(xhr) }
        }
    );
};

R2.FormWidget.AjaxSearch.prototype._parameters = function () {
    var params = {};
    params.name_param = this.text.attr("name");
    params[ this.text.attr("name") ] = this.text.val();

    return params;
}

R2.FormWidget.AjaxSearch.prototype._handleSuccess = function (data) {
    this.on_success(data);
};

R2.FormWidget.AjaxSearch.prototype._handleFailure = function (trans) {
    this.on_failure("failure");
};
