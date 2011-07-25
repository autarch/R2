JSAN.use("R2.Role.CurriesThis");
JSAN.use("R2.Role.EventHandler");
JSAN.use("R2.Role.Publisher");

Role(
    "R2.Role.AjaxCollection", {
        does: [
            R2.Role.CurriesThis,
            R2.Role.EventHandler,
            R2.Role.Publisher
        ],
        requires: [ "_itemClass", "_collectionAttr" ],
        methods: {
            _ucfirstAttr: function () {
                var attr = this._collectionAttr();
                return attr.substring( 0, 1 ).toUpperCase() + attr.substring(1);
            },
            _ajaxRequest: function ( type, data, uri ) {
                this._publishEvent( "requesting" + this._ucfirstAttr() );

                var params = {
                    url:      uri || this.uri(),
                    type:     type,
                    dataType: "json",
                    success:  this._curryThis( this._handleDataResponse ),
                    error:    this._curryThis( this._handleErrorResponse )
                };

                if ( typeof data != "undefined" ) {
                    params.contentType = "application/json; charset=UTF-8";
                    params.data = $.toJSON(data);
                }

                $.ajax(params);
            },
            _handleDataResponse: function (response) {
                var itemClass = this._itemClass();

                this[ this._collectionAttr() ](
                    $.map(
                        response[ this._collectionAttr() ],
                        function (item) {
                            return new itemClass (item);
                        }
                    )
                );

                this._publishEvent(
                    "received" + this._ucfirstAttr(),
                    this[ this._collectionAttr() ]()
                );
            },
            _handleErrorResponse: function (response) {
                this._publishEvent("receivedError");
            }
        }
    }
);
