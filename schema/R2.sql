SET CLIENT_MIN_MESSAGES = ERROR;

DROP DATABASE IF EXISTS "R2";

CREATE DATABASE "R2"
       ENCODING = 'UTF8';

\connect "R2"

SET CLIENT_MIN_MESSAGES = ERROR;

CREATE DOMAIN email_address AS VARCHAR(255)
       CONSTRAINT valid_email_address CHECK ( VALUE ~ E'^.+@.+(?:\\..+)+' );

CREATE TABLE "User" (
       -- will be the same as a person_id
       user_id            INT8               PRIMARY KEY,
       username           VARCHAR(255)       UNIQUE NOT NULL,
       -- SHA512 in Base64 encoding
       password           VARCHAR(86)        NOT NULL,
       timezone           VARCHAR(50)        NOT NULL DEFAULT 'UTC',
       date_format        VARCHAR(12)        NOT NULL DEFAULT 'MM-dd-YYYY',
       time_format        VARCHAR(12)        NOT NULL DEFAULT 'hh:mm a',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       is_system_admin    BOOLEAN            DEFAULT FALSE,
       CONSTRAINT valid_username CHECK ( username != '' ),
       CONSTRAINT valid_password CHECK ( password != '' )
);

CREATE TABLE "Account" (
       account_id         SERIAL             PRIMARY KEY,
       name               VARCHAR(255)       UNIQUE  NOT NULL,
       domain_id          INTEGER            NOT NULL,
       default_timezone   VARCHAR(50)        NOT NULL DEFAULT 'UTC',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "Role" (
       role_id            SERIAL             PRIMARY KEY,
       name               VARCHAR(30)        UNIQUE NOT NULL
);

CREATE TABLE "AccountUserRole" (
       account_id         INTEGER            NOT NULL,
       user_id            INT8               NOT NULL,
       role_id            INTEGER            NOT NULL,
       PRIMARY KEY ( account_id, user_id )
);

CREATE TABLE "Domain" (
       domain_id          SERIAL             PRIMARY KEY,
       web_hostname       VARCHAR(255)       UNIQUE NOT NULL,
       email_hostname     VARCHAR(255)       UNIQUE NOT NULL,
       requires_ssl       BOOLEAN            DEFAULT FALSE,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT valid_web_hostname CHECK ( web_hostname != '' ),
       CONSTRAINT valid_email_hostname CHECK ( email_hostname != '' )
);

CREATE TABLE "File" (
       file_id            SERIAL8            PRIMARY KEY,
       mime_type          VARCHAR(100)       NOT NULL,
       filename           TEXT               NOT NULL,
       -- This lets us look up a variation of a file (notably a
       -- resized image) by generating a file name from some other
       -- File row, rather than having to know its file_id. For most
       -- files, this will be the same as its file_id, but for resized
       -- images it will be something like 1234-100x100
       unique_name        TEXT               UNIQUE NULL,
       contents           BYTEA              NOT NULL,
       account_id         INT8               NOT NULL
);

CREATE TYPE contact_type AS ENUM ( 'Person', 'Organization', 'Household' );

CREATE DOMAIN uri AS VARCHAR(255)
       CONSTRAINT valid_uri CHECK ( VALUE ~ E'^https?://[\\w-_]+(\.[\\w-_]+)*\\.\\w{2,3}' );

CREATE TABLE "Contact" (
       contact_id         SERIAL8            PRIMARY KEY,
       contact_type       contact_type       NOT NULL,
       allows_email       BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_mail        BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_phone       BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_trade       BOOLEAN            NOT NULL DEFAULT FALSE,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       image_file_id      INT8               NULL,
       -- an identifier from another app, probably created via an
       -- initial import from something else
       external_id        VARCHAR(255)       UNIQUE NULL,
       account_id         INTEGER            NOT NULL
);

CREATE TABLE "Group" (
       group_id           SERIAL             PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       is_mailing_list    BOOLEAN            NOT NULL DEFAULT FALSE,
       applies_to_person  BOOLEAN            NOT NULL DEFAULT FALSE,
       applies_to_household     BOOLEAN      NOT NULL DEFAULT FALSE,
       applies_to_organization  BOOLEAN      NOT NULL DEFAULT FALSE,
       account_id         INT8               NOT NULL
);

CREATE TABLE "GroupMember" (
       group_id           INT8               NOT NULL,
       contact_id         INT8               NOT NULL,
       PRIMARY KEY ( group_id, contact_id )
);

CREATE DOMAIN pos_int AS INTEGER
       CONSTRAINT is_positive CHECK ( VALUE > 0 );

CREATE TABLE "CustomFieldGroup" (
       custom_field_group_id          SERIAL8      PRIMARY KEY,
       name                           VARCHAR(255) NOT NULL,
       display_order                  pos_int      NOT NULL,
       applies_to_person              BOOLEAN      NOT NULL DEFAULT TRUE,
       applies_to_household           BOOLEAN      NOT NULL DEFAULT FALSE,
       applies_to_organization        BOOLEAN      NOT NULL DEFAULT FALSE,
       account_id                     INT8         NOT NULL
-- unique constraints are not deferrable
--       CONSTRAINT account_id_display_order_ck
--                  UNIQUE ( account_id, display_order )
--                  INITIALLY DEFERRED
);

CREATE TABLE "CustomField" (
       custom_field_id          SERIAL8      PRIMARY KEY,
       label                    VARCHAR(255) NOT NULL,
       description              TEXT         NOT NULL DEFAULT '',
       custom_field_type_id     INTEGER      NOT NULL,
       account_id               INT8         NOT NULL,
       is_required              BOOLEAN      DEFAULT FALSE,
       html_widget_type_id      INTEGER      NOT NULL,
       display_order            pos_int      NOT NULL,
       custom_field_group_id  INT8   NOT NULL
--       CONSTRAINT custom_field_group_id_display_order_ck
--                  UNIQUE ( custom_field_group_id, display_order )
--                  INITIALLY DEFERRED
);

CREATE TABLE "HTMLWidgetType" (
       html_widget_type_id      SERIAL       PRIMARY KEY,
       name                     VARCHAR(255) NOT NULL,
       description              VARCHAR(255) NOT NULL
);

CREATE TABLE "CustomFieldType" (
       custom_field_type_id     SERIAL8      PRIMARY KEY,
       -- something like Integer, Float, Select, etc
       name                     VARCHAR(255) NOT NULL
);

CREATE TABLE "CustomFieldIntegerValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    INT8         NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE TABLE "CustomFieldFloatValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    FLOAT8       NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE TABLE "CustomFieldDateValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    DATE         NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE TABLE "CustomFieldDateTimeValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    TIMESTAMP WITHOUT TIME ZONE  NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE TABLE "CustomFieldTextValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    TEXT         NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE TABLE "CustomFieldBinaryValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    BYTEA        NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);

