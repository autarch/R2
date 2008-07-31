JSAN.use('DOM.Find');
JSAN.use('DOM.Utils');
JSAN.use('R2.FormWidget.AjaxSearch');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

if ( typeof R2.HouseholdForm == "undefined" ) {
    R2.HouseholdForm = {};
}

R2.HouseholdForm.instrumentForm = function () {
    var form = document.getElementById("household-form");

    if ( ! form ) {
        return;
    }

    R2.HouseholdForm._instrumentMemberSearch();
};

R2.HouseholdForm._instrumentMemberSearch = function () {

    var search =
        new R2.FormWidget.AjaxSearch( "/person",
                                      "member",
                                      R2.HouseholdForm._populateResults,
                                      R2.HouseholdForm._handleError
                                    );

};

R2.HouseholdForm._populateResults = function (results) {
    alert(results);
};

R2.HouseholdForm._handleError = function (results) {
    alert("ERROR");
};