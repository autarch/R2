JSAN.use('R2.Email');
JSAN.use('R2.Form');
JSAN.use('R2.M.TagCollection');
JSAN.use('R2.VM.Tags.Form');
JSAN.use('R2.VM.Tags.List');

$(document).ready(
    function () {
        R2.Email.instrumentAllEmailLinks();
        R2.Form.instrumentAllForms();

        if ( $("#tags").length ) {
            var coll = new R2.M.TagCollection( { uri: $("#tags-form").attr("action") } );
            var tag_form = new R2.VM.Tags.Form ( { collection: coll } );
            var list = new R2.VM.Tags.List ( { collection: coll } );
            coll.populateTags();
        }
    }
);
