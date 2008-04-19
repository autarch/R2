SET CLIENT_MIN_MESSAGES = ERROR;

DROP DATABASE IF EXISTS "R2";

CREATE DATABASE "R2"
       ENCODING = 'UTF8';

\connect "R2"

SET CLIENT_MIN_MESSAGES = ERROR;

CREATE TABLE "User" (
       -- will be the same as a person_id
       user_id            INT8               PRIMARY KEY,
       -- SHA512 in Base64 encoding
       password           VARCHAR(86)        NOT NULL,
       timezone           VARCHAR(50)        NOT NULL DEFAULT 'UTC',
       date_format        VARCHAR(12)        NOT NULL DEFAULT '%m-%d-%Y',
       time_format        VARCHAR(12)        NOT NULL DEFAULT '%I:%M %P',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       is_system_admin    BOOLEAN            DEFAULT FALSE,
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
       file_name          TEXT               NOT NULL,
       file_contents      BYTEA              NOT NULL
);

CREATE TYPE contact_type AS ENUM ( 'Person', 'Organization', 'Household' );

CREATE DOMAIN email_address AS VARCHAR(255)
       CONSTRAINT valid_email_address CHECK ( VALUE ~ E'^.+@.+(?:\\..+)+' );

CREATE DOMAIN uri AS VARCHAR(255)
       CONSTRAINT valid_uri CHECK ( VALUE ~ E'^https?://[\w-]+(\.[\w-]+)*\.\w{2,3}' );

CREATE TABLE "Contact" (
       contact_id         SERIAL8            PRIMARY KEY,
       contact_type       contact_type       NOT NULL,
       allows_email       BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_mail        BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_phone       BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_trade       BOOLEAN            NOT NULL DEFAULT FALSE,
       email_address      email_address      NULL,
       website            uri                NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       image_file_id      INT8               NULL,
       -- an identifier from another app, probably created via an
       -- initial import from something else
       external_id        VARCHAR(255)       UNIQUE NULL,
       account_id         INTEGER            NOT NULL,
       CONSTRAINT email_address_account_id_ck UNIQUE ( email_address, account_id )
);

CREATE DOMAIN pos_int AS INTEGER
       CONSTRAINT is_positive CHECK ( VALUE > 0 );

CREATE TYPE contact_type_or_all AS ENUM ( 'All', 'Person', 'Organization', 'Household' );

CREATE TABLE "ContactCustomFieldGroup" (
       contact_custom_field_group_id    SERIAL8      PRIMARY KEY,
       name                           VARCHAR(255) NOT NULL,
       description                    TEXT         NULL,
       display_order                  pos_int      NOT NULL,
       applies_to                     contact_type_or_all  NOT NULL  DEFAULT 'Person',
       account_id                     INT8         NOT NULL
-- unique constraints are not deferrable
--       CONSTRAINT account_id_display_order_ck
--                  UNIQUE ( account_id, display_order )
--                  INITIALLY DEFERRED
);

