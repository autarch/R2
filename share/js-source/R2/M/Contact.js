JSAN.use("R2.Role.FromJSON");

(function () {
     var attrs = {};

     var names = [
         'contact_type',
         'display_name'
     ];

     $.each(
         names,
         function ( i, v ) {
             attrs[v] = {
                 is:        "roc",
                 isPrivate: true,
                 lazy:      true,
                 init:      function () {
                     return this._entity()[v];
                 }
             };
         }
     );

     Class(
         "R2.M.Contact", {
             does: [
                 R2.Role.FromJSON
             ],
             has: attrs,
             methods: {
                 _content_type: function () {
                     return "application/r2.contact+json";
                 }
             }
         }
     );
})();
