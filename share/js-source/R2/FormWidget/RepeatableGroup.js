JSAN.use('Animation.Fade');
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');
JSAN.use('DOM.Utils');
JSAN.use('R2.Element');
JSAN.use('R2.FormWidget.DivDeleter');

if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.RepeatableGroup = function ( div, form ) {
    this.html = div.innerHTML;
    this.repeat_count = 1;

    this.form = form;

    var matches = div.className.match( /JS-repeatable-group-(\S+)/ );
    var type = matches[1];

    var repeater = $( type + "-repeater" );

    if ( ! repeater ) {
        return;
    }

    this.repeater = repeater;

    var self = this;

    DOM.Events.addListener( repeater,
                            "click",
                            function (e) { self._repeatGroup(e) }
                          );
};

R2.FormWidget._idSequence = 0;

R2.FormWidget.RepeatableGroup.prototype._repeatGroup = function (e) {
    e.preventDefault();
    if ( e.stopPropogation ) {
        e.stopPropagation();
    }

    this.repeat_count++;

    /* this HTML regexing is super-hacky, but doing it via
       DOM manipulation does not seem to end up reflected in the
       innerHTML */

    var html = this.html.replace( /new1/g, "new" + this.repeat_count )
                        .replace( /class="for-radio selected"/g, "class=\"for-radio\"" )
                        .replace( /checked="checked"/g, "" )
                        /* this is for the "delete this group" piece of the repeater */
                        .replace( /display: none/g, "" );

    var div = document.createElement("div");
    div.id = "R2-RepeatableGroup-" + R2.FormWidget._idSequence++;

    div.className = "repeat-group";

    div.innerHTML = html;

    div.style.opacity = 0;

    this._instrumentDeleter(div);

    this.repeater.parentNode.insertBefore( div, this.repeater );

    this.form.instrumentRadioButtons();

    var pos = R2.Element.realPosition( e.currentTarget );

    /* This puts the repeater link at the bottom of the screen */
    var to = pos.top - document.documentElement.clientHeight;
    to += e.currentTarget.offsetHeight;

    var current = window.pageYOffset;
    /* damn you, IE */
    if ( typeof "current" == undefined ) {
        current = document.body.scrollTop;
    }

    if ( to > current ) {
        window.scrollTo( 0, to );
    }

    div.style.opacity = 0;

    Animation.Fade.fade( { "elementId":     div.id,
                           "targetOpacity": 1 } );
}

R2.FormWidget.RepeatableGroup.prototype._instrumentDeleter = function (div) {
    var deleter = DOM.Find.getElementsByAttributes( { tagName:   "A",
                                                      className: "delete-repeated-group",
                                                    }, div )[0];

    if ( ! deleter ) {
        return;
    }

    new R2.FormWidget.DivDeleter( div, deleter );
};
