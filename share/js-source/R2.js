JSAN.use('DOM.Ready');
JSAN.use('R2.Form');
JSAN.use('R2.HouseholdForm');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.instrumentAll = function () {
    R2.Form.instrumentAllForms();
    R2.HouseholdForm.instrumentForm();
};

DOM.Ready.onDOMDone( R2.instrumentAll );
