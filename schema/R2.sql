SET CLIENT_MIN_MESSAGES = ERROR;

CREATE DOMAIN email_address AS citext
       CONSTRAINT valid_email_address CHECK ( VALUE ~ E'^.+@.+(?:\\..+)+' );

-- Is there a way to ensure that this table only ever has one row?
CREATE TABLE "Version" (
       version                  INTEGER         PRIMARY KEY
);

CREATE UNIQUE INDEX only_one_version_row ON "Version" ((TRUE));

CREATE TYPE date_style AS ENUM ( 'American', 'European', 'YMD' );

CREATE TABLE "User" (
       -- will be the same as a person_id
       user_id                  SERIAL8         PRIMARY KEY,
       username                 TEXT            UNIQUE NOT NULL,
       -- RFC2307 Blowfish crypt
       password                 VARCHAR(67)     NOT NULL,
       time_zone                TEXT            NOT NULL DEFAULT 'UTC',
       date_style               date_style      NOT NULL DEFAULT 'American',
       use_24_hour_time         BOOLEAN         DEFAULT FALSE,
       creation_datetime        TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       last_modified_datetime   TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       is_system_admin          BOOLEAN         DEFAULT FALSE,
       is_disabled              BOOLEAN         DEFAULT FALSE,
       is_system_user           BOOLEAN         DEFAULT FALSE,
       person_id                INT8            NULL,
       account_id               INT8            NULL,
       role_id                  INTEGER         NULL,
       CONSTRAINT valid_username CHECK ( username != '' ),
       CONSTRAINT valid_password CHECK ( password != '' ),
       CONSTRAINT account_requires_role
                  CHECK ( ( account_id IS NULL AND role_id IS NULL )
                          OR
                          ( account_id IS NOT NULL AND role_id IS NOT NULL ) )
);

CREATE INDEX "User_person_id" ON "User" ("person_id");
CREATE INDEX "User_account_id" ON "User" ("account_id");
CREATE INDEX "User_role_id" ON "User" ("role_id");

CREATE TABLE "Account" (
       account_id               SERIAL          PRIMARY KEY,
       name                     TEXT            UNIQUE  NOT NULL,
       domain_id                INTEGER         NOT NULL,
       default_time_zone        TEXT            NOT NULL DEFAULT 'UTC',
       fiscal_year_start_month  INTEGER         NOT NULL DEFAULT 1,
       creation_datetime        TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT valid_name CHECK ( name != '' ),
       CONSTRAINT valid_fiscal_year_start_month
                  CHECK ( fiscal_year_start_month >= 1 AND fiscal_year_start_month <= 12 )
);

CREATE INDEX "Account_domain_id" ON "Account" ("domain_id");

CREATE TABLE "Role" (
       role_id                  SERIAL          PRIMARY KEY,
       name                     TEXT            UNIQUE  NOT NULL
);

CREATE DOMAIN hostname AS citext
       CONSTRAINT valid_hostname CHECK ( VALUE ~ E'^[^\\.]+(?:\\.[^\\.]+)+$' );

CREATE TABLE "Domain" (
       domain_id          SERIAL             PRIMARY KEY,
       web_hostname       hostname           UNIQUE  NOT NULL,
       email_hostname     hostname           UNIQUE  NOT NULL,
       requires_ssl       BOOLEAN            DEFAULT FALSE,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT valid_web_hostname CHECK ( web_hostname != '' ),
       CONSTRAINT valid_email_hostname CHECK ( email_hostname != '' )
);

CREATE DOMAIN filename AS citext
       CONSTRAINT no_slashes CHECK ( VALUE ~ E'^[^\\\\/]+$' );

CREATE TABLE "File" (
       file_id            SERIAL8            PRIMARY KEY,
       mime_type          citext             NOT NULL,
       filename           filename           NOT NULL,
       -- This lets us look up a variation of a file (notably a
       -- resized image) by generating a file name from some other
       -- File row, rather than having to know its file_id. For most
       -- files, this will be the same as its file_id, but for resized
       -- images it will be something like 1234-100x100
       unique_name        citext             UNIQUE NULL,
       contents           BYTEA              NOT NULL,
       creation_datetime        TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       account_id         INT8               NOT NULL
);

CREATE INDEX "File_account_id" ON "File" ("account_id");

CREATE TYPE contact_type AS ENUM ( 'Person', 'Organization', 'Household' );

CREATE DOMAIN uri AS TEXT
       CONSTRAINT valid_uri CHECK ( VALUE ~ E'^https?://[\\w-_]+(\.[\\w-_]+)*\\.\\w{2,3}' );