CREATE TABLE "ContactCustomField" (
       contact_custom_field_id  SERIAL8      PRIMARY KEY,
       label                    VARCHAR(255) NOT NULL,
       description              TEXT         NULL,
       custom_field_type_id     INTEGER      NOT NULL,
       account_id               INT8         NOT NULL,
       is_required              BOOLEAN      DEFAULT FALSE,
       html_widget_type_id      INTEGER      NOT NULL,
       display_order            pos_int      NOT NULL,
       contact_custom_field_group_id  INT8   NOT NULL
--       CONSTRAINT contact_custom_field_group_id_display_order_ck
--                  UNIQUE ( contact_custom_field_group_id, display_order )
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

CREATE TABLE "ContactCustomFieldIntegerValue" (
       contact_custom_field_id  INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    INT8         NOT NULL,
       PRIMARY KEY ( contact_custom_field_id, contact_id )
);

CREATE TABLE "ContactCustomFieldFloatValue" (
       contact_custom_field_id  INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    FLOAT8       NOT NULL,
       PRIMARY KEY ( contact_custom_field_id, contact_id )
);

CREATE TABLE "ContactCustomFieldDateValue" (
       contact_custom_field_id  INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    DATE         NOT NULL,
       PRIMARY KEY ( contact_custom_field_id, contact_id )
);

CREATE TABLE "ContactCustomFieldDateTimeValue" (
       contact_custom_field_id  INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    TIMESTAMP WITHOUT TIME ZONE  NOT NULL,
       PRIMARY KEY ( contact_custom_field_id, contact_id )
);

CREATE TABLE "ContactCustomFieldTextValue" (
       contact_custom_field_id  INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    TEXT         NOT NULL,
       PRIMARY KEY ( contact_custom_field_id, contact_id )
);

CREATE TABLE "ContactCustomFieldBinaryValue" (
       contact_custom_field_id  INT8         NOT NULL,
       contact_id               INT8         NOT NULL,
       value                    BYTEA        NOT NULL,
       PRIMARY KEY ( contact_custom_field_id, contact_id )
);

CREATE TABLE "ContactCustomFieldSelectOption" (
       contact_custom_field_select_option_id INT8 PRIMARY KEY,
       contact_custom_field_id  INT8         NOT NULL,
       display_order            pos_int      NOT NULL,
       value                    VARCHAR(255) NOT NULL
--       CONSTRAINT contact_custom_field_id_display_order_ck
--                  UNIQUE ( contact_custom_field_id, display_order )
--                  INITIALLY DEFERRED
);

CREATE TABLE "ContactCustomFieldSingleSelectValue" (
       contact_custom_field_id    INT8         NOT NULL,
       contact_id                 INT8         NOT NULL,
       contact_custom_field_select_option_id  INT8  NOT NULL,
       PRIMARY KEY ( contact_custom_field_id, contact_id )
);
       
CREATE TABLE "ContactCustomFieldMultiSelectValue" (
       contact_custom_field_id    INT8         NOT NULL,
       contact_id                 INT8         NOT NULL,
       contact_custom_field_select_option_id  INT8  NOT NULL,
       PRIMARY KEY ( contact_custom_field_id, contact_id, contact_custom_field_select_option_id )
);

CREATE TABLE "ContactNote" (
       contact_note_id    SERIAL8            PRIMARY KEY,
       contact_id         INT8               NOT NULL,
       notes              TEXT               NOT NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       user_id            INT8               NOT NULL
);

CREATE TABLE "ContactHistory" (
       contact_history_id SERIAL8            PRIMARY KEY,
       contact_id         INT8               NOT NULL,
       contact_history_type_id  INT          NOT NULL,
       user_id            INT8               NOT NULL,
       address_id         INT8               NULL,
       phone_number_id    INT8               NULL,
       notes              TEXT               NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       -- something that describes the change to the thing in question
       -- as a data structure, and provides a way to reverse it,
       -- presumably a Storable-created data structure
       reversal_blob      BYTEA              NOT NULL
);

CREATE TABLE "ContactHistoryType" (
       contact_history_type_id  SERIAL         PRIMARY KEY,
       description        VARCHAR(255)       NOT NULL,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_description CHECK ( description != '' )
);

CREATE TABLE "ContactTag" (
       contact_id       INT8            NOT NULL,
       tag_id           INT8            NOT NULL
);

CREATE DOMAIN tag AS VARCHAR(255)
       CONSTRAINT valid_tag CHECK ( VALUE ~ E'^\S+$' );

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
       gender             gender             NULL,
       household_id       INT8               NULL
);

CREATE TABLE "PersonMessaging" (
       person_id          INT8               NOT NULL,
       messaging_provider_id  INT8           NOT NULL,
       screen_name        VARCHAR(200)       NOT NULL,
       PRIMARY KEY ( person_id, messaging_provider_id )
);

CREATE TABLE "MessagingProvider" (
       messaging_provider_id  SERIAL8        PRIMARY KEY,
       name                   VARCHAR(255)   NOT NULL,
       add_uri_template       VARCHAR(255)   NULL,
       chat_uri_template      VARCHAR(255)   NULL,
       call_uri_template      VARCHAR(255)   NULL,
       video_uri_template     VARCHAR(255)   NULL,
       status_uri_template    VARCHAR(255)   NULL,
       account_id             INT8           NOT NULL
);

