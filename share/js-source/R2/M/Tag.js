Class(
    'R2.M.Tag', {
        has: {
            uri: {
                is:       'roc',
                isPrivate: true,
                required:  true
            },
            is_email_list: {
                is:       'roc',
                isPrivate: true,
                required:  true
            },
            tag: {
                is:       'roc',
                isPrivate: true,
                required:  true
            },
            tag_id: {
                is:       'roc',
                isPrivate: true,
                required:  true
            },
            delete_uri: {
                is:       'roc',
                isPrivate: true
            },
            css_class: {
                is:        'roc',
                isPrivate: true,
                lazy:      true,
                builder:   '_build_css_class'
            }
        },
        methods: {
            _build_css_class: function () {
                return this.is_email_list()
                    ? "email-tag-link"
                    : "tag-link";
            }
        }
    }
);
