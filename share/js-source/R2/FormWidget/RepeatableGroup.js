JSAN.use('R2.FormWidget.DivDeleter');

if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.RepeatableGroup = function ( div, form ) {
    this.html = div.clone().html();
    this.classes = div.attr("class");
    this.repeat_count = 1;

    this.form = form;

    var type = div.attr("class").match( /JS-repeatable-group-(\S+)/ )[1];

    var repeater = $( "#" + type + "-repeater" );

    if ( ! repeater.length ) {
        return;
    }

    this.repeater = repeater;

    var self = this;

    repeater.click(
        function (e) {
            e.preventDefault();
            e.stopPropagation();
            self._repeatGroup( $( e.currentTarget ) );
        }
    );
};

R2.FormWidget._idSequence = 0;

R2.FormWidget.RepeatableGroup.prototype._repeatGroup = function (target) {
    this.repeat_count++;

    var div = $("<div/>");

    div.hide();

    div.attr( "id", "R2-RepeatableGroup-" + R2.FormWidget._idSequence++ );
    div.attr( "class", this.classes );

    div.html( this.html );

    this._cleanClonedHTML(div);

    this._instrumentDeleter(div);

    this.repeater.before(div);

    this.form.instrumentRadioButtons();

    var pos = target.position();

    /* This puts the repeater link at the bottom of the screen */
    var to = pos.top - document.documentElement.clientHeight;
    to += target.outerHeight();

    var current = window.pageYOffset;
    /* damn you, IE */
    if ( typeof "current" == undefined ) {
        current = document.body.scrollTop;
    }

    if ( to > current ) {
        window.scrollTo( 0, to );
    }

    div.fadeIn(500);
};

R2.FormWidget.RepeatableGroup.prototype._cleanClonedHTML = function (div) {
    var count = this.repeat_count;

    div.find("*").filter(
        function () {
            return (/new1/).test( $(this).attr("name") )
                || (/new1/).test( $(this).attr("id") )
                || (/new1/).test( $(this).attr("for") );
        }
    ).each(
        function () {
            if ( $(this).attr("id") ) {
                var id = $(this).attr("id").replace( /new1/g, "new" + count );
                $(this).attr( "id", id );
            }

            if ( $(this).attr("name") ) {
                var name = $(this).attr("name").replace( /new1/g, "new" + count );
                $(this).attr( "name", name );
            }

            if ( $(this).attr("for") ) {
                var for_attr = $(this).attr("for").replace( /new1/g, "new" + count );
                $(this).attr( "for", for_attr );
            }
        }
    );

    div.find(":radio").filter(
        function () {
            return (/is_preferred$/).test( $(this).attr("name") );
        }
    ).each(
        function () {
            $(this).attr( "checked", "" );
        }
    );

    div.find("label").filter(
        function () {
            return (/is_preferred-/).test( $(this).attr("id") );
        }
    ).each(
        function () {
            $(this).removeClass("selected");
        }
    );

    div.find("a.JS-delete-div").show();

    return;
};

R2.FormWidget.RepeatableGroup.prototype._instrumentDeleter = function (div) {
    var deleter = div.find("a.JS-delete-div").first();

    if ( ! deleter.length ) {
        return;
    }

    new R2.FormWidget.DivDeleter( div, deleter );
};
