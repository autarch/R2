JSAN.use('R2.FormWidget.DivDeleter');

if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.RepeatableGroup = function ( div, form ) {
    this.html = div.html();
    this.repeat_count = 1;

    this.form = form;

    var type = div.attr("class").match( /JS-repeatable-group-(\S+)/ )[1];

    var repeater = $( "#" + type + "-repeater" );

    if ( ! repeater ) {
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

    /* this HTML regexing is super-hacky, but doing it via
       DOM manipulation does not seem to end up reflected in the
       innerHTML */

    var html = this.html.replace( /new1/g, "new" + this.repeat_count )
                        .replace( /class="for-radio selected"/g, "class=\"for-radio\"" )
                        .replace( /checked="checked"/g, "" )
                        /* this is for the "delete this group" piece of the repeater */
                        .replace( /display: none/g, "" );

    var div = $("<div/>");
    div.attr(
        "id", "R2-RepeatableGroup-" + R2.FormWidget._idSequence++,
        "class", "repeat-group"
    );

    div.hide();

    div.html(html);

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
}

R2.FormWidget.RepeatableGroup.prototype._instrumentDeleter = function (div) {
    var deleter = $( "a.delete-repeated-group", div ).first();

    if ( ! deleter.length ) {
        return;
    }

    new R2.FormWidget.DivDeleter( div, deleter );
};