CREATE TABLE "Contact" (
       contact_id         SERIAL8            PRIMARY KEY,
       contact_type       contact_type       NOT NULL,
       allows_email       BOOLEAN            NOT NULL DEFAULT TRUE,
       email_opt_out      BOOLEAN            NOT NULL DEFAULT FALSE,
       allows_mail        BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_phone       BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_trade       BOOLEAN            NOT NULL DEFAULT FALSE,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       image_file_id      INT8               NULL,
       -- an identifier from another app, probably created via an
       -- initial import from something else
       external_id        TEXT               UNIQUE NULL,
       account_id         INTEGER            NOT NULL
);

CREATE INDEX "Contact_image_file_id" ON "Contact" ("image_file_id");
CREATE INDEX "Contact_account_id" ON "Contact" ("account_id");

CREATE DOMAIN pos_int AS INTEGER
       CONSTRAINT is_positive CHECK ( VALUE > 0 );

CREATE TABLE "CustomFieldGroup" (
       custom_field_group_id          SERIAL8      PRIMARY KEY,
       name                           citext       NOT NULL,
       display_order                  pos_int      NOT NULL,
       applies_to_person              BOOLEAN      NOT NULL DEFAULT TRUE,
       applies_to_household           BOOLEAN      NOT NULL DEFAULT FALSE,
       applies_to_organization        BOOLEAN      NOT NULL DEFAULT FALSE,
       account_id                     INT8         NOT NULL,
       CONSTRAINT "CustomFieldGroup_account_id_display_order_unique"
                  UNIQUE ( account_id, display_order )
);

CREATE INDEX "CustomFieldGroup_account_id" ON "CustomFieldGroup" ("account_id");

CREATE TYPE custom_field_type AS
       ENUM ( 'Integer', 'Decimal', 'Date', 'DateTime', 'Text', 'File', 'SingleSelect', 'MultiSelect' );

CREATE TABLE "CustomField" (
       custom_field_id          SERIAL8      PRIMARY KEY,
       label                    TEXT         NOT NULL,
       description              TEXT         NOT NULL DEFAULT '',
       type                     custom_field_type  NOT NULL,
       is_required              BOOLEAN      DEFAULT FALSE,
       html_widget_id           INTEGER      NOT NULL,
       display_order            pos_int      NOT NULL,
       account_id               INT8         NOT NULL,
       custom_field_group_id    INT8         NOT NULL,
       CONSTRAINT "CustomField_custom_field_group_id_display_order_unique"
                  UNIQUE ( custom_field_group_id, display_order )
);

CREATE INDEX "CustomField_custom_field_group_id"
       ON "CustomField" ("custom_field_group_id");
CREATE INDEX "CustomField_html_widget_id"
       ON "CustomField" ("html_widget_id");

CREATE TABLE "HTMLWidget" (
       html_widget_id           SERIAL       PRIMARY KEY,
       name                     TEXT         UNIQUE NOT NULL,
       description              TEXT         NOT NULL,
       type                     custom_field_type  NOT NULL
);

CREATE TABLE "CustomFieldIntegerValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    INT8         NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE INDEX "CustomFieldIntegerValue_custom_field_id"
       ON "CustomFieldIntegerValue" ("custom_field_id");

CREATE TABLE "CustomFieldDecimalValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    FLOAT8       NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE INDEX "CustomFieldDecimalValue_custom_field_id"
       ON "CustomFieldDecimalValue" ("custom_field_id");

CREATE TABLE "CustomFieldDateValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    DATE         NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE INDEX "CustomFieldDateValue_custom_field_id"
       ON "CustomFieldDateValue" ("custom_field_id");

CREATE TABLE "CustomFieldDateTimeValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    TIMESTAMP WITHOUT TIME ZONE  NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE INDEX "CustomFieldDateTimeValue_custom_field_id"
       ON "CustomFieldDateTimeValue" ("custom_field_id");

CREATE TABLE "CustomFieldTextValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    TEXT         NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE INDEX "CustomFieldTextValue_custom_field_id"
       ON "CustomFieldTextValue" ("custom_field_id");

CREATE TABLE "CustomFieldFileValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    BYTEA        NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE INDEX "CustomFieldFileValue_custom_field_id"
       ON "CustomFieldFileValue" ("custom_field_id");

CREATE TABLE "CustomFieldSelectOption" (
       custom_field_select_option_id INT8    PRIMARY KEY,
       custom_field_id          INT8         NOT NULL,
       display_order            pos_int      NOT NULL,
       value                    TEXT         NOT NULL,
       CONSTRAINT "CustomFieldSelectOption_custom_field_id_display_order_unique"
                  UNIQUE ( custom_field_id, display_order )
);

CREATE INDEX "CustomFieldSelectOption_custom_field_id"
       ON "CustomFieldSelectOption" ("custom_field_id");

CREATE TABLE "CustomFieldSingleSelectValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       custom_field_select_option_id  INT8   NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE INDEX "CustomFieldSingleSelectValue_custom_field_id"
       ON "CustomFieldSingleSelectValue" ("custom_field_id");
