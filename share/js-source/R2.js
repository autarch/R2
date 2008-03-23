JSAN.use('DOM.Ready');
JSAN.use('R2.Form');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.instrumentAll = function () {
    R2.Form.instrumentAllForms();
};

DOM.Ready.onDOMDone( R2.instrumentAll );
