JSAN.use("R2.Role.CurriesThis");

Role(
    "R2.Role.Spinner", {
        does: R2.Role.CurriesThis,
        my: {
            has: {
                Spinner: {
                    is:        "roc",
                    isPrivate: true,
                    lazy:      "_BuildSpinner"
                },
            },
            methods: {
                _BuildSpinner: function () {
                    var image = new Image ();
                    image.src = "/images/spinner.gif";

                    var spinner = $("<img/>");
                    spinner.attr( "src", image.src );
                    spinner.attr( "height", 16 );
                    spinner.attr( "width", 16 );
                    spinner.attr( "alt", "spinner image" );
                    spinner.attr( "title", "Loading ..." );

                    return spinner;
                }
            }
        },       
        has: {
            spinner: {
                is:        "rwc",
                isPrivate: true
            },
            spinner_id: {
                is:        "roc",
                isPrivate: true,
                builder:   "_buildspinner_id"
            }
        },
        methods: {
            _buildspinner_id: function () {
                return "JS-" + ( typeof this ) + "-spinner";
            },
            _showSpinnerIn: function (elt) {
                if ( ! this._elt_needs_spinner(elt) ) {
                    return;
                }

                var spinner = this.my.Spinner().clone();
                spinner.attr( "id", this.spinner_id() );

                elt.children().detach();
                elt.append(spinner);

                this.spinner(spinner);
            },
            _showSpinnerOver: function (elt) {
                if ( ! this._elt_needs_spinner(elt) ) {
                    return;
                }

                var container = $("<div/>");
                container.css( "background-color", "#fff" );
                container.css( "opacity", "0.9" );
                container.css( "position", "fixed" );
                container.css( "text-align", "center" );

                container.css( "height", elt.height() );
                container.css( "width", elt.width() );
                container.attr( "id", this.spinner_id() );

                var spinner = this.my.Spinner().clone();
                if ( elt.height() > spinner.height() )  {
                    var margin = ( elt.height() - spinner.height() ) / 2;
                    spinner.css( "margin-top", margin );
                    spinner.css( "margin-bottom", margin );
                }

                container.append(spinner);
                elt.children().first().before(container);

                this.spinner(container);
            },
            _elt_needs_spinner: function (elt) {
                if ( ! elt.length ) {
                    return false;
                }

                if ( elt.find( "#" + this.spinner_id() ).length ) {
                    return false;
                }

                return true;
            },
            _removeSpinner: function () {
                if ( ! this.spinner() ) {
                    return;
                }

                this.spinner().detach();
                this.spinner(null);
            }
        }
    }
);