CREATE INDEX "CustomFieldSingleSelectValue_custom_field_select_option_id"
       ON "CustomFieldSingleSelectValue" ("custom_field_select_option_id");
       
CREATE TABLE "CustomFieldMultiSelectValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       custom_field_select_option_id  INT8   NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id, custom_field_select_option_id )
);

CREATE INDEX "CustomFieldMultiSelectValue_custom_field_id"
       ON "CustomFieldMultiSelectValue" ("custom_field_id");
CREATE INDEX "CustomFieldMultiSelectValue_custom_field_select_option_id"
       ON "CustomFieldMultiSelectValue" ("custom_field_select_option_id");

CREATE TABLE "Email" (
       email_id           SERIAL8            PRIMARY KEY,
       from_contact_id    INT8               NULL,
       from_user_id       INT8               NULL,
       donation_id        INT8               UNIQUE  NULL,
       subject            TEXT               NOT NULL,
       raw_content        TEXT               NOT NULL,
       account_id         INT8               NULL,
       email_datetime     TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT valid_subject CHECK ( subject != '' ),
       CONSTRAINT valid_raw_content CHECK ( raw_content != '' )
);

CREATE INDEX "Email_from_contact_id" ON "Email" ("from_contact_id");
CREATE INDEX "Email_from_user_id" ON "Email" ("from_user_id");
CREATE INDEX "Email_donation_id" ON "Email" ("donation_id");
CREATE INDEX "Email_account_id" ON "Email" ("account_id");

CREATE TABLE "ContactEmail" (
       contact_id         INT8               NOT NULL,
       email_id           INT8               NOT NULL,
       PRIMARY KEY ( contact_id, email_id )
);

CREATE INDEX "ContactEmail_email_id" ON "ContactEmail" ("email_id");

