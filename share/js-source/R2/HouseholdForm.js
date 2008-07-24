JSAN.use('DOM.Find');
JSAN.use('DOM.Utils');
JSAN.use('R2.FormWidget.AjaxSearch');


if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.HouseholdForm.instrumentForm = function () {
    var form = document.getElementById("household-form");

    if ( ! form ) {
        return;
    }

    R2.HouseholdForm._instrumentMemberSearch();
};

R2.HouseholdForm._instrumentMemberSearch = function () {
    var submit = document.getElementById("member-search-submit");

    var search = new R2.FormWidget.AjaxSearch(submit);

    
};