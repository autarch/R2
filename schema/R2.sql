SET CLIENT_MIN_MESSAGES = ERROR;

DROP DATABASE IF EXISTS "R2";

CREATE DATABASE "R2"
       ENCODING = 'UTF8';

\connect "R2"

SET CLIENT_MIN_MESSAGES = ERROR;

CREATE DOMAIN email_address AS VARCHAR(255)
       CONSTRAINT valid_email_address CHECK ( VALUE ~ E'^.+@.+(?:\\..+)+' );

CREATE TABLE "User" (
       user_id            SERIAL8            PRIMARY KEY,
       -- SHA512 in Base64 encoding
       password           VARCHAR(86)        NOT NULL,
       timezone           VARCHAR(50)        NOT NULL DEFAULT 'UTC',
       date_format        VARCHAR(12)        NOT NULL DEFAULT '%m/%d/%Y',
       time_format        VARCHAR(12)        NOT NULL DEFAULT '%I:%M %P',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       person_id          INT8               NOT NULL,
       CONSTRAINT valid_password CHECK ( password != '' )
);

CREATE TABLE "Account" (
       account_id         SERIAL             PRIMARY KEY,
       name               VARCHAR(255)       UNIQUE  NOT NULL,
       primary_user_id    INT8               NOT NULL,
       domain_id          INTEGER            NOT NULL,
       default_timezone   VARCHAR(50)        NOT NULL DEFAULT 'UTC',
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT valid_name CHECK ( name != '' )
);

CREATE TABLE "Domain" (
       domain_id          SERIAL             PRIMARY KEY,
       web_hostname       VARCHAR(255)       UNIQUE NOT NULL,
       email_hostname     VARCHAR(255)       UNIQUE NOT NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       CONSTRAINT valid_web_hostname CHECK ( web_hostname != '' ),
       CONSTRAINT valid_email_hostname CHECK ( email_hostname != '' )
);

CREATE TYPE party_type AS ENUM ( 'Person', 'Organiation', 'Household' );

CREATE DOMAIN uri AS VARCHAR(255)
       CONSTRAINT valid_uri CHECK ( VALUE ~ E'^https?://[\w-]+(\.[\w-]+)*\.\w{2,3}' );

CREATE TABLE "Party" (
       party_id           SERIAL8            PRIMARY KEY,
       party_type         party_type         NOT NULL,
       allows_email       BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_mail        BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_phone       BOOLEAN            NOT NULL DEFAULT TRUE,
       allows_trade       BOOLEAN            NOT NULL DEFAULT FALSE,
       email_address      email_address      NULL,
       website            uri                NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       -- an identifier from another app, probably created via an
       -- initial import from something else
       external_id        VARCHAR(255)       UNIQUE NULL,
       account_id         INTEGER            NOT NULL
);

CREATE TABLE "PartyNote" (
       party_note_id      SERIAL8            PRIMARY KEY,
       party_id           INT8               NOT NULL,
       notes              TEXT               NOT NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       user_id            INT8               NOT NULL
);

