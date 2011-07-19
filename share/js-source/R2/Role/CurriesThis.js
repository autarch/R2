Role(
    'R2.Role.CurriesThis', {
        methods: {
            _curryThis: function ( fn, args ) {
                var self   = this;
                var method = fn;

                args = Array.prototype.slice.call( arguments, 1 );

                return function () {
                    return method.apply(
                        self,
                        args.concat( Array.prototype.slice.call( arguments ) )
                    );
                };
            }
        }
    }
);
