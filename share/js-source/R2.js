JSAN.use('R2.Form');
JSAN.use('R2.FormWithMemberSearch');

$(document).ready(
    function () {
        R2.Form.instrumentAllForms();
        new R2.FormWithMemberSearch ();
    }
);
