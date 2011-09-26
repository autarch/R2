JSAN.use('R2.M.EmailCollection');
JSAN.use('R2.VM.Emails.Table');

if ( typeof R2 == "undefined" ) {
    R2 = {};
}

R2.Emails = {};

R2.Emails.instrumentEmails = function () {
    if ( ! $("#emails").length ) {
        return;
    }

    var uri = window.location.href;
    var coll = new R2.M.EmailCollection( { uri: uri } );
    var table = new R2.VM.Emails.Table ( { collection: coll } );
    coll.populateEmails();
};
