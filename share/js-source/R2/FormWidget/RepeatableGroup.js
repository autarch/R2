JSAN.use('Animation.Fade');
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');
JSAN.use('DOM.Utils');


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

    var matches = div.className.match( /JS-repeater-(.+)/ );
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

    /* replacing checked="checked" is super-hacky, but doing it via
       DOM manipulation does not seem to end up reflected in the
       innerHTML */

    var html = this.html.replace( /new1/g, "new" + this.repeat_count )
                        .replace( /checked="checked"/g, "" );


    var div = document.createElement("div");
    div.id = "R2-RepeatableGroup-" + R2.FormWidget._idSequence++;

    div.innerHTML = html;

    div.style.opacity = 0;

    this.repeater.parentNode.insertBefore( div, this.repeater );

    this.form.instrumentRadioButtons();

    Animation.Fade.fade( { elementId: div.id, targetOpacity: 1 } );
}