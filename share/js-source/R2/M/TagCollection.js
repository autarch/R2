JSAN.use("R2.Role.AjaxCollection");
JSAN.use("R2.M.Tag");

Class(
    "R2.M.TagCollection", {
        does: [
            R2.Role.AjaxCollection,
        ],
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
                this._ajaxRequest("GET");
            },
            addTags: function (tags) {
                this._ajaxRequest( "PUT", { tags: tags } );
            },
            deleteTag: function (uri) {
                this._ajaxRequest( "DELETE", undefined, uri );
            },
            _itemClass: function () {
                return R2.M.Tag;
            },
            _collectionAttr: function () {
                return "tags";
            }          
        }
    }
);
