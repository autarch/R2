Class(
    'R2.M.Tag', {
        has: {
            uri: {
                is:       'roc',
                required: true
            },
            is_email_list: {
                is:       'roc',
                required: true
            },
            tag: {
                is:       'roc',
                required: true
            },
            delete_uri: {
                is: 'roc',
            },
            icon: {
                is:        'roc',
                isPrivate: true,
                lazy:      true,
                builder:   '_build_icon'
            }
        },
        methods: {
            _build_icon: function () {
                return this.is_email_list
                    ? "/images/icons/mail-tag.png"
                    : "/images/icons/tag.png";
            }
        }
    }
);
