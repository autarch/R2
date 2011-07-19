JSAN.use("R2.Role.CurriesThis");
JSAN.use("R2.Role.EventHandler");

Class(
    "R2.VM.Tags.Form", {
        does: [ R2.Role.CurriesThis, R2.Role.EventHandler ],
        has: {
            collection: {
                is:        "roc",
                isPrivate: true,
                required:  true
            },
            form: {
                is:        "roc",
                isPrivate: true,
                builder:   "_build_form"
            },
            form_input: {
                is:        "roc",
                isPrivate: true,
                lazy:      true,
                builder:   "_build_form_input"
            }
        },
        methods: {
            initialize: function () {
                this._instrumentForm();
            },
            _build_form: function () {
                return $("#tags-form");
            },
            _build_form_input: function () {
                return this.form().find('input[name="tags"]').first();
            },
            _instrumentForm: function () {
                this._handlerFor(
                    this.form(),
                    "submit",
                    this._curryThis( this._submitForm )
                );
            },
            _submitForm: function () {
                var new_tags = this.form_input().val();

                if ( ! ( new_tags && new_tags.length ) ) {
                    return;
                }

                this.form_input().val("");

                this.collection().addTags(new_tags);
            },
        }
    }
);
