Role(
    'R2.Role.Publisher', {
        has: {
            subscribers: {
                is:        'rwc',
                isPrivate: true,
                init:      function () { return {} }
            }
        },
        methods: {
            addSubscriber: function ( event, func ) {
                var subs = this.subscribers();
                if ( ! subs[event] ) {
                    subs[event] = [];
                }

                subs[event].push(func);
            },
            _publishEvent: function (event) {
                var subs = this.subscribers()[event];

                if ( ! ( subs && subs.length ) ) {
                    return;
                }

                var args = Array.prototype.slice.call( arguments, 1 );

                for ( var i = 0; i < subs.length; i++ ) {
                    subs[i].apply( null, args );
                }
            }
        }
    }
);
