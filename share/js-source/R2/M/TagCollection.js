JSAN.use("R2.Role.CurriesThis");
JSAN.use("R2.Role.EventHandler");
JSAN.use("R2.Role.Publisher");
JSAN.use("R2.M.Tag");

Class(
    "R2.M.TagCollection", {
        does: [ R2.Role.CurriesThis, R2.Role.EventHandler, R2.Role.Publisher ],
        has: {
            uri: {
                is:        "roc",
                isPrivate: true,
            },   
            tags: {
                is:        "rwc",
                isPrivate: true,
            }
        },
        methods: {
            populateTags: function () {
                this._ajaxTagList("GET");
            },
            addTags: function (tags) {
                this._ajaxTagList( "POST", { tags: tags } );
            },
            deleteTag: function (uri) {
                console.log(uri);
                this._ajaxTagList( "DELETE", undefined, uri );
            },
            _ajaxTagList: function ( type, data, uri ) {
                this._publishEvent("requestingTags");

                var params = {
                    url:      uri || this.uri(),
                    type:     type,
                    dataType: "json",
                    success:  this._curryThis( this._handleTagResponse ),
                    error:    this._curryThis( this._handleErrorResponse )
                };

                if ( typeof data != "undefined" ) {
                    params.data = data;
                }

                $.ajax(params);
            },
            _handleTagResponse: function (response) {
                this.tags(
                    $.map(
                        response.tags,
                        function (tag) { return new R2.M.Tag (tag); }
                    )
                );
                this._publishEvent( "receivedTags", this.tags() );
            },
            _handleErrorResponse: function (response) {
                this._publishEvent("receivedError");
            }
        }
    }
);
