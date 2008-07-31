JSAN.use('DOM.Events');
JSAN.use('HTTP.Request');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.AjaxSearch = function ( uri, prefix, on_success, on_failure ) {
    this.text     = document.getElementById( prefix + "-search-text" );
    this.submit   = document.getElementById( prefix + "-search-submit" );

    if ( ! ( this.text && this.submit ) ) {
        return;
    }

    this.uri        = uri;
    this.on_success = on_success;
    this.on_failure = on_failure;

    this._instrumentSubmit();
};

R2.FormWidget.AjaxSearch.prototype._instrumentSubmit = function () {
    var self = this;

    DOM.Events.addListener( this.submit,
                            "click",
                            function (e) {
                                e.preventDefault();
                                if ( e.stopPropogation ) {
                                    e.stopPropagation();
                                }

                                self._submitSearch();
                            }
                          );
};

R2.FormWidget.AjaxSearch.prototype._submitSearch = function () {
    if ( this.req ) {
        this.req.transport.abort();
    }

    var self = this;

    this.req = new HTTP.Request ( { "uri":    this.uri,
                                    "method": "get",
                                    "parameters": this._parameters(),
                                    "onSuccess": function (trans) { self._handleSuccess(trans) },
                                    "onFailure": function (trans) { self._handleFailure(trans) }
                                  }
                                );

    this.req.request();
};

R2.FormWidget.AjaxSearch.prototype._parameters = function () {
    return encodeURIComponent( this.text.name ) + "=" + encodeURIComponent( this.text.value );
}

R2.FormWidget.AjaxSearch.prototype._handleSuccess = function (trans) {
    var results = eval( "(" + trans.responseText + ")" );

    this.on_success(results);
};

R2.FormWidget.AjaxSearch.prototype._handleFailure = function (trans) {
    this.on_failure("failure");
};
