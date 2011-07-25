JSAN.use('R2.Form');
JSAN.use('R2.Tags');

$(document).ready(
    function () {
        R2.Form.instrumentAllForms();
        R2.Tags.instrumentTags();
    }
);