CREATE TABLE "CustomFieldSelectOption" (
       custom_field_select_option_id INT8    PRIMARY KEY,
       custom_field_id          INT8         NOT NULL,
       display_order            pos_int      NOT NULL,
       value                    VARCHAR(255) NOT NULL
--       CONSTRAINT custom_field_id_display_order_ck
--                  UNIQUE ( custom_field_id, display_order )
--                  INITIALLY DEFERRED
);

CREATE TABLE "CustomFieldSingleSelectValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       custom_field_select_option_id  INT8   NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id )
);
       
CREATE TABLE "CustomFieldMultiSelectValue" (
       custom_field_id          INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       custom_field_select_option_id  INT8   NOT NULL,
       PRIMARY KEY ( custom_field_id, contact_id, custom_field_select_option_id )
);

CREATE TABLE "ContactNote" (
       contact_note_id    SERIAL8            PRIMARY KEY,
       contact_id         INT8               NOT NULL,
       contact_note_type_id  INT             NOT NULL,
       user_id            INT8               NOT NULL,
       note               TEXT               NOT NULL,
       note_datetime      TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "ContactNoteType" (
       contact_note_type_id  SERIAL          PRIMARY KEY,
       description        VARCHAR(255)       NOT NULL,
       is_system_defined  BOOLEAN            NOT NULL DEFAULT FALSE,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_description CHECK ( description != '' ),
       CONSTRAINT description_account_id_ck UNIQUE ( description, account_id )
);

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

CREATE TABLE "ContactHistoryType" (
       contact_history_type_id  SERIAL       PRIMARY KEY,
       system_name        VARCHAR(255)       UNIQUE  NOT NULL,
       description        VARCHAR(255)       NOT NULL,
       sort_order         pos_int            NOT NULL,
       CONSTRAINT valid_description CHECK ( description != '' )
);

CREATE TABLE "ContactTag" (
       contact_id       INT8            NOT NULL,
       tag_id           INT8            NOT NULL
);

CREATE DOMAIN tag AS VARCHAR(255)
       CONSTRAINT valid_tag CHECK ( VALUE ~ E'^\\S+$' );

CREATE TABLE "Tag" (
       tag_id           SERIAL8         PRIMARY KEY,
       tag              tag             NOT NULL,
       account_id       INT8            NOT NULL,
       CONSTRAINT tag_account_id_ck UNIQUE ( tag, account_id )
);

CREATE TYPE gender AS ENUM ( 'male', 'female', 'transgender' );

CREATE TABLE "Person" (
       person_id          INT8               PRIMARY KEY,
       salutation         VARCHAR(20)        NOT NULL DEFAULT '',
       first_name         VARCHAR(255)       NOT NULL DEFAULT '',
       middle_name        VARCHAR(255)       NOT NULL DEFAULT '',
       last_name          VARCHAR(255)       NOT NULL DEFAULT '',
       suffix             VARCHAR(20)        NOT NULL DEFAULT '',
       birth_date         DATE               NULL,
       gender             gender             NULL
);

CREATE TABLE "PersonMessagingProvider" (
       person_id          INT8               NOT NULL,
       messaging_provider_id  INT8           NOT NULL,
       screen_name        VARCHAR(200)       NOT NULL,
       PRIMARY KEY ( person_id, messaging_provider_id )
);

CREATE TABLE "MessagingProvider" (
       messaging_provider_id  SERIAL8        PRIMARY KEY,
       name                   VARCHAR(255)   UNIQUE  NOT NULL,
       add_uri_template       VARCHAR(255)   NOT NULL DEFAULT '',
       chat_uri_template      VARCHAR(255)   NOT NULL DEFAULT '',
       call_uri_template      VARCHAR(255)   NOT NULL DEFAULT '',
       video_uri_template     VARCHAR(255)   NOT NULL DEFAULT '',
       status_uri_template    VARCHAR(255)   NOT NULL DEFAULT ''
);

CREATE TABLE "AccountMessagingProvider" (
       account_id         INT8               NOT NULL,
       messaging_provider_id  INT8           NOT NULL,
       PRIMARY KEY (account_id, messaging_provider_id)
);

CREATE TABLE "Household" (
       household_id       SERIAL8            PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "HouseholdMember" (
       household_id       INT8               NOT NULL,
       person_id          INT8               NOT NULL,
       position           VARCHAR(255)       NOT NULL DEFAULT '',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY ( household_id, person_id )
);

CREATE TABLE "Organization" (
       organization_id    INT8               PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "OrganizationMember" (
       organization_id    INT8               NOT NULL,
       person_id          INT8               NOT NULL,
       position           VARCHAR(255)       NOT NULL DEFAULT '',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY ( organization_id, person_id )
);

-- It's tepmting to make the email address unique, but contacts could
-- share an email address, especially in the case of a household and a
-- person in the household, or an organization.
CREATE TABLE "EmailAddress" (
       email_address_id   SERIAL8            PRIMARY KEY,
       contact_id         INT8               NOT NULL,
       email_address      email_address      NOT NULL,
       is_preferred       BOOLEAN            DEFAULT FALSE,
       note               TEXT               NOT NULL DEFAULT ''
);

CREATE TABLE "Website" (
       website_id         SERIAL8            PRIMARY KEY,
       contact_id         INT8               NOT NULL,
       label              VARCHAR(50)        NOT NULL DEFAULT 'Website',
       uri                uri                NOT NULL,
       note               TEXT               NOT NULL DEFAULT ''
);

-- Consider a trigger to enforce one primary address per contact?
CREATE TABLE "Address" (
       address_id         SERIAL8            PRIMARY KEY,
       contact_id         INTEGER            NOT NULL,
       address_type_id    INTEGER            NOT NULL,
       street_1           VARCHAR(255)       NOT NULL DEFAULT '',
       street_2           VARCHAR(255)       NOT NULL DEFAULT '',
       city               VARCHAR(255)       NOT NULL DEFAULT '',
       region             VARCHAR(255)       NOT NULL DEFAULT '',
       postal_code        VARCHAR(20)        NOT NULL DEFAULT '',
       iso_code           CHAR(2)            NOT NULL,
       latitude           FLOAT              NULL,
       longitude          FLOAT              NULL,
       -- The address as returned by a geocoding service like Google
       -- Maps.
       canonical_address  TEXT               NOT NULL DEFAULT '',
       is_preferred       BOOLEAN            DEFAULT FALSE,
       note               TEXT               NOT NULL DEFAULT '',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "AccountCountry" (
       account_id         INT8               NOT NULL,
       iso_code           CHAR(2)            NOT NULL,
       is_default         BOOLEAN            NOT NULL DEFAULT FALSE,
       PRIMARY KEY (account_id, iso_code)
);

CREATE TABLE "Country" (
       iso_code           CHAR(2)            PRIMARY KEY,
       name               VARCHAR(255)       UNIQUE  NOT NULL,
       CONSTRAINT valid_iso_code CHECK ( iso_code != '' ),
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "TimeZone" (
       olson_name         VARCHAR(255)       PRIMARY KEY,
       iso_code           CHAR(2)            NOT NULL,
       description        VARCHAR(100)       NOT NULL,
       display_order      INTEGER            NOT NULL,
       CONSTRAINT valid_olson_name CHECK ( olson_name != '' ),
       CONSTRAINT valid_iso_code CHECK ( iso_code != '' ),
       CONSTRAINT valid_description CHECK ( description != '' ),
       CONSTRAINT valid_display_order CHECK ( display_order > 0 )
-- unique constraints are not deferrable
--       CONSTRAINT account_id_display_order_ck
--                  UNIQUE ( iso_code, display_order )
--                  INITIALLY DEFERRED
);

CREATE TABLE "AddressType" (
       address_type_id    SERIAL8            PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       applies_to_person  BOOLEAN            NOT NULL DEFAULT FALSE,
       applies_to_household     BOOLEAN      NOT NULL DEFAULT FALSE,
       applies_to_organization  BOOLEAN      NOT NULL DEFAULT FALSE,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

-- Consider a trigger to enforce one primary phone number per contact?
CREATE TABLE "PhoneNumber" (
       phone_number_id    SERIAL8            PRIMARY KEY,
       contact_id         INTEGER            NOT NULL,
       phone_number_type_id   INT8           NOT NULL,
       phone_number       VARCHAR(30)        DEFAULT '',
       is_preferred       BOOLEAN            DEFAULT FALSE,
       note               TEXT               NOT NULL DEFAULT '',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE "PhoneNumberType" (
       phone_number_type_id  SERIAL8         PRIMARY KEY,
       name                  VARCHAR(255)    NOT NULL,
       applies_to_person  BOOLEAN            NOT NULL DEFAULT FALSE,
       applies_to_household     BOOLEAN      NOT NULL DEFAULT FALSE,
       applies_to_organization  BOOLEAN      NOT NULL DEFAULT FALSE,
       account_id            INT8            NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "Donation" (
       donation_id        SERIAL8            PRIMARY KEY,
       amount             NUMERIC(13,2)      NOT NULL,
       donation_date      DATE               NOT NULL,
       contact_id         INT8               NOT NULL,
       value_for_donor    NUMERIC(13,2)      NOT NULL DEFAULT 0.00,
       transaction_cost   NUMERIC(13,2)      NOT NULL DEFAULT 0.00,
       is_recurring       BOOL               NOT NULL DEFAULT FALSE,
       receipt_sent       BOOL               NOT NULL DEFAULT FALSE,
       donation_source_id INT8               NOT NULL,
       donation_target_id INT8               NOT NULL,
       payment_type_id    INT8               NOT NULL,
       note               TEXT               NOT NULL DEFAULT '',
       CONSTRAINT valid_amount CHECK ( amount > 0.00 ),
       CONSTRAINT valid_value_for_donor CHECK ( value_for_donor >= 0.00 ),
       CONSTRAINT valid_transaction_cost CHECK ( transaction_cost >= 0.00 )
);

CREATE TABLE "DonationSource" (
       donation_source_id SERIAL8            PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "DonationTarget" (
       donation_target_id SERIAL8            PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "PaymentType" (
       payment_type_id    SERIAL8            PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "Session" (
       id                 CHAR(72)           PRIMARY KEY,
       session_data       BYTEA              NOT NULL,
       expires            INT                NOT NULL
);


ALTER TABLE "User" ADD CONSTRAINT "User_user_id"
  FOREIGN KEY ("user_id") REFERENCES "Person" ("person_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Account" ADD CONSTRAINT "Account_domain_id"
  FOREIGN KEY ("domain_id") REFERENCES "Domain" ("domain_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "AccountUserRole" ADD CONSTRAINT "AccountUserRole_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "AccountUserRole" ADD CONSTRAINT "AccountUserRole_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "AccountUserRole" ADD CONSTRAINT "AccountUserRole_role_id"
  FOREIGN KEY ("role_id") REFERENCES "Role" ("role_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "AccountCountry" ADD CONSTRAINT "AccountCountry_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "AccountCountry" ADD CONSTRAINT "AccountCountry_iso_code"
  FOREIGN KEY ("iso_code") REFERENCES "Country" ("iso_code")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "TimeZone" ADD CONSTRAINT "TimeZone_iso_code"
  FOREIGN KEY ("iso_code") REFERENCES "Country" ("iso_code")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "File" ADD CONSTRAINT "File_accont_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Contact" ADD CONSTRAINT "Contact_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Contact" ADD CONSTRAINT "Contact_image_file_id"
  FOREIGN KEY ("image_file_id") REFERENCES "File" ("file_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Group" ADD CONSTRAINT "Group_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "GroupMember" ADD CONSTRAINT "GroupMember_group_id"
  FOREIGN KEY ("group_id") REFERENCES "Group" ("group_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "GroupMember" ADD CONSTRAINT "GroupMember_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldGroup" ADD CONSTRAINT "CustomFieldGroup_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomField" ADD CONSTRAINT "CustomField_custom_field_group_id"
  FOREIGN KEY ("custom_field_group_id") REFERENCES "CustomFieldGroup" ("custom_field_group_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomField" ADD CONSTRAINT "CustomField_html_widget_type_id"
  FOREIGN KEY ("html_widget_type_id") REFERENCES "HTMLWidgetType" ("html_widget_type_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomField" ADD CONSTRAINT "CustomField_custom_field_type_id"
  FOREIGN KEY ("custom_field_type_id") REFERENCES "CustomFieldType" ("custom_field_type_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldIntegerValue" ADD CONSTRAINT "CustomFieldIntegerValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldIntegerValue" ADD CONSTRAINT "CustomFieldIntegerValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldFloatValue" ADD CONSTRAINT "CustomFieldFloatValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldFloatValue" ADD CONSTRAINT "CustomFieldFloatValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldDateValue" ADD CONSTRAINT "CustomFieldDateValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldDateValue" ADD CONSTRAINT "CustomFieldDateValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldTextValue" ADD CONSTRAINT "CustomFieldTextValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldTextValue" ADD CONSTRAINT "CustomFieldTextValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldBinaryValue" ADD CONSTRAINT "CustomFieldBinaryValue_custom_field_id"
  FOREIGN KEY ("custom_field_id") REFERENCES "CustomField" ("custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "CustomFieldBinaryValue" ADD CONSTRAINT "CustomFieldBinaryValue_contact_id"
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

ALTER TABLE "Person" ADD CONSTRAINT "Person_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PersonMessagingProvider" ADD CONSTRAINT "PersonMessagingProvider_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Person" ("person_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "PersonMessagingProvider" ADD CONSTRAINT "PersonMessagingProvider_messaging_provider_id"
  FOREIGN KEY ("messaging_provider_id") REFERENCES "MessagingProvider" ("messaging_provider_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "AccountMessagingProvider" ADD CONSTRAINT "AccountMessagingProvider_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "AccountMessagingProvider" ADD CONSTRAINT "AccountMessagingProvider_messaging_provider_id"
  FOREIGN KEY ("messaging_provider_id") REFERENCES "MessagingProvider" ("messaging_provider_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

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

ALTER TABLE "Address" ADD CONSTRAINT "Address_iso_code"
  FOREIGN KEY ("iso_code") REFERENCES "Country" ("iso_code")
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

ALTER TABLE "Donation" ADD CONSTRAINT "Donation_donation_target_id"
  FOREIGN KEY ("donation_target_id") REFERENCES "DonationTarget" ("donation_target_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "DonationTarget" ADD CONSTRAINT "DonationTarget_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Donation" ADD CONSTRAINT "Donation_payment_type_id"
  FOREIGN KEY ("payment_type_id") REFERENCES "PaymentType" ("payment_type_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "PaymentType" ADD CONSTRAINT "PaymentType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;
