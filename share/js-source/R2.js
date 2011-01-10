JSAN.use('Data.Dump');
JSAN.use('DOM.Ready');
JSAN.use('R2.Form');
JSAN.use('R2.FormWithMemberSearch');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.instrumentAll = function () {
    R2.Form.instrumentAllForms();
    new R2.FormWithMemberSearch ();
};

DOM.Ready.onDOMDone( R2.instrumentAll );
