JSAN.use("R2.Role.CurriesThis");
JSAN.use("R2.Role.EventHandler");
JSAN.use("R2.Role.Spinner");

Class(
    "R2.VM.Emails.Table", {
        does: [ R2.Role.CurriesThis, R2.Role.EventHandler, R2.Role.Spinner ],
        has: {
            collection: {
                is:        "roc",
                isPrivate: true,
                required:  true
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
                    "requestingEmails",
                    this._curryThis( this._requestingEmails )
                );

                this.collection().addSubscriber(
                    "receivedEmails",
                    this._curryThis( this._updateEmailDisplay )
                );

                this.collection().addSubscriber(
                    "receivedError",
                    this._curryThis( this._showError )
                );
            },
            _build_container: function () {
                return $("#emails");
            },
            _requestingEmails: function () {
                if ( this._isShowingEmails()) {
                    this._showSpinnerOver( this.container() );
                }
                else {
                    this._showSpinnerIn( this.container() );
                }
            },
            _isShowingEmails: function () {
                return this.container().find('table').length ? true : false;
            },
            _updateEmailDisplay: function (emails) {
                this._removeSpinner();

                this.container().children().remove();
                $("#emailTable").tmpl(emails).appendTo( this.container() );
            },
            _showError: function () {
                this.container().children().remove();
                $("#emailsTableError").tmpl().appendTo( this.container() );
            }
        }
    }
);

