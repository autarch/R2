Role(
    "R2.Role.FromJSON", {
        requires: [
            "_content_type"
        ],
        my: {
            has: {
                host: null
            },
            methods: {
                newFromEntity: function (entity) {
                    return new this.HOST ( { entity: entity } );
                }
            }
        },
        has: {
            uri: {
                is:       "roc",
                isPrivate: true,
                required:  true
            },
            entity: {
                is:       "roc",
                isPrivate: true,
                required:  true
            }
        }
    }
);