CREATE TABLE "PartyHistory" (
       party_history_id   SERIAL8            PRIMARY KEY,
       party_id           INT8               NOT NULL,
       party_history_type_id  INT            NOT NULL,
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

CREATE TABLE "PartyHistoryType" (
       party_history_type_id  SERIAL         PRIMARY KEY,
       description        VARCHAR(255)       NOT NULL,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_description CHECK ( description != '' )
);

CREATE TYPE gender AS ENUM ( 'male', 'female', 'transgender' );

CREATE TABLE "Person" (
       person_id          INT8               PRIMARY KEY,
       salutation         VARCHAR(5)         NOT NULL DEFAULT '',
       first_name         VARCHAR(255)       NOT NULL DEFAULT '',
       middle_name        VARCHAR(255)       NOT NULL DEFAULT '',
       last_name          VARCHAR(255)       NOT NULL DEFAULT '',
       suffix             VARCHAR(20)        NOT NULL DEFAULT '',
       birth_date         DATE               NULL,
       gender             gender             NULL,
       household_id       INT8               NULL
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

-- Consider a trigger to enforce one primary address per party?
CREATE TABLE "Address" (
       address_id         SERIAL8            PRIMARY KEY,
       address_type_id    INTEGER            NOT NULL,
       street_1           VARCHAR(255)       NOT NULL DEFAULT '',
       street_2           VARCHAR(255)       NULL,
       city               VARCHAR(255)       NOT NULL DEFAULT '',
       region             VARCHAR(255)       NOT NULL DEFAULT '',
       country_id         INTEGER            NOT NULL,
       latitude           FLOAT              NULL,
       longitude          FLOAT              NULL,
       -- The address as returned by a geocoding service like Google
       -- Maps.
       canonical_address  TEXT               NULL,
       is_primary         BOOLEAN            DEFAULT FALSE,
       notes              TEXT               NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       party_id           INTEGER            NULL
);

CREATE TABLE "AddressType" (
       address_type_id    SERIAL8            PRIMARY KEY,
       name               VARCHAR(255)       NOT NULL,
       account_id         INT8               NOT NULL,
       CONSTRAINT valid_name CHECK ( name != '' )
);

-- Consider a trigger to enforce one primar phone number per party?
CREATE TABLE "PhoneNumber" (
       phone_number_id    SERIAL8            PRIMARY KEY,
       phone_number_type_id   INT8           NOT NULL,
       phone_number       VARCHAR(30)        DEFAULT '',
       is_primary         BOOLEAN            DEFAULT FALSE,
       notes              TEXT               NULL,
       creation_datetime  TIMESTAMP WITHOUT TIME ZONE  NOT NULL DEFAULT CURRENT_TIMESTAMP,
       party_id           INTEGER            NULL
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
       party_id           INT8               NOT NULL,
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


ALTER TABLE "User" ADD CONSTRAINT "User_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Person" ("person_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Account" ADD CONSTRAINT "Account_primary_user_id"
  FOREIGN KEY ("primary_user_id") REFERENCES "User" ("user_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Account" ADD CONSTRAINT "Account_domain_id"
  FOREIGN KEY ("domain_id") REFERENCES "Domain" ("domain_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Party" ADD CONSTRAINT "Party_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PartyNote" ADD CONSTRAINT "PartyNote_party_id"
  FOREIGN KEY ("party_id") REFERENCES "Party" ("party_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PartyNote" ADD CONSTRAINT "PartyNote_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "PartyHistory" ADD CONSTRAINT "PartyHistory_party_id"
  FOREIGN KEY ("party_id") REFERENCES "Party" ("party_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PartyHistory" ADD CONSTRAINT "PartyHistory_user_id"
  FOREIGN KEY ("user_id") REFERENCES "User" ("user_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "PartyHistory" ADD CONSTRAINT "PartyHistory_party_history_type_id"
  FOREIGN KEY ("party_history_type_id") REFERENCES "PartyHistoryType" ("party_history_type_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "PartyHistory" ADD CONSTRAINT "PartyHistory_address_id"
  FOREIGN KEY ("address_id") REFERENCES "Address" ("address_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "PartyHistoryType" ADD CONSTRAINT "PartyHistoryType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PartyHistory" ADD CONSTRAINT "PartyHistory_phone_number_id"
  FOREIGN KEY ("phone_number_id") REFERENCES "PhoneNumber" ("phone_number_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Person" ADD CONSTRAINT "Person_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Party" ("party_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Person" ADD CONSTRAINT "Person_household_id"
  FOREIGN KEY ("household_id") REFERENCES "Household" ("household_id")
  ON DELETE SET NULL ON UPDATE CASCADE;

ALTER TABLE "Household" ADD CONSTRAINT "Household_household_id"
  FOREIGN KEY ("household_id") REFERENCES "Party" ("party_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Organization" ADD CONSTRAINT "Organization_organization_id"
  FOREIGN KEY ("organization_id") REFERENCES "Party" ("party_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "OrganizationMember" ADD CONSTRAINT "OrganizationMember_organization_id"
  FOREIGN KEY ("organization_id") REFERENCES "Organization" ("organization_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "OrganizationMember" ADD CONSTRAINT "OrganizationMember_person_id"
  FOREIGN KEY ("person_id") REFERENCES "Person" ("person_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Address" ADD CONSTRAINT "Address_party_id"
  FOREIGN KEY ("party_id") REFERENCES "Party" ("party_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Address" ADD CONSTRAINT "Address_address_type_id"
  FOREIGN KEY ("address_type_id") REFERENCES "AddressType" ("address_type_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "AddressType" ADD CONSTRAINT "AddressType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PhoneNumber" ADD CONSTRAINT "PhoneNumber_party_id"
  FOREIGN KEY ("party_id") REFERENCES "Party" ("party_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PhoneNumber" ADD CONSTRAINT "PhoneNumber_phone_number_type_id"
  FOREIGN KEY ("phone_number_type_id") REFERENCES "PhoneNumberType" ("phone_number_type_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "PhoneNumberType" ADD CONSTRAINT "PhoneNumberType_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Donation" ADD CONSTRAINT "Donation_party_id"
  FOREIGN KEY ("party_id") REFERENCES "Party" ("party_id")
  ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "Donation" ADD CONSTRAINT "Donation_fund_id"
  FOREIGN KEY ("fund_id") REFERENCES "Fund" ("fund_id")
  ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "Fund" ADD CONSTRAINT "Fund_account_id"
  FOREIGN KEY ("account_id") REFERENCES "Account" ("account_id")
  ON DELETE CASCADE ON UPDATE CASCADE;
