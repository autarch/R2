Role(
    'R2.Role.EventHandler', {
        methods: {
            _handlerFor: function ( object, event, handler ) {
                object.bind(
                    event,
                    function (e) {
                        e.preventDefault();
                        e.stopPropagation();
                        handler.call( null, e );
                    }
                );
            }
        }
    }
);
