JSAN.use('DOM.Element');
JSAN.use('DOM.Events');
JSAN.use('DOM.Find');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.FormWidget == "undefined" ) {
    R2.FormWidget = {};
}

R2.FormWidget.AjaxSearch = function ( submit, 