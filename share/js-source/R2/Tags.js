JSAN.use('R2.M.TagCollection');
JSAN.use('R2.VM.Tags.Form');
JSAN.use('R2.VM.Tags.List');

if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.Tags = {};

R2.Tags.instrumentTags = function () {
    if ( ! $("#tags").length ) {
        return;
    }

    var coll = new R2.M.TagCollection( { uri: $("#tags-form").attr("action") } );
    var tag_form = new R2.VM.Tags.Form ( { collection: coll } );
    var list = new R2.VM.Tags.List ( { collection: coll } );
    coll.populateTags();
};
