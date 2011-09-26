JSAN.use("R2.M.Email");
JSAN.use("R2.Role.AjaxCollection");

Class(
    "R2.M.EmailCollection", {
        does: [
            R2.Role.AjaxCollection
        ],
        has: {
            uri: {
                is:        "roc",
                isPrivate: true,
            },   
            emails: {
                is:        "rwc",
                isPrivate: true,
            }
        },
        methods: {
            populateEmails: function () {
                this._ajaxRequest("GET");
            },
            addEmails: function (emails) {
                this._ajaxRequest( "PUT", { emails: emails } );
            },
            deleteEmail: function (uri) {
                this._ajaxRequest( "DELETE", undefined, uri );
            },
            _itemClass: function () {
                return R2.M.Email;
            },
            _collectionAttr: function () {
                return "emails";
            }          
        }
    }
);