CREATE TABLE "Household" (
       household_id       SERIAL8            PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "Organization" (
       organization_id    INT8               PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "OrganizationMember" (
       organization_id    INT8               NOT NULL,
       person_id          INT8               NOT NULL,
       position           VARCHAR(255)       NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       PRIMARY KEY ( organization_id, person_id )
);

-- Consider a trigger to enforce one primary address per contact?
CREATE TABLE "Address" (
       address_id         SERIAL8            PRIMARY KEY,
       address_type_id    INTEGER            NOT NULL,
       street_1           VARCHAR(255)       NOT NULL DEFAULT '',
       street_2           VARCHAR(255)       NULL,
       city               VARCHAR(255)       NOT NULL DEFAULT '',
       region             VARCHAR(255)       NOT NULL DEFAULT '',
       postal_code        VARCHAR(20)        NOT NULL DEFAULT '',
       iso_code           CHAR(2)            NOT NULL,
       latitude           FLOAT              NULL,
       longitude          FLOAT              NULL,
       -- The address as returned by a geocoding service like Google
       -- Maps.
       canonical_address  TEXT               NULL,
       is_preferred       BOOLEAN            DEFAULT FALSE,
       notes              TEXT               NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       contact_id         INTEGER            NULL
);

CREATE TABLE "AccountCountry" (
       account_id         INT8               NOT NULL,
       iso_code           CHAR(2)            NOT NULL,
       PRIMARY KEY (account_id, iso_code)
);

CREATE TABLE "Country" (
       iso_code           CHAR(2)            PRIMARY KEY,
       name               VARCHAR(255)       UNIQUE  NOT NULL,
       CONSTRAINT valid_iso_code CHECK ( iso_code != '' ),
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "AddressType" (
       address_type_id    SERIAL8            PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

-- Consider a trigger to enforce one primary phone number per contact?
CREATE TABLE "PhoneNumber" (
       phone_number_id    SERIAL8            PRIMARY KEY,
       phone_number_type_id   INT8           NOT NULL,
       phone_number       VARCHAR(30)        DEFAULT '',
       is_preferred       BOOLEAN            DEFAULT FALSE,
       notes              TEXT               NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       contact_id         INTEGER            NULL
);

CREATE TABLE "PhoneNumberType" (
       phone_number_type_id  SERIAL8         PRIMARY KEY,
       name                  VARCHAR(255)    NOT NULL,
       account_id            INT8            NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "Donation" (
       donation_id        SERIAL8            PRIMARY KEY,
       amount             NUMERIC(2)         NOT NULL,
       donation_date      DATE               NOT NULL,
       contact_id         INT8               NOT NULL,
       fund_id            INT8               NOT NULL,
       notes              TEXT               NULL,
       CONSTRAINT valid_amount CHECK ( amount > 0.0 )
);

CREATE TABLE "Fund" (
       fund_id            SERIAL8            PRIMARY KEY,
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

ALTER TABLE "Contact" ADD CONSTRAINT "Contact_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Contact" ADD CONSTRAINT "Contact_image_file_id"
  FOREIGN KEY ("image_file_id") REFERENCES "File" ("file_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldGroup" ADD CONSTRAINT "ContactCustomFieldGroup_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomField" ADD CONSTRAINT "ContactCustomField_contact_custom_field_group_id"
  FOREIGN KEY ("contact_custom_field_group_id") REFERENCES "ContactCustomFieldGroup" ("contact_custom_field_group_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomField" ADD CONSTRAINT "ContactCustomField_html_widget_type_id"
  FOREIGN KEY ("html_widget_type_id") REFERENCES "HTMLWidgetType" ("html_widget_type_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomField" ADD CONSTRAINT "ContactCustomField_custom_field_type_id"
  FOREIGN KEY ("custom_field_type_id") REFERENCES "CustomFieldType" ("custom_field_type_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldIntegerValue" ADD CONSTRAINT "ContactCustomFieldIntegerValue_contact_custom_field_id"
  FOREIGN KEY ("contact_custom_field_id") REFERENCES "ContactCustomField" ("contact_custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldIntegerValue" ADD CONSTRAINT "ContactCustomFieldIntegerValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldFloatValue" ADD CONSTRAINT "ContactCustomFieldFloatValue_contact_custom_field_id"
  FOREIGN KEY ("contact_custom_field_id") REFERENCES "ContactCustomField" ("contact_custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldFloatValue" ADD CONSTRAINT "ContactCustomFieldFloatValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldDateValue" ADD CONSTRAINT "ContactCustomFieldDateValue_contact_custom_field_id"
  FOREIGN KEY ("contact_custom_field_id") REFERENCES "ContactCustomField" ("contact_custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldDateValue" ADD CONSTRAINT "ContactCustomFieldDateValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldTextValue" ADD CONSTRAINT "ContactCustomFieldTextValue_contact_custom_field_id"
  FOREIGN KEY ("contact_custom_field_id") REFERENCES "ContactCustomField" ("contact_custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldTextValue" ADD CONSTRAINT "ContactCustomFieldTextValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldBinaryValue" ADD CONSTRAINT "ContactCustomFieldBinaryValue_contact_custom_field_id"
  FOREIGN KEY ("contact_custom_field_id") REFERENCES "ContactCustomField" ("contact_custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldBinaryValue" ADD CONSTRAINT "ContactCustomFieldBinaryValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldSelectOption" ADD CONSTRAINT "ContactCustomFieldSelectOption_contact_custom_field_id"
  FOREIGN KEY ("contact_custom_field_id") REFERENCES "ContactCustomField" ("contact_custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldSingleSelectValue" ADD CONSTRAINT "ContactCustomFieldSingleSelectValue_contact_custom_field_id"
  FOREIGN KEY ("contact_custom_field_id") REFERENCES "ContactCustomField" ("contact_custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldSingleSelectValue" ADD CONSTRAINT "ContactCustomFieldSingleSelectValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldSingleSelectValue" ADD CONSTRAINT "ContactCustomFieldSingleSelectValue_contact_custom_field_select_option_id"
  FOREIGN KEY ("contact_custom_field_select_option_id") REFERENCES "ContactCustomFieldSelectOption" ("contact_custom_field_select_option_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldMultiSelectValue" ADD CONSTRAINT "ContactCustomFieldMultiSelectValue_contact_custom_field_id"
  FOREIGN KEY ("contact_custom_field_id") REFERENCES "ContactCustomField" ("contact_custom_field_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldMultiSelectValue" ADD CONSTRAINT "ContactCustomFieldMultiSelectValue_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactCustomFieldMultiSelectValue" ADD CONSTRAINT "ContactCustomFieldMultiSelectValue_contact_custom_field_select_option_id"
  FOREIGN KEY ("contact_custom_field_select_option_id") REFERENCES "ContactCustomFieldSelectOption" ("contact_custom_field_select_option_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactNote" ADD CONSTRAINT "ContactNote_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactNote" ADD CONSTRAINT "ContactNote_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_contact_history_type_id"
  FOREIGN KEY ("contact_history_type_id") REFERENCES "ContactHistoryType" ("contact_history_type_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_address_id"
  FOREIGN KEY ("address_id") REFERENCES "Address" ("address_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ContactHistoryType" ADD CONSTRAINT "ContactHistoryType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactHistory" ADD CONSTRAINT "ContactHistory_phone_number_id"
  FOREIGN KEY ("phone_number_id") REFERENCES "PhoneNumber" ("phone_number_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "ContactTag" ADD CONSTRAINT "ContactTag_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "ContactTag" ADD CONSTRAINT "ContactTag_tag_id"
  FOREIGN KEY ("tag_id") REFERENCES "Tag" ("tag_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Person" ADD CONSTRAINT "Person_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Person" ADD CONSTRAINT "Person_household_id"
  FOREIGN KEY ("household_id") REFERENCES "Household" ("household_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "PersonMessaging" ADD CONSTRAINT "PersonMessaging_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Person" ("person_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "PersonMessaging" ADD CONSTRAINT "PersonMessaging_messaging_provider_id"
  FOREIGN KEY ("messaging_provider_id") REFERENCES "MessagingProvider" ("messaging_provider_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "MessagingProvider" ADD CONSTRAINT "MessagingProvider_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Household" ADD CONSTRAINT "Household_household_id"
  FOREIGN KEY ("household_id") REFERENCES "Contact" ("contact_id")
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

ALTER TABLE "Donation" ADD CONSTRAINT "Donation_contact_id"
  FOREIGN KEY ("contact_id") REFERENCES "Contact" ("contact_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Donation" ADD CONSTRAINT "Donation_fund_id"
  FOREIGN KEY ("fund_id") REFERENCES "Fund" ("fund_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Fund" ADD CONSTRAINT "Fund_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;