CREATE TABLE "ContactNote" (
       contact_note_id    SERIAL8            PRIMARY KEY,
       contact_id         INT8               NOT NULL,
       contact_note_type_id  INT             NOT NULL,
       user_id            INT8               NOT NULL,
       note               TEXT               NOT NULL,
       note_datetime      TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "ContactNote_contact_id" ON "ContactNote" ("contact_id");
CREATE INDEX "ContactNote_contact_note_type_id" ON "ContactNote" ("contact_note_type_id");

CREATE TABLE "ContactNoteType" (
       contact_note_type_id  SERIAL          PRIMARY KEY,
       description        TEXT               NOT NULL,
       is_system_defined  BOOLEAN            NOT NULL DEFAULT FALSE,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_description CHECK ( description != '' ),
       CONSTRAINT "ContactNoteType_description_account_id_unique"
                  UNIQUE ( description, account_id )
);

CREATE INDEX "ContactNoteType_account_id" ON "ContactNoteType" ("account_id");

CREATE TABLE "ContactHistory" (
       contact_history_id SERIAL8            PRIMARY KEY,
       contact_id         INT8               NOT NULL,
       contact_history_type_id  INT          NOT NULL,
       user_id            INT8               NOT NULL,
       email_address_id   INT8               NULL,
       website_id         INT8               NULL,
       address_id         INT8               NULL,
       phone_number_id    INT8               NULL,
       other_contact_id   INT8               NULL,
       description        TEXT               NOT NULL DEFAULT '',
       history_datetime   TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       -- something that describes the change to the thing in question
       -- as a data structure, and provides a way to reverse it,
       -- presumably a Storable-created data structure
       reversal_blob      BYTEA              NOT NULL,
       CONSTRAINT contact_id_ne_other_contact_id CHECK ( contact_id != other_contact_id )
);

CREATE INDEX "ContactHistory_contact_id" ON "ContactHistory" ("contact_id");
CREATE INDEX "ContactHistory_contact_history_type_id"
       ON "ContactHistory" ("contact_history_type_id");
CREATE INDEX "ContactHistory_user_id" ON "ContactHistory" ("user_id");
CREATE INDEX "ContactHistory_email_address_id" ON "ContactHistory" ("email_address_id");
CREATE INDEX "ContactHistory_website_id" ON "ContactHistory" ("website_id");
CREATE INDEX "ContactHistory_phone_number_id" ON "ContactHistory" ("phone_number_id");
CREATE INDEX "ContactHistory_other_contact_id" ON "ContactHistory" ("other_contact_id");

CREATE TABLE "ContactHistoryType" (
       contact_history_type_id  SERIAL       PRIMARY KEY,
       system_name        TEXT               UNIQUE  NOT NULL,
       description        TEXT               NOT NULL,
       sort_order         pos_int            NOT NULL,
       CONSTRAINT valid_description CHECK ( description != '' )
);

CREATE TABLE "ContactTag" (
       contact_id       INT8            NOT NULL,
       tag_id           INT8            NOT NULL,
       PRIMARY KEY ( contact_id, tag_id )
);

CREATE INDEX "ContactTag_tag_id" ON "ContactTag" ("tag_id");

CREATE TABLE "Tag" (
       tag_id           SERIAL8         PRIMARY KEY,
       tag              citext          NOT NULL,
       account_id       INT8            NOT NULL,
       CONSTRAINT "Tag_tag_account_id_unique" UNIQUE ( tag, account_id )
);

CREATE INDEX "Tag_account_id" ON "Tag" ("account_id");

-- An email list is simply additional data for a tag
CREATE TABLE "EmailList" (
       tag_id           INT8            PRIMARY KEY,
       description      TEXT            NOT NULL
);

CREATE TABLE "ContactEmailListOptOut" (
       tag_id           INT8            NOT NULL,
       contact_id       INT8            NOT NULL,
       PRIMARY KEY ( tag_id, contact_id )
);

CREATE INDEX "ContactEmailListOptOut_contact_id"
        ON "ContactEmailListOptOut" ("contact_id");

CREATE TABLE "Activity" (
       activity_id        SERIAL8       PRIMARY KEY,
       name               citext        NOT NULL,
       activity_type_id   INT8          NOT NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       is_archived        BOOLEAN       DEFAULT FALSE,
       account_id         INT8          NOT NULL,
       CONSTRAINT "Activity_account_id_name"
                  UNIQUE ( account_id, name )
);

CREATE TABLE "ActivityType" (
       activity_type_id   SERIAL8       PRIMARY KEY,
       name               TEXT          NOT NULL,
       display_order      pos_int       NOT NULL,
       account_id         INT8          NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' ),
       CONSTRAINT "ActivityType_account_id_name"
                  UNIQUE ( account_id, name ),
       CONSTRAINT "ActivityType_account_id_display_order"
                  UNIQUE ( account_id, display_order )
);

CREATE TABLE "ContactParticipation" (
       contact_participation_id   SERIAL8     PRIMARY KEY,
       contact_id                 INT8        NOT NULL,
       activity_id                INT8        NOT NULL,
       participation_type_id      INT8        NOT NULL,
       description                TEXT        DEFAULT '',
       start_date                 DATE        NOT NULL,
       end_date                   DATE        NULL,
       CONSTRAINT start_before_end
                  CHECK ( end_date IS NULL
                          OR end_date >= start_date )
);

CREATE TABLE "ParticipationType" (
       participation_type_id  SERIAL8       PRIMARY KEY,
       name                   TEXT          NOT NULL,
       display_order          pos_int       NOT NULL,
       account_id             INT8          NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' ),
       CONSTRAINT "ParticipationType_account_id_name"
                  UNIQUE ( account_id, name ),
       CONSTRAINT "ParticipationType_account_id_display_order"
                  UNIQUE ( account_id, display_order )
);

CREATE TABLE "Person" (
       person_id          INT8               PRIMARY KEY,
       salutation         citext             NOT NULL DEFAULT '',
       first_name         citext             NOT NULL DEFAULT '',
       middle_name        citext             NOT NULL DEFAULT '',
       last_name          citext             NOT NULL DEFAULT '',
       suffix             citext             NOT NULL DEFAULT '',
       birth_date         DATE               NULL,
       gender             citext             NULL
);

CREATE TABLE "MessagingProvider" (
       messaging_provider_id  SERIAL8        PRIMARY KEY,
       contact_id         INT8               NOT NULL,
       messaging_provider_type_id  INT8      NOT NULL,
       screen_name        TEXT               NOT NULL,
       is_preferred       BOOLEAN            DEFAULT FALSE,
       note               TEXT               NOT NULL DEFAULT ''
);

CREATE INDEX "MessagingProvider_contact_id" ON "MessagingProvider" ("contact_id");
CREATE INDEX "MessagingProvider_messaging_provider_type_id"
       ON "MessagingProvider" ("messaging_provider_type_id");

CREATE TABLE "MessagingProviderType" (
       messaging_provider_type_id  SERIAL8        PRIMARY KEY,
       name                   citext         UNIQUE  NOT NULL,
       add_uri_template       TEXT           NOT NULL DEFAULT '',
       chat_uri_template      TEXT           NOT NULL DEFAULT '',
       call_uri_template      TEXT           NOT NULL DEFAULT '',
       video_uri_template     TEXT           NOT NULL DEFAULT '',
       status_uri_template    TEXT           NOT NULL DEFAULT ''
);

CREATE TABLE "PersonRelationship" (
       person_id          INT8               NOT NULL,
       relationship_type_id  INT8            NOT NULL,
       other_person_id    INT8               NOT NULL,
       note               TEXT               NOT NULL DEFAULT '',
       PRIMARY KEY ( person_id, relationship_type_id, other_person_id )
);

CREATE INDEX "PersonRelationship_relationship_type_id"
       ON "PersonRelationship" ("relationship_type_id");
CREATE INDEX "PersonRelationship_other_person_id"
       ON "PersonRelationship" ("other_person_id");

CREATE TABLE "RelationshipType" (
       relationship_type_id  SERIAL8         PRIMARY KEY,
       account_id          INT8              NOT NULL,
       name                TEXT              NOT NULL,
       inverse_name        TEXT              NOT NULL
);   

CREATE INDEX "RelationshipType_account_id" ON "RelationshipType" ("account_id");

CREATE TABLE "Household" (
       household_id       SERIAL8            PRIMARY KEY,
       name               citext             NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "HouseholdMember" (
       household_id       INT8               NOT NULL,
       person_id          INT8               NOT NULL,
       position           citext             NOT NULL DEFAULT '',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY ( household_id, person_id )
);

CREATE INDEX "HouseholdMember_person_id" ON "HouseholdMember" ("person_id");

CREATE TABLE "Organization" (
       organization_id    INT8               PRIMARY KEY,
       name               citext             NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "OrganizationMember" (
       organization_id    INT8               NOT NULL,
       person_id          INT8               NOT NULL,
       position           citext             NOT NULL DEFAULT '',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY ( organization_id, person_id )
);

CREATE INDEX "OrganizationMember_person_id" ON "OrganizationMember" ("person_id");

-- It's tempting to make the email address unique, but contacts could
-- share an email address, especially in the case of a household and a
-- person in the household, or an organization.
CREATE TABLE "EmailAddress" (
       email_address_id   SERIAL8            PRIMARY KEY,
       contact_id         INT8               NOT NULL,
       email_address      email_address      NOT NULL,
       is_preferred       BOOLEAN            DEFAULT FALSE,
       note               TEXT               NOT NULL DEFAULT ''
);

CREATE INDEX "EmailAddress_contact_id" ON "EmailAddress" ("contact_id");

CREATE TABLE "Website" (
       website_id         SERIAL8            PRIMARY KEY,
       contact_id         INT8               NOT NULL,
       label              TEXT               NOT NULL DEFAULT 'Website',
       uri                uri                NOT NULL,
       note               TEXT               NOT NULL DEFAULT ''
);

CREATE INDEX "Website_contact_id" ON "Website" ("contact_id");

-- Consider a trigger to enforce one primary address per contact?
CREATE TABLE "Address" (
       address_id         SERIAL8            PRIMARY KEY,
       contact_id         INTEGER            NOT NULL,
       address_type_id    INTEGER            NOT NULL,
       street_1           citext             NOT NULL DEFAULT '',
       street_2           citext             NOT NULL DEFAULT '',
       city               citext             NOT NULL DEFAULT '',
       region             citext             NOT NULL DEFAULT '',
       postal_code        citext             NOT NULL DEFAULT '',
       country            citext             NOT NULL DEFAULT '',
       latitude           FLOAT              NULL,
       longitude          FLOAT              NULL,
       -- The address as returned by a geocoding service like Google
       -- Maps.
       canonical_address  TEXT               NOT NULL DEFAULT '',
       is_preferred       BOOLEAN            DEFAULT FALSE,
       note               TEXT               NOT NULL DEFAULT '',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "Address_contact_id" ON "Address" ("contact_id");
CREATE INDEX "Address_address_type_id" ON "Address" ("address_type_id");

CREATE TABLE "AddressType" (
       address_type_id    SERIAL8            PRIMARY KEY,
       name               TEXT               NOT NULL,
       display_order      pos_int            NOT NULL,
       applies_to_person  BOOLEAN            NOT NULL DEFAULT FALSE,
       applies_to_household     BOOLEAN      NOT NULL DEFAULT FALSE,
       applies_to_organization  BOOLEAN      NOT NULL DEFAULT FALSE,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' ),
       CONSTRAINT "AddressType_account_id_display_order_unique"
                  UNIQUE ( account_id, display_order )
);

CREATE INDEX "AddressType_account_id" ON "AddressType" ("account_id");

CREATE TABLE "TimeZone" (
       olson_name         TEXT               PRIMARY KEY,
       description        VARCHAR(100)       NOT NULL,
       country            citext             NOT NULL,
       display_order      INTEGER            NOT NULL,
       CONSTRAINT valid_olson_name CHECK ( olson_name != '' ),
       CONSTRAINT valid_description CHECK ( description != '' ),
       CONSTRAINT valid_display_order CHECK ( display_order > 0 ),
       CONSTRAINT TimeZone_country_display_order_unique
                  UNIQUE ( country, display_order )
);

-- Consider a trigger to enforce one primary phone number per contact?
CREATE TABLE "PhoneNumber" (
       phone_number_id    SERIAL8            PRIMARY KEY,
       contact_id         INTEGER            NOT NULL,
       phone_number_type_id   INT8           NOT NULL,
       phone_number       TEXT               DEFAULT '',
       is_preferred       BOOLEAN            DEFAULT FALSE,
       allows_sms         BOOLEAN            DEFAULT FALSE,
       note               TEXT               NOT NULL DEFAULT '',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "PhoneNumber_contact_id" ON "PhoneNumber" ("contact_id");
CREATE INDEX "PhoneNumber_phone_number_type_id"
       ON "PhoneNumber" ("phone_number_type_id");

CREATE TABLE "PhoneNumberType" (
       phone_number_type_id  SERIAL8         PRIMARY KEY,
       name                  TEXT            NOT NULL,
       display_order         pos_int         NOT NULL,
       applies_to_person     BOOLEAN         NOT NULL DEFAULT FALSE,
       applies_to_household     BOOLEAN      NOT NULL DEFAULT FALSE,
       applies_to_organization  BOOLEAN      NOT NULL DEFAULT FALSE,
       account_id            INT8            NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' ),
       CONSTRAINT PhoneNumberType_account_id_display_order_unique
                  UNIQUE ( account_id, display_order )
);

CREATE INDEX "PhoneNumberType_account_id" ON "PhoneNumberType" ("account_id");

CREATE TABLE "Donation" (
       donation_id        SERIAL8            PRIMARY KEY,
       amount             NUMERIC(13,2)      NOT NULL,
       donation_date      DATE               NOT NULL,
       contact_id         INT8               NOT NULL,
       gift_item          TEXT               NOT NULL DEFAULT '',
       gift_sent_date     DATE               NULL,
       value_for_donor    NUMERIC(13,2)      NOT NULL DEFAULT 0.00,
       transaction_cost   NUMERIC(13,2)      NOT NULL DEFAULT 0.00,
       dedication         TEXT               NOT NULL DEFAULT '',
       recurrence_frequency  TEXT            NULL,
       receipt_date       DATE               NULL,
       donation_source_id INT8               NOT NULL,
       donation_campaign_id  INT8            NOT NULL,
       payment_type_id    INT8               NOT NULL,
       external_id        TEXT               NULL,
       note               TEXT               NOT NULL DEFAULT '',
       CONSTRAINT valid_amount CHECK ( amount > 0.00 ),
       CONSTRAINT valid_value_for_donor CHECK ( value_for_donor >= 0.00 ),
       CONSTRAINT valid_transaction_cost CHECK ( transaction_cost >= 0.00 )
);

CREATE INDEX "Donation_contact_id" ON "Donation" ("contact_id");
CREATE INDEX "Donation_donation_source_id" ON "Donation" ("donation_source_id");
CREATE INDEX "Donation_donation_campaign_id" ON "Donation" ("donation_campaign_id");
CREATE INDEX "Donation_payment_type_id" ON "Donation" ("payment_type_id");

CREATE TABLE "DonationSource" (
       donation_source_id SERIAL8            PRIMARY KEY,
       name               TEXT               NOT NULL,
       display_order      pos_int            NOT NULL,
       account_id         INT8               NOT NULL,
       is_active          BOOLEAN            DEFAULT TRUE,
       CONSTRAINT valid_name CHECK ( name != '' ),
       CONSTRAINT DonationSource_account_id_display_order_unique
                  UNIQUE ( account_id, display_order )
);

CREATE INDEX "DonationSource_account_id" ON "DonationSource" ("account_id");

CREATE TABLE "DonationCampaign" (
       donation_campaign_id  SERIAL8         PRIMARY KEY,
       name               TEXT               NOT NULL,
       display_order      pos_int            NOT NULL,
       account_id         INT8               NOT NULL,
       is_active          BOOLEAN            DEFAULT TRUE,
       CONSTRAINT valid_name CHECK ( name != '' ),
       CONSTRAINT DonationCampaign_account_id_display_order_unique
                  UNIQUE ( account_id, display_order )
);

CREATE INDEX "DonationCampaign_account_id" ON "DonationCampaign" ("account_id");

CREATE TABLE "PaymentType" (
       payment_type_id    SERIAL8            PRIMARY KEY,
       name               TEXT               NOT NULL,
       display_order      pos_int            NOT NULL,
       account_id         INT8               NOT NULL,
       is_active          BOOLEAN            DEFAULT TRUE,
       CONSTRAINT valid_name CHECK ( name != '' ),
       CONSTRAINT PaymentType_account_id_display_order_unique
                  UNIQUE ( account_id, display_order )
);

CREATE INDEX "PaymentType_account_id" ON "PaymentType" ("account_id");

CREATE TABLE "SavedSearch" (
       name               TEXT               NOT NULL,
       class              TEXT               NOT NULL,
       params             TEXT               NOT NULL,
       user_id            INT8               NOT NULL,
       is_shared          BOOLEAN            DEFAULT FALSE,
       CONSTRAINT valid_name CHECK ( name != '' ),
       CONSTRAINT valid_class CHECK ( class != '' ),
       PRIMARY KEY ( name, user_id )
);

CREATE TABLE "Session" (
       id                 CHAR(72)           PRIMARY KEY,
       session_data       BYTEA              NOT NULL,
       expires            INT                NOT NULL
);


ALTER TABLE "User" ADD CONSTRAINT "User_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Person" ("person_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "User" ADD CONSTRAINT "User_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "User" ADD CONSTRAINT "User_role_id"
  FOREIGN KEY ("role_id") REFERENCES "Role" ("role_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Account" ADD CONSTRAINT "Account_domain_id"
  FOREIGN KEY ("domain_id") REFERENCES "Domain" ("domain_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "File" ADD CONSTRAINT "File_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Contact" ADD CONSTRAINT "Contact_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Contact" ADD CONSTRAINT "Contact_image_file_id"
  FOREIGN KEY ("image_file_id") REFERENCES "File" ("file_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "CustomFieldGroup" ADD CONSTRAINT "CustomFieldGroup_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomField" ADD CONSTRAINT "CustomField_custom_field_group_id"
  FOREIGN KEY ("custom_field_group_id") REFERENCES "CustomFieldGroup" ("custom_field_group_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomField" ADD CONSTRAINT "CustomField_html_widget_id"
  FOREIGN KEY ("html_widget_id") REFERENCES "HTMLWidget" ("html_widget_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldIntegerValue" ADD CONSTRAINT "CustomFieldIntegerValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldIntegerValue" ADD CONSTRAINT "CustomFieldIntegerValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldDecimalValue" ADD CONSTRAINT "CustomFieldDecimalValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldDecimalValue" ADD CONSTRAINT "CustomFieldDecimalValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldDateValue" ADD CONSTRAINT "CustomFieldDateValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldDateValue" ADD CONSTRAINT "CustomFieldDateValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldDateTimeValue" ADD CONSTRAINT "CustomFieldDateTimeValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldDateTimeValue" ADD CONSTRAINT "CustomFieldDateTimeValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldTextValue" ADD CONSTRAINT "CustomFieldTextValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldTextValue" ADD CONSTRAINT "CustomFieldTextValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldFileValue" ADD CONSTRAINT "CustomFieldFileValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldFileValue" ADD CONSTRAINT "CustomFieldFileValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldSelectOption" ADD CONSTRAINT "CustomFieldSelectOption_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldSingleSelectValue" ADD CONSTRAINT "CustomFieldSingleSelectValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldSingleSelectValue" ADD CONSTRAINT "CustomFieldSingleSelectValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldSingleSelectValue" ADD CONSTRAINT "CustomFieldSingleSelectValue_custom_field_select_option_id"
  FOREIGN KEY ("custom_field_select_option_id") REFERENCES "CustomFieldSelectOption" ("custom_field_select_option_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldMultiSelectValue" ADD CONSTRAINT "CustomFieldMultiSelectValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldMultiSelectValue" ADD CONSTRAINT "CustomFieldMultiSelectValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldMultiSelectValue" ADD CONSTRAINT "CustomFieldMultiSelectValue_custom_field_select_option_id"
  FOREIGN KEY ("custom_field_select_option_id") REFERENCES "CustomFieldSelectOption" ("custom_field_select_option_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_contact_history_type_id"
  FOREIGN KEY ("contact_history_type_id") REFERENCES "ContactHistoryType" ("contact_history_type_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_email_address_id"
  FOREIGN KEY ("email_address_id") REFERENCES "EmailAddress" ("email_address_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_website_id"
  FOREIGN KEY ("website_id") REFERENCES "Website" ("website_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_address_id"
  FOREIGN KEY ("address_id") REFERENCES "Address" ("address_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_phone_number_id"
  FOREIGN KEY ("phone_number_id") REFERENCES "PhoneNumber" ("phone_number_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_other_contact_id"
  FOREIGN KEY ("other_contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Email" ADD CONSTRAINT "Email_from_contact_id"
  FOREIGN KEY ("from_contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Email" ADD CONSTRAINT "Email_from_user_id"
  FOREIGN KEY ("from_user_id") REFERENCES "User" ("user_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Email" ADD CONSTRAINT "Email_donation_id"
  FOREIGN KEY ("donation_id") REFERENCES "Donation" ("donation_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Email" ADD CONSTRAINT "Email_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ContactEmail" ADD CONSTRAINT "ContactEmail_email_id"
  FOREIGN KEY ("email_id") REFERENCES "Email" ("email_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactEmail" ADD CONSTRAINT "ContactEmail_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactNote" ADD CONSTRAINT "ContactNote_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactNote" ADD CONSTRAINT "ContactNote_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ContactNote" ADD CONSTRAINT "ContactNote_contact_note_type_id"
  FOREIGN KEY ("contact_note_type_id") REFERENCES "ContactNoteType" ("contact_note_type_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ContactNoteType" ADD CONSTRAINT "ContactNoteType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactTag" ADD CONSTRAINT "ContactTag_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactTag" ADD CONSTRAINT "ContactTag_tag_id"
  FOREIGN KEY ("tag_id") REFERENCES "Tag" ("tag_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Tag" ADD CONSTRAINT "Account_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "EmailList" ADD CONSTRAINT "Tag_tag_id"
  FOREIGN KEY ("tag_id") REFERENCES "Tag" ("tag_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactEmailListOptOut" ADD CONSTRAINT "Tag_tag_id"
  FOREIGN KEY ("tag_id") REFERENCES "Tag" ("tag_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactEmailListOptOut" ADD CONSTRAINT "Contact_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Activity" ADD CONSTRAINT "Activity_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Activity" ADD CONSTRAINT "Activity_activity_type_id"
  FOREIGN KEY ("activity_type_id") REFERENCES "ActivityType" ("activity_type_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ActivityType" ADD CONSTRAINT "ActivityType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactParticipation" ADD CONSTRAINT "ContactParticipation_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactParticipation" ADD CONSTRAINT "ContactParticipation_activity_id"
  FOREIGN KEY ("activity_id") REFERENCES "Activity" ("activity_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactParticipation" ADD CONSTRAINT "ContactParticipation_participation_type_id"
  FOREIGN KEY ("participation_type_id") REFERENCES "ParticipationType" ("participation_type_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ParticipationType" ADD CONSTRAINT "ParticipationType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Person" ADD CONSTRAINT "Person_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "MessagingProvider" ADD CONSTRAINT "MessagingProvider_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "MessagingProvider" ADD CONSTRAINT "MessagingProvider_messaging_provider_type_id"
  FOREIGN KEY ("messaging_provider_type_id") REFERENCES "MessagingProviderType" ("messaging_provider_type_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "PersonRelationship" ADD CONSTRAINT "PersonRelationship_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Person" ("person_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "PersonRelationship" ADD CONSTRAINT "PersonRelationship_relationship_type_id"
  FOREIGN KEY ("relationship_type_id") REFERENCES "RelationshipType" ("relationship_type_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "PersonRelationship" ADD CONSTRAINT "PersonRelationship_other_person_id"
  FOREIGN KEY ("other_person_id") REFERENCES "Person" ("person_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "RelationshipType" ADD CONSTRAINT "RelationshipType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Household" ADD CONSTRAINT "Household_household_id"
  FOREIGN KEY ("household_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "HouseholdMember" ADD CONSTRAINT "HouseholdMember_household_id"
  FOREIGN KEY ("household_id") REFERENCES "Household" ("household_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "HouseholdMember" ADD CONSTRAINT "HouseholdMember_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Person" ("person_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Organization" ADD CONSTRAINT "Organization_organization_id"
  FOREIGN KEY ("organization_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "OrganizationMember" ADD CONSTRAINT "OrganizationMember_organization_id"
  FOREIGN KEY ("organization_id") REFERENCES "Organization" ("organization_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "OrganizationMember" ADD CONSTRAINT "OrganizationMember_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Person" ("person_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "EmailAddress" ADD CONSTRAINT "EmailAddress_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Address" ADD CONSTRAINT "Address_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Address" ADD CONSTRAINT "Address_address_type_id"
  FOREIGN KEY ("address_type_id") REFERENCES "AddressType" ("address_type_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "AddressType" ADD CONSTRAINT "AddressType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PhoneNumber" ADD CONSTRAINT "PhoneNumber_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PhoneNumber" ADD CONSTRAINT "PhoneNumber_phone_number_type_id"
  FOREIGN KEY ("phone_number_type_id") REFERENCES "PhoneNumberType" ("phone_number_type_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PhoneNumberType" ADD CONSTRAINT "PhoneNumberType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Website" ADD CONSTRAINT "Website_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Donation" ADD CONSTRAINT "Donation_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Donation" ADD CONSTRAINT "Donation_donation_source_id"
  FOREIGN KEY ("donation_source_id") REFERENCES "DonationSource" ("donation_source_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "DonationSource" ADD CONSTRAINT "DonationSource_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Donation" ADD CONSTRAINT "Donation_donation_campaign_id"
  FOREIGN KEY ("donation_campaign_id") REFERENCES "DonationCampaign" ("donation_campaign_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Donation" ADD CONSTRAINT "Donation_payment_type_id"
  FOREIGN KEY ("payment_type_id") REFERENCES "PaymentType" ("payment_type_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "DonationCampaign" ADD CONSTRAINT "DonationCampaign_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PaymentType" ADD CONSTRAINT "PaymentType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "SavedSearch" ADD CONSTRAINT "SavedSearch_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

INSERT INTO "Version" (version) VALUES (1);
