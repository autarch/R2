JSAN.use('R2.Role.CurriesThis');

Role(
    'R2.Role.Spinner', {
        does: R2.Role.CurriesThis,
        my: {
            has: {
                Spinner: {
                    is:        'roc',
                    isPrivate: true,
                    lazy:      '_BuildSpinner'
                }
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
                is:        'rwc',
                isPrivate: true,
            }
        },
        methods: {
            /* The reason for doing this on a delay is that if the server
               response for an AJAX response is extremely fast, the spinner
               image flashes and disappears, which looks weird. */
            _showSpinnerIn: function (elt) {
                if ( ! elt.length ) {
                    return;
                }

                elt.children().detach();
                elt.append( this.my.Spinner() );

                this.spinner( this.my.Spinner() );
            },
            _showSpinnerOver: function (elt) {
                if ( ! elt.length ) {
                    return;
                }

                var container = $("<div/>");
                container.css( "background-color", "#fff" );
                container.css( "opacity", "0.9" );
                container.css( "position", "fixed" );
                container.css( "text-align", "center" );

                container.css( "height", elt.height() );
                container.css( "width", elt.width() );

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
            _removeSpinner: function () {
                if ( ! this.spinner() ) {
                    return;
                }

                this.spinner().detach();
            }
        }
    }
);
