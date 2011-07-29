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
            },
            last_tags: {
                is:        "rwc",
                isPrivate: true,
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
                this._removeSpinner();

                if ( this.last_tags() ) {
                    this._addNewTags(tags);
                }
                else {
                    this._showAllTags(tags);
                }

                var last_tags = {};
                for ( var i = 0; i < tags.length; i++ ) {
                    last_tags[ tags[i].tag_id() ] = true;
                }

                this._removeDeletedTags( last_tags, tags );

                this.last_tags( tags.length ? last_tags : null );
            },
            _addNewTags: function (new_tags) {
                for ( var i = 0; i < new_tags.length; i++ ) {
                    this._maybeInsertTag(
                        new_tags[i],
                        i > 0 ? new_tags[ i - 1 ] : null
                    );
                }
            },
            _maybeInsertTag: function ( tag, prev_tag ) {
                if ( this.last_tags()[ tag.tag_id() ] ) {
                    return;
                }
                else {
                    var new_html = $("#tagListItem").tmpl(tag);
                    new_html.hide();

                    if (prev_tag) {
                        new_html.insertAfter( $( "#JS-tag-" + prev_tag.tag_id() ) );
                    }
                    else {
                        new_html.prependTo( this.container().find("ul") );
                    }

                    /* Without this the element can end up with
                       "display: block" as a style in some browsers
                       (saw this in Firefox 5) */
                    new_html.removeAttr("style");

                    new_html.fadeIn();
                }

                this._instrumentDeleteLinks();
            },
            _removeDeletedTags: function ( new_tag_ids, new_tags ) {
                var last_tags = this.last_tags();
                if ( ! last_tags ) {
                    return;
                }

                var self = this;

                $.each(
                    last_tags,
                    function (id) {
                        if ( ! new_tag_ids[id] ) {
                            $( "#JS-tag-" + id ).fadeOut(
                                400,
                                function () {
                                    if ( ! new_tags.length ) {
                                        self._showAllTags(new_tags);
                                    }
                                }
                            );
                        }
                    }
                );
            },
            _showAllTags: function (tags) {
                this.container().children().remove();
                $("#tagsListTemplate").tmpl( { tags: tags } ).appendTo( this.container() );
                this._instrumentDeleteLinks();
            },
            _showError: function () {
                this.container().children().remove();
                $("#tagsListErrorTemplate").tmpl().appendTo( this.container() );
            },
            _instrumentDeleteLinks: function () {
                var handler = this._curryThis( this._deleteTag );
                var self = this;

                this.container().find("a.delete-tag").each(
                    function () {
                        $(this).unbind("click.R2-delete-tag");

                        self._handlerFor(
                            $(this),
                            "click.R2-delete-tag",
                            handler
                        );
                    }
                );
            },
            _deleteTag: function (e) {
                this.collection().deleteTag( $( e.currentTarget ).attr("href") );
            }
        }
    }
);
