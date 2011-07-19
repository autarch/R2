JSAN.use("R2.Role.CurriesThis");
JSAN.use("R2.Role.EventHandler");
JSAN.use("R2.Role.Spinner");

Class(
    "R2.VM.Tags.List", {
        does: [ R2.Role.CurriesThis, R2.Role.EventHandler, R2.Role.Spinner ],
        has: {
            collection: {
                is:        "roc",
                isPrivate: true,
                required:  true,
            },
            container: {
                is:        "roc",
                isPrivate: true,
                builder:   "_build_container"
            }
        },
        methods: {
            initialize: function () {
                this.collection().addSubscriber(
                    "requestingTags",
                    this._curryThis( this._requestingTags )
                );

                this.collection().addSubscriber(
                    "receivedTags",
                    this._curryThis( this._updateTagDisplay )
                );

                this.collection().addSubscriber(
                    "receivedError",
                    this._curryThis( this._showError )
                );
            },
            _build_container: function () {
                return $("#tags-list");
            },
            _requestingTags: function () {
                if ( this._isShowingTags()) {
                    this._showSpinnerOver( this.container() );
                }
                else {
                    this._showSpinnerIn( this.container() );
                }
            },
            _isShowingTags: function () {
                return this.container().find('li').length ? true : false;
            },
            _updateTagDisplay: function (tags) {
                this.container().children().detach();
                $("#tagsListTemplate").tmpl( { tags: tags } ).appendTo( this.container() );
                this._instrumentDeleteLinks();
            },
            _showError: function () {
                this.container().children().detach();
                $("#tagsListErrorTemplate").tmpl().appendTo( this.container() );
            },
            _instrumentDeleteLinks: function () {
                var handler = this._curryThis( this._deleteTag );
                var self = this;

                this.container().find("a.delete-tag").each(
                    function () {
                        self._handlerFor(
                            $(this),
                            "click",
                            handler
                        );
                    }
                );
            },
            _deleteTag: function (e) {
                this.collection().deleteTag( $(e.currentTarget).attr("href") );
            }
        }
    }
);
