JSAN.use('DOM.Ready');
JSAN.use('R2.Form');
JSAN.use('R2.FormWithMemberSearch');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.instrumentAll = function () {
    R2.Form.instrumentAllForms();
    R2.FormWithMemberSearch.instrumentForm();
};

DOM.Ready.onDOMDone( R2.instrumentAll );
