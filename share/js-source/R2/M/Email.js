JSAN.use("R2.M.Contact");
JSAN.use("R2.Role.FromJSON");

(function () {
     var attrs = {};

     var names = [
         'date',
         'formatted_datetime',
         'subject',
         'headers',
         'body_summary',
         'plain_body',
         'html_body'
     ];

     $.each(
         names,
         function ( i, v ) {
             attrs[v] = {
                 is:        "roc",
                 isPrivate: true,
                 lazy:      true,
                 init:      function () { return this._entity()[v]; }
             };
         }
     );

     attrs.from = {
         is:        "roc",
         isPrivate: true,
         lazy:      true,
         builder:   "_build_from"
     };

     attrs.contacts = {
         is:        "roc",
         isPrivate: true,
         lazy:      true,
         builder:   "_build_contacts"
     };

     Class(
         "R2.M.Email", {
             does: [
                 R2.Role.FromJSON
             ],
             has: attrs,
             methods: {
                 _content_type: function () {
                     return "application/r2.email+json";
                 },
                 _build_from: function () {
                     return R2.M.Contact.newFromEntity( this._entity().from );
                 },
                 _build_contacts: function () {
                     return $.map(
                         this._entity().contacts,
                         function ( i, v ) {
                             return R2.M.Contact.newFromEntity(v);
                         }
                     );
                 }
             }
         }
     );
})();
